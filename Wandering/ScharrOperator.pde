public static class ScharrOperator {
  // ===========================
  // 3x3 Scharr-like kernels
  // ===========================
  private static final int[][] SCHARR3X3_X = {
    { -6144, 0, 6144 },
    {-20480, 0, 20480 },
    { -6144, 0, 6144 }
  };

  private static final int[][] SCHARR3X3_Y = {
    { -6144, -20480, -6144 },
    {     0, 0, 0 },
    {  6144, 20480, 6144 }
  };

  // ===========================
  // 5x5 Scharr-like kernels
  // ===========================
  private static final int[][] SCHARR5X5_X = {
    { -1024, -1024, 0, 1024, 1024 },
    { -4096, -4096, 0, 4096, 4096 },
    { -6144, -6144, 0, 6144, 6144 },
    { -4096, -4096, 0, 4096, 4096 },
    { -1024, -1024, 0, 1024, 1024 }
  };

  private static final int[][] SCHARR5X5_Y = {
    { -1024, -4096, -6144, -4096, -1024 },
    { -1024, -4096, -6144, -4096, -1024 },
    {     0, 0, 0, 0, 0 },
    {  1024, 4096, 6144, 4096, 1024 },
    {  1024, 4096, 6144, 4096, 1024 }
  };

  // ===========================
  // 7x7 Scharr-like kernels
  // ===========================
  private static final int[][] SCHARR7X7_X = {
    {  -256, -128, -128, 0, 128, 128, 256 },
    { -1536, -768, -768, 0, 768, 768, 1536 },
    { -3840, -1920, -1920, 0, 1920, 1920, 3840 },
    { -5120, -2560, -2560, 0, 2560, 2560, 5120 },
    { -3840, -1920, -1920, 0, 1920, 1920, 3840 },
    { -1536, -768, -768, 0, 768, 768, 1536 },
    {  -256, -128, -128, 0, 128, 128, 256 }
  };

  private static final int[][] SCHARR7X7_Y = {
    {  -256, -1536, -3840, -5120, -3840, -1536, -256 },
    {  -128, -768, -1920, -2560, -1920, -768, -128 },
    {  -128, -768, -1920, -2560, -1920, -768, -128 },
    {     0, 0, 0, 0, 0, 0, 0 },
    {   128, 768, 1920, 2560, 1920, 768, 128 },
    {   128, 768, 1920, 2560, 1920, 768, 128 },
    {   256, 1536, 3840, 5120, 3840, 1536, 256 }
  };


  // =========================================================
  // Generic convolution
  // =========================================================
  private static void convolveNxN(float[][] img, int[][] kx, int[][] ky, float[] gradX, float[] gradY) {
    int w = img[0].length;
    int h = img.length;
    int khalf = kx.length / 2;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        float gx = 0;
        float gy = 0;

        for (int ky_i = -khalf; ky_i <= khalf; ky_i++) {
          for (int kx_i = -khalf; kx_i <= khalf; kx_i++) {
            int ox = max(0, min(x + kx_i, w - 1));
            int oy = max(0, min(y + ky_i, h - 1));
            float pixel = img[oy][ox];
            gx += pixel * kx[ky_i + khalf][kx_i + khalf];
            gy += pixel * ky[ky_i + khalf][kx_i + khalf];
          }
        }
        gradX[y * w + x] = gx;
        gradY[y * w + x] = gy;
      }
    }
  }

  // =========================================================
  // Magnitude + Direction
  // =========================================================
  private static float[][] gradientMagDir(int size, float[] gradX, float[] gradY) {
    float[] magnitude = new float[gradX.length];
    float[] direction = new float[gradX.length];
    //  final float scale = 1.0f / (sqrt(2) * 255 * 32768);
    float magMax = 1E-20;
    for (int i = 0; i < gradX.length; i++) {
      float gx = gradX[i];
      float gy = gradY[i];
      magnitude[i] = (float) Math.sqrt(gx * gx + gy * gy);
      magMax = max(magMax, magnitude[i]);
      direction[i] = (float) (Math.atan2(gy, gx) + TWO_PI) % TWO_PI / TWO_PI;
    }
    float maxR = 1.0f / magMax;
    for (int i = 0; i < gradX.length; i++) {
      magnitude[i] *= maxR;
    }
    return new float[][] {magnitude, direction};
  }

  private static float[][] getGradientMap(PImage img, int[][] kernelX, int[][] kernelY) {
    int w = img.width;
    int h = img.height;
    float[][] lightness = new float[h][w];
    img.loadPixels();
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        lightness[y][x] = lightness(img.pixels[y * w + x]);
        //  println("l(" + x + ", " + y + ") = " + lightness[y][x]);
      }
    }
    float[] gradX = new float[w * h];
    float[] gradY = new float[w * h];
    convolveNxN(lightness, kernelX, kernelY, gradX, gradY);
    return gradientMagDir(kernelX.length, gradX, gradY);
  }

  public static enum Size {
    THREE,
      FIVE,
      SEVEN;
  }

  public static final int MAGNITUDE = 0;
  public static final int ANGLE = 1;

  public static float[][] getGradientMaps(PImage img, Size s) {
    img.loadPixels();
    switch(s) {
    case THREE:
      return getGradientMap(img, SCHARR3X3_X, SCHARR3X3_Y);
    case FIVE:
      return getGradientMap(img, SCHARR5X5_X, SCHARR5X5_Y);
    case SEVEN:
      return getGradientMap(img, SCHARR7X7_X, SCHARR7X7_Y);
    default:
      throw new NullPointerException("Size was null!");
    }
  }
}

