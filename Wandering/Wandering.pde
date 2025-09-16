import java.util.SplittableRandom; //<>// //<>// //<>//
import java.awt.Rectangle;
import java.awt.GraphicsDevice;
import java.awt.GraphicsEnvironment;
import java.util.Random;
import java.util.Deque;
import java.util.List;
import java.util.Arrays;
import java.util.BitSet;
import java.util.Collections;
import java.util.LinkedList;

PImage baseImg;
PImage origImg;
PImage paintImg;
int scale;
int saveScale;
SplittableRandom rng;
SplittableRandom rng2;
float deviation;
float bifurcationProbability;
float tourLengthBase;
int surfaceWidth;
int surfaceHeight;
int panX;
int panY;
int startPanX;
int startPanY;
boolean prioritizeSimilar;
boolean avoidUsed;
boolean edgeCollisionTerminates;
boolean isRunning;
boolean isPanning;
float pathDeviation;
int scanIncrement;
float curveBase;
Iterator<Integer> scanPermIt;
float globalOpacity;
BitSet used;
color previousColor;
float zoom;

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
  noLoop();
  used = new BitSet();
  for (int i = 0; i < 32; i++) {
    println(sin(i * TWO_PI / 32));
  }
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
  return (int) (v * rng.nextFloat(1 - deviation, 1 + deviation));
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
  return (int) min(origImg.width + origImg.height, max(20, (origImg.width + origImg.height) * tourLengthBase));
}

void showParams() {
  println("tourLengthBase: " + tourLengthBase + ", tourLength: " + getTourLength() + ", bifurcationP: " + bifurcationProbability +
    ", globalOpacity: " + globalOpacity + ", scanIncrement: " + scanIncrement + ", scale: " + scale +
    ", saveScale: " + saveScale + ", deviation: " + deviation + ", curveBase: " + curveBase + ", pathDeviation: " + pathDeviation);
}

void keyReleased() {
  key = 0;
}

