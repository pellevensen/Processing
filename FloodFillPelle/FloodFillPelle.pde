import java.util.BitSet; //<>// //<>//

PImage origImage; //<>// //<>//
PImage img;
PImage screenImg;
float size = 20;
float opacity = 0.1;
int centreX;
int centreY;
float maxDist;
boolean suspendDrawing;
float threshold;

void setup() {
  size(300, 300, P2D);
  img = null;
  origImage = null;
  selectInput("Select a file to process:", "fileSelected");
  frameRate(400);
  noLoop();
}

private static double spare;
private static boolean hasSpare = false;

public static double generateGaussian(double mean, double stdDev) {
  if (hasSpare) {
    hasSpare = false;
    return spare * stdDev + mean;
  } else {
    double u, v, s;
    do {
      u = Math.random() * 2 - 1;
      v = Math.random() * 2 - 1;
      s = u * u + v * v;
    } while (s >= 1 || s == 0);
    s = Math.sqrt(-2.0 * Math.log(s) / s);
    spare = v * s;
    hasSpare = true;
    return mean + stdDev * u * s;
  }
}

private float gauss(int vs) {
  float acc = 0;
  for (int i = 0; i < vs; i++) {
    acc += random(0, 1);
  }

  return acc - vs * 0.5f;
}

void fileSelected(File selection) {
  if (selection == null) {
    println("Window was closed or the user hit cancel.");
  } else {
    origImage = loadImage(selection.getAbsolutePath());
    loop();
  }
}

void mousePressed() {
  println("mouseButton: " + mouseButton);
  if (mouseButton == LEFT) {
    centreX = mouseX;
    centreY = mouseY;
    suspendDrawing = false;
    println("centreX: " + centreX + ", centreY: " + centreY);
  } else if (mouseButton == RIGHT) {
    suspendDrawing = !suspendDrawing;
  } else {
    println("mouseButton: " + mouseButton);
  }
}

void mouseDragged() {
  if (mouseButton == LEFT) {
    centreX = mouseX;
    centreY = mouseY;
    suspendDrawing = false;
  }
}

void mouseWheel(MouseEvent event) {
  threshold = max(1, max(0, threshold * pow(1.05, -event.getCount())));
  size = max(1, size * pow(1.05, -event.getCount()));
}

int toIndex(int x, int y) {
  return x + y * img.width;
}

float distance(color c1, int x2, int y2) {
  color c2 = img.get(x2, y2);

  float rd = ((c1 >>> 16) & 0xFF) -((c2 >>> 16) & 0xFF);
  float gd = ((c1 >>> 8) & 0xFF) -((c2 >>> 8) & 0xFF);
  float bd = ((c1 >>> 0) & 0xFF) -((c2 >>> 0) & 0xFF);

  return pow(rd / 5.0f, 2.0f) + pow(gd / 5.0, 2.0) + pow(bd / 5.0, 2.0);
}

void floodFill(color c, int x, int y) {
  int xd[] = {-1, 0, 1, 0};
  int yd[] = {0, -1, 0, 1};
  java.util.Deque<Integer> positions = new java.util.ArrayDeque<>();
  BitSet seen = new BitSet();

  positions.addLast(toIndex(x, y));

  while (!positions.isEmpty()) {
    int p = positions.removeFirst();
    if (!seen.get(p)) {
      seen.set(p);
      int xa = p % img.width;
      int ya = p / img.width;
      if (distance(c, xa, ya) < threshold) {
        int rn = (int) (red(screenImg.pixels[xa + ya * img.width]) * (1.0f - opacity) + red(c) * opacity);
        int gn = (int) (green(screenImg.pixels[xa + ya * img.width]) * (1.0f - opacity) + green(c) * opacity);
        int bn = (int) (blue(screenImg.pixels[xa + ya * img.width]) * (1.0f - opacity) + blue(c) * opacity);
       
        screenImg.pixels[xa + ya * img.width] = (rn << 16) | (gn << 8) | (bn << 0);
        for (int i = 0; i < xd.length; i++) {
          int xo = xa + xd[i];
          int yo = ya + yd[i];
          if (xo >= 0 && xo < img.width && yo >= 0 && yo < img.height &&
            !seen.get(toIndex(xo, yo)) && distance(c, xo, yo) < threshold) {
            positions.addLast(toIndex(xo, yo));
          }
        }
      }
    }
  }
}

/*
 
 
 seen.set(toIndex(x, y));
 set(x, y, c);
 //  circle(x, y, 2);
 for (int i = 0; i < xd.length; i++) {
 int xo = x + xd[i];
 int yo = y + yd[i];
 if (xo >= 0 && xo < width && yo >= 0 && yo < height &&
 !seen.get(toIndex(xo, yo)) && distance(c, xo, yo) < threshold) {
 //  println("F x: " + x + ", y: " + y + ", c: " + c + ", d: " + distance(c, xo, yo));
 seen.set(toIndex(xo, yo));
 floodFill(c, x0, y0, xo, yo, seen);
 } else {
 // println("x: " + x + ", y: " + y + ", c: " + c + ", d: " + distance(c, xo, yo));
 }
 }
 }
 */

void floodFill(int x, int y) {
  if (x >= 0 && x < img.width && y >= 0 && y < img.height) {
    color c = img.get(x, y);
    floodFill(c, x, y);
  }
}

void draw() {
  // size = max(5, size * 0.999);
  // opacity = max(20, opacity * 0.999);
  if (img == null) {
    if (origImage != null) {
      img = origImage;
      img.resize(0, 1080);
      img.loadPixels();
      centreX = img.width / 2;
      centreY = img.height / 2;
      println("Width: " + img.width + ", height: " + img.height);
      windowResize(img.width, img.height);
      maxDist = dist(0, 0, img.width, img.height);
      suspendDrawing = false;
      image(img, 0, 0);
      screenImg = createImage(img.width, img.height, RGB);
      img.loadPixels();
      screenImg.loadPixels();

      for (int i = 0; i < img.pixels.length; i++) {
        screenImg.pixels[i] = img.pixels[i];
        screenImg.pixels[i] = 0;
      }
      screenImg.updatePixels();
    }
  } else if (!suspendDrawing) {
    //     image(img, 0, 0); // Just display the image.
    screenImg.loadPixels();
    for (int i = 0; i < 400; i++) {
      float r = abs((float) (generateGaussian(0, 10) * size));
      float tau = random(-PI, PI);
      int x = (int) (centreX + cos(tau) * r);
      int y = (int) (centreY + sin(tau) * r);
      //      stroke(img.get(x, y), 30); noFill();
      floodFill(x, y);
    }
    screenImg.updatePixels();
    image(screenImg, 0, 0);
    if (frameCount % 10 == 0) {
      println("frameRate: " + frameRate + ", opacity: " + opacity + ", threshold: " + threshold + ", size: " + size);
    }
  }
}
