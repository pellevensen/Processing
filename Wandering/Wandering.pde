import java.util.SplittableRandom; //<>// //<>// //<>// //<>//
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

final static float OPACITY_THRESHOLD = 0.01;

PImage baseImg;
PImage origImg;
PImage paintImg;
int surfaceWidth;
int surfaceHeight;
int panX;
int panY;
int startPanX;
int startPanY;

// private static class WanderingParams {
  boolean prioritizeSimilar;
  int refinementAttempts;
  boolean avoidUsed;
  boolean edgeCollisionTerminates;
  boolean isRunning;
  boolean isPanning;
  float pathDeviation;
  int scanIncrement;
  float noiseLevel;
  float curveBase;
  Iterator<Integer> scanPermIt;
  float globalOpacity;
  BitSet used;
  color previousColor;
  float zoom;
  float frameWidth;
  boolean followColors;
  int scale;
  int saveScale;
  SplittableRandom rng;
  float deviation;
  float bifurcationProbability;
  float tourLengthBase;
// }

void setup() {
  selectScreen();
  selectInput("Select a file to process:", "fileSelected");
  rng = new SplittableRandom(1);
  deviation = 0.05;
  bifurcationProbability = 0.01;
  tourLengthBase = 0.1;
  globalOpacity = 1.0;
  scale = 1;
  saveScale = 1;
  zoom = 1;
  curveBase = 0;
  frameWidth = 0.001;
  noLoop();
  used = new BitSet();
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
  origImg.resize(baseImg.width * scale, baseImg.height * scale);
  paintImg.resize(baseImg.width * scale, baseImg.height * scale);
  origImg.loadPixels();
  for (int pIdx = 0; pIdx < origImg.pixels.length; pIdx++) {
    color c = origImg.pixels[pIdx];
    c = rgbWithHsbTweak(origImg.pixels[pIdx], (float) rng.nextGaussian(0, noiseLevel * 10), (float) rng.nextGaussian(0, noiseLevel / 5), (float) rng.nextGaussian(0, noiseLevel));
    //  c = rgbWithHsbTweak(origImg.pixels[pIdx], 0, (float) 0, (float) rng.nextGaussian(0, noiseLevel));
    origImg.pixels[pIdx] = c;
  }
  paintImg.loadPixels();
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
  return (int) (v + rng.nextGaussian(0, deviation));
}

void mouseWheel(MouseEvent event) {
  //  zoom = constrain(zoom - event.getCount(), 1, scale * 4);
  //  if (zoom == 1) {
  //    panX = panY = 0;
  //  } else {
  /*
    int scaledX = (mouseX - panX) / (zoom - 1);
   int scaledY = (mouseY - panY) / (zoom - 1);
   
   panX = -constrain(scaledX, 0, width - 1);
   panY = -constrain(scaledY, 0, height - 1);
   */
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
  return (int) min((origImg.width + origImg.height) * 16, max(20, (origImg.width + origImg.height) * tourLengthBase));
}

