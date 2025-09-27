import java.util.SplittableRandom; //<>// //<>// //<>// //<>// //<>// //<>// //<>// //<>// //<>// //<>//
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
import java.util.SortedSet;
import java.util.NavigableSet;
import java.util.TreeSet;
import java.util.LinkedList;
import java.util.concurrent.ConcurrentSkipListSet;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.atomic.AtomicLong;
import java.util.Queue;

// The Voynich microscope:
// tourLengthBase: 41.666664, tourLength: 262144, bifurcationP: 1.0E-6, globalOpacity: 1.0
// scanIncrement: 0, scale: 4, saveScale: 1, deviation: 0.072000004, curveBase: 0.009233277
// pathDeviation: 0.0, refinements: 5393

final static boolean USE_MIXBOX = true;
final static float OPACITY_THRESHOLD = 0.001;
static String SKETCH_ROOT;
static final int MAX_QUEUE_SIZE = 2000;

volatile PImage baseImg;
volatile PImage origImg;
volatile  PImage paintImg;
volatile boolean isRescaling;
float showOriginal;
int surfaceWidth;
int surfaceHeight;
int panX;
int panY;
float zoom;
int startPanX;
int startPanY;
boolean isRunning;
boolean isPanning;
boolean showHUD;
long startTime;
AtomicLong pointsPlotted;

long findSum = 0;
long finds = 0;
long drawnFragments;
long fragmentFrames;
NavigableSet<WeightedCoordinate> differenceCandidates;
BitSet invalidated = new BitSet();
Sobol2 sobol = new Sobol2();
// PointHistogram pointHistogram;
BitSet frozen;
ArrayBlockingQueue<DrawSequence> drawQueue;
ArrayBlockingQueue<WanderP> wanderQueue;
int maxThreads = 0;
List<Thread> wanderThreads;
Thread drawProcessor;

private static class WanderingParams {
  boolean prioritizeSimilar;
  int refinementAttempts;
  boolean avoidUsed;
  boolean edgeCollisionTerminates;
  float pathDeviation;
  boolean useSobol;
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
  float feedback;
}

WanderingParams wp;

void setup() {
  selectScreen();
  selectInput("Select a file to process:", "fileSelected");

  // Store the sketch folder once
  SKETCH_ROOT = sketchPath("");

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
  frozen = new BitSet();
  differenceCandidates = new TreeSet<>();
  drawQueue = new ArrayBlockingQueue<>(MAX_QUEUE_SIZE);
  wanderQueue = new ArrayBlockingQueue<>(MAX_QUEUE_SIZE);
  drawProcessor = drawProcessor(drawQueue);

  wanderThreads = new ArrayList<Thread>();
  resetTimingData();
  drawProcessor.start();
  // windowResizable(true);
  println("Java version: " + System.getProperty("java.version"));
}

private void removeAll() {
  synchronized(differenceCandidates) {
    differenceCandidates.clear();
    invalidated.clear();
  }
}

private WeightedCoordinate removeFirst() {
  synchronized(differenceCandidates) {
    WeightedCoordinate wc;
    float diff;
    do {
      wc = differenceCandidates.first();
      differenceCandidates.remove(wc);
      diff = colorDistance(getColor(wc.x, wc.y), paintImg.get(wc.x, wc.y));
    } while (!differenceCandidates.isEmpty() && Math.abs(diff - wc.weight) > 0.05);
    return wc;
  }
}

private WeightedCoordinate removeLast() {
  synchronized(differenceCandidates) {
    WeightedCoordinate wc = differenceCandidates.last();
    differenceCandidates.remove(wc);
    return wc;
  }
}

private void startWanderThreads() {
  print("Stopping wander threads... ");
  if (maxThreads != wanderThreads.size()) {
    for (int i = 0; i < wanderThreads.size(); i++) {
      wanderThreads.get(i).interrupt();
      try {
        wanderThreads.get(i).join();
      }
      catch(InterruptedException e) {
        // Ignore.
      }
      print(i + " ");
    }
  }
  wanderThreads.clear();
  println("All wander threads stopped.\n");

  for (int i = 0; i < maxThreads; i++) {
    wanderThreads.add(wanderProcessor(this.wanderQueue, this.drawQueue, wp.rng.nextLong()));
    wanderThreads.get(i).start();
  }
}

