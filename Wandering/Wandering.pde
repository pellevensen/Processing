import java.util.SplittableRandom; //<>// //<>// //<>// //<>// //<>//
import java.awt.Rectangle;
import java.awt.GraphicsDevice;
import java.awt.GraphicsEnvironment;
import java.awt.event.InputEvent;
import java.util.Random;
import java.util.Deque;
import java.util.List;
import java.util.Arrays;
import java.util.BitSet;
import java.util.Collections;
import java.util.LinkedList;

// The Voynich microscope:
// tourLengthBase: 41.666664, tourLength: 262144, bifurcationP: 1.0E-6, globalOpacity: 1.0
// scanIncrement: 0, scale: 4, saveScale: 1, deviation: 0.072000004, curveBase: 0.009233277
// pathDeviation: 0.0, refinements: 5393

final static float OPACITY_THRESHOLD = 0.001;

PImage baseImg;
PImage origImg;
PImage paintImg;
int surfaceWidth;
int surfaceHeight;
int panX;
int panY;
float zoom;
int startPanX;
int startPanY;
boolean isRunning;
boolean isPanning;

long findSum = 0;
long finds = 0;

private static class WanderingParams {
  boolean prioritizeSimilar;
  int refinementAttempts;
  boolean avoidUsed;
  boolean edgeCollisionTerminates;
  float pathDeviation;
  int scanIncrement;
  float noiseLevel;
  float curveBase;
  Iterator<Integer> scanPermIt;
  float globalOpacity;
  BitSet used;
  color previousColor;
  float frameWidth;
  boolean followColors;
  int scale;
  int saveScale;
  SplittableRandom rng;
  float deviation;
  float bifurcationProbability;
  float tourLengthBase;
}

WanderingParams wp;

void setup() {
  selectScreen();
  selectInput("Select a file to process:", "fileSelected");
  wp = new WanderingParams();
  wp.rng = new SplittableRandom(1);
  wp.deviation = 0.05;
  wp.bifurcationProbability = 0.01;
  wp.tourLengthBase = 0.1;
  wp.globalOpacity = 1.0;
  wp.scale = 1;
  wp.saveScale = 1;
  zoom = 1;
  wp.curveBase = 0;
  wp.frameWidth = 0.001;
  noLoop();
  wp.used = new BitSet();
  // windowResizable(true);
}

void suspendResume() {
  isRunning = !isRunning;
  if (isRunning) {
    loop();
  } else {
    noLoop();
  }
}

void selectScreen() {
  // Välj monitor (0 = primär, 1 = sekundär, osv.)
  int screenIndex = 1;
  surface.setVisible(false);

  // Hämta alla skärmar
  GraphicsDevice[] gds = GraphicsEnvironment
    .getLocalGraphicsEnvironment()
    .getScreenDevices();

  if (screenIndex < 0 || screenIndex >= gds.length) {
    println("Ogiltigt skärmindex, använder primär skärm.");
    screenIndex = 0;
  }

  // Skärmens bounding box (kan ha negativa x/y om monitor ligger till vänster/uppe)
  Rectangle bounds = gds[screenIndex].getDefaultConfiguration().getBounds();
  println("Bounding box för skärm: " + bounds);
  // Justera storlek om fönstret är större än skärmen
  surfaceWidth = max(width, bounds.width - 50);
  surfaceHeight = max(height, bounds.height - 50);

  // Sätt storlek och position (centrera på vald skärm)
  surface.setSize(surfaceWidth, surfaceHeight);
  println(surface.getClass());
  surface.setLocation(0, 0);
}

void rescale() {
  origImg = baseImg.copy();
  origImg.resize(baseImg.width * wp.scale, baseImg.height * wp.scale);
  paintImg.resize(baseImg.width * wp.scale, baseImg.height * wp.scale);
  origImg.loadPixels();
  for (int pIdx = 0; pIdx < origImg.pixels.length; pIdx++) {
    color c = origImg.pixels[pIdx];
    c = rgbWithHsbTweak(origImg.pixels[pIdx],
      (float) wp.rng.nextGaussian(0, wp.noiseLevel * 10),
      (float) wp.rng.nextGaussian(0, wp.noiseLevel / 5),
      (float) wp.rng.nextGaussian(0, wp.noiseLevel));
    origImg.pixels[pIdx] = c;
  }
  paintImg.loadPixels();
  wp.used = new BitSet();
}

