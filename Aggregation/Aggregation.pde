import java.util.SplittableRandom; //<>// //<>// //<>// //<>//
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

final int MIN_DRAW_USECS = 50;

// Don't touch -- part of basic operations.
PImage baseImg;
PImage origImg;
PImage paintImg;
int scale;
int saveScale;
SplittableRandom rng;
int surfaceWidth;
int surfaceHeight;
int panX;
int panY;
int startPanX;
int startPanY;
boolean isRunning;
boolean isPanning;
float zoom;
// End of bookkeeping stuff.

int particleX;
int particleY;
// float particleDirection;
color particleColor;
BitSet fixed;
int seeds;
float maxFixedRatio;
int stepsSinceLastHit;
float blurAmount;
float brightnessAmount;

void setup() {
  selectScreen();
  selectInput("Select a file to process:", "fileSelected");
  rng = new SplittableRandom(1);
  scale = 1;
  saveScale = 1;
  zoom = 1;
  noLoop();
  fixed = new BitSet();
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
  generateSeeds(seeds);
  println("New scale, image w: " + origImg.width + ", h: " + origImg.height);
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
    println("Base image width: " + w + ", height: " + h);
    windowResize(w, h);

    paintImg = createImage(baseImg.width, baseImg.height, RGB);
    rescale();
    surface.setVisible(true);
    getNewRandomPosition();
    seeds = (int) (origImg.width * origImg.height * 0.001);
    generateSeeds(seeds);
    maxFixedRatio = 0.1;
    blurAmount = 1.0;
    brightnessAmount = 1.0;
    loop();
  }
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

void showParams() {
  println("scale: " + scale + ", save scale: " + saveScale);
}

void keyReleased() {
  key = 0;
}

void increaseSeeds(float factor) {
  seeds = (int) (max(seeds + 1, seeds * factor));
}

void decreaseSeeds(float factor) {
  seeds = (int) (max(1, min(seeds - 1, seeds / factor)));
}

void keyPressed() {
  if (key == 65535 || key == ' ') {
    // Ignore plain shift key and space (used for panning).
    return;
  }
  switch(key) {
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
  case 'Z':
    scale += 1;
    rescale();
    increaseSeeds(scale / (float) (scale + 1));
    println("scale: " + scale);
    break;
  case 'z':
    scale = max(1, scale - 1);
    rescale();
    decreaseSeeds(scale / (float) (scale - 1));
    println("scale: " + scale);
    break;
  case 'X':
    saveScale += 1;
    println("saveScale: " + saveScale);
    break;
  case  'x':
    saveScale = max(1, saveScale - 1);
    println("saveScale: " + saveScale);
    break;
  case 'D':
    brightnessAmount = min(brightnessAmount * 1.01 + 1E-4, 10);
    println("brightness amount: " + brightnessAmount);
    break;
  case 'd':
    brightnessAmount = max(0.2, brightnessAmount / 1.01);
    println("brightness amount: " + brightnessAmount);
    break;
  case 'B':
    blurAmount = min(blurAmount * 1.1 + 1E-6, 1);
    println("blur amount: " + blurAmount);
    break;
  case 'b':
    blurAmount = max(0, blurAmount / 1.1);
    println("blur amount: " + blurAmount);
    break;
  case 'N':
    increaseSeeds(1.5);
    generateSeeds(seeds);
    println("new seeds: " + seeds);
    break;
  case 'n':
    decreaseSeeds(1.5);
    generateSeeds(seeds);
    println("new seeds: " + seeds);
    break;
  case 'C':
    increaseSeeds(1.1);
    generateSeedCircle(seeds);
    println("new seed circle: " + seeds);
    break;
  case 'c':
    decreaseSeeds(1.1);
    generateSeedCircle(seeds);
    println("new seed circle: " + seeds);
    break;
  case 'F':
    maxFixedRatio = min(1, maxFixedRatio * 1.1);
    println("maxFixedRatio: " + maxFixedRatio);
    break;
  case 'f':
    maxFixedRatio = max(0.001, maxFixedRatio / 1.1);
    println("maxFixedRatio: " + maxFixedRatio);
    break;
  case 's':
    String filename = "Wandering-" + System.currentTimeMillis() + ".png";
    print("Saving " + filename + "... ");
    PImage scaledImg = paintImg.copy();
    scaledImg.resize(baseImg.width * saveScale, baseImg.height * saveScale);
    scaledImg.save(filename);
    println("Done!");
    break;
  case DELETE:
    paintImg.loadPixels();
    for (int i = 0; i < paintImg.pixels.length; i++) {
      paintImg.pixels[i] = 0;
    }
    paintImg.updatePixels();
    break;
  default:
    println("Unknown key: '" + key + "', " + (int) key);
  }
}

void generateSeeds2(int seeds) {
  fixed = new BitSet();
  for (int s = 0; s < seeds; s++) {
    int x = rng.nextInt(0, origImg.width);
    int y = rng.nextInt(0, origImg.height);
    int p = x + y * origImg.width;
    fixed.set(p);
    paintImg.set(x, y, origImg.get(x, y));
  }
  adjust(paintImg, 0, 1, (int) (255 * brightnessAmount));
  gaussianBlur5(paintImg, blurAmount);
}

