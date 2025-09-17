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
