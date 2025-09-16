class Twinkle {
  float x;
  float y;
  final float fadeInRatio;
  final float fadeOutRatio;
  final float radius;
  final float decay;
  final float xd;
  final float yd;
  final float speed;
  boolean isFadingIn;
  float fadeValue;

  Twinkle(int x, int y, float fadeInRatio, float fadeOutRatio, float radius, float hardness, float angle, float speed) {
    this.x = x;
    this.y = y;
    this.fadeInRatio = fadeInRatio;
    this.fadeOutRatio = fadeOutRatio;
    this.radius = radius;
    this.decay = lerp(pow(1.0f / 256, 1.0 / radius) - 1e-12, 1, 1);
    isFadingIn = true;
    this.xd = sin(angle) * speed;
    this.yd = cos(angle) * speed;
    this.speed = speed;
  }

  Twinkle(int x, int y, float fadeInRatio, float fadeOutRatio, float radius, float hardness) {
    this(x, y, fadeInRatio, fadeOutRatio, radius, hardness, 0, 0);
  }

  void step(PGraphics img) {
    x += xd;
    y += yd;
    if (isFadingIn) {
      fadeValue += fadeInRatio;
      if (fadeValue >= 1) {
        fadeValue = 1;
        isFadingIn = false;
      }
    } else {
      fadeValue -= fadeOutRatio;
      if (fadeValue <= 0) {
        fadeValue = 0;
      }
    }

    float opacity = 1;
    if (decay >= 0.9999) {
      img.noStroke();
      //      color c = color(fadeValue * 255, opacity * 255);
      color c = color(fadeValue * 255);
      img.fill(c);
      img.circle(x - radius, y - radius, radius);
    } else {
      img.noFill();
      img.strokeWeight(1);
      for (int r = 1; r <= radius; r++) {
        color c = color(fadeValue * 255, opacity * 255);
        opacity *= decay;
        img.stroke(c);
        img.circle(x - radius, y - radius, r);
      }
    }
  }

  boolean isDone() {
    return !isFadingIn  && fadeValue <= 1E-5;
  }
}