void fileSelected(File selection) {
  if (selection == null) {
    println("Window was closed or the user hit cancel.");
  } else {
    baseImg = loadImage(selection.getAbsolutePath());
    println("Width: " + baseImg.width + ", height: " + baseImg.height);
    float imgRatio = baseImg.width / (float) baseImg.height;
    float windowRatio = surfaceWidth / (float) surfaceHeight;
    println("Image ratio: " + imgRatio + ", displayRatio: " + windowRatio +
      ", surfaceHeight: " + surfaceHeight + ", displayWidth: " + surfaceWidth);
    int w = baseImg.width;
    int h = baseImg.height;

    if (baseImg.width > surfaceWidth || baseImg.height > surfaceHeight) {
      if (imgRatio < windowRatio) {
        // Constrain height.
        h = surfaceHeight;
        w = (int) (baseImg.width * ((float) surfaceHeight / baseImg.height));
      } else {
        w = surfaceWidth;
        h = (int) (baseImg.height * ((float) surfaceWidth / baseImg.width));
      }
    }
    println("w: " + w + ", " + h);
    windowResize(w, h);

    paintImg = createImage(baseImg.width, baseImg.height, RGB);
    rescale();
    surface.setVisible(true);
    loop();
  }
}

int tweak(float v) {
  return (int) (v + wp.rng.nextGaussian(0, wp.deviation));
}

void mouseWheel(MouseEvent event) {
  float e = event.getCount();  // +1 down, -1 up
  float zoomFactor = sqrt(2);

  // compute zoom about the mouse position
  float prevZoom = zoom;
  if (e < 0) {
    zoom *= pow(zoomFactor, -e);
  } else if (e > 0) {
    zoom /= pow(zoomFactor, e);
  }

  // keep zoom reasonable
  zoom = constrain(zoom, 1, 20.0);

  // adjust pan so zoom is centered on mouse
  float dx = mouseX - panX;
  float dy = mouseY - panY;
  float scaleChange = zoom / prevZoom;
  panX -= dx * (scaleChange - 1);
  panY -= dy * (scaleChange - 1);
  clampOffsets();
}

void clampOffsets() {
  float imgW = origImg.width * zoom;
  float imgH = origImg.height * zoom;

  if (imgW >= width) {
    panX = (int) constrain(panX, width - width * zoom, 0);
  } else {
    print("clamp 2x ");
    panX = (int) ((width - imgW) / 2);
  }

  if (imgH >= height) {
    panY = (int) constrain(panY, height - height * zoom, 0);
  } else {
    panY = (int) ((height - imgH) / 2);
  }
}

void mouseReleased() {
  if (mouseButton == CENTER || (mouseButton == LEFT && key == ' ')) {
    isPanning = false;
  }
}

void mouseClicked() {
  if (mouseButton == RIGHT) {
    suspendResume();
    println("isRunning: " + isPanning);
  } else if ((mouseButton == LEFT && key == ' ')) {
    mouseButton = 0;
  }
}

void mouseDragged() {
  if (mouseButton == CENTER || (mouseButton == LEFT && key == ' ')) {
    if (!isPanning) {
      isPanning = true;
      startPanX = mouseX;
      startPanY = mouseY;
    } else {
      panX += mouseX - startPanX;
      panY += mouseY - startPanY;
      startPanX = mouseX;
      startPanY = mouseY;
    }
    clampOffsets();
  }
}

int getTourLength() {
  return (int) min((origImg.width + origImg.height) * 16, max(20, (origImg.width + origImg.height) * wp.tourLengthBase));
}

void showParams() {
  println("tourLengthBase: " + wp.tourLengthBase + ", tourLength: " + getTourLength() + ", bifurcationP: " + wp.bifurcationProbability +
    ", globalOpacity: " + wp.globalOpacity + ", scanIncrement: " + wp.scanIncrement + ", scale: " + wp.scale +
    ", saveScale: " + wp.saveScale + ", deviation: " + wp.deviation + ", curveBase: " + wp.curveBase + ", pathDeviation: " + wp.pathDeviation +
    ", refinements: " + wp.refinementAttempts + ", noiseLevel: " + wp.noiseLevel);
}

