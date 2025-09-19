public static class Convolve { //<>//
  static int bound(int x, int min, int max) {
    return max(min, min(x, max - 1));
  }

  /// IGNORERA JUST NU ---
  public static void normalize(float[][] m) {
    float sum = 0;
    for (int i = 0; i < m.length; i++) {
      for (int j = 0; j < m[i].length; j++) {
        sum += m[i][j];
      }
    }
    for (int i = 0; i < m.length; i++) {
      for (int j = 0; j < m[i].length; j++) {
        m[i][j] /= sum;
      }
    }
  }

  public static void convolve(PImage img, float[][] m) {
  }
}

void adjust(PImage img, int min, float bias, int max) {
  float scale = 255.0 / (max - min);
  img.loadPixels();

  for (int y = 0; y < img.height; y++) {
    for (int x = 0; x < img.width; x++) {
      float r = barron(constrain((red(img.get(x, y)) - min) * scale, 0, 255) / 255.0, bias, 0) * 255;
      float g = barron(constrain((green(img.get(x, y)) - min) * scale, 0, 255) / 255.0, bias, 0) * 255;
      float b = barron(constrain((blue(img.get(x, y)) - min) * scale, 0, 255) / 255.0, bias, 0) * 255;
      img.set(x, y, color(r, g, b));
    }
  }

  img.updatePixels();
}

void blur(PImage img, float amount) {
  PImage blurred = img.copy();
  for (int y = 0; y < img.height; y++) {
    for (int x = 0; x < img.width; x++) {
      int rSum = 0;
      int gSum = 0;
      int bSum = 0;
      for (int yd = -1; yd <= 1; yd++) {
        for (int xd = -1; xd <= 1; xd++) {
          color c = img.get(Convolve.bound(x + xd, 0, img.width), Convolve.bound( y + yd, 0, img.height));
          rSum += red(c); // Utläses likadant som rSum = rSum + red(c)
          gSum += green(c);
          bSum += blue(c);
        }
      }
      int r = (int) lerp(red(img.get(x, y)), rSum / 9.0f, amount);
      int g = (int) lerp(green(img.get(x, y)), gSum / 9.0f, amount);
      int b = (int) lerp(blue(img.get(x, y)), bSum / 9.0f, amount);
      blurred.set(x, y, color(r, g, b));
    }
  }
  for (int y = 0; y < img.height; y++) {
    for (int x = 0; x < img.width; x++) {
      img.set(x, y, blurred.get(x, y));
    }
  }
}

private void convolve3x3NoBounds(int[][] kernel, int x, int y, PImage input, PImage target) {
  int rSum = 0;
  int gSum = 0;
  int bSum = 0;
  for (int yd = 0; yd <= 2; yd++) {
    for (int xd = 0; xd <= 2; xd++) {
      color c = input.get(x + xd - 1, y + yd - 1);
      rSum += ((c >>> 16) & 0xFF) * kernel[yd][xd];
      gSum += ((c >>> 8) & 0xFF) * kernel[yd][xd];
      bSum += ((c >>> 0) & 0xFF) * kernel[yd][xd];
    }
  }

  int r = (rSum >>> 16) & 0xFF;
  int g = (gSum >>> 16) & 0xFF;
  int b = (bSum >>> 16) & 0xFF;
  target.set(x, y, color(r, g, b));
}

private void convolve3x3Bounds(int[][] kernel, int x, int y, PImage input, PImage target) {
  int rSum = 0;
  int gSum = 0;
  int bSum = 0;
  int w = input.width;
  int h = input.height;
  for (int yd = 0; yd <= 2; yd++) {
    for (int xd = 0; xd <= 2; xd++) {
      color c = input.get(Convolve.bound(x + xd - 1, 0, w), Convolve.bound(y + yd - 1, 0, h));
      rSum += ((c >>> 16) & 0xFF) * kernel[yd][xd];
      gSum += ((c >>> 8) & 0xFF) * kernel[yd][xd];
      bSum += ((c >>> 0) & 0xFF) * kernel[yd][xd];
    }
  }
  int r = (rSum >>> 16) & 0xFF;
  int g = (gSum >>> 16) & 0xFF;
  int b = (bSum >>> 16) & 0xFF;
  target.set(x, y, color(r, g, b));
}

