import java.util.Set;
import java.util.HashSet;
import java.util.function.Function;

// Serial version:
// Fragments/frame, 1750x1167, tourlength 291: 1.30407885E9
// Fragments/frame, 1750x1167, tourlength 4494: 9.1737107E8
// Fragments/frame, , 1750x1167
public interface Wander {
  public void wander(int x, int y, color c);
}

public static class DrawSequence {
  public final PixOp[] ps;
  public final color c;

  public DrawSequence(PixOp[] ps, color c) {
    this.ps = ps;
    this.c = c;
  }
}


private static class PixOp implements Comparable<PixOp> {
  public final int p;
  public final float opacity;

  public PixOp(int p, float opacity) {
    this.p = p;
    this.opacity = opacity;
  }

  @Override int compareTo(PixOp other) {
    return (int) (this.p - other.p);
  }
}

public static class WanderP {
  private final color c;
  private final Function<SplittableRandom, PixOp[]> wander;

  public WanderP(color c, Function<SplittableRandom, PixOp[]> wander) {
    this.c = c;
    this.wander = wander;
  }

  public PixOp[] wander(SplittableRandom rng) {
    return wander.apply(rng);
  }

  public color getColor() {
    return this.c;
  }
}

PixOp[] wander0p(int x, int y, color cNew) {
  int[] xs = {1, 1, 0, -1, -1, -1, 0, 1};
  int[] ys = {0, -1, -1, -1, 0, 1, 1, 1};
  int w = origImg.width;
  int h = origImg.height;
  int tourLength = getTourLength();
  PixOp[] tour = new PixOp[tourLength];
  int pIdx = 0;

  for (int i = 0; i < tourLength; i++) {
    float opacity = getOpacity(i, tourLength);
    if (opacity < OPACITY_THRESHOLD) {
      break;
    }
    int dir = wp.rng.nextInt(xs.length);
    x = (x + xs[dir] + w) % w;
    y = (y + ys[dir] + h) % h;
    tour[pIdx++] = new PixOp(x + y * w, opacity);
  }
  return tour;
}

int wander0s(int x, int y, color cNew) {
  int[] xs = {1, 1, 0, -1, -1, -1, 0, 1};
  int[] ys = {0, -1, -1, -1, 0, 1, 1, 1};
  int w = origImg.width;
  int h = origImg.height;
  int tourLength = getTourLength();

  int steps;
  for (steps = 0; steps < tourLength; steps++) {
    int dir = wp.rng.nextInt(xs.length);
    x = (x + xs[dir] + w) % w;
    y = (y + ys[dir] + h) % h;

    if (! paintImage(x, y, steps, tourLength, cNew)) {
      break;
    }
  }
  return steps;
}

int wander1s(int x, int y, color cNew) {
  float xp = x;
  float yp = y;
  float[] xs = {0.0, 0.19509032, 0.38268346, 0.55557024,
    0.70710677, 0.83146966, 0.9238795, 0.9807853,
    1.0, 0.98078525, 0.9238795, 0.83146954,
    0.70710677, 0.5555702, 0.38268328, 0.19509031,
    -8.742278E-8, -0.19509049, -0.38268343, -0.5555703,
    -0.7071069, -0.8314698, -0.9238797, -0.98078525,
    -1.0, -0.98078525, -0.92387944, -0.8314695,
    -0.70710653, -0.5555703, -0.38268343, -0.19509023};
  float[] ys = {1.0, 0.98078525, 0.9238795, 0.83146954,
    0.70710677, 0.5555702, 0.38268328, 0.19509031,
    -8.742278E-8, -0.19509049, -0.38268343, -0.5555703,
    -0.7071069, -0.8314698, -0.9238797, -0.98078525,
    -1.0, -0.98078525, -0.92387944, -0.8314695,
    -0.70710653, -0.5555703, -0.38268343, -0.19509023,
    0.0, 0.19509032, 0.38268346, 0.55557024,
    0.70710677, 0.83146966, 0.9238795, 0.9807853};

  float dir = wp.rng.nextInt(0, xs.length);
  float opacity = 1.0;
  List<Integer> bifurcationPoints = new LinkedList<>();
  int tourLength = getTourLength();
  PixOp[] tour = new PixOp[tourLength];
  int pIdx = 0;

  int steps;
  for (steps = 0; steps < tourLength; steps++) {
    if (!paintImage((int) xp, (int) yp, steps, tourLength, cNew)) {
      break;
    }

    if (bifurcationPoints.size() < tourLength / 4) {
      bifurcationPoints.add((int) xp + (int) yp * origImg.width);
    }
    if (wp.rng.nextFloat() < wp.bifurcationProbability && !bifurcationPoints.isEmpty()) {
      int p = bifurcationPoints.remove(wp.rng.nextInt((bifurcationPoints.size() + 1) / 2));
      xp = p % origImg.width;
      yp = p / origImg.width;
      dir += (wp.rng.nextInt(0, 2) - 1) * 3;
    }
    if (wp.pathDeviation > 0) {
      dir = (dir + (float) wp.rng.nextGaussian(0, wp.pathDeviation) + xs.length) % xs.length;
    } else {
      dir = (dir + wp.rng.nextInt(-2, 3) * 0.5 + xs.length) % xs.length;
    }
    float xd = xs[(int) dir];
    float yd = ys[(int) dir];
    xp = constrain(xp + xd, 0, origImg.width - 1);
    yp = constrain(yp + yd, 0, origImg.height - 1);
  }
  return steps;
}