void keyReleased() {
  key = 0;
}

void keyPressed(KeyEvent e) {

  if (key == 65535 || key == ' ') {
    // Ignore plain shift key and space.
    return;
  }
  switch(key) {
  case '+':
    wp.tourLengthBase = min(wp.tourLengthBase * 1.2, 50);
    break;
  case  '-':
    wp.tourLengthBase = max(wp.tourLengthBase / 1.2, 1E-8);
    break;
  case '1':
  case '3':
  case '5':
  case '7':
  case '9':
    int width = key - '0';
    if (width == 1) {
      width = 21;
    }
    print("Blurring with width: " + width + "...");
    gaussianBlur(paintImg, width, 1);
    println("Done!");
    break;
  case '0':
  case '2':
  case '4':
  case '6':
  case '8':
    float blend = (key - '0') * 0.1;
    if (blend == 0) {
      blend = 1;
    }
    normalize(paintImg, blend);
    break;
  case 'q':
    wp.frameWidth = max(wp.frameWidth / 1.2, 0.001);
    println("frameWidth: " + wp.frameWidth);
    break;
  case 'Q':
    wp.frameWidth = min(wp.frameWidth * 1.2, 0.1);
    println("frameWidth: " + wp.frameWidth);
    break;
  case 'w':
    frame(0xFFFFFF);
    break;
  case 'W':
    frame(0);
    break;
  case 'F':
    wp.curveBase = constrain(wp.curveBase * 1.2f + 1E-6, 1E-4, TWO_PI);
    break;
  case 'f':
    wp.curveBase = max(0, wp.curveBase / 1.2f - 1E-4);
    break;
  case 'R':
    wp.scanIncrement = max(wp.scanIncrement, 16);
    wp.scanIncrement = min(wp.scanIncrement * 2, origImg.width - 1);
    if (wp.scanIncrement < origImg.width - 1) {
      wp.used = new BitSet();
      wp.scanPermIt = new Perm(getScanMax(), wp.rng.nextInt()).iterator();
    }
    break;
  case 'r':
    wp.scanIncrement = max(wp.scanIncrement / 2, 0);
    if (wp.scanIncrement < 16) {
      wp.scanIncrement = 0;
    }
    if (wp.scanIncrement > 0) {
      wp.used = new BitSet();
      wp.scanPermIt = new Perm(getScanMax(), wp.rng.nextInt()).iterator();
    }
    break;
  case 'D':
    wp.deviation = constrain(wp.deviation * 1.2, 0.0001, 1);
    break;
  case 'd':
    wp.deviation = constrain(wp.deviation / 1.2, 0.0001, 1);
    break;
  case 'T':
    wp.refinementAttempts = (int) (wp.refinementAttempts * 1.5 + 1);
    finds = 0;
    findSum = 0;
    break;
  case 't':
    wp.refinementAttempts = (int) max(wp.refinementAttempts / 1.5 - 1, 0);
    finds = 0;
    findSum = 0;
    break;
  case 'N':
    wp.noiseLevel = wp.noiseLevel * 1.5 + 0.01;
    rescale();
    break;
  case 'n':
    wp.noiseLevel = max(0, wp.noiseLevel / 1.5 - 0.01);
    rescale();
    break;
  case 'Z':
    wp.scale += 1;
    rescale();
    break;
  case 'z':
    wp.scale = max(1, wp.scale - 1);
    rescale();
    break;
  case 'X':
    wp.saveScale += 1;
    break;
  case  'x':
    wp.saveScale = max(1, wp.saveScale - 1);
    break;
  case 'B':
    wp.bifurcationProbability = constrain(wp.bifurcationProbability * 1.5, 0, 1 - 1E-6);
    break;
  case 'b':
    wp.bifurcationProbability = constrain(wp.bifurcationProbability / 1.5, 1E-10, 1 - 1E-6);
    break;
  case 'O':
    wp.globalOpacity = min(wp.globalOpacity * 1.1 + 0.01, 5);
    break;
  case 'o':
    wp.globalOpacity = max(wp.globalOpacity / 1.1, 1E-3);
    break;
  case 's':
    String filename = "Wandering-" + System.currentTimeMillis() + ".png";
    print("Saving " + filename + "... ");
    PImage scaledImg;
    if (wp.saveScale != 1) {
      scaledImg = createImage(paintImg.width / wp.saveScale, paintImg.height / wp.saveScale, RGB);
      scaledImg.copy(paintImg, 0, 0, origImg.width, origImg.height, 0, 0, paintImg.width / wp.saveScale, paintImg.height / wp.saveScale);
    } else {
      scaledImg = paintImg;
    }
    print("\tscaledImg w: " + scaledImg.width + ", h: " + scaledImg.height + ". ");
    scaledImg.save(filename);
    println("Done!");
    break;
  case 'c':
    wp.prioritizeSimilar = !wp.prioritizeSimilar;
    println("prioritize similar: " + wp.prioritizeSimilar);
    break;
  case 'C':
    wp.followColors = !wp.followColors;
    println("follow colors: " + wp.followColors);
    break;
  case 'P':
    wp.pathDeviation = constrain(wp.pathDeviation * 1.2 + 1E-4, 0, 20);
    break;
  case 'p':
    wp.pathDeviation = constrain(wp.pathDeviation / 1.2 - 1E-4, 0, 20);
    break;
  case 'a':
    wp.avoidUsed = !wp.avoidUsed;
    println("avoid used: " + wp.avoidUsed);
    break;
  case 'e':
    wp.edgeCollisionTerminates = !wp.edgeCollisionTerminates;
    println("egde collision terminates: " + wp.edgeCollisionTerminates);
    break;
  case DELETE:
  case BACKSPACE:
    paintImg.loadPixels();
    int v = e.isShiftDown() ? 0xFFFFFF : 0;
    for (int i = 0; i < paintImg.pixels.length; i++) {
      paintImg.pixels[i] = v;
    }
    wp.used = new BitSet();
    break;
  default:
    println("Unknown key: '" + key + "', " + (int) key);
  }
  showParams();
}