void gaussianBlur3(PImage img, float amount) {
  img.loadPixels();
  PImage blurred = img.copy();
  int[][] gaussian3x3 = {
    {  4096, 8192, 4096 },
    {  8192, 16384, 8192 },
    {  4096, 8192, 4096 }
  };
  int center = (int) (16384 * pow(2, 18 * (1 - amount)));
  float scale = 65536.0 / (32768 + 16384 + center);
  gaussian3x3[1][1] = center;
  int wSum = 0;
  for (int i = 0; i < 3; i++) {
    for (int j = 0; j < 3; j++) {
      gaussian3x3[i][j] *= scale;
      wSum += gaussian3x3[i][j];
    }
  }
  gaussian3x3[1][1] = 65536 - wSum;

  for (int y = 1; y < img.height - 1; y++) {
    for (int x = 1; x < img.width - 1; x++) {
      convolve3x3NoBounds(gaussian3x3, x, y, img, blurred);
    }
  }
  for (int y : new int[] {0, img.height - 1}) {
    for (int x = 0; x < img.width; x++) {
      convolve3x3Bounds(gaussian3x3, x, y, img, blurred);
    }
  }
  for (int x : new int[] {0, img.width - 1}) {
    for (int y = 1; y < img.height - 1; y++) {
      convolve3x3Bounds(gaussian3x3, x, y, img, blurred);
    }
  }

  img.pixels = blurred.pixels;
  img.updatePixels();
}

private void convolve5x5NoBounds(int[][] kernel, int x, int y, PImage input, PImage target) {
  int rSum = 0;
  int gSum = 0;
  int bSum = 0;

  for (int yd = 0; yd <= 4; yd++) {
    for (int xd = 0; xd <= 4; xd++) {
      color c = input.get(x + xd - 2, y + yd - 2);
      rSum += ((c >>> 16) & 0xFF) * kernel[yd][xd];
      gSum += ((c >>> 8) & 0xFF) * kernel[yd][xd];
      bSum += ((c >>> 0) & 0xFF) * kernel[yd][xd];
    }
  }
  int r = (rSum >>> 16) & 0xFF;
  int g = (gSum >>> 16) & 0xFF;
  int b = (bSum >>> 16) & 0xFF;
  target.set(x, y, color(r, g, b));
}

private void convolve5x5Bounds(int[][] kernel, int x, int y, PImage input, PImage target) {
  int rSum = 0;
  int gSum = 0;
  int bSum = 0;
  int w = input.width;
  int h = input.height;
  for (int yd = 0; yd <= 4; yd++) {
    for (int xd = 0; xd <= 4; xd++) {
      color c = input.get(Convolve.bound(x + xd - 2, 0, w), Convolve.bound(y + yd - 2, 0, h));
      rSum += ((c >>> 16) & 0xFF) * kernel[yd][xd];
      gSum += ((c >>> 8) & 0xFF) * kernel[yd][xd];
      bSum += ((c >>> 0) & 0xFF) * kernel[yd][xd];
    }
  }
  int r = (rSum >>> 16) & 0xFF;
  int g = (gSum >>> 16) & 0xFF;
  int b = (bSum >>> 16) & 0xFF;
  target.set(x, y, color(r, g, b));
}

