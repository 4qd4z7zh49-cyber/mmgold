class NotificationDestination {
  static const String goldPrice = 'gold_price';
  static const String holdings = 'holdings';
  static const String calculator = 'calculator';
  static const String history = 'history';

  static const String defaultTarget = goldPrice;

  static const List<NotificationTargetOption> options = [
    NotificationTargetOption(value: goldPrice, label: 'ရွှေဈေး'),
    NotificationTargetOption(value: holdings, label: 'စုဘူး'),
    NotificationTargetOption(value: calculator, label: 'တွက်ချက်'),
    NotificationTargetOption(value: history, label: 'မှတ်တမ်း'),
  ];

  static String normalize(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    switch (value) {
      case holdings:
        return holdings;
      case calculator:
        return calculator;
      case history:
        return history;
      case goldPrice:
      default:
        return defaultTarget;
    }
  }

  static int? tabIndexFor(String? target) {
    switch (normalize(target)) {
      case goldPrice:
        return 0;
      case holdings:
        return 1;
      case calculator:
        return 2;
      case history:
        return 3;
      default:
        return null;
    }
  }
}

class NotificationTargetOption {
  final String value;
  final String label;

  const NotificationTargetOption({
    required this.value,
    required this.label,
  });
}