int[] findLargeDiscrepancy(int attempts, int size) {
  float maxDiff = 0;
  float diffSum = 0.0;
  int worstX = 0;
  int worstY = 0;
  BitSet checked = new BitSet();

  for (int i = 0; i < attempts; i++) {
    int x;
    int y;
    int p;
    do {
      x = wp.rng.nextInt(0, origImg.width);
      y = wp.rng.nextInt(0, origImg.height);
      p = x + y * paintImg.width;
    } while (checked.get(p));

    for (int xd = -size; xd <= size; xd++) {
      for (int yd = -size; yd <= size; yd++) {
        int xo = constrain(x + xd * wp.scale * 2, 0, paintImg.width - 1);
        int yo = constrain(y + yd * wp.scale * 2, 0, paintImg.height - 1);
        p = xo + yo * paintImg.width;
        checked.set(p);
        float diff = colorDistance(origImg.pixels[p], paintImg.pixels[p]);
        diffSum += diff;
      }
    }
    if (diffSum > maxDiff) {
      worstX = x;
      worstY = y;
      maxDiff = diffSum;
    }
  }

  return new int[] {worstX, worstY};
}

int findCircularPrevious(BitSet s, int idx, boolean v) {
  int found = v ? s.previousSetBit(idx) : s.previousClearBit(idx);
  return 0;
}

int[] findUnused(int attempts) {
  int maxSpan = 0;
  int spanMid = maxSpan / 2;
  int w = origImg.width;
  int h = origImg.height;

  if (wp.used.cardinality() < origImg.width  * origImg.height * 0.01) {
    int p;
    do {
      p = wp.rng.nextInt(1, w * h - 1);
    } while (wp.used.get(p));
    return new int[] {p % w, p / w};
  }
  if (wp.used.cardinality() > 0) {
    for (int j = 0; j < min(wp.used.cardinality(), attempts); j++) {
      int p = wp.rng.nextInt(1, w * h - 1);
      int spanStart = 0;
      if (wp.used.get(p)) {
        spanStart = wp.used.nextClearBit(p);
      } else {
        spanStart = wp.used.previousSetBit(p) + 1;
      }
      int spanEnd = w * h - 1;
      spanEnd = wp.used.nextSetBit(spanStart) - 1;

      int spanLength = spanEnd - spanStart;
      if (spanLength > maxSpan) {
        spanMid = (spanStart + spanEnd) / 2;
        maxSpan = spanLength;
      }
    }
  }
  int x = spanMid % w;
  int y = spanMid / w;
  //  println("used: " + wp.used.get(spanMid) + ", maxSpan: " + maxSpan + ", spanMid: " + spanMid + ", x: " + x + ", y: " + y );
  return new int[] {x, y};
}