void keyPressed() {
  if (key == 65535 || key == ' ') {
    // Ignore plain shift key.
    return;
  }
  switch(key) {
  case '+':
    tourLengthBase = min(tourLengthBase * 1.2, 50);
    break;
  case  '-':
    tourLengthBase = max(tourLengthBase / 1.2, 1E-8);
    break;
  case '0':
  case '1':
  case '2':
  case '3':
  case '4':
  case '5':
  case '6':
  case '7':
  case '8':
  case '9':
    float blend = (key - '0') * 0.1;
    if (blend == 0) {
      blend = 1;
    }
    normalize(paintImg, blend);
    break;
  case 'F':
    curveBase = constrain(curveBase * 1.2f + 1E-6, 1E-4, TWO_PI);
    break;
  case 'f':
    curveBase = max(0, curveBase / 1.2f - 1E-4);
    break;
  case 'R':
    scanIncrement = max(scanIncrement * 2, 2);
    tourLengthBase = constrain(tourLengthBase * 1.3, 1E-4, 12);
    used = new BitSet();
    scanPermIt = new Perm(getScanMax(), rng.nextInt()).iterator();
    break;
  case 'r':
    scanIncrement = max(scanIncrement / 2, 0);
    tourLengthBase = constrain(tourLengthBase / 1.3, 1E-4, 100);
    used = new BitSet();
    scanPermIt = new Perm(getScanMax(), rng.nextInt()).iterator();
    break;
  case 'D':
    deviation = constrain(deviation * 1.2, 0.0001, 1);
    break;
  case 'd':
    deviation = constrain(deviation / 1.2, 0.0001, 1);
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
    bifurcationProbability = constrain(bifurcationProbability * 1.5, 1E-6, 1 - 1E-6);
    break;
  case 'b':
    bifurcationProbability = constrain(bifurcationProbability / 1.5, 1E-6, 1 - 1E-6);
    break;
  case 'O':
    globalOpacity = min(globalOpacity * 1.1, 2);
    break;
  case 'o':
    globalOpacity = max(globalOpacity / 1.1, 1E-3);
    break;
  case 's':
    String filename = "Wandering-" + System.currentTimeMillis() + ".png";
    print("Saving " + filename + "... ");
    PImage scaledImg = paintImg.copy();
    scaledImg.resize(baseImg.width * saveScale, baseImg.height * saveScale);
    scaledImg.save(filename);
    println("Done!");
    break;
  case 'c':
    prioritizeSimilar = !prioritizeSimilar;
    println("prioritize similar: " + prioritizeSimilar);
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
    paintImg.loadPixels();
    for (int i = 0; i < paintImg.pixels.length; i++) {
      paintImg.pixels[i] = 0;
    }
    break;
  default:
    println("Unknown key: '" + key + "', " + (int) key);
  }
  showParams();
}

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
            if (avoidUsed) {
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
      color cNew = rgbWithHsbTweak(c, (float) rng.nextGaussian(0, deviation * 100), 0, 0);
      if (curveBase > 0) {
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
}

int getScanMax() {
  if (scanIncrement < 1) {
    return 0;
  }
  return (origImg.width / scanIncrement) * (origImg.height / scanIncrement);
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
  float opacity = 1.0;
  float decay = 1.0f / tourLength;
  for (int steps = 0; steps < tourLength; steps++) {
    color cOld = paintImg.get((int) xp, (int) yp);
    color cMix = lerpColor(cOld, cNew, min(1.0, globalOpacity * opacity));
    paintImg.set((int) xp, (int) yp, cMix);
    if (rng.nextFloat() < bifurcationProbability) {
    //  dir = rng.nextInt(0, xs.length);
      xp = x;
      yp = y;
    }
    if (pathDeviation > 0) {
      dir = (dir + (float) rng.nextGaussian(pathDeviation, pathDeviation) + xs.length) % xs.length;
    } else {
      dir = (dir + rng.nextInt(-2, 3) * 0.5 + xs.length) % xs.length;
    }
    float xd = xs[(int) dir];
    float yd = ys[(int) dir];
    xp = constrain(xp + xd, 0, origImg.width - 1);
    yp = constrain(yp + yd, 0, origImg.height - 1);
    opacity -= decay;
  }
}

void wander2(int x, int y, color cNew, int tourLength) {
  int[] xs = {1, 1, 0, -1, -1, -1, 0, 1};
  int[] ys = {0, -1, -1, -1, 0, 1, 1, 1};
  int[] dos = shuffle(xs.length, rng);
  List<Integer> ps = new LinkedList<>();
  BitSet visited = new BitSet();
  float opacity = 1.0;
  float decay = 1.0f / tourLength;

  for (int steps = 0; steps < tourLength; steps++) {
    color cOld = paintImg.get(x, y);
    visited.set(x + y * origImg.width);
    ps.add(x + y * origImg.width);
    color cMix = lerpColor(cOld, cNew, min(1.0, globalOpacity * opacity));
    paintImg.set(x, y, cMix);
    opacity -= decay;
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
        int p = ps.remove(rng.nextInt(ps.size()));
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
      int p = ps.remove(rng.nextInt(ps.size()));
      x = p % origImg.width;
      y = p / origImg.width;
    }
  }
}

