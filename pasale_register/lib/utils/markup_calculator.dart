class MarkupCalculator {
  static double calculateSellingPrice(double costPrice, double markupPercent) {
    if (costPrice < 0 || markupPercent < 0) return 0.0;
    return costPrice + (costPrice * (markupPercent / 100.0));
  }
}
