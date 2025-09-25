public static class WeightedCoordinate implements Comparable<WeightedCoordinate> {
  public final int x;
  public final int y;
  public final float weight;

  public WeightedCoordinate(int x, int y, float weight) {
    this.x = x;
    this.y = y;
    this.weight = weight;
  }

  @Override public int compareTo(WeightedCoordinate o) {
    return (int) Math.signum(o.weight - this.weight);
  }

  @Override public String toString() {
    return "WC -- x: " + this.x + ", y: " + y + ", weight: " + weight;
  }
}
