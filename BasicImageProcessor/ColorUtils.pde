float[] rgbToHsb(int rgb) { //<>//
  return rgbToHsb((rgb >>> 16) & 0xFF, (rgb >>> 8) & 0xFF, rgb & 0xFF);
}

int rgbWithHsbTweak(int rgb, float hOffset, float sOffset, float bOffset) {
  float[] hsb = rgbToHsb(rgb);
  return hsbToRgbA((hsb[0] + hOffset + 360) % 360, constrain(hsb[1] + sOffset, 0, 1), constrain(hsb[2] + bOffset, 0, 1));
}

float[] rgbToHsb(int r, int g, int b) {
  float rf = r / 255.0f;
  float gf = g / 255.0f;
  float bf = b / 255.0f;

  float max = max(rf, max(gf, bf));
  float min = min(rf, min(gf, bf));
  float delta = max - min;

  float h, s, v; // (v = brightness)

  // Hue
  if (delta == 0) {
    h = 0; // undefined hue
  } else if (max == rf) {
    h = 60 * (((gf - bf) / delta) % 6);
  } else if (max == gf) {
    h = 60 * (((bf - rf) / delta) + 2);
  } else {
    h = 60 * (((rf - gf) / delta) + 4);
  }
  if (h < 0) h += 360;

  // Saturation
  s = (max == 0) ? 0 : delta / max;

  // Brightness (value)
  v = max;

  return new float[] {h, s, v};
}

// Convert from HSB (Hue[0,360), Sat[0,1], Bri[0,1]) back to RGB [0,255]
int hsbToRgbA(float h, float s, float v) {
  float c = v * s; // chroma
  float x = c * (1 - abs((h / 60f) % 2 - 1));
  float m = v - c;

  float rf, gf, bf;

  if (h < 60) {
    rf = c;
    gf = x;
    bf = 0;
  } else if (h < 120) {
    rf = x;
    gf = c;
    bf = 0;
  } else if (h < 180) {
    rf = 0;
    gf = c;
    bf = x;
  } else if (h < 240) {
    rf = 0;
    gf = x;
    bf = c;
  } else if (h < 300) {
    rf = x;
    gf = 0;
    bf = c;
  } else {
    rf = c;
    gf = 0;
    bf = x;
  }

  int r = Math.round((rf + m) * 255);
  int g = Math.round((gf + m) * 255);
  int b = Math.round((bf + m) * 255);

  return 0xFF000000 | (r << 16) | (g << 8) | (b);
}

float colorDistance(color c1, color c2) {
  return (pow(((c1 >>> 16) & 0xFF) - ((c2 >>> 16) & 0xFF), 2) + pow(((c1 >>> 8) & 0xFF) - ((c2 >>> 8) & 0xFF), 2) +
    pow(((c1 >>> 0) & 0xFF) - ((c2 >>> 0) & 0xFF), 2)) * (1.0f / (65025 * 3));
}

// Jonathan T. Barron's function from
// "A Convenient Generalization of Schlick's Bias and Gain Functions"
static float barron(float x, float s, float t) {
  if (x < t) {
    return t * x / (x + s * (t - x) + Float.MIN_NORMAL);
  }

  return (1 - t) * (x - 1) / (1 - x - s * (t - x) + Float.MIN_NORMAL) + 1;
}

void normalize(PImage img, float blend) {
  float rMin = 255;
  float gMin = 255;
  float bMin = 255;
  float rMax = 0;
  float gMax = 0;
  float bMax = 0;

  img.loadPixels();
  float dampening = 1 - 1000.0 / (img.width * img.height);
  for (int i = 0; i < img.pixels.length; i++) {
    color c = img.pixels[i];
    int r = (c >>> 16) & 0xFF;
    int g = (c >>> 8) & 0xFF;
    int b = (c >>> 0) & 0xFF;
    rMin = lerp(min(rMin, r), rMin, dampening);
    gMin = lerp(min(gMin, g), gMin, dampening);
    bMin = lerp(min(bMin, b), bMin, dampening);
    rMax = lerp(max(rMax, r), rMax, dampening);
    gMax = lerp(max(gMax, g), gMax, dampening);
    bMax = lerp(max(bMax, b), bMax, dampening);
  }
  float rScale = 255.0f / (max(1, rMax - rMin));
  float gScale = 255.0f / (max(1, gMax - gMin));
  float bScale = 255.0f / (max(1, bMax - bMin));
  println("rMin: " + rMin + ", rMax: " + rMax + ", rScale: " + rScale);
  for (int i = 0; i < img.pixels.length; i++) {
    color c = img.pixels[i];
    int r = (c >>> 16) & 0xFF;
    int g = (c >>> 8) & 0xFF;
    int b = (c >>> 0) & 0xFF;
    r = (int) constrain(lerp(r, (r - rMin) * rScale, blend), 0, 255);
    g = (int) constrain(lerp(g, (g - gMin) * gScale, blend), 0, 255);
    b = (int) constrain(lerp(b, (b - bMin) * bScale, blend), 0, 255);
    img.pixels[i] = (r << 16) | (g << 8) | (b << 0);
  }
}

// From https://stackoverflow.com/questions/596216/formula-to-determine-perceived-brightness-of-rgb-color
private static float sRGBtoLin(int c) {
  float cf = c * 0.003921568627; // Reciprocal of 255.
  if ( cf <= 0.04045 ) {
    return cf * 0.077399380805; // Reciprocal of 12.92;
  } else {
    // Reciprocal of 1.055 ~= 0.947867298578
    return pow((( cf + 0.055)*0.947867298578), 2.2);
  }
}

static float lightness(color c) {
  int r = (c >>> 16) & 0xFF;
  int g = (c >>> 8) & 0xFF;
  int b = (c >>> 0) & 0xFF;
  float y = (0.2126 * sRGBtoLin(r) + 0.7152 * sRGBtoLin(g) + 0.0722 * sRGBtoLin(b));
  // 216/24389 ~= 0.00885645168
  if ( y <= 0.00885645168) {       // The CIE standard states 0.008856 but 216/24389 is the intent for 0.008856451679036
    return y * 903.296296296296296;  // The CIE standard states 903.3, but 24389/27 is the intent, making 903.296296296296296
  } else {
    return pow(y, (1.0/3)) * 116 - 16;
  }
}
