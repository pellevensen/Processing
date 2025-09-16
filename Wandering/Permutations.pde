import java.util.Iterator;
import java.util.SplittableRandom;

static class Perm implements Iterable<Integer> {
  int[] perm;

  public Perm(int max, int seed) {
    perm = new int[max];
    for (int i = 0; i < max; i++) {
      perm[i] = i;
    }

    SplittableRandom rng = new SplittableRandom(seed);
    for (int i = max - 1; i > 1; i--) {
      int r = rng.nextInt(i + 1);
      int t = perm[i];
      perm[i] = perm[r];
      perm[r] = t;
    }
  }

  @Override Iterator<Integer> iterator() {
    return new Iterator<>() {
      int pos = 0;
      @Override boolean hasNext() {
        return pos < perm.length - 1;
      }

      @Override Integer next() {
        return perm[pos++];
      }
    };
  }
}