// Code below from ChatGPT with minor tweaks.

// Apply 1D convolution along rows
private static float[][] convolveRows(float[][] img, float[] kernel) {
  int h = img.length, w = img[0].length;
  int k = kernel.length / 2;
  float[][] out = new float[h][w];

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      float sum = 0;
      for (int i = -k; i <= k; i++) {
        int xx = Math.min(Math.max(x + i, 0), w - 1); // clamp
        sum += img[y][xx] * kernel[i + k];
      }
      out[y][x] = sum;
    }
  }
  return out;
}

// Apply 1D convolution along columns
private static float[][] convolveCols(float[][] img, float[] kernel) {
  int h = img.length, w = img[0].length;
  int k = kernel.length / 2;
  float[][] out = new float[h][w];

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      float sum = 0;
      for (int i = -k; i <= k; i++) {
        int yy = Math.min(Math.max(y + i, 0), h - 1); // clamp
        sum += img[yy][x] * kernel[i + k];
      }
      out[y][x] = sum;
    }
  }
  return out;
}

// Return smoothing + derivative kernels
private static float[][] getKernels(int ksize) {
  switch (ksize) {
  case 3:
    return new float[][] {
      {3, 10, 3},
      {-1, 0, 1}
    };
  case 5:
    return new float[][] {
      {1, 4, 5, 4, 1},
      {-1, -2, 0, 2, 1}
    };
  case 7:
    return new float[][] {
      {1, 6, 15, 20, 15, 6, 1},
      {-1, -4, -5, 0, 5, 4, 1}
    };
  case 9:
    return new float[][] {
      {1, 8, 28, 56, 70, 56, 28, 8, 1},
      {-1, -6, -15, -20, 0, 20, 15, 6, 1}
    };
  case 11:
    return new float[][] {
      {1, 10, 45, 120, 210, 252, 210, 120, 45, 10, 1},
      {-1, -8, -28, -56, -70, 0, 70, 56, 28, 8, 1}
    };
  case 13:
    return new float[][] {
      {1, 12, 66, 220, 495, 792, 924, 792, 495, 220, 66, 12, 1},
      {-1, -10, -45, -120, -210, -252, 0, 252, 210, 120, 45, 10, 1}
    };
  default:
    throw new IllegalArgumentException("ksize must be {3,5,7,9,11,13}");
  }
}

