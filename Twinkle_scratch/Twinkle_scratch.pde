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

final int MAX_TWINKLES = 500;

int origWidth;
int origHeight;

PGraphics twinkleImg;
PImage origImg;
SplittableRandom rng;
int surfaceWidth;
int surfaceHeight;
List<Twinkle> twinkles;

void setup() {
  size(500, 500, P2D);
  selectScreen();
  selectInput("Select a file to process:", "fileSelected");
  rng = new SplittableRandom(1);
  twinkles = new ArrayList<>();
  noLoop();
  frameRate = 1000;
}

void selectScreen() {
  // Välj monitor (0 = primär, 1 = sekundär, osv.)
  int screenIndex = 0;
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
    origWidth = origImg.width;
    origHeight = origImg.height;
    int w = origWidth;
    int h = origHeight;
    float imgRatio = w / (float) h;
    float windowRatio = surfaceWidth / (float) surfaceHeight;
    println("Image ratio: " + imgRatio + ", displayRatio: " + windowRatio +
      ", surfaceHeight: " + surfaceHeight + ", displayWidth: " + surfaceWidth);
    if (w > surfaceWidth || h > surfaceHeight) {
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
    windowResize(origImg.width, origImg.height);

    twinkleImg = createGraphics(origWidth, origHeight);
    for (int i = 0; i < MAX_TWINKLES; i++) {
      twinkles.add(getRandomTwinkle());
    }
    surface.setVisible(true);
    loop();
  }
}

void mouseWheel(MouseEvent event) {
  println("New event: " + event);
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
  } else if (key == '-') {
  } else if (key == 's') {
    String filename = "Twinkle-" + System.currentTimeMillis() + ".png";
    print("Saving " + filename + "... ");
    twinkleImg.save(filename);
    println("Done!");
  } else if (key == 'c') {
  } else if (key == 'a') {
  }
}

Twinkle getRandomTwinkle() {
  int x = rng.nextInt(0, origWidth);
  int y = rng.nextInt(0, origHeight);
  float theta = atan2(x - origWidth / 2, y - origHeight / 2);
  return new Twinkle(x, y,
    rng.nextFloat(0.1, 0.2),
    rng.nextFloat(0.01, 0.05),
    rng.nextFloat(2, 4),
    1,
    theta,
    rng.nextFloat(0, 0.0001 * (float) Math.hypot(origWidth, origHeight)));
}

void draw() {
  if (twinkleImg != null) {
    List<Twinkle> doneTwinkles = new ArrayList<>();
    twinkleImg.beginDraw();
    //  twinkleImg.clear();
    twinkleImg.background(0);
    twinkleImg.blendMode(SCREEN);
    for (Twinkle t : twinkles) {
      t.step(twinkleImg);
      if (t.isDone()) {
        doneTwinkles.add(t);
      }
    }

    for (int i = 0; i < doneTwinkles.size(); i++) {
      twinkles.add(getRandomTwinkle());
    }
    twinkles.removeAll(doneTwinkles);
    twinkleImg.endDraw();

    if (frameCount % 1 == 0) {
      blendMode(REPLACE);
      image(origImg, 0, 0, width, height);
      blendMode(SCREEN);
      image(twinkleImg, 0, 0, width, height);
    }
  }
  if (frameCount % 100 == 0) {
    println("Framerate: " + frameRate);
  }
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