void showParams() {
  println("tourLengthBase: " + tourLengthBase + ", tourLength: " + getTourLength() + ", bifurcationP: " + bifurcationProbability +
    ", globalOpacity: " + globalOpacity + ", scanIncrement: " + scanIncrement + ", scale: " + scale +
    ", saveScale: " + saveScale + ", deviation: " + deviation + ", curveBase: " + curveBase + ", pathDeviation: " + pathDeviation +
    ", refinements: " + refinementAttempts + ", noiseLevel: " + noiseLevel);
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
    tourLengthBase = min(tourLengthBase * 1.2, 50);
    break;
  case  '-':
    tourLengthBase = max(tourLengthBase / 1.2, 1E-8);
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
    frameWidth = max(frameWidth / 1.2, 0.001);
    println("frameWidth: " + frameWidth);
    break;
  case 'Q':
    frameWidth = min(frameWidth * 1.2, 0.1);
    println("frameWidth: " + frameWidth);
    break;
  case 'w':
    frame(0xFFFFFF);
    break;
  case 'W':
    frame(0);
    break;
  case 'F':
    curveBase = constrain(curveBase * 1.2f + 1E-6, 1E-4, TWO_PI);
    break;
  case 'f':
    curveBase = max(0, curveBase / 1.2f - 1E-4);
    break;
  case 'R':
    scanIncrement = max(scanIncrement, 16);
    scanIncrement = min(scanIncrement * 2, origImg.width - 1);
    if (scanIncrement < origImg.width - 1) {
      tourLengthBase = constrain(tourLengthBase * 1.3, 1E-4, 12);
      used = new BitSet();
      scanPermIt = new Perm(getScanMax(), rng.nextInt()).iterator();
    }
    break;
  case 'r':
    scanIncrement = max(scanIncrement / 2, 0);
    if (scanIncrement < 16) {
      scanIncrement = 0;
    }
    if (scanIncrement > 0) {
      tourLengthBase = constrain(tourLengthBase / 1.3, 1E-4, 100);
      used = new BitSet();
      scanPermIt = new Perm(getScanMax(), rng.nextInt()).iterator();
    }
    break;
  case 'D':
    deviation = constrain(deviation * 1.2, 0.0001, 1);
    break;
  case 'd':
    deviation = constrain(deviation / 1.2, 0.0001, 1);
    break;
  case 'T':
    refinementAttempts = (int) (refinementAttempts * 1.5 + 1);
    break;
  case 't':
    refinementAttempts = (int) max(refinementAttempts / 1.5 - 1, 0);
    break;
  case 'N':
    noiseLevel = noiseLevel * 1.5 + 0.01;
    rescale();
    break;
  case 'n':
    noiseLevel = max(0, noiseLevel / 1.5 - 0.01);
    rescale();
    break;
  case 'Z':
    scale += 1;
    rescale();
    break;
  case 'z':
    scale = max(1, scale - 1);
    rescale();
    break;
  case 'X':
    saveScale += 1;
    break;
  case  'x':
    saveScale = max(1, saveScale - 1);
    break;
  case 'B':
    bifurcationProbability = constrain(bifurcationProbability * 1.5, 0, 1 - 1E-6);
    break;
  case 'b':
    bifurcationProbability = constrain(bifurcationProbability / 1.5, 1E-10, 1 - 1E-6);
    break;
  case 'O':
    globalOpacity = min(globalOpacity * 1.1 + 0.01, 5);
    break;
  case 'o':
    globalOpacity = max(globalOpacity / 1.1, 1E-3);
    break;
  case 's':
    String filename = "Wandering-" + System.currentTimeMillis() + ".png";
    print("Saving " + filename + "... ");
    PImage scaledImg;
    if (saveScale != 1) {
      scaledImg = createImage(paintImg.width / saveScale, paintImg.height / saveScale, RGB);
      scaledImg.copy(paintImg, 0, 0, origImg.width, origImg.height, 0, 0, paintImg.width / saveScale, paintImg.height / saveScale);
    } else {
      scaledImg = paintImg;
    }
    print("\tscaledImg w: " + scaledImg.width + ", h: " + scaledImg.height + ". ");
    scaledImg.save(filename);
    println("Done!");
    break;
  case 'c':
    prioritizeSimilar = !prioritizeSimilar;
    println("prioritize similar: " + prioritizeSimilar);
    break;
  case 'C':
    followColors = !followColors;
    println("follow colors: " + followColors);
    break;
  case 'P':
    pathDeviation = constrain(pathDeviation * 1.2 + 1E-4, 0, 20);
    break;
  case 'p':
    pathDeviation = constrain(pathDeviation / 1.2 - 1E-4, 0, 20);
    break;
  case 'a':
    avoidUsed = !avoidUsed;
    println("avoid used: " + avoidUsed);
    break;
  case 'e':
    edgeCollisionTerminates = !edgeCollisionTerminates;
    println("egde collision terminates: " + edgeCollisionTerminates);
    break;
  case DELETE:
  case BACKSPACE:
    paintImg.loadPixels();
    int v = e.isShiftDown() ? 0xFFFFFF : 0;
    for (int i = 0; i < paintImg.pixels.length; i++) {
      paintImg.pixels[i] = v;
    }
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
      x = rng.nextInt(0, origImg.width);
      y = rng.nextInt(0, origImg.height);
      p = x + y * paintImg.width;
    } while (checked.get(p));

    for (int xd = -size; xd <= size; xd++) {
      for (int yd = -size; yd <= size; yd++) {
        int xo = constrain(x + xd * scale * 2, 0, paintImg.width - 1);
        int yo = constrain(y + yd * scale * 2, 0, paintImg.height - 1);
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

long findSum = 0;
long finds = 0;

void draw() {
  if (paintImg != null && origImg != null) {
    paintImg.loadPixels();
    int tourLength = getTourLength();
    long startTime = System.currentTimeMillis();
    while (System.currentTimeMillis() - startTime < 100) {
      int x = rng.nextInt(0, origImg.width);
      int y = rng.nextInt(0, origImg.height);
      if (mousePressed && mouseButton == LEFT && key != ' ') {
        int scaledX = (int) ((mouseX - panX) / zoom);
        int scaledY = (int) ((mouseY - panY) / zoom);
        x = (int) constrain((int) (rng.nextGaussian(scaledX, baseImg.width * 0.01) * origImg.width / width), 0, origImg.width - 1);
        y = (int) constrain((int) (rng.nextGaussian(scaledY, baseImg.height * 0.01) * origImg.height / height), 0, origImg.height - 1);
        previousColor = origImg.get(x, y);
      } else {
        if (!prioritizeSimilar) {
          if (scanIncrement == 0) {
            if (refinementAttempts > 0) {
              // Test med 472 försök, radie 0.
              // Test med 472 försök, radie 5.
              // Test med 472 försök, radie 3.
              // Test med 139 försök, radie 3, mul 2.
              long beginFind = System.nanoTime();
              int[] xy = findLargeDiscrepancy(refinementAttempts, 2);
              x = xy[0];
              y = xy[1];
              long nanosInFind = System.nanoTime() - beginFind;
              findSum += nanosInFind;
              finds++;
            } else if (avoidUsed) {
              for (int j = 0; j < 50 && used.get(x + origImg.width * y); j++) {
                x = rng.nextInt(0, origImg.width);
                y = rng.nextInt(0, origImg.height);
              }
              if (used.get(x + origImg.width * y)) {
                used = new BitSet();
                println("Resetting used.");
              } else {
                used.set(x + origImg.width * y);
              }
            }
          } else {
            int scanMax = getScanMax();
            if (scanPermIt == null) {
              scanPermIt = new Perm(scanMax, rng.nextInt()).iterator();
            }
            if (!scanPermIt.hasNext()) {
              scanIncrement /= 2;
              showParams();
              if (scanIncrement >= 8) {
                scanMax = getScanMax();
                scanPermIt = new Perm(scanMax, rng.nextInt()).iterator();
              } else {
                scanIncrement = 0;
              }
            }
            if (scanIncrement >= 8) {
              int scanPos = scanPermIt.next();
              x = constrain(scanPos % (origImg.width / scanIncrement) * scanIncrement + rng.nextInt(-scanIncrement / 4, scanIncrement / 4 + 1),
                0, origImg.width - 1);
              y = constrain(scanPos / (origImg.width / scanIncrement) * scanIncrement + rng.nextInt(-scanIncrement / 4, scanIncrement / 4 + 1),
                0, origImg.height - 1);
            }
          }
        } else {
          int bestX = 0;
          int bestY = 0;
          float bestDiff = Float.POSITIVE_INFINITY;
          for (int cIdx = 0; cIdx < 50; cIdx++) {
            int cx = rng.nextInt(0, origImg.width);
            int cy = rng.nextInt(0, origImg.height);
            float diff = colorDistance(previousColor, origImg.get(cx, cy));
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
      if (!prioritizeSimilar) {
        previousColor = lerpColor(previousColor, c, 0.01);
      }
      color cNew = rgbWithHsbTweak(c, (float) rng.nextGaussian(0, deviation * 100), (float) rng.nextGaussian(0, deviation), 0);
      if (followColors) {
        wanderFollow(x, y, cNew, tourLength);
      } else if (curveBase > 0) {
        wander3(x, y, cNew, tourLength);
      } else if (pathDeviation > 0) {
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
  if (frameCount % 10 == 0 && finds > 0 && refinementAttempts > 0) {
    println(SHIFT + " time spent in findLargeDifference: " + (findSum / (float) finds / 1000000) + " ms.");
  }
}

int getScanMax() {
  if (scanIncrement < 1) {
    return 0;
  }
  return (origImg.width / scanIncrement) * (origImg.height / scanIncrement);
}

float getOpacity(int currentStep, int tourLength) {
  return globalOpacity <= 0 ? 0 : (float) (1 - barron(currentStep / (float) tourLength, 16 / globalOpacity, 0));
}

// Painterly: tourLengthBase: 12.0, tourLength: 245028, bifurcationP: 0.010000001, globalOpacity: 1.0, scanIncrement: 128, scale: 7, saveScale: 1, deviation: 0.05, curveBase: 0.0, pathDeviation: 0.0, refinements: 3571, noiseLevel: 0.039475307

void frame(color frameColor) {
  boolean oldEdgeTermination = edgeCollisionTerminates;
  edgeCollisionTerminates = true;
  int edgeOffset = (int) ((origImg.width + origImg.height) * frameWidth);
  globalOpacity = 1;
  float oldTourLengthBase = tourLengthBase;
  tourLengthBase = edgeOffset * 0.1;
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
  println("Frame made, setting opacity to 0!");
  globalOpacity = 0;
  edgeCollisionTerminates = oldEdgeTermination;
  tourLengthBase = oldTourLengthBase;
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

  float dir = rng.nextInt(0, xs.length);
  double opacity = 1.0;
  List<Integer> bifurcationPoints = new LinkedList<>();

  for (int steps = 0; steps < tourLength; steps++) {
    color cOld = paintImg.get((int) xp, (int) yp);
    color cMix = lerpColor(cOld, cNew, min(1.0, (float) (globalOpacity * opacity)));
    paintImg.set((int) xp, (int) yp, cMix);
    bifurcationPoints.add((int) xp + (int) yp * origImg.width);
    if (rng.nextFloat() < bifurcationProbability) {
      int p = bifurcationPoints.remove(rng.nextInt(bifurcationPoints.size() / 2, bifurcationPoints.size()));
      xp = p % origImg.width;
      yp = p / origImg.width;
      dir += (rng.nextInt(0, 2) - 1) * 3;
    }
    if (pathDeviation > 0) {
      dir = (dir + (float) rng.nextGaussian(0, pathDeviation) + xs.length) % xs.length;
    } else {
      dir = (dir + rng.nextInt(-2, 3) * 0.5 + xs.length) % xs.length;
    }
    float xd = xs[(int) dir];
    float yd = ys[(int) dir];
    xp = constrain(xp + xd, 0, origImg.width - 1);
    yp = constrain(yp + yd, 0, origImg.height - 1);
    if (opacity * globalOpacity < OPACITY_THRESHOLD) {
      return;
    }
  }
}

void wander2(int x, int y, color cNew, int tourLength) {
  int[] xs = {1, 1, 0, -1, -1, -1, 0, 1};
  int[] ys = {0, -1, -1, -1, 0, 1, 1, 1};
  int[] dos = shuffle(xs.length, rng);
  List<Integer> ps = new LinkedList<>();
  BitSet visited = new BitSet();
  float opacity = 1.0;

  for (int steps = 0; steps < tourLength; steps++) {
    color cOld = paintImg.get(x, y);
    visited.set(x + y * origImg.width);
    ps.add(x + y * origImg.width);
    color cMix = lerpColor(cOld, cNew, min(1.0, globalOpacity * opacity));
    paintImg.set(x, y, cMix);
    //  println("step: " + steps + ", opacity: " + opacity + ", globalOpacity: " + globalOpacity + ", ratio to next: " + (opacity / getOpacity(steps, tourLength)));
    opacity = getOpacity(steps, tourLength);
    if (opacity * globalOpacity < OPACITY_THRESHOLD) {
      return;
    }
    int d = rng.nextInt(xs.length);
    int xd = xs[d];
    int yd = ys[d];
    if (!edgeCollisionTerminates) {
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
      if (rng.nextFloat() < bifurcationProbability && !ps.isEmpty()) {
        // Bifurcate.
        int p = ps.remove(rng.nextInt(ps.size() / 2, ps.size()));
        x = p % origImg.width;
        y = p / origImg.width;
      }
      for (int i = 0; i < xs.length; i++) {
        if (!edgeCollisionTerminates) {
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
      dos = shuffle(xs.length, rng);
      //      Collections.shuffle(ps, new Random(10));
      int p = ps.remove(rng.nextInt(ps.size() / 2, ps.size()));
      x = p % origImg.width;
      y = p / origImg.width;
    }
  }
}

void wanderFollow(int x, int y, color cNew, int tourLength) {
  int[] xs = {1, 1, 0, -1, -1, -1, 0, 1};
  int[] ys = {0, -1, -1, -1, 0, 1, 1, 1};
  int[] dos = shuffle(xs.length, rng);
  List<Integer> ps = new LinkedList<>();
  BitSet visited = new BitSet();
  float opacity = 1.0;

  for (int steps = 0; steps < tourLength; steps++) {
    color cOld = paintImg.get(x, y);
    visited.set(x + y * origImg.width);
    ps.add(x + y * origImg.width);
    color cMix = lerpColor(cOld, cNew, min(1.0, globalOpacity * opacity));
    paintImg.set(x, y, cMix);
    opacity = getOpacity(steps, tourLength);
    int d = rng.nextInt(xs.length);
    int xd = xs[d];
    int yd = ys[d];
    if (!edgeCollisionTerminates) {
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
      if (rng.nextFloat() < bifurcationProbability && !ps.isEmpty()) {
        // Bifurcate.
        int p = ps.remove(rng.nextInt(ps.size() / 2, ps.size()));
        x = p % origImg.width;
        y = p / origImg.width;
      }
      for (int i = 0; i < xs.length; i++) {
        if (!edgeCollisionTerminates) {
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
      dos = shuffle(xs.length, rng);
      //      Collections.shuffle(ps, new Random(10));
      int p = ps.remove(rng.nextInt(ps.size() / 2, ps.size()));
      x = p % origImg.width;
      y = p / origImg.width;
    }
  }
}

void wander3(int x, int y, color cNew, int tourLength) {
  //  float thetaBase = rng.nextFloat(-PI, PI);
  float thetaBase = (float) rng.nextGaussian(PI / 2, 1);
  float theta = 0;
  float curveAngle = (float) ((rng.nextBoolean() ? curveBase : -curveBase) * rng.nextGaussian(1, 0.001));
  float curveIncrement = (curveAngle < 0 ? -curveBase : curveBase) / origImg.width;
  double opacity = 1.0 / (scale * scale);
  float angleScale = 10000.0 / (origImg.width * origImg.height) * curveIncrement;
  double decay = (float) Math.pow(0.001, 1.0 / tourLength);
  List<Integer> ps = new LinkedList<>();
  BitSet painted = new BitSet();
  float ox = x;
  float oy = y;
  float xs = x;
  float ys = y;

  for (int steps = 0; steps < tourLength; steps++) {
    ps.add((int) xs + (int) ys * origImg.width);

    for (int ix = (int) -scale / 2; ix <= scale / 2; ix++) {
      for (int iy = (int) -scale / 2; iy <= scale / 2; iy++) {
        int xo = (int) (xs + ix);
        int yo = (int) (ys + iy);
        if (!edgeCollisionTerminates || (xo >= 0 && xo < origImg.width && yo >= 0 && yo < origImg.height)) {
          xo = (xo + origImg.width) % origImg.width;
          yo = (yo + origImg.height) % origImg.height;
          //if (!painted.get(xo + origImg.width * yo)) {
          color cOld = paintImg.get(xo, yo);
          float opacityScale = 1.0f / sqrt((ix * ix + iy * iy)) / (scale * scale / 4);
          color cMix = lerpColor(cOld, cNew, min(1.0, (float) (globalOpacity * opacity * opacityScale)));
          paintImg.set(xo, yo, cMix);
          painted.set(xo + origImg.width * yo);
          // }
        }
      }
    }
    // tourLengthBase: 0.35831818, tourLength: 9755, bifurcationP: 5.8527646E-4, globalOpacity: 1.0, scanIncrement: 0, scale: 3, saveScale: 1, deviation: 0.05, curveBase: 0.0045748698

    opacity = getOpacity(steps, tourLength);
    if (opacity * globalOpacity < OPACITY_THRESHOLD) {
      return;
    }

    theta += curveAngle;
    xs = xs + sin(thetaBase + theta);
    ys = ys + cos(thetaBase + theta);
    if (edgeCollisionTerminates && isOutOfBounds((int) xs, (int) ys)) {
      if (!ps.isEmpty()) {
        int p = ps.remove(rng.nextInt(ps.size() / 2, ps.size()));
        xs = p % origImg.width;
        ys = p / origImg.width;
        curveAngle = Math.signum(-curveAngle) * curveBase;
        curveIncrement *= -1;
      } else {
        return;
      }
    } else {
      xs = (xs + origImg.width) % origImg.width;
      ys = (ys + origImg.height) % origImg.height;
    }
    if (rng.nextFloat() < bifurcationProbability * decay * pow(pow(xs - ox, 2) + pow(ys - oy, 2), 0.7) && !ps.isEmpty()) {
      int p = ps.remove(rng.nextInt(ps.size() / 2, ps.size()));
      xs = p % origImg.width;
      ys = p / origImg.width;
      curveAngle = Math.signum(-curveAngle) * curveBase;
      curveIncrement *= -1;
    }
    curveAngle += curveIncrement;
    curveAngle -= (pow(xs - ox, 2) + pow(ys - oy, 2)) * angleScale;
  }
}

boolean isOutOfBounds(int x, int y) {
  return x < 0 || x >= origImg.width || y < 0 || y >= origImg.height;
}

int[] shuffle(int size, SplittableRandom rng) {
  int[] perm = new int[size];
  for (int i = 0; i < size; i++) {
    perm[i] = i;
  }
  for (int i = size - 1; i > 0; i--) {
    float x = rng.nextFloat();
    int r = (int) (barron(x, 0.3, 0) * (i + 1));

    int t = perm[r];
    perm[r] = perm[i];
    perm[i] = t;
  }
  return perm;
}