// Apply Scharr separable filter for one axis
public static float[][] scharr(float[][] img, int ksize, boolean isYAxis) {
  float[][] kernels = getKernels(ksize);
  float[] v = kernels[0];
  float[] d = kernels[1];

  if (!isYAxis) {
    float[][] tmp = convolveCols(img, v); // smooth Y
    return convolveRows(tmp, d);          // derivative X
  } else {
    float[][] tmp = convolveRows(img, v); // smooth X
    return convolveCols(tmp, d);          // derivative Y
  }
}

// Compute magnitude and orientation
public static float[][][] gradientMagnitudeAndAngle(float[][] mat, int kernelSize, float maxMagnitude) {
  float[][] gx = scharr(mat, kernelSize, false);
  float[][] gy = scharr(mat, kernelSize, true);

  float[][] magnitude = new float[mat.length][mat[0].length];
  float[][] angle = new float[mat.length][mat[0].length];

  int h = gx.length, w = gx[0].length;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      float dx = gx[y][x];
      float dy = gy[y][x];
      magnitude[y][x] = (float) Math.sqrt(dx * dx + dy * dy);
      angle[y][x] = (float) Math.atan2(dy, dx);
    }
  }

  normalizeToX(magnitude, maxMagnitude);

  return new float[][][] {magnitude, angle};
}

// Compute magnitude and orientation
public static short[][] gradientMagnitudeAndAngle(float[] arr, int width, int kernelSize) {
  float[][] mat = new float[arr.length / width][width];
  for (int y = 0; y < arr.length / width; y++) {
    System.arraycopy(arr, y * width, mat[y], 0, width);
  }

  float[][][] gradientMagnitudeAndAngle = gradientMagnitudeAndAngle(mat, kernelSize, Short.MAX_VALUE);
  short[] magnitudes = new short[arr.length];
  short[] angles = new short[arr.length];
  double ANGLE_SCALE = 32767 / PI;
  short minAngle = Short.MAX_VALUE;
  short maxAngle = Short.MIN_VALUE;
  float minRAngle = Float.MAX_VALUE;
  float maxRAngle = Float.MIN_VALUE;

  for (int y = 0; y < mat.length; y++) {
    for (int x = 0; x < width; x++) {
      magnitudes[y * width + x] = (short) (gradientMagnitudeAndAngle[0][y][x]);
      angles[y * width + x] = (short) (gradientMagnitudeAndAngle[1][y][x] * ANGLE_SCALE);
      minAngle = (short) Math.min(minAngle, magnitudes[y * width + x]);
      maxAngle = (short) Math.max(maxAngle, magnitudes[y * width + x]);
      minRAngle = Math.min(minRAngle, gradientMagnitudeAndAngle[0][y][x]);
      maxRAngle = Math.max(maxRAngle, gradientMagnitudeAndAngle[0][y][x]);
    }
  }
  println("minAngle: " + minAngle + ", maxAngle: " + maxAngle + ", minRAngle: " + minRAngle + ", maxRAngle: " + maxRAngle);

  return new short[][] {magnitudes, angles};
}

public static short[][] gradientMagnitudeAndAngle(PImage img, int kernelSize) {
  float[] arr = new float[img.height * img.width];
  for (int y = 0; y < img.height; y++) {
    for (int x = 0; x < img.width; x++) {
      arr[y * img.width + x] = lightness(img.get(x, y));
    }
  }
  return gradientMagnitudeAndAngle(arr, img.width, kernelSize);
}

public static void normalizeToX(float[][] img, float max) {
  int h = img.length, w = img[0].length;
  float maxVal = Float.NEGATIVE_INFINITY;
  float minVal = Float.POSITIVE_INFINITY;

  // find min and max
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      maxVal = max(img[y][x], maxVal);
      minVal = min(minVal, img[y][x]);
    }
  }

  float range = maxVal - minVal;
  float scale = max / range; 

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      img[y][x] = scale * (img[y][x] - minVal);
    }
  }
}
