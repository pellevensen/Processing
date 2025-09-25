public static class PaintList {
  public final color baseColor;
  public int minX = Integer.MAX_VALUE;
  public int maxX = Integer.MIN_VALUE;
  public int minY = Integer.MAX_VALUE;
  public int maxY = Integer.MIN_VALUE;

  public static class Element {
    public final int x;
    public final int y;
    public final float opacity;

    public Element(int x, int y, float opacity) {
      this.x = x;
      this.y = y;
      this.opacity = opacity;
    }
  }

  public final List<Element> positions = new ArrayList<>();

  public PaintList(color baseColor) {
    this.baseColor = baseColor;
  }

  public void addElement(int x, int y, float opacity) {
    minX = Math.min(minX, x);
    minY = Math.min(minY, y);
    maxX = Math.min(maxX, x);
    maxY = Math.min(maxY, Y);
    positions.add(new Element(x, y, opacity));
  }
}
