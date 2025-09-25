// Code originally from ChatGPT, tweaks by pelle@evensen.org.
public static class Sobol2 {
  // number of direction bits (32 gives 32-bit fractional resolution)
  private static final int BITS = 32;
  private final int[] v1 = new int[BITS + 1]; // direction numbers for dim 1 (1..BITS)
  private final int[] v2 = new int[BITS + 1]; // direction numbers for dim 2
  private int state = 0;        // index of last produced sample (starts at 0)
  private int x1 = 0, x2 = 0;   // integer Gray-XOR states for each dimension

  // scale to map 32-bit integer fraction -> double in [0,1)
  private static final double SCALE = 1.0 / 4294967296.0; // 1 / 2^32

  public Sobol2() {
    initDirectionNumbers();
  }

  // Initialize direction numbers for dim 1 and dim 2
  private void initDirectionNumbers() {
    // Dim 1: simple van der Corput in base 2 (m1 = 1)
    // v1[i] = 1 << (32 - i)  for i = 1..BITS
    for (int i = 1; i <= BITS; i++) {
      v1[i] = 1 << (32 - i);
    }

    // Dim 2: parameters: s=2, a=1, m = [1, 3]
    // See classical Sobol initialization formula
    int s = 2;
    int a = 1;
    int[] m = new int[] { 0, 1, 3 }; // 1-based indexing: m[1]=1, m[2]=3

    // for i = 1..s set v[i] = m[i] << (32 - i)
    for (int i = 1; i <= s; i++) {
      v2[i] = m[i] << (32 - i);
    }
    // for i = s+1..BITS compute v[i] using recurrence:
    for (int i = s + 1; i <= BITS; i++) {
      int vi = v2[i - s] ^ (v2[i - s] >>> s);
      // apply the a coefficients
      for (int k = 1; k <= s - 1; k++) {
        int ak = (a >>> (s - 1 - k)) & 1;
        if (ak == 1) {
          vi ^= v2[i - k];
        }
      }
      v2[i] = vi;
    }
  }

  /**
   * Generate next Sobol point in 2D as double[2] in [0,1).
   * The sequence starts with index = 0 -> point (0,0).
   */
  public double[] next() {
    // increment state (we use indices starting at 1 for the Gray-bit trick)
    state++;
    // find the index (1-based) of the rightmost set bit of 'state'
    // (ctz gives number of trailing zeros in state; position = ctz + 1)
    int c = Integer.numberOfTrailingZeros(state) + 1; // 1..BITS

    // update XOR accumulators for each dimension
    x1 ^= v1[c];
    x2 ^= v2[c];

    // map to double in [0,1)
    double u = (x1 & 0xFFFFFFFFL) * SCALE;
    double v = (x2 & 0xFFFFFFFFL) * SCALE;
    return new double[] { u, v };
  }

  /** Reset the sequence to start (next() will return index 1 point; index 0 was (0,0)). */
  public void reset() {
    state = 0;
    x1 = 0;
    x2 = 0;
  }

  /** Produce the i-th point directly (0-based). Uses repeated next() internally (simple). */
  public double[] sampleAtIndex(int i) {
    if (i < 0) throw new IllegalArgumentException("index must be >= 0");
    reset();
    double[] p = new double[] {0.0, 0.0};
    for (int k = 0; k <= i; k++) p = next();
    return p;
  }
}
