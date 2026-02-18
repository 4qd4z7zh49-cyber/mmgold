class MmWeight {
  static double toKyattha({
    required double kyat,
    required double pae,
    required double yway,
  }) {
    return kyat + (pae / 16.0) + (yway / 128.0);
  }

  static String format(double kyattha) {
    final sign = kyattha < 0 ? '-' : '';
    double x = kyattha.abs();

    int kyat = x.floor();
    x = (x - kyat) * 16;
    int pae = x.floor();
    x = (x - pae) * 8;
    int yway = x.round();

    if (yway >= 8) {
      yway -= 8;
      pae += 1;
    }
    if (pae >= 16) {
      pae -= 16;
      kyat += 1;
    }
    return '$sign$kyat ကျပ် $pae ပဲ $yway ရွေး';
  }
}