PixOp[] wander1p(int x, int y, color cNew, SplittableRandom rng) {
  float xp = x;
  float yp = y;
  float[] xs = {0.0, 0.19509032, 0.38268346, 0.55557024,
    0.70710677, 0.83146966, 0.9238795, 0.9807853,
    1.0, 0.98078525, 0.9238795, 0.83146954,
    0.70710677, 0.5555702, 0.38268328, 0.19509031,
    -8.742278E-8, -0.19509049, -0.38268343, -0.5555703,
    -0.7071069, -0.8314698, -0.9238797, -0.98078525,
    -1.0, -0.98078525, -0.92387944, -0.8314695,
    -0.70710653, -0.5555703, -0.38268343, -0.19509023};
  float[] ys = {1.0, 0.98078525, 0.9238795, 0.83146954,
    0.70710677, 0.5555702, 0.38268328, 0.19509031,
    -8.742278E-8, -0.19509049, -0.38268343, -0.5555703,
    -0.7071069, -0.8314698, -0.9238797, -0.98078525,
    -1.0, -0.98078525, -0.92387944, -0.8314695,
    -0.70710653, -0.5555703, -0.38268343, -0.19509023,
    0.0, 0.19509032, 0.38268346, 0.55557024,
    0.70710677, 0.83146966, 0.9238795, 0.9807853};

  float dir = wp.rng.nextInt(0, xs.length);
  float opacity = 1.0;
  List<Integer> bifurcationPoints = new LinkedList<>();
  int tourLength = getTourLength();
  PixOp[] tour = new PixOp[tourLength];
  int pIdx = 0;

  int steps;
  for (steps = 0; steps < tourLength; steps++) {
    opacity = getOpacity(steps, tourLength);
    if (opacity < OPACITY_THRESHOLD) {
      break;
    }
    tour[pIdx++] = new PixOp((int) xp + (int) yp * origImg.width, opacity);

    if (bifurcationPoints.size() < tourLength / 4) {
      bifurcationPoints.add((int) xp + (int) yp * origImg.width);
    }
    if (wp.rng.nextFloat() < wp.bifurcationProbability && !bifurcationPoints.isEmpty()) {
      int p = bifurcationPoints.remove(wp.rng.nextInt((bifurcationPoints.size() + 1) / 2));
      xp = p % origImg.width;
      yp = p / origImg.width;
      dir += (wp.rng.nextInt(0, 2) - 1) * 3;
    }
    if (wp.pathDeviation > 0) {
      dir = (dir + (float) wp.rng.nextGaussian(0, wp.pathDeviation) + xs.length) % xs.length;
    } else {
      dir = (dir + wp.rng.nextInt(-2, 3) * 0.5 + xs.length) % xs.length;
    }
    float xd = xs[(int) dir];
    float yd = ys[(int) dir];
    xp = constrain(xp + xd, 0, origImg.width - 1);
    yp = constrain(yp + yd, 0, origImg.height - 1);
  }

  return tour;
}

