import java.util.Iterator;
import java.util.SplittableRandom;

static class Perm implements Iterable<Integer> {
  private int[] perm;
  private long size;
  private int s;
  private long mulc;
  private long mask;
  private long ctr;

  //public Perm(int max, int seed) {
  //  setupShufflePerm(max, seed);
  //}

  private void setupShufflePerm(int max, int seed) {
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

  private long mix(long ctr) {
    for (int i = 0; i < 3; i++) {
      ctr ^= ~(ctr << s);
      ctr = ((ctr & mask) * mulc) & mask;
    }
    return ctr;
  }

  public Perm(long max, long seed) {
    if (max < 1 << 24) {
      setupShufflePerm((int) max, (int) seed);
    } else {
      this.s = (int) (64 - Long.numberOfLeadingZeros(max)); //<>//
      this.mask = (1L << this.s) - 1;
      this.s /= 2;
      this.mulc = 23456789;
      this.mulc = mix(seed) | 1;
      this.ctr = mix(mix(seed));
      this.size = max;
    }
  }

  @Override Iterator<Integer> iterator() {
    if (perm != null) {
      return new Iterator<>() {
        int pos = 0;
        @Override boolean hasNext() {
          return pos < perm.length - 1;
        }

        @Override Integer next() {
          if (pos < perm.length) {
            return perm[pos++];
          } else {
            return 0;
          }
        }
      };
    } else {
      return new Iterator<>() {
        int pos = 0;
        @Override boolean hasNext() {
          return pos < size;
        }

        @Override Integer next() {
          long p = 0;
          do {
            ctr++; //<>//
            p = mix(ctr);
          } while (p >= size);
          pos++;
          return (int) p;
        }
      };
    }
  }
}