void draw() {
  if (paintImg != null && origImg != null) {
    paintImg.loadPixels();
    int tourLength = getTourLength();
    long startTime = System.currentTimeMillis();
    while (System.currentTimeMillis() - startTime < 100) {
      int x = wp.rng.nextInt(0, origImg.width);
      int y = wp.rng.nextInt(0, origImg.height);
      if (mousePressed && mouseButton == LEFT && key != ' ') {
        int scaledX = (int) ((mouseX - panX) / zoom);
        int scaledY = (int) ((mouseY - panY) / zoom);
        x = (int) constrain((int) (wp.rng.nextGaussian(scaledX, baseImg.width * 0.01) * origImg.width / width), 0, origImg.width - 1);
        y = (int) constrain((int) (wp.rng.nextGaussian(scaledY, baseImg.height * 0.01) * origImg.height / height), 0, origImg.height - 1);
        wp.previousColor = origImg.get(x, y);
      } else {
        if (!wp.prioritizeSimilar) {
          if (wp.scanIncrement == 0) {
            if (wp.refinementAttempts > 0) {
              // Test med 472 försök, radie 0.
              // Test med 472 försök, radie 5.
              // Test med 472 försök, radie 3.
              // Test med 139 försök, radie 3, mul 2.
              long beginFind = System.nanoTime();
              int[] xy = findLargeDiscrepancy(wp.refinementAttempts, 2);
              x = xy[0];
              y = xy[1];
              long nanosInFind = System.nanoTime() - beginFind;
              findSum += nanosInFind;
              finds++;
            } else if (wp.avoidUsed) {
              if (!wp.used.get(0)) {
                x = 0;
                y = 0;
                wp.used.set(x + y * origImg.width);
              } else if (!wp.used.get(origImg.width * origImg.height - 1)) {
                x = origImg.width - 1;
                y = origImg.height - 1;
                wp.used.set(x + y * origImg.width);
              } else {
                int[] xy = findUnused(10);
                x = xy[0];
                y = xy[1];
                wp.used.set(x + origImg.width * y);
                if (wp.used.cardinality() / (float) (origImg.width * origImg.height) > 0.9999) {
                  wp.used.clear();
                  println("Used bitmap close to full, clearing.");
                }
              }
            }
          } else {
            int scanMax = getScanMax();
            if (wp.scanPermIt == null) {
              wp.scanPermIt = new Perm(scanMax, wp.rng.nextInt()).iterator();
            }
            if (!wp.scanPermIt.hasNext()) {
              wp.scanIncrement /= 2;
              showParams();
              if (wp.scanIncrement >= 8) {
                scanMax = getScanMax();
                wp.scanPermIt = new Perm(scanMax, wp.rng.nextInt()).iterator();
              } else {
                wp.scanIncrement = 0;
              }
            }
            if (wp.scanIncrement >= 8) {
              int scanPos = wp.scanPermIt.next();
              x = constrain(scanPos % (origImg.width / wp.scanIncrement) * wp.scanIncrement,
                0, origImg.width - 1);
              y = constrain(scanPos / (origImg.width / wp.scanIncrement) * wp.scanIncrement,
                0, origImg.height - 1);
            }
          }
        } else {
          int bestX = 0;
          int bestY = 0;
          float bestDiff = Float.POSITIVE_INFINITY;
          for (int cIdx = 0; cIdx < 50; cIdx++) {
            int cx = wp.rng.nextInt(0, origImg.width);
            int cy = wp.rng.nextInt(0, origImg.height);
            float diff = colorDistance(wp.previousColor, origImg.get(cx, cy));
            if (diff < bestDiff) {
              bestX = cx;
              bestY = cy;
              bestDiff = diff;
            }
          }
          x = bestX;
          y = bestY;
        }
      }
      color c = origImg.get(x, y);
      if (!wp.prioritizeSimilar) {
        wp.previousColor = lerpColor(wp.previousColor, c, 0.01);
      }
      color cNew = rgbWithHsbTweak(c, (float) wp.rng.nextGaussian(0, wp.deviation * 100), (float) wp.rng.nextGaussian(0, wp.deviation), 0);
      wp.used.set(x + y * origImg.width);
      if (wp.followColors) {
        println("followColors not supported yet!");
        // wanderFollow(x, y, cNew, tourLength);
      } else if (wp.curveBase > 0) {
        wander3(x, y, cNew, tourLength);
      } else if (wp.pathDeviation > 0) {
        wander1(x, y, cNew, tourLength);
      } else {
        wander2(x, y, cNew, tourLength);
      }
    }
    paintImg.updatePixels();
    if (zoom == 1) {
      image(paintImg, 0, 0, width, height);
    } else {
      pushMatrix();
      translate(panX, panY);
      scale(zoom);
      image(paintImg, 0, 0, width, height);
      popMatrix();
    }
  }
  if (frameCount % 10 == 0 && finds > 0 && wp.refinementAttempts > 0) {
    println("Time spent in findLargeDifference: " + (findSum / (float) finds / 1000000) + " ms.");
  }
}

