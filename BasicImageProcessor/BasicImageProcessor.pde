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

final int MIN_DRAW_USECS = 20;

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

void setup() {
  selectScreen();
  selectInput("Select a file to process:", "fileSelected");
  rng = new SplittableRandom(1);
  scale = 1;
  saveScale = 1;
  zoom = 1;
  noLoop();
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
    println("Base image width: " + w + ", height: " + h);
    windowResize(w, h);

    paintImg = createImage(baseImg.width, baseImg.height, RGB);
    rescale();
    surface.setVisible(true);
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
  showParams();
}

void draw() {
  if (paintImg != null && origImg != null) {
    paintImg.loadPixels();
    long startTime = System.currentTimeMillis();
    // Do drawing stuff for at least MIN_DRAW_USECS
    while (System.currentTimeMillis() - startTime < MIN_DRAW_USECS) {
      // Stupid demo: take a random pixel from the original
      // and draw it on the paint image.
      int xOrig = rng.nextInt(0, origImg.width);
      int yOrig = rng.nextInt(0, origImg.height);
      int xPaint = rng.nextInt(0, origImg.width);
      int yPaint = rng.nextInt(0, origImg.height);
      if (mousePressed && mouseButton == LEFT && key != ' ') {
        do {
          int scaledX = (int) (((mouseX - panX) / zoom) * origImg.width / width);
          int scaledY = (int) (((mouseY - panY) / zoom) * origImg.height / height);

          xPaint = (int) (scaledX + rng.nextGaussian(0, (origImg.width + origImg.height) / 200));
          yPaint = (int) (scaledY + rng.nextGaussian(0, (origImg.width + origImg.height) / 200));
        } while (isOutOfBounds(xPaint, yPaint));
      } else {
        xPaint = rng.nextInt(0, origImg.width);
        yPaint = rng.nextInt(0, origImg.height);
      }
      color c = origImg.get(xOrig, yOrig);
      paintImg.set(xPaint, yPaint, c);
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

boolean isOutOfBounds(int x, int y) {
  return x < 0 || x >= origImg.width || y < 0 || y >= origImg.height;
}