int wander2s(int x, int y, color cNew) {
  int[] xs = {1, 1, 0, -1, -1, -1, 0, 1};
  int[] ys = {0, -1, -1, -1, 0, 1, 1, 1};
  int[] dos = shuffle(xs.length);
  int ox = x;
  int oy = y;
  float bifTimeout = 0;
  BitSet visited = new BitSet();
  Set<Integer> visitedSet = new HashSet<>();
  int tourLength = getTourLength();
  List<Integer> ps = new ArrayList<>();
  float opacity = 1.0;
  boolean useHashSet = true;

  int steps;
stepLoop:
  for (steps = 0; steps < tourLength; steps++) {
    if (!paintImage(x, y, steps, tourLength, cNew)) {
      break;
    }

    if (!useHashSet) {
      if (!visited.get(x + y * origImg.width)) {
        visited.set(x + y * origImg.width);
        if (ps.size() < tourLength / 4) {
          ps.add(x + y * origImg.width);
        }
      }

      if (opacity > 0.5) {
        wp.used.set(x + y * origImg.width);
        this.invalidated.set(x + y * origImg.width);
      }
    } else {
      if (visitedSet.add(x + y * origImg.width)) {
        if (ps.size() < tourLength / 4) {
          ps.add(x + y * origImg.width);
        }
      }

      if (opacity > 0.5) {
        wp.used.set(x + y * origImg.width);
        this.invalidated.set(x + y * origImg.width);
      }
    }
    int d = wp.rng.nextInt(xs.length);
    int xd = xs[d];
    int yd = ys[d];
    if (!wp.edgeCollisionTerminates) {
      x = (x + xd + origImg.width) % origImg.width;
      y = (y + yd + origImg.height) % origImg.height;
    } else {
      x = x + xd;
      y = y + yd;
      if (isOutOfBounds(x, y)) {
        if (ps.isEmpty()) {
          break;
        }
        int ep = wp.rng.nextInt(max(1, min(ps.size(), tourLength / 4)));
        int p = ps.remove(ep);
        x = p % origImg.width;
        y = p / origImg.width;
        bifTimeout = 0;
      }
    }
    while (visited.get(x + y * origImg.width)) {
      int cx = 0;
      int cy = 0;
      float dist = dist(x, y, ox, oy) / tourLength * 100;
      if ((wp.rng.nextFloat() < wp.bifurcationProbability * dist || bifTimeout > 5) && !ps.isEmpty()) {
        // Bifurcate.
        int ep = wp.rng.nextInt(max(1, min(ps.size(), tourLength / 4)));
        int p = ps.remove(ep);
        x = p % origImg.width;
        y = p / origImg.width;
        bifTimeout = 0;
      }
      for (int i = 0; i < xs.length; i++) {
        if (!wp.edgeCollisionTerminates) {
          cx = (x + xs[dos[i]] + origImg.width) % origImg.width;
          cy = (y + ys[dos[i]] + origImg.height) % origImg.height;
        } else {
          cx = x + xs[dos[i]];
          cy = y + ys[dos[i]];
          if (isOutOfBounds(cx, cy)) {
            break stepLoop;
          }
        }
        if (!visited.get(cx + cy * origImg.width)) {
          break stepLoop;
        }
      }
      if (cx != x || cy != y) {
        x = cx;
        y = cy;
        break;
      }
      //dos = shuffle(xs.length);
      //      Collections.shuffle(ps, new Random(10));
      int ep = wp.rng.nextInt(max(1, ps.size() / 4));
      int p = ps.remove(ep);
      x = p % origImg.width;
      y = p / origImg.width;
      bifTimeout = 0;
    }
  }
  return steps;
}