int getScanMax() {
  if (wp.scanIncrement < 1) {
    return 0;
  }
  return (origImg.width / wp.scanIncrement) * (origImg.height / wp.scanIncrement);
}

float getOpacity(int currentStep, int tourLength) {
  return wp.globalOpacity <= 0 ? 0 : (float) wp.globalOpacity * (1 - barron(currentStep / (float) tourLength, 16 / wp.globalOpacity, 0));
}

// Painterly: tourLengthBase: 12.0, tourLength: 245028, bifurcationP: 0.010000001, globalOpacity: 1.0, scanIncrement: 128, scale: 7, saveScale: 1, deviation: 0.05, curveBase: 0.0, pathDeviation: 0.0, refinements: 3571, noiseLevel: 0.039475307

void frame(color frameColor) {
  boolean oldEdgeTermination = wp.edgeCollisionTerminates;
  wp.edgeCollisionTerminates = true;
  int edgeOffset = (int) ((origImg.width + origImg.height) * wp.frameWidth);
  wp.globalOpacity = 1;
  float oldTourLengthBase = wp.tourLengthBase;
  wp.tourLengthBase = edgeOffset * 0.1;
  print("edgeOffset: " + edgeOffset + ", ");
  for (int base = 0; base < edgeOffset; base++) {
    for (int x = base; x < origImg.width; x += 4 + base) {
      wander2(x, base, frameColor, getTourLength());
      wander2(x, origImg.height - base - 1, frameColor, getTourLength());
    }
    for (int y = base; y < origImg.height; y += 4 + base) {
      wander2(base, y, frameColor, getTourLength());
      wander2(origImg.width - base - 1, y, frameColor, getTourLength());
    }
    print(edgeOffset - base - 1 + ", ");
  }
  println("Done framing!");
  println("Frame made, suspending!");
  isRunning = false;
  noLoop();
  wp.edgeCollisionTerminates = oldEdgeTermination;
  wp.tourLengthBase = oldTourLengthBase;
}