private void startDifferenceThread() {
  Thread t = new Thread(new Runnable() {
    int w;
    int h;
    Perm perm;
    Iterator<Integer> permIt;
    SplittableRandom dRng = new SplittableRandom(1);
    final int SIZE = 0;
    final float SCALE = (float) (1.0f / Math.pow(2 * SIZE + 1, 2));

    @Override void run() {
      while (true) {
        try {
          if (origImg != null && paintImg != null) {
            if (origImg.width != w || origImg.height != h) {
              w = origImg.width;
              h = origImg.height;
              differenceCandidates = new TreeSet<>();
              print("Setting up perm: ");
              perm = new Perm(h * w, 1);
              permIt = perm.iterator();
              print(" perm done.");
              origImg.loadPixels();
              paintImg.loadPixels();
            }
            if (!permIt.hasNext()) {
              perm = new Perm(h * w, perm.hashCode());
              permIt = perm.iterator();
              invalidated = new BitSet();
              println("Complete scan finished. Restarting.");
            }
            int p = permIt.next();
            if (!frozen.get(p)) {
              int x = p % w;
              int y = p / w;
              float diffSum = 0;
              for (int xd = -SIZE; xd <= SIZE; xd++) {
                for (int yd = -SIZE; yd <= SIZE; yd++) {
                  int xo = constrain(x + xd, 0, w - 1);
                  int yo = constrain(y + yd, 0, h - 1);
                  float diff = colorDistance(getColor(xo, yo), paintImg.get(xo, yo)) + dRng.nextFloat(0, 1E-8);
                  diffSum += diff;
                }
              }
              diffSum *= SCALE;
              synchronized(differenceCandidates) {
                differenceCandidates.add(new WeightedCoordinate(x, y, diffSum));
                if (differenceCandidates.size() > (int) (h * w * 0.05f)) {
                  WeightedCoordinate wc = removeLast();
                  //  println("last: " + wc + " -- first: " + differenceCandidates.first());
                }
              }
            }
          } else {
            try {
              Thread.sleep(10);
            }
            catch(InterruptedException e) {
              // Ignore.
            }
          }
        }
        catch(Exception ex) {
          ex.printStackTrace();
        }
      }
    }
  }
  );
  t.start();
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
  isRescaling = true;
  differenceCandidates = new TreeSet<>();
  try {
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
      paintImg.loadPixels();
      wp.used = new BitSet();
    }
    // pointHistogram = new PointHistogram(origImg.width, origImg.height);
  }
  catch(OutOfMemoryError e) {
    System.err.println("Out of memory. Reverting to scale " + wp.scale + ".");
    wp.scale--;
    // Recover by regenerating images.
    rescale();
  }
  drawQueue.clear();
  wanderQueue.clear();
  isRescaling = false;
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
    startDifferenceThread();
    startTime = System.currentTimeMillis();
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
    println("isRunning: " + isRunning);
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
    ", globalOpacity: " + wp.globalOpacity + ", useSobol: " + wp.useSobol + ", scale: " + wp.scale +
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
  case '?':
    showHUD = !showHUD;
    break;
  case 'q':
    wp.frameWidth = max(wp.frameWidth / 1.2, 0.001);
    println("frameWidth: " + wp.frameWidth);
    break;
  case 'Q':
    wp.frameWidth = min(wp.frameWidth * 1.2, 0.1);
    println("frameWidth: " + wp.frameWidth);
    break;
  case 'i':
    removeAll();
    invalidated.clear();
    wp.used.clear();
    sobol.reset();
    frozen.clear();
    resetTimingData();
    break;
  case 'w':
    frame(0xFFFFFF);
    break;
  case 'W':
    frame(0);
    break;
  case 'K':
    maxThreads = min(maxThreads + 1, 16);
    startWanderThreads();
    println("Increased number of wander threads: " + maxThreads);
    break;
  case 'k':
    maxThreads = max(maxThreads - 1, 0);
    startWanderThreads();
    println("Decreased number of wander threads: " + maxThreads);
    break;
  case 'L':
    wp.feedback = min(wp.feedback * 1.2f + 1E-6, 1);
    break;
  case 'l':
    wp.feedback = max(0, wp.feedback / 1.2f - 1E-4);
    break;
  case 'F':
    wp.curveBase = constrain(wp.curveBase * 1.2f + 1E-6, 1E-4, TWO_PI);
    break;
  case 'f':
    wp.curveBase = max(0, wp.curveBase / 1.2f - 1E-4);
    break;
  case 'R':
    sobol.reset();
    wp.useSobol = true;
    break;
  case 'r':
    wp.useSobol = false;
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
    //  case 'g':
    //    println("\t\tFinding largest hits, " + frozen.cardinality() + " frozen.");
    ////     List<IntPoint2D> maxHits = pointHistogram.getSortedPoints(origImg.width, false, frozen);
    //    paintImg.loadPixels();
    //    origImg.loadPixels();
    //    int maxMax = 0;
    //    for (IntPoint2D p : maxHits) {
    //      //      println("x: " + p.x + ", y: " + p.y + ", hits: " + pointHistogram.getHits(p.x, p.y));
    //      wander2s(p.x, p.y, getColor(p.x, p.y));
    //      frozen.set(p.x + p.y * origImg.width);
    //      maxMax = Math.max(maxMax, pointHistogram.getHits(p.x, p.y));
    //    }
    //    paintImg.updatePixels();
    //    println("Frozen: " + frozen.cardinality() + ", maxHits: " + maxMax);
    //    break;
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
  case 'U':
    showOriginal = min(showOriginal * 1.1 + 0.01, 1);
    break;
  case 'u':
    showOriginal = max(showOriginal / 1.1 - 0.01, 0);
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
    removeAll();
    break;
  default:
    println("Unknown key: '" + key + "', " + (int) key);
  }
  showParams();
  fragmentFrames = 0;
  drawnFragments = 0;
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