PixOp[] wander2p(int x, int y, color cNew, SplittableRandom rng) {
  int[] xs = {1, 1, 0, -1, -1, -1, 0, 1};
  int[] ys = {0, -1, -1, -1, 0, 1, 1, 1};
  int[] dos = shuffle(xs.length);
  int ox = x;
  int oy = y;
  float bifTimeout = 0;
  BitSet visited = new BitSet();
  Set<Integer> visitedSet = new HashSet<>();
  int tourLength = getTourLength();
  PixOp[] tour = new PixOp[tourLength];
  int pIdx = 0;
  List<Integer> ps = new ArrayList<>();
  boolean useHashSet = true;

  int steps;
stepLoop:
  for (steps = 0; steps < tourLength; steps++) {
    float opacity = getOpacity(steps, tourLength);
    if (opacity < OPACITY_THRESHOLD) {
      break;
    }

    tour[pIdx++] = new PixOp(x + y * origImg.width, opacity);

    if (!useHashSet) {
      if (!visited.get(x + y * origImg.width)) {
        visited.set(x + y * origImg.width);
        if (ps.size() < tourLength / 4) {
          ps.add(x + y * origImg.width);
        }
      }

      if (opacity > 0.5) {
        wp.used.set(x + y * origImg.width);
        this.invalidated.set(x + y * origImg.width);
      }
    } else {
      if (visitedSet.add(x + y * origImg.width)) {
        if (ps.size() < tourLength / 4) {
          ps.add(x + y * origImg.width);
        }
      }

      if (opacity > 0.5) {
        wp.used.set(x + y * origImg.width);
        this.invalidated.set(x + y * origImg.width);
      }
    }
    int d = wp.rng.nextInt(xs.length);
    int xd = xs[d];
    int yd = ys[d];
    if (!wp.edgeCollisionTerminates) {
      x = (x + xd + origImg.width) % origImg.width;
      y = (y + yd + origImg.height) % origImg.height;
    } else {
      x = x + xd;
      y = y + yd;
      if (isOutOfBounds(x, y)) {
        if (ps.isEmpty()) {
          break;
        }
        int ep = wp.rng.nextInt(max(1, min(ps.size(), tourLength / 4)));
        int p = ps.remove(ep);
        x = p % origImg.width;
        y = p / origImg.width;
        bifTimeout = 0;
      }
    }
    while (visited.get(x + y * origImg.width)) {
      int cx = 0;
      int cy = 0;
      float dist = dist(x, y, ox, oy) / tourLength * 100;
      if ((wp.rng.nextFloat() < wp.bifurcationProbability * dist || bifTimeout > 5) && !ps.isEmpty()) {
        // Bifurcate.
        int ep = wp.rng.nextInt(max(1, min(ps.size(), tourLength / 4)));
        int p = ps.remove(ep);
        x = p % origImg.width;
        y = p / origImg.width;
        bifTimeout = 0;
      }
      for (int i = 0; i < xs.length; i++) {
        if (!wp.edgeCollisionTerminates) {
          cx = (x + xs[dos[i]] + origImg.width) % origImg.width;
          cy = (y + ys[dos[i]] + origImg.height) % origImg.height;
        } else {
          cx = x + xs[dos[i]];
          cy = y + ys[dos[i]];
          if (isOutOfBounds(cx, cy)) {
            break stepLoop;
          }
        }
        if (!visited.get(cx + cy * origImg.width)) {
          break stepLoop;
        }
      }
      if (cx != x || cy != y) {
        x = cx;
        y = cy;
        break;
      }
      //dos = shuffle(xs.length);
      //      Collections.shuffle(ps, new Random(10));
      int ep = wp.rng.nextInt(max(1, ps.size() / 4));
      int p = ps.remove(ep);
      x = p % origImg.width;
      y = p / origImg.width;
      bifTimeout = 0;
    }
  }
  return tour;
}

// Whisks: tourLengthBase: 0.16939592, tourLength: 3458, bifurcationP: 1.2783398E-5, globalOpacity: 1.0, scanIncrement: 0, scale: 7, saveScale: 1, deviation: 0.05, curveBase: 0.0033495426, pathDeviation: 0.0, refinements: 5393, noiseLevel: 0.0