void wander1(int x, int y, color cNew, int tourLength) {
  float xp = x;
  float yp = y;
  float[] xs = {0.0, 0.19509032, 0.38268346, 0.55557024,
    0.70710677, 0.83146966, 0.9238795, 0.9807853,
    1.0, 0.98078525, 0.9238795, 0.83146954,
    0.70710677, 0.5555702, 0.38268328, 0.19509031,
    -8.742278E-8, -0.19509049, -0.38268343, -0.5555703,
    -0.7071069, -0.8314698, -0.9238797, -0.98078525,
    -1.0, -0.98078525, -0.92387944, -0.8314695,
    -0.70710653, -0.5555703, -0.38268343, -0.19509023};
  float[] ys = {1.0, 0.98078525, 0.9238795, 0.83146954,
    0.70710677, 0.5555702, 0.38268328, 0.19509031,
    -8.742278E-8, -0.19509049, -0.38268343, -0.5555703,
    -0.7071069, -0.8314698, -0.9238797, -0.98078525,
    -1.0, -0.98078525, -0.92387944, -0.8314695,
    -0.70710653, -0.5555703, -0.38268343, -0.19509023,
    0.0, 0.19509032, 0.38268346, 0.55557024,
    0.70710677, 0.83146966, 0.9238795, 0.9807853};

  float dir = wp.rng.nextInt(0, xs.length);
  double opacity = 1.0;
  List<Integer> bifurcationPoints = new LinkedList<>();

  for (int steps = 0; steps < tourLength; steps++) {
    opacity = getOpacity(steps, tourLength);
    if (opacity < OPACITY_THRESHOLD) {
      return;
    }
    color cOld = paintImg.get((int) xp, (int) yp);
    color cMix = lerpColor(cOld, cNew, min(1.0, (float) (wp.globalOpacity * opacity)));
    paintImg.set((int) xp, (int) yp, cMix);
    bifurcationPoints.add((int) xp + (int) yp * origImg.width);
    if (wp.rng.nextFloat() < wp.bifurcationProbability) {
      int p = bifurcationPoints.remove(wp.rng.nextInt(bifurcationPoints.size() / 2, bifurcationPoints.size()));
      xp = p % origImg.width;
      yp = p / origImg.width;
      dir += (wp.rng.nextInt(0, 2) - 1) * 3;
    }
    if (wp.pathDeviation > 0) {
      dir = (dir + (float) wp.rng.nextGaussian(0, wp.pathDeviation) + xs.length) % xs.length;
    } else {
      dir = (dir + wp.rng.nextInt(-2, 3) * 0.5 + xs.length) % xs.length;
    }
    float xd = xs[(int) dir];
    float yd = ys[(int) dir];
    xp = constrain(xp + xd, 0, origImg.width - 1);
    yp = constrain(yp + yd, 0, origImg.height - 1);
  }
}

void wander2(int x, int y, color cNew, int tourLength) {
  int[] xs = {1, 1, 0, -1, -1, -1, 0, 1};
  int[] ys = {0, -1, -1, -1, 0, 1, 1, 1};
  int[] dos = shuffle(xs.length);
  List<Integer> ps = new LinkedList<>();
  BitSet visited = new BitSet();
  float opacity = 1.0;

  for (int steps = 0; steps < tourLength; steps++) {
    opacity = getOpacity(steps, tourLength);
    if (opacity < OPACITY_THRESHOLD) {
      return;
    }
    color cOld = paintImg.get(x, y);
    visited.set(x + y * origImg.width);
    ps.add(x + y * origImg.width);
    color cMix = lerpColor(cOld, cNew, opacity);
    paintImg.set(x, y, cMix);
    int d = wp.rng.nextInt(xs.length);
    int xd = xs[d];
    int yd = ys[d];
    if (!wp.edgeCollisionTerminates) {
      x = (x + xd + origImg.width) % origImg.width;
      y = (y + yd + origImg.height) % origImg.height;
    } else {
      x = x + xd;
      y = y + yd;
      if (isOutOfBounds(x, y)) {
        return;
      }
    }
    while (visited.get(x + y * origImg.width)) {
      int cx = 0;
      int cy = 0;
      if (wp.rng.nextFloat() < wp.bifurcationProbability && !ps.isEmpty()) {
        // Bifurcate.
        int p = ps.remove(wp.rng.nextInt(ps.size() / 2, ps.size()));
        x = p % origImg.width;
        y = p / origImg.width;
      }
      for (int i = 0; i < xs.length; i++) {
        if (!wp.edgeCollisionTerminates) {
          cx = (x + xs[dos[i]] + origImg.width) % origImg.width;
          cy = (y + ys[dos[i]] + origImg.height) % origImg.height;
        } else {
          cx = x + xs[dos[i]];
          cy = y + ys[dos[i]];
          if (isOutOfBounds(cx, cy)) {
            return;
          }
        }
        if (!visited.get(cx + cy * origImg.width)) {
          break;
        }
      }
      if (cx != x || cy != y) {
        x = cx;
        y = cy;
        break;
      }
      dos = shuffle(xs.length);
      //      Collections.shuffle(ps, new Random(10));
      int p = ps.remove(wp.rng.nextInt(ps.size() / 2, ps.size()));
      x = p % origImg.width;
      y = p / origImg.width;
    }
  }
}