void updateCanvas() {
  if (zoom == 1) {
    image(paintImg, 0, 0, width, height);
    if (showOriginal > 0) {
      tint(255.0, showOriginal * 255);  // Apply transparency without changing color
      image(origImg, 0, 0, width, height);
      tint(255.0, 255);
    }
  } else {
    pushMatrix();
    translate(panX, panY);
    scale(zoom);
    image(paintImg, 0, 0, width, height);
    if (showOriginal > 0) {
      tint(255.0, showOriginal * 255);  // Apply transparency without changing color
      image(origImg, 0, 0, width, height);
      tint(255.0, 255);
    }
    popMatrix();
  }
  if (showHUD) {
    displayHud(wp);
  }
}

color getColor(int x, int y) {
  while (isRescaling) {
    try {
      Thread.sleep(10);
    }
    catch(InterruptedException ie) {
      // Do nothing.
    }
  }
  int wo = origImg.width;
  int ho = origImg.height;
  int wpa = paintImg.width;
  int hpa = paintImg.height;
  if (wo != wpa || ho != hpa) {
    return 0xFF000000;
    //    println("Uh oh 1 wo: " + wo + ", wp: " + wpa + ", ho: " + ho + ", hp: " + hpa);
  }
  if (x < 0 || x >= wo || x >= wpa || y < 0 || y >= ho || y >= hpa) {
    println("Uh oh! x: " + x + ", y: " + y + ", wo: " + wo + ", ho: " + ho + ", wp: " + wpa + ", hp: " + hpa);
  }

  color orig = origImg.get(x, y);
  color paint = paintImg.get(x, y);

  if (USE_MIXBOX) {
    return Mixbox.lerp(orig, paint, wp.feedback);
  }
  return lerpColor(orig, paint, wp.feedback);
}

void resetTimingData() {
  startTime = System.currentTimeMillis();
  pointsPlotted = new AtomicLong();
}