int wander3s(int x, int y, color cNew) {
  //  float thetaBase = wp.rng.nextFloat(-PI, PI);
  float thetaBase = (float) wp.rng.nextGaussian(PI / 2, 1);
  float theta = 0;
  float curveAngle = (float) ((wp.rng.nextBoolean() ? wp.curveBase : -wp.curveBase) * wp.rng.nextGaussian(1, 0.001));
  float curveIncrement = (curveAngle < 0 ? -wp.curveBase : wp.curveBase) / origImg.width;
  float opacity;
  float angleScale = 10000.0 / (origImg.width * origImg.height) * curveIncrement;
  int tourLength = getTourLength();
  List<Integer> ps = new LinkedList<>();
  BitSet painted = new BitSet();
  float ox = x;
  float oy = y;
  float xs = x;
  float ys = y;
  float maxC = 0;

  int steps;
  for (steps = 0; steps < tourLength; steps++) {
    ps.add((int) xs + (int) ys * origImg.width);
    int xt = (int) xs;
    int yt = (int) ys;
    if (!wp.edgeCollisionTerminates || (xt >= 0 && xt < origImg.width && yt >= 0 && yt < origImg.height)) {
      if (!paintImage((int) xt, (int) ys, steps, tourLength, cNew)) {
        break;
      }

      painted.set(xt + origImg.width * yt);
    }

    theta += curveAngle;
    xs += sin(thetaBase + theta);
    ys += cos(thetaBase + theta);
    if (wp.edgeCollisionTerminates && isOutOfBounds((int) xs, (int) ys)) {
      if (!ps.isEmpty()) {
        int low = ps.size() / 4;
        int high = ps.size() * 3 / 4;
        if (high - low == 0) {
          low = 0;
          high = ps.size();
        }
        int p = ps.remove(wp.rng.nextInt(low, high));
        xs = p % origImg.width;
        ys = p / origImg.width;
        curveAngle = Math.signum(-curveAngle) * wp.curveBase;
        curveIncrement *= -1;
      } else {
        break;
      }
    } else {
      xs = (xs + origImg.width) % origImg.width;
      ys = (ys + origImg.height) % origImg.height;
    }
    if (wp.rng.nextFloat() < wp.bifurcationProbability * pow(pow(xs - ox, 2) + pow(ys - oy, 2), 0.7) && !ps.isEmpty()) {
      int low = ps.size() / 4;
      int high = ps.size() * 3 / 4;
      if (high - low == 0) {
        low = 0;
        high = ps.size();
      }
      int p = ps.remove(wp.rng.nextInt(low, high));
      xs = p % origImg.width;
      ys = p / origImg.width;
      curveAngle = Math.signum(-curveAngle) * wp.curveBase;
      curveIncrement *= -1;
    }
    curveAngle += curveIncrement;
    curveAngle -= (pow(xs - ox, 2) + pow(ys - oy, 2)) * angleScale;
    if (abs(curveAngle) > PI / 60) {
      curveAngle *= 0.01;
    }
    maxC = max(maxC, curveAngle);
  }
  return steps;
}

