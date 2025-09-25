public static class PointHistogram { //<>//
  private final int w;
  private final int h;
  private final int[] hist;

  public PointHistogram(int width, int height) {
    this.w = width;
    this.h = height;
    this.hist = new int[width * height];
  }

  public int add(int x, int y) {
    return add(x + y * this.w);
  }

  public void clear(int x, int y) {
    this.hist[x + y * this.w] = 0;
  }

  public int add(int p) {
    return ++this.hist[p];
  }

  public int getHits(int x, int y) {
    return getHits(x + y * this.w);
  }

  public int getHits(int p) {
    return this.hist[p];
  }

  public void clear(int p) {
    this.hist[p] = 0;
  }

  public List<IntPoint2D> getSortedPoints(int max, boolean descending, BitSet exclude) {
    if (max < 0) {
      max = this.w * this.h;
    }
    max = min(max, this.w * this.h);

    class WPoint2D implements Comparable<WPoint2D> {
      public final IntPoint2D p;
      public final int w;

      public WPoint2D(IntPoint2D p, int w) {
        this.p = p;
        this.w = w;
      }
      @Override int compareTo(WPoint2D other) {
        int w = (int) Math.signum(other.w - this.w) * (descending ? -1 : 1);
        if (w != 0) {
          return w;
        }
        int xd = (int) Math.signum(other.p.x - this.p.x);
        if (xd != 0) {
          return xd;
        }
        return (int) Math.signum(other.p.y - this.p.y);
      }
      @Override public boolean equals(Object o) {
        if (o == this) {
          return true;
        }
        if (o == null || o.getClass() != this.getClass()) {
          return false;
        }
        WPoint2D o2 = (WPoint2D) o;
        return this.w == o2.w && this.p.equals(o2.p);
      }
    }
    if (max < this.w * this.h * 0.1) {
      SortedSet<WPoint2D> sorted = new TreeSet<>();
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          int p = x + y * this.w;
          if (hist[p] > 0 && !exclude.get(p)) {
            sorted.add(new WPoint2D(new IntPoint2D(x, y), this.hist[x + y * this.w]));
            if (sorted.size() > max * 2) {
              SortedSet<WPoint2D> tmpSorted = new TreeSet<>();
              Iterator<WPoint2D> sIt = sorted.iterator();
              for (int i = 0; i < max && sIt.hasNext(); i++) {
                tmpSorted.add(sIt.next());
              }
              sorted = tmpSorted;
            }
          }
        }
      }
      List<IntPoint2D> points = new ArrayList<>();
      Iterator<WPoint2D> sIt = sorted.iterator();

      for (int i = 0; i < max && sIt.hasNext(); i++) {
        points.add(sIt.next().p);
      }
      return points;
    } else {
      WPoint2D[] sorted = new WPoint2D[max];
      int p = 0;
      for (int y = 0; y < this.h; y++) {
        for (int x = 0; x < w; x++) {
          sorted[p++] = new WPoint2D(new IntPoint2D(x, y), this.hist[x + y * this.w]);
        }
      }
      Arrays.sort(sorted);
      List<IntPoint2D> points = new ArrayList<>();

      for (int i = 0; i < max; i++) {
        points.add(sorted[i].p);
      }
      return points;
    }
  }
}
