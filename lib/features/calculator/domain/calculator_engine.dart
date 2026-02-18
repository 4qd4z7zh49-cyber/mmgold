class CalculatorResult {
  final double discountWeight; // kyattha
  final double netWeight; // kyattha
  final double baseAmount; // MMK (before discount)
  final double discountAmount; // MMK
  final double finalAmount; // MMK (after discount)

  const CalculatorResult({
    required this.discountWeight,
    required this.netWeight,
    required this.baseAmount,
    required this.discountAmount,
    required this.finalAmount,
  });
}

class CalculatorEngine {
  static CalculatorResult calculate({
    required double market16,
    required double factor,
    required double weightKyattha,
    required double discountAmount,
    required bool isBuy,
  }) {
    final denom = market16 * factor;

    final discountWeight =
        (discountAmount <= 0 || denom <= 0) ? 0.0 : (discountAmount / denom);

    final netWeight = isBuy
        ? (weightKyattha + discountWeight)
        : (weightKyattha - discountWeight);

    final safeNet = netWeight < 0 ? 0.0 : netWeight;

    // Voucher rule:
    // Base = original weight (before discount)
    final baseAmount = market16 * weightKyattha * factor;

    // Final = net weight (after discount)
    final finalAmount = market16 * safeNet * factor;

    return CalculatorResult(
      discountWeight: discountWeight,
      netWeight: safeNet,
      baseAmount: baseAmount,
      discountAmount: discountAmount,
      finalAmount: finalAmount,
    );
  }
}