PixOp[] wander3p(int x, int y, color cNew, SplittableRandom rng) {
  //  float thetaBase = wp.rng.nextFloat(-PI, PI);
  float thetaBase = (float) wp.rng.nextGaussian(PI / 2, 1);
  float theta = 0;
  float curveAngle = (float) ((wp.rng.nextBoolean() ? wp.curveBase : -wp.curveBase) * wp.rng.nextGaussian(1, 0.001));
  float curveIncrement = (curveAngle < 0 ? -wp.curveBase : wp.curveBase) / origImg.width;
  float opacity;
  float angleScale = 10000.0 / (origImg.width * origImg.height) * curveIncrement;
  int tourLength = getTourLength();
  List<Integer> ps = new LinkedList<>();
  BitSet painted = new BitSet();
  float ox = x;
  float oy = y;
  float xs = x;
  float ys = y;
  float maxC = 0;
  PixOp[] tour = new PixOp[tourLength];
  int pIdx = 0;

  int steps;
  for (steps = 0; steps < tourLength; steps++) {
    opacity = getOpacity(steps, tourLength);
    if (opacity < OPACITY_THRESHOLD) {
      break;
    }

    ps.add((int) xs + (int) ys * origImg.width);
    int xt = (int) xs;
    int yt = (int) ys;
    if (!wp.edgeCollisionTerminates || (xt >= 0 && xt < origImg.width && yt >= 0 && yt < origImg.height)) {
      tour[pIdx++] = new PixOp(xt + yt * origImg.width, opacity);
    }

    theta += curveAngle;
    xs += sin(thetaBase + theta);
    ys += cos(thetaBase + theta);
    if (wp.edgeCollisionTerminates && isOutOfBounds((int) xs, (int) ys)) {
      if (!ps.isEmpty()) {
        int low = ps.size() / 4;
        int high = ps.size() * 3 / 4;
        if (high - low == 0) {
          low = 0;
          high = ps.size();
        }
        int p = ps.remove(wp.rng.nextInt(low, high));
        xs = p % origImg.width;
        ys = p / origImg.width;
        curveAngle = Math.signum(-curveAngle) * wp.curveBase;
        curveIncrement *= -1;
      } else {
        break;
      }
    } else {
      xs = (xs + origImg.width) % origImg.width;
      ys = (ys + origImg.height) % origImg.height;
    }
    if (wp.rng.nextFloat() < wp.bifurcationProbability * pow(pow(xs - ox, 2) + pow(ys - oy, 2), 0.7) && !ps.isEmpty()) {
      int low = ps.size() / 4;
      int high = ps.size() * 3 / 4;
      if (high - low == 0) {
        low = 0;
        high = ps.size();
      }
      int p = ps.remove(wp.rng.nextInt(low, high));
      xs = p % origImg.width;
      ys = p / origImg.width;
      curveAngle = Math.signum(-curveAngle) * wp.curveBase;
      curveIncrement *= -1;
    }
    curveAngle += curveIncrement;
    curveAngle -= (pow(xs - ox, 2) + pow(ys - oy, 2)) * angleScale;
    if (abs(curveAngle) > PI / 60) {
      curveAngle *= 0.01;
    }
    maxC = max(maxC, curveAngle);
  }

  return tour;
}

boolean isOutOfBounds(int x, int y) {
  return x < 0 || x >= origImg.width || y < 0 || y >= origImg.height;
}

int[] shuffle(int size) {
  int[] perm = new int[size];
  for (int i = 0; i < size; i++) {
    perm[i] = i;
  }
  for (int i = size - 1; i > 0; i--) {
    float x = wp.rng.nextFloat();
    int r = (int) (barron(x, 0.3, 0) * (i + 1));

    int t = perm[r];
    perm[r] = perm[i];
    perm[i] = t;
  }
  return perm;
}

Thread drawProcessor(ArrayBlockingQueue<DrawSequence> drawQueue) {
  return new Thread(new Runnable() {

    @Override void run() {
      while (!Thread.currentThread().isInterrupted()) {
        try {
          DrawSequence ds = drawQueue.take();
          PixOp[] ps = ds.ps;
          int pp = 0;
          for (pp = 0; pp < ps.length && ps[pp] != null; pp++) ;
          Arrays.sort(ps, 0, pp);
          for (int i = 0; i < ps.length && ps[i] != null; i++) {
            PixOp po = ps[i];
            int x = po.p % origImg.width;
            int y = po.p / origImg.width;
            if (!paintImage(x, y, ds.c, po.opacity)) {
              break;
            }
            pp++;
          }
          pointsPlotted.addAndGet(pp);
        }
        catch(InterruptedException ie) {
          break;
        }
      }
    }
  }
  );
}

Thread wanderProcessor(ArrayBlockingQueue<WanderP> wanderQueue, ArrayBlockingQueue<DrawSequence> drawQueue, long seed) {
  final SplittableRandom rng = new SplittableRandom(seed);

  return new Thread(new Runnable() {
    @Override void run() {
      while (!Thread.currentThread().isInterrupted()) {
        try {
          WanderP w = wanderQueue.take();
          PixOp[] ps = w.wander(rng);
          drawQueue.put(new DrawSequence(ps, w.getColor()));
        }
        catch(InterruptedException ie) {
          break;
        }
      }
    }
  }
  );
}