void gaussianBlur5(PImage img, float amount) {
  img.loadPixels();
  PImage blurred = img.copy();
  int[][] gaussian5x5 = {
    {  240, 960, 1681, 960, 240 },
    {  960, 3841, 6242, 3841, 960 },
    { 1681, 6242, 9844, 6242, 1681 },
    {  960, 3841, 6242, 3841, 960 },
    {  240, 960, 1681, 960, 240 }
  };
  int center = (int) (gaussian5x5[2][2] * pow(2, 7 * (1 - amount)));
  float scale = 65536.0 / ((65536 - gaussian5x5[2][2]) + center);
  gaussian5x5[2][2] = center;
  int wSum = 0;
  for (int i = 0; i < 5; i++) {
    for (int j = 0; j < 5; j++) {
      gaussian5x5[i][j] *= scale;
      wSum += gaussian5x5[i][j];
    }
  }
  gaussian5x5[2][2] += 65536 - wSum;
  for (int y = 2; y < img.height - 2; y++) {
    for (int x = 2; x < img.width - 2; x++) {
      convolve5x5NoBounds(gaussian5x5, x, y, img, blurred);
    }
  }
  for (int y : new int[] {0, 1, img.height - 2, img.height - 1}) {
    for (int x = 0; x < img.width; x++) {
      convolve5x5Bounds(gaussian5x5, x, y, img, blurred);
    }
  }
  for (int x : new int[] {0, 1, img.width -2, img.width - 1}) {
    for (int y = 1; y < img.height - 1; y++) {
      convolve5x5Bounds(gaussian5x5, x, y, img, blurred);
    }
  }

  img.pixels = blurred.pixels;
  img.updatePixels();
}

void gaussianBlur(PImage src, int width, float amount) {
  if(width % 2 == 0) {
    throw new IllegalArgumentException("width must be odd and >= 3 (was " + width + ").");
  }
  gaussianBlur(src, gaussianVector(width), amount);
}

// ---- Separable Gaussian blur ----
void gaussianBlur(PImage src, int[] kernel, float amount) {
  int w = src.width;
  int h = src.height;
  PImage tmp = createImage(w, h, RGB);

  // First pass: horizontal blur
  src.loadPixels();
  tmp.loadPixels();
  int half = kernel.length / 2;
  int norm = 0;
  for (int v : kernel) {
    norm += v;
  }
  float normInv = 1.0f / norm;

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      int rSum = 0;
      int gSum = 0;
      int bSum = 0;
      for (int k = -half; k <= half; k++) {
        int xx = constrain(x + k, 0, w - 1);
        int c = src.pixels[y * w + xx];
        rSum += (int) (((c >>> 16) & 0xFF) * kernel[k + half]);
        gSum += (int) (((c >>> 8) & 0xFF) * kernel[k + half]);
        bSum += (int) (((c >>> 0) & 0xFF) * kernel[k + half]);
      }
      tmp.pixels[y * w + x] = color(rSum * normInv, gSum * normInv, bSum * normInv);
    }
  }
  tmp.updatePixels();

  // Second pass: vertical blur
  tmp.loadPixels();

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      int rSum = 0;
      int gSum = 0;
      int bSum = 0;
      for (int k = -half; k <= half; k++) {
        int yy = constrain(y + k, 0, h - 1);
        int c = tmp.pixels[yy * w + x];
        rSum += (int) (((c >>> 16) & 0xFF) * kernel[k + half]);
        gSum += (int) (((c >>> 8) & 0xFF) * kernel[k + half]);
        bSum += (int) (((c >>> 0) & 0xFF) * kernel[k + half]);
      }
      src.pixels[y * w + x] = lerpColor(src.pixels[y * w + x], color(rSum * normInv, gSum * normInv, bSum * normInv), amount);
    }
  }
  src.updatePixels();
}

// ---- Gaussian kernel generator (using Pascal's triangle row) ----
int[] gaussianVector(int size) {
  if (size % 2 == 0) throw new IllegalArgumentException("Size must be odd");
  int n = size - 1;
  int[] vec = new int[size];

  // Binomial coefficients (row n of Pascal's triangle)
  for (int k = 0; k <= n; k++) {
    vec[k] = binomial(n, k);
  }
  return vec; // sum = 2^n, acts as Gaussian weights
}

int binomial(int n, int k) {
  int res = 1;
  for (int i = 1; i <= k; i++) {
    res = res * (n - i + 1) / i;
  }
  return res;
}
