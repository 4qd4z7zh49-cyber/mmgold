// Domain types only (NO UI).

// 1) Buy / Sell
enum ActionType { buy, sell }

// 2) Gold form: bar (အတုံး) / ornament (အထည်)
enum GoldForm { bar, ornament }

extension GoldFormLabel on GoldForm {
  String get label {
    switch (this) {
      case GoldForm.bar:
        return 'အတုံး';
      case GoldForm.ornament:
        return 'အထည်';
    }
  }
}

// 4) Purity factors vs 16-pae gold
class GoldPurity {
  static const Map<String, double> factor = {
    '16 ပဲရည်': 16 / 16,
    '15 ပဲရည်': 15 / 16,
    '14 ပဲ ၂ ပြား': (14 + 2 / 8) / 16,
    '14 ပဲ': 14 / 16,
    '13 ပဲ ၂ ပြား': (13 + 2 / 8) / 16,
    '13 ပဲ': 13 / 16,
    '12 ပဲ ၂ ပြား': (12 + 2 / 8) / 16,
    '12 ပဲ': 12 / 16,
  };
}

// 3) Discount (MMK / % / custom)
enum DiscountUnit { percent, mmk }

enum DiscountMode { none, mmk, percent, custom }

class DiscountValue {
  final DiscountMode mode;
  final double value;
  final DiscountUnit unit;

  const DiscountValue._(this.mode, this.value, this.unit);

  static const none = DiscountValue._(DiscountMode.none, 0, DiscountUnit.mmk);

  factory DiscountValue.mmk(double v) =>
      DiscountValue._(DiscountMode.mmk, v, DiscountUnit.mmk);

  factory DiscountValue.percent(double v) =>
      DiscountValue._(DiscountMode.percent, v, DiscountUnit.percent);

  factory DiscountValue.custom(double v, DiscountUnit unit) =>
      DiscountValue._(DiscountMode.custom, v, unit);

  bool get isPercent => unit == DiscountUnit.percent;
}