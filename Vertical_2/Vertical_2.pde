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
import javax.swing.JFileChooser;
import java.io.FileWriter;
import java.io.Writer;
import java.io.FileReader;
import java.io.Reader;
import java.util.Scanner;
import java.util.Set;
import java.util.HashSet;

final int MIN_DRAW_USECS = 20;

// Don't touch -- zooming and panning.
PImage baseImg;
PImage origImg;
PImage paintImg;
int scale = 1;
int saveScale = 1;
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

// Here comes our own variables...
Set<File> files = new HashSet<>();
List<PImage> images = new ArrayList<>();
final String CONF_FILE_NAME = "./vertical-conf.txt";
final String PATH_ID = "lastUsedDirectory:";
int imageIdx;

void setup() {
  selectScreen();

  File path = readLatestDirectory();
  if (path == null) {
    path = new File(sketchPath());
  }
  println(path);
  File[] newFiles = addFiles(path);
  saveLatestDirectory(newFiles[0]);

  for (File f : newFiles) {
    files.add(f);
  }

  readImageFiles();

  rng = new SplittableRandom(1);
  scale = 1;
  saveScale = 1;
  zoom = 1;
  noLoop();
}

void readImageFiles() {
  for (File f : files) {
    PImage img = loadImage(f.getAbsolutePath());
    // Processing reports files that can't be read so we don't have to.
    if (img != null) {
      images.add(img);
    }
  }
  adjustWindow();
}

void saveLatestDirectory(File f) {
  try (Writer w = new FileWriter(sketchPath() + "/" + CONF_FILE_NAME)) {
    w.write(PATH_ID + f.getAbsoluteFile().getParent());
  }
  catch(IOException ex) {
    ex.printStackTrace();
  }
}

File readLatestDirectory() {
  try (Scanner s = new Scanner(new File(sketchPath() + "/" + CONF_FILE_NAME))) {
    s.skip(PATH_ID);
    File path = new File(s.nextLine());
    return path;
  }
  catch(IOException ex) {
    ex.printStackTrace();
    return null;
  }
}

File[] addFiles(File path) {
  JFileChooser chooser = new JFileChooser(path);
  chooser.setMultiSelectionEnabled(true);   // <-- allow multiple
  chooser.setFileSelectionMode(JFileChooser.FILES_ONLY);

  int result = chooser.showOpenDialog(null);

  if (result == JFileChooser.APPROVE_OPTION) {
    File[] files = chooser.getSelectedFiles();
    return files;
  } else {
    println("No files chosen.");
    return new File[0];
  }
}

void adjustWindow() {
  baseImg = images.get(0);
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
  case BACKSPACE:
    paintImg.loadPixels();
    for (int i = 0; i < paintImg.pixels.length; i++) {
      paintImg.pixels[i] = 0;
    }
    paintImg.updatePixels();
    break;

    // Here comes our image modes!
  case 'q':
    merge();
    break;
  case 'w':
    max();
    break;
  case 'e':
    min();
    break;
  case 'r':
    difference();
    break;
  case 't':
    median();
    break;

  default:
    println("Unknown key: '" + key + "', " + (int) key);
  }
  showParams();
}

void median() {
  paintImg = createImage(images.get(0).width, images.get(0).height, RGB);
  int[] rs = new int[images.size()];
  int[] gs = new int[images.size()];
  int[] bs = new int[images.size()];
  int mid = images.size() / 2;

  for (int y = 0; y < paintImg.height; y++) {
    for (int x = 0; x < paintImg.width; x++) {
      for (int i = 0; i < images.size(); i++) {
        color c = images.get(i).get(x, y);
        rs[i] = (int) red(c);
        gs[i] = (int) green(c);
        bs[i] = (int) blue(c);
      }
      Arrays.sort(rs);
      Arrays.sort(gs);
      Arrays.sort(bs);
      int r;
      int g;
      int b;
      if(mid % 2 == 0) {
         r = (rs[mid] + rs[mid + 1]) / 2;
         g = (gs[mid] + gs[mid + 1]) / 2;
         b = (bs[mid] + bs[mid + 1]) / 2;
      } else {
         r = rs[mid];
         g = gs[mid];
         b = bs[mid];
      }
      paintImg.set(x, y, color(r, g, b));
    }
  }
}

