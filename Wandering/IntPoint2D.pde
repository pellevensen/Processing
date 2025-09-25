public static class IntPoint2D {
  public final int x;
  public final int y;

  public IntPoint2D(int x, int y) {
    this.x = x;
    this.y = y;
  }

  @Override public int hashCode() {
    int h = x;
    h *= 23456789;
    h ^= ~h >>> 16;
    h += y;
    h *= 23456789;
    h ^= ~h >>> 16;
    h += x;
    h *= 23456789;
    h ^= ~h >>> 16;
    h += y;
    return h;
  }

  @Override public boolean equals(Object o) {
    if (o == this) {
      return true;
    }
    if (o == null || o.getClass() != this.getClass()) {
      return false;
    }
    IntPoint2D o2 = (IntPoint2D) o;
    return o2.x == this.x && o2.y == this.y;
  }
}