void draw() {
  try {
    if (paintImg != null && origImg != null) {
      paintImg.loadPixels();

      long startTime = System.currentTimeMillis();
      while (System.currentTimeMillis() - startTime < 100) {
        int x = wp.rng.nextInt(0, origImg.width);
        int y = wp.rng.nextInt(0, origImg.height);
        if (mousePressed && mouseButton == LEFT && key != ' ') {
          int scaledX = (int) ((mouseX - panX) / zoom);
          int scaledY = (int) ((mouseY - panY) / zoom);
          x = (int) constrain((int) (wp.rng.nextGaussian(scaledX, baseImg.width * 0.002) * origImg.width / width), 0, origImg.width - 1);
          y = (int) constrain((int) (wp.rng.nextGaussian(scaledY, baseImg.height * 0.002) * origImg.height / height), 0, origImg.height - 1);
          wp.previousColor = getColor(x, y);
        } else {
          if (!wp.prioritizeSimilar) {
            if (!wp.useSobol) {
              if (wp.refinementAttempts > 0) {
                synchronized(differenceCandidates) {
                  do {
                    if (!differenceCandidates.isEmpty()) {
                      WeightedCoordinate dc = removeFirst();
                      x = dc.x;
                      y = dc.y;
                    } else {
                      x = -1;
                      break;
                    }
                  } while (this.wp.used.get(x + y * origImg.width) && this.invalidated.get(x + y * origImg.width));
                }
                if (x < 0) {
                  x = wp.rng.nextInt(0, origImg.width);
                  y = wp.rng.nextInt(0, origImg.height);
                }
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
                  int[] xy = findUnused(1);
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
              if (wp.useSobol) {
                double[] coord = sobol.next();
                x = (int) (coord[0] * origImg.width);
                y = (int) (coord[1] * origImg.height);
              }
            }
          } else {
            int bestX = 0;
            int bestY = 0;
            float bestDiff = Float.POSITIVE_INFINITY;
            for (int cIdx = 0; cIdx < 50; cIdx++) {
              int cx = wp.rng.nextInt(0, origImg.width);
              int cy = wp.rng.nextInt(0, origImg.height);
              float diff = colorDistance(wp.previousColor, getColor(cx, cy));
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
        color c = getColor(x, y);
        if (!wp.prioritizeSimilar) {
          wp.previousColor = lerpColor(wp.previousColor, c, 0.01);
        }
        color cNew = rgbWithHsbTweak(c, (float) wp.rng.nextGaussian(0, wp.deviation * 100), (float) wp.rng.nextGaussian(0, wp.deviation), 0);
        wp.used.set(x + y * origImg.width);
        this.invalidated.set(x + y  * origImg.width);
        if (maxThreads > 0) {
          final int xp = x;
          final int yp = y;
          final int cw = cNew;
          if (wp.followColors) {
            println("followColors not supported yet!");
            // wanderFollow(x, y, cNew, tourLength);
          } else if (wp.curveBase > 0) {
            wanderQueue.put(new WanderP(cw, (rng) ->  wander3p(xp, yp, cw, rng)));
          } else if (wp.pathDeviation > 0) {
            wanderQueue.put(new WanderP(cw, (rng) ->  wander1p(xp, yp, cw, rng)));
          } else {
            wanderQueue.put(new WanderP(cw, (rng) ->  wander2p(xp, yp, cw, rng)));
          }
        } else {
          if (wp.followColors) {
            println("followColors not supported yet!");
            // wanderFollow(x, y, cNew, tourLength);
          } else if (wp.curveBase > 0) {
            pointsPlotted.addAndGet( wander3s(x, y, cNew));
          } else if (wp.pathDeviation > 0) {
            pointsPlotted.addAndGet(wander1s(x, y, cNew));
          } else {
            pointsPlotted.addAndGet(wander2s(x, y, cNew));
            //          wander2s(x, y, cNew);
          }
        }

        drawnFragments++;
      }
      paintImg.updatePixels();
      updateCanvas();
      fragmentFrames++;
    }
    if (frameCount % 10 == 0) {
      println("MPoints/sec: " + getMPixelThroughput() + ", candidates: " + differenceCandidates.size() + ", fragments / frame: " + (float) (drawnFragments / fragmentFrames) +
        "\tenqueued wanders: " + wanderQueue.size() + ", draw queue: " + drawQueue.size());
    }
  }
  catch(Exception e) {
    e.printStackTrace();
  }
}

float getMPixelThroughput() {
  float secondsSpent = (System.currentTimeMillis() - startTime) / 1000.0;
  return pointsPlotted.longValue() / (float) (secondsSpent) / 1000000.0;
}

void displayHUDLines(List<String> lines, int size) {
  textSize(size);
  float maxWidth = 0;
  for (String s : lines) {
    maxWidth = max(maxWidth, textWidth(s));
  }

  noStroke();
  fill(0, 128);
  int yPos = height - size * lines.size();
  rect(0, yPos - size, maxWidth + 20, height);
  fill(255, 255);

  for (String s : lines) {
    text(s, 10, yPos);
    yPos += size;
  }
}

void displayHud(WanderingParams wp) {
  float secondsSpent = (System.currentTimeMillis() - startTime) / 1000000.0;

  displayHUDLines(List.of(
    "prioritizeSimilar: " + wp.prioritizeSimilar,
    "refinementAttempts: " + wp.refinementAttempts,
    "avoidUsed: " + wp.avoidUsed + ", used density: " + (wp.used.cardinality() / (float) (origImg.width * origImg.height) * 100) + "%",
    "edgeCollisionTerminates: " + wp.edgeCollisionTerminates,
    "pathDeviation: " + wp.pathDeviation,
    "use Sobol: " + wp.useSobol,
    "noiseLevel: " + wp.noiseLevel,
    "curveBase: " + wp.curveBase,
    "globalOpacity: " + wp.globalOpacity,
    "previousColor: " + (String.format("#%x", wp.previousColor & 0xFFFFFF)),
    "frameWidth: " + wp.frameWidth,
    "scale: " + wp.scale,
    "saveScale: " +wp.saveScale,
    "deviation: " +wp.deviation,
    "bifurcationProbability: " +wp.bifurcationProbability,
    "tourLengthBase: " + wp.tourLengthBase + ", tourLength: " + getTourLength(),
    "feedback: " + wp.feedback,
    "maxThreads: " + maxThreads,
    "base image: " + baseImg.width + " x " + baseImg.height + ", paint image: " + paintImg.width + " x " + paintImg.height,
    "fragments / frame: " + ((float) drawnFragments / fragmentFrames),
    "MPoints/sec: " + getMPixelThroughput(),
    "draw queue size: " + this.drawQueue.size() + ", wander queue size: " + this.wanderQueue.size()
    ), 20);
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
      wander2s(x, base, frameColor);
      wander2s(x, origImg.height - base - 1, frameColor);
    }
    for (int y = base; y < origImg.height; y += 4 + base) {
      wander2s(base, y, frameColor);
      wander2s(origImg.width - base - 1, y, frameColor);
    }
    print(edgeOffset - base - 1 + ", ");
    paintImg.updatePixels();
    updateCanvas();
    redraw();
  }
  println("Done framing!");
  wp.globalOpacity = 0;
  println("Frame made, opacity set to 0.");
  wp.edgeCollisionTerminates = oldEdgeTermination;
  wp.tourLengthBase = oldTourLengthBase;
}

boolean paintImage(int x, int y, int steps, int tourLength, color c) {
  float opacity = getOpacity(steps, tourLength);
  color cOld = paintImg.get(x, y);
  color cMix;

  if (opacity < OPACITY_THRESHOLD) {
    return false;
  }

  if (USE_MIXBOX) {
    cMix = Mixbox.lerp(cOld, c, opacity);
  } else {
    cMix = lerpColor(cOld, c, opacity);
  }
  int p = x + y * origImg.width;
  if (!frozen.get(p)) {
    paintImg.set(x, y, cMix);
    if (opacity > 0.5) {
      wp.used.set(p);
      // pointHistogram.add(p);
      invalidated.set(p);
    }
  }
  return true;
}

boolean paintImage(int x, int y, color c, float opacity) {
  color cOld = paintImg.get(x, y);
  color cMix;

  if (opacity < OPACITY_THRESHOLD) {
    return false;
  }

  if (USE_MIXBOX) {
    cMix = Mixbox.lerp(cOld, c, opacity);
  } else {
    cMix = lerpColor(cOld, c, opacity);
  }
  int p = x + y * origImg.width;
  paintImg.set(x, y, cMix);

  return true;
}