void difference() {
  paintImg = createImage(images.get(0).width, images.get(0).height, RGB);
  int[][] rMat = new int[paintImg.height][paintImg.width];
  int[][] gMat = new int[paintImg.height][paintImg.width];
  int[][] bMat = new int[paintImg.height][paintImg.width];

  for (int i = 0; i < images.size() - 1; i++) {
    for (int y = 0; y < paintImg.height; y++) {
      for (int x = 0; x < paintImg.width; x++) {
        color c1 = images.get(i).get(x, y);
        color c2 = images.get(i + 1).get(x, y);
        rMat[y][x] += abs(red(c1) - red(c2)) ;
        gMat[y][x] += abs(green(c1) - green(c2));
        bMat[y][x] += abs(blue(c1) - blue(c2));
      }
    }
  }

  for (int y = 0; y < paintImg.height; y++) {
    for (int x = 0; x < paintImg.width; x++) {
      int r = 255 - rMat[y][x] / (images.size() - 1);
      int g = 255 - gMat[y][x] / (images.size() - 1);
      int b = 255 - bMat[y][x] / (images.size() - 1);
      paintImg.set(x, y, color(r, g, b));
    }
  }
}

void merge() {
  paintImg = createImage(images.get(0).width, images.get(0).height, RGB);
  int[][] rMat = new int[paintImg.height][paintImg.width];
  int[][] gMat = new int[paintImg.height][paintImg.width];
  int[][] bMat = new int[paintImg.height][paintImg.width];

  for (PImage img : images) {
    for (int y = 0; y < paintImg.height; y++) {
      for (int x = 0; x < paintImg.width; x++) {
        color c = img.get(x, y);
        rMat[y][x] += red(c);
        gMat[y][x] += green(c);
        bMat[y][x] += blue(c);
      }
    }
  }

  for (int y = 0; y < paintImg.height; y++) {
    for (int x = 0; x < paintImg.width; x++) {
      int r = rMat[y][x] / images.size();
      int g = gMat[y][x] / images.size();
      int b = bMat[y][x] / images.size();
      paintImg.set(x, y, color(r, g, b));
    }
  }
}

void min() {
  paintImg = createImage(images.get(0).width, images.get(0).height, RGB);
  int[][] rMat = new int[paintImg.height][paintImg.width];
  int[][] gMat = new int[paintImg.height][paintImg.width];
  int[][] bMat = new int[paintImg.height][paintImg.width];

  for (int y = 0; y < paintImg.height; y++) {
    Arrays.fill(rMat[y], 255);
    Arrays.fill(gMat[y], 255);
    Arrays.fill(bMat[y], 255);
  }

  for (PImage img : images) {
    for (int y = 0; y < paintImg.height; y++) {
      for (int x = 0; x < paintImg.width; x++) {
        color c = img.get(x, y);
        rMat[y][x] = (int) min(red(c), rMat[y][x]);
        gMat[y][x] = (int) min(green(c), gMat[y][x]);
        bMat[y][x] = (int) min(blue(c), bMat[y][x]);
      }
    }
  }

  for (int y = 0; y < paintImg.height; y++) {
    for (int x = 0; x < paintImg.width; x++) {
      int r = rMat[y][x];
      int g = gMat[y][x];
      int b = bMat[y][x];
      paintImg.set(x, y, color(r, g, b));
    }
  }
}

void max() {
  paintImg = createImage(images.get(0).width, images.get(0).height, RGB);
  int[][] rMat = new int[paintImg.height][paintImg.width];
  int[][] gMat = new int[paintImg.height][paintImg.width];
  int[][] bMat = new int[paintImg.height][paintImg.width];

  for (PImage img : images) {
    for (int y = 0; y < paintImg.height; y++) {
      for (int x = 0; x < paintImg.width; x++) {
        color c = img.get(x, y);
        rMat[y][x] = (int) max(red(c), rMat[y][x]);
        gMat[y][x] = (int) max(green(c), gMat[y][x]);
        bMat[y][x] = (int) max(blue(c), bMat[y][x]);
      }
    }
  }

  for (int y = 0; y < paintImg.height; y++) {
    for (int x = 0; x < paintImg.width; x++) {
      int r = rMat[y][x];
      int g = gMat[y][x];
      int b = bMat[y][x];
      paintImg.set(x, y, color(r, g, b));
    }
  }
}

void draw() {
  if (paintImg != null && origImg != null) {
    //    paintImg = images.get(imageIdx++);
    //    println(imageIdx);
    //    if(imageIdx >= images.size()) {
    //      imageIdx = 0;
    //    }

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