void wander3a(int x, int y, color cNew, int tourLength) {
  float thetaBase = rng.nextFloat(-PI, PI);
  float theta = 0;
  float curveAngle = (float) ((rng.nextBoolean() ? curveBase : -curveBase) * rng.nextGaussian(1, 0.001));
  float curveIncrement = (curveAngle < 0 ? -curveBase : curveBase) / origImg.width;
  float opacity = 1.0;
  float angleScale = 1000.0 / (origImg.width * origImg.height) * curveIncrement;
  float decay = 1.0f / tourLength;
  List<Integer> ps = new LinkedList<>();
  BitSet painted = new BitSet();
  float ox = x;
  float oy = y;
  float xs = x;
  float ys = y;

  for (int steps = 0; steps < tourLength; steps++) {
    ps.add((int) xs + (int) ys * origImg.width);

    for (int ix = -scale / 2; ix <= scale / 2; ix++) {
      for (int iy = -scale / 2; iy <= scale / 2; iy++) {
        int xo = (int) (xs + ix);
        int yo = (int) (ys + iy);
        if (xo >= 0 && xo < origImg.width && yo >= 0 && yo < origImg.height) {
          if (!painted.get(xo + origImg.width * yo)) {
            color cOld = paintImg.get(xo, yo);
            color cMix = lerpColor(cOld, cNew, min(1.0, globalOpacity * opacity));
            paintImg.set(xo, yo, cMix);
            painted.set(xo + origImg.width * yo);
          }
        }
      }
    }
    opacity -= decay;
    theta += curveAngle;
    xs = xs + sin(thetaBase + theta);
    ys = ys + cos(thetaBase + theta);
    if (isOutOfBounds((int) xs, (int) ys)) {
      if (!ps.isEmpty()) {
        int p = ps.remove(rng.nextInt(ps.size()));
        xs = p % origImg.width;
        ys = p / origImg.width;
        curveAngle = Math.signum(-curveAngle) * curveBase;
        curveIncrement *= -1;
      } else {
        return;
      }
    }
    if (rng.nextFloat() < bifurcationProbability && !ps.isEmpty()) {
      int p = ps.remove(rng.nextInt(ps.size()));
      xs = p % origImg.width;
      ys = p / origImg.width;
      curveAngle = Math.signum(-curveAngle) * curveBase;
      curveIncrement *= -1;
    }
    curveAngle += curveIncrement;
    curveAngle -= (pow(xs - ox, 2) + pow(ys - oy, 2)) * angleScale;
  }
}

void wander3(int x, int y, color cNew, int tourLength) {
  float thetaBase = rng.nextFloat(-PI, PI);
  float theta = 0;
  float curveAngle = (float) ((rng.nextBoolean() ? curveBase : -curveBase) * rng.nextGaussian(1, 0.001));
  float curveIncrement = (curveAngle < 0 ? -curveBase : curveBase) / origImg.width;
  float opacity = 1.0;
  float angleScale = 10000.0 / (origImg.width * origImg.height) * curveIncrement;
  float decay = 1.0f / tourLength;
  List<Integer> ps = new LinkedList<>();
  BitSet painted = new BitSet();
  float ox = x;
  float oy = y;
  float xs = x;
  float ys = y;

  for (int steps = 0; steps < tourLength; steps++) {
    ps.add((int) xs + (int) ys * origImg.width);

    for (int ix = -scale / 2; ix <= scale / 2; ix++) {
      for (int iy = -scale / 2; iy <= scale / 2; iy++) {
        int xo = (int) (xs + ix);
        int yo = (int) (ys + iy);
        if (xo >= 0 && xo < origImg.width && yo >= 0 && yo < origImg.height) {
          if (!painted.get(xo + origImg.width * yo)) {
            color cOld = paintImg.get(xo, yo);
            color cMix = lerpColor(cOld, cNew, min(1.0, globalOpacity * opacity));
            paintImg.set(xo, yo, cMix);
            painted.set(xo + origImg.width * yo);
          }
        }
      }
    }
    // tourLengthBase: 0.35831818, tourLength: 9755, bifurcationP: 5.8527646E-4, globalOpacity: 1.0, scanIncrement: 0, scale: 3, saveScale: 1, deviation: 0.05, curveBase: 0.0045748698

    opacity -= decay;
    theta += curveAngle;
    xs = xs + sin(thetaBase + theta);
    ys = ys + cos(thetaBase + theta);
    if (isOutOfBounds((int) xs, (int) ys)) {
      if (!ps.isEmpty()) {
        int p = ps.remove(rng.nextInt(ps.size()));
        xs = p % origImg.width;
        ys = p / origImg.width;
        curveAngle = Math.signum(-curveAngle) * curveBase;
        curveIncrement *= -1;
      } else {
        return;
      }
    }
    if (rng.nextFloat() < bifurcationProbability && !ps.isEmpty()) {
      int p = ps.remove(rng.nextInt(ps.size()));
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