// TODO: Consider choosing seeds by checking for max differences
// between crystals and origImage.
void generateSeeds(int seeds) {
  fixed = new BitSet();
  for (int s = 0; s < seeds; s++) {
    int x = 0;
    int y = 0;
    int p = 0;
    int bestX = 0;
    int bestY = 0;
    float maxDist = 0;
    for (int i = 0; i < 1000; i++) {
      do {
        x = rng.nextInt(0, origImg.width);
        y = rng.nextInt(0, origImg.height);
        p = x + y * origImg.width;
      } while (fixed.get(p));
      float dist = colorDistance(paintImg.get(x, y), origImg.get(x, y));
      if (dist > maxDist) {
        bestX = x;
        bestY = y;
        maxDist = dist;
      }
    }
    fixed.set(bestX + bestY * origImg.width);
    paintImg.set(bestX, bestY, lerpColor(origImg.get(bestX, bestY), paintImg.get(bestX, bestY), 0.5));
  }
  adjust(paintImg, 0, 1, (int) (255 * brightnessAmount));
  gaussianBlur5(paintImg, blurAmount);
}

void generateSeedCircle(int seeds) {
  fixed = new BitSet();
  int radius = min(origImg.width, origImg.height) / 3;
  for (int s = 0; s < seeds; s++) {
    float theta = TWO_PI * s / (float) seeds;
    int x = (int) (sin(theta) * radius + origImg.width / 2);
    int y = (int) (cos(theta) * radius + origImg.height / 2);
    int p = x + y * origImg.width;
    fixed.set(p);
    paintImg.set(x, y, origImg.get(x, y));
  }
  adjust(paintImg, 0, 1, (int) (255 * brightnessAmount));
  gaussianBlur5(paintImg, blurAmount);
}

int wrapX(int x) {
  return (x + origImg.width) % origImg.width;
}

int wrapY(int y) {
  return (y + origImg.height) % origImg.height;
}

void getNewRandomPosition2() {
  int s = origImg.width * origImg.height;
  float xd;
  float yd;
  float radius1;
  do {
    int p = rng.nextInt(0, s);
    if (rng.nextBoolean()) {
      p = fixed.nextSetBit(p);
      if (p == -1) {
        p = fixed.nextSetBit(0);
      }
    } else {
      p = fixed.previousSetBit(p);
      if (p == -1) {
        p = fixed.previousSetBit(s);
      }
    }
    int x = p % origImg.width;
    int y = p / origImg.width;
    float theta = rng.nextFloat(-PI, PI);
    radius1 = rng.nextFloat(2, 50);
    xd = sin(theta);
    yd = cos(theta);
    particleX = wrapX((int) (x + xd * radius1));
    particleY = wrapY((int) (y + yd * radius1));
    // particleDirection = theta + PI;
  } while (fixed.get(particleX + particleY * origImg.width));

  float radius2 = radius1 * 2;
  particleColor = origImg.get(wrapX((int) (particleX + xd * radius2)), wrapY((int) (particleY + yd * radius2)));
}

void getNewRandomPosition() {
  do {
    particleX = rng.nextInt(0, origImg.width);
    particleY = rng.nextInt(0, origImg.height);
  } while (fixed.get(particleX + particleY * origImg.width));
  particleColor = origImg.get(particleX, particleY);
}

void draw() {
  final int[] xs = {1, 1, 0, -1, -1, -1, 0, 1};
  final int[] ys = {0, -1, -1, -1, 0, 1, 1, 1};

  if (paintImg != null && origImg != null) {
    paintImg.loadPixels();
    long startTime = System.currentTimeMillis();
    // Do drawing stuff for at least MIN_DRAW_USECS
    int newFixed = 0;
    int steps = 0;
    int dir = rng.nextInt(xs.length);
    while (System.currentTimeMillis() - startTime < MIN_DRAW_USECS) {
      steps++;
      stepsSinceLastHit++;
      if (mousePressed && mouseButton == LEFT && key != ' ') {
        int scaledX = (int) (((mouseX - panX) / zoom) * origImg.width / width);
        int scaledY = (int) (((mouseY - panY) / zoom) * origImg.height / height);
        int p = scaledX + scaledY * origImg.width;
        fixed.set(p);
        paintImg.set(scaledX, scaledY, origImg.get(scaledX, scaledY));
      } else {
        int prevX = (int) particleX;
        int prevY = (int) particleY;
        dir = rng.nextInt(xs.length);
        particleX = constrain(particleX + xs[dir], 0, origImg.width - 1);
        particleY = constrain(particleY + ys[dir], 0, origImg.height - 1);
        int p = (int) particleX + (int) particleY * origImg.width;
        if (fixed.get(p)) {
          paintImg.set(prevX, prevY, particleColor);
          int p2 = prevX + prevY * origImg.width;
          fixed.set(p2);
          if (fixed.cardinality() > origImg.width * origImg.height * maxFixedRatio) {
            generateSeeds(seeds);
            println("Ratio achieved! Regenerating seeds.");
          }
          newFixed++;
          getNewRandomPosition();
          stepsSinceLastHit = 0;
        }
      }
      if (stepsSinceLastHit > 50000) {
        getNewRandomPosition();
      }
    }
    if (newFixed == 0) {
      println("x: " + particleX + ", y: " + particleY);
    }
    if (frameCount % 100 == 0 && newFixed > 0) {
      println("New fixed: " + newFixed + ", mean steps till hit: " + (steps / (float) newFixed) +
        ", frameRate: " + frameRate + ", steps/frame: " + steps + ", filled ratio: " +
        fixed.cardinality() / (float) (origImg.width * origImg.height));
      //adjust(paintImg, 0, 1.00, 256);
      //blur(paintImg, 0.001);
      // blur(paintImg, 20.0 / sqrt(origImg.width * origImg.height));
      // gaussianBlur3(paintImg, 100.0 / sqrt(origImg.width * origImg.height));
      //       gaussianBlur3(paintImg, 1);
    }
    paintImg.updatePixels();
    if (frameCount % 4 >= 0) {
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
}

boolean isOutOfBounds(int x, int y) {
  return x < 0 || x >= origImg.width || y < 0 || y >= origImg.height;
}