// Whisks: tourLengthBase: 0.16939592, tourLength: 3458, bifurcationP: 1.2783398E-5, globalOpacity: 1.0, scanIncrement: 0, scale: 7, saveScale: 1, deviation: 0.05, curveBase: 0.0033495426, pathDeviation: 0.0, refinements: 5393, noiseLevel: 0.0

void wander3(int x, int y, color cNew, int tourLength) {
  //  float thetaBase = wp.rng.nextFloat(-PI, PI);
  float thetaBase = (float) wp.rng.nextGaussian(PI / 2, 1);
  float theta = 0;
  float curveAngle = (float) ((wp.rng.nextBoolean() ? wp.curveBase : -wp.curveBase) * wp.rng.nextGaussian(1, 0.001));
  float curveIncrement = (curveAngle < 0 ? -wp.curveBase : wp.curveBase) / origImg.width;
  float opacity;
  float angleScale = 10000.0 / (origImg.width * origImg.height) * curveIncrement;
  double decay = (float) Math.pow(0.001, 1.0 / tourLength);
  List<Integer> ps = new LinkedList<>();
  BitSet painted = new BitSet();
  float ox = x;
  float oy = y;
  float xs = x;
  float ys = y;

  for (int steps = 0; steps < tourLength; steps++) {
    opacity = getOpacity(steps, tourLength);
    if (opacity < OPACITY_THRESHOLD) {
      return;
    }
    ps.add((int) xs + (int) ys * origImg.width);
    int xt = (int) xs;
    int yt = (int) ys;
    if (!wp.edgeCollisionTerminates || (xt >= 0 && xt < origImg.width && yt >= 0 && yt < origImg.height)) {
      color cOld = paintImg.get(xt, yt);
      color cMix = lerpColor(cOld, cNew, min(1.0, opacity));
      paintImg.set(xt, yt, cMix);
      painted.set(xt + origImg.width * yt);
    }

    theta += curveAngle;
    xs += sin(thetaBase + theta);
    ys += cos(thetaBase + theta);
    if (wp.edgeCollisionTerminates && isOutOfBounds((int) xs, (int) ys)) {
      if (!ps.isEmpty()) {
        int p = ps.remove(wp.rng.nextInt(ps.size() / 2, ps.size()));
        xs = p % origImg.width;
        ys = p / origImg.width;
        curveAngle = Math.signum(-curveAngle) * wp.curveBase;
        curveIncrement *= -1;
      } else {
        return;
      }
    } else {
      xs = (xs + origImg.width) % origImg.width;
      ys = (ys + origImg.height) % origImg.height;
    }
    if (wp.rng.nextFloat() < wp.bifurcationProbability * decay * pow(pow(xs - ox, 2) + pow(ys - oy, 2), 0.7) && !ps.isEmpty()) {
      int p = ps.remove(wp.rng.nextInt(ps.size() / 2, ps.size()));
      xs = p % origImg.width;
      ys = p / origImg.width;
      curveAngle = Math.signum(-curveAngle) * wp.curveBase;
      curveIncrement *= -1;
    }
    curveAngle += curveIncrement;
    curveAngle -= (pow(xs - ox, 2) + pow(ys - oy, 2)) * angleScale;
  }
}

boolean isOutOfBounds(int x, int y) {
  return x < 0 || x >= origImg.width || y < 0 || y >= origImg.height;
}

int[] shuffle(int size) {
  int[] perm = new int[size];
  for (int i = 0; i < size; i++) {
    perm[i] = i;
  }
  for (int i = size - 1; i > 0; i--) {
    float x = wp.rng.nextFloat();
    int r = (int) (barron(x, 0.3, 0) * (i + 1));

    int t = perm[r];
    perm[r] = perm[i];
    perm[i] = t;
  }
  return perm;
}
