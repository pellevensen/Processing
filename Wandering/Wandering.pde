import java.util.SplittableRandom; //<>//
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

PImage origImg;
PImage paintImg;
SplittableRandom rng;
SplittableRandom rng2;
float deviation;
float decay;
int tourLength;
int surfaceWidth;
int surfaceHeight;
boolean prioritizeSimilar;
boolean avoidUsed;
color previousColor;

void setup() {
  selectScreen();
  selectInput("Select a file to process:", "fileSelected");
  rng = new SplittableRandom(1);
  deviation = 0.2;
  tourLength = 2000;
  noLoop();
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

void fileSelected(File selection) {
  if (selection == null) {
    println("Window was closed or the user hit cancel.");
  } else {
    origImg = loadImage(selection.getAbsolutePath());
    origImg.resize(origImg.width * 2, origImg.height * 2);
    println("Width: " + origImg.width + ", height: " + origImg.height);
    float imgRatio = origImg.width / (float) origImg.height;
    float windowRatio = surfaceWidth / (float) surfaceHeight;
    println("Image ratio: " + imgRatio + ", displayRatio: " + windowRatio +
      ", surfaceHeight: " + surfaceHeight + ", displayWidth: " + surfaceWidth);
    loop();
    int w = origImg.width;
    int h = origImg.height;

    if (origImg.width > surfaceWidth || origImg.height > surfaceHeight) {
      if (imgRatio < windowRatio) {
        // Constrain height.
        h = surfaceHeight;
        w = (int) (origImg.width * ((float) surfaceHeight / origImg.height));
      } else {
        w = surfaceWidth;
        h = (int) (origImg.height * ((float) surfaceWidth / origImg.width));
      }
    }
    println("w: " + w + ", " + h);
    windowResize(w, h);

    paintImg = origImg.copy();
    surface.setVisible(true);
  }
}

int tweak(float v) {
  return (int) (v * rng.nextFloat(1 - deviation, 1 + deviation));
}

void mouseWheel(MouseEvent event) {
  deviation = constrain(deviation - event.getCount() * 0.05, 0.001, 1);
  println("New deviation: " + deviation);
}

void mouseClicked() {
  if (mouseButton == RIGHT) {
    noLoop();
  } else if (mouseButton == LEFT) {
    loop();
  }
}

void keyPressed() {
  if (key == '+') {
    tourLength = (int) max(tourLength + 1, tourLength * 1.2);
  } else if (key == '-') {
    tourLength = (int) max(1, min(tourLength - 1, tourLength / 1.2));
  } else if (key == 's') {
    String filename = "Wandering-" + System.currentTimeMillis() + ".png";
    print("Saving " + filename + "... ");
    PImage scaledImg = paintImg.copy();
    scaledImg.resize(scaledImg.width / 2, scaledImg.height / 2);
    scaledImg.save(filename);
    println("Done!");
  } else if (key == 'c') {
    prioritizeSimilar = !prioritizeSimilar;
    println("prioritze similar: " + prioritizeSimilar);
  } else if (key == 'a') {
    avoidUsed = !avoidUsed;
    println("avoid used: " + avoidUsed);
  }
  println("tourLength: " + tourLength);
}

void draw() {
  if (paintImg != null) {
    origImg.loadPixels();
    paintImg.loadPixels();
    final float decay = pow(1.0f / 256, 1.0 / tourLength) - 1e-12;
    for (int i = 0; i < max(1, 100000 / tourLength); i++) {
      int x;
      int y;
      if (mousePressed && mouseButton == LEFT) {
        x = mouseX * origImg.width / width;
        y = mouseY * origImg.height / height;
      } else {
        if (!prioritizeSimilar) {
          x = rng.nextInt(0, origImg.width);
          y = rng.nextInt(0, origImg.height);
        } else {
          int bestX = 0;
          int bestY = 0;
          float bestDiff = Float.POSITIVE_INFINITY;
          for (int cIdx = 0; cIdx < 5000; cIdx++) {
            int cx = rng.nextInt(0, origImg.width);
            int cy = rng.nextInt(0, origImg.height);
            float diff = colorDistance(previousColor, paintImg.get(cx, cy));
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
      previousColor = lerpColor(previousColor, c, 0.01);
      color cNew = rgbWithHsbTweak(c, rng.nextFloat(0, 360 * deviation), 0, 0);
      if (tourLength < 200) {
        wander1(x, y, cNew, decay);
      } else {
        wander2(x, y, cNew, decay);
      }
    }
    paintImg.updatePixels();
    image(paintImg, 0, 0, width, height);
  }
}

void wander1(int x, int y, color cNew, float decay) {
  float opacity = 1.0;
  for (int steps = 0; steps < tourLength; steps++) {
    color cOld = paintImg.get(x, y);
    color cMix = lerpColor(cOld, cNew, opacity);
    paintImg.set(x, y, cMix);
    int xd = rng.nextInt(-1, 2);
    int yd = rng.nextInt(-1, 2);
    x = constrain(x + xd, 0, origImg.width - 1);
    y = constrain(y + yd, 0, origImg.height - 1);
    opacity = opacity * decay;
  }
}

void wander2(int x, int y, color cNew, float decay) {
  int[] xs = {1, 1, 0, -1, -1, -1, 0, 1, 0};
  int[] ys = {0, -1, -1, -1, 0, 1, 1, 1, -1};
  int[] dos = shuffle(xs.length, rng);
  List<Integer> ps = new LinkedList<>();
  BitSet visited = new BitSet();
  float opacity = 1.0;
  for (int steps = 0; steps < tourLength; steps++) {
    color cOld = paintImg.get(x, y);
    visited.set(x + y * origImg.width);
    ps.add(x + y * origImg.width);
    color cMix = lerpColor(cOld, cNew, opacity);
    paintImg.set(x, y, cMix);
    int d = rng.nextInt(xs.length);
    int xd = xs[d];
    int yd = ys[d];
    x = (x + xd + origImg.width) % origImg.width;
    y = (y + yd + origImg.height) % origImg.height;
    while (visited.get(x + y * origImg.width)) {
      int cx = 0;
      int cy = 0;
      for (int i = 0; i < xs.length; i++) {
        cx = (x + xs[dos[i]] + origImg.width) % origImg.width;
        cy = (y + ys[dos[i]] + origImg.height) % origImg.height;
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
      opacity = opacity * decay;
    }
  }
}

int[] shuffle(int size, SplittableRandom rng) {
  int[] perm = new int[size];
  for(int i = 0; i < size; i++) {
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
