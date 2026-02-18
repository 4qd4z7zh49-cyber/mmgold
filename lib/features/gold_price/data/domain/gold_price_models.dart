class GoldPriceLatest {
  // Meta
  final String? date;
  final String? time;

  /// DateTime / int(ms) / ISO String / null
  final dynamic updatedAt;
  final String? imageUrl;

  // YGEA
  final int? ygea16;

  // 16 (old)
  final int? k16Buy;
  final int? k16Sell;

  // 16 (new system)
  final int? k16newBuy;
  final int? k16newSell;

  // 15 (old)
  final int? k15Buy;
  final int? k15Sell;

  // 15 (new system)
  final int? k15newBuy;
  final int? k15newSell;

  const GoldPriceLatest({
    this.date,
    this.time,
    this.updatedAt,
    this.imageUrl,
    this.ygea16,
    this.k16Buy,
    this.k16Sell,
    this.k16newBuy,
    this.k16newSell,
    this.k15Buy,
    this.k15Sell,
    this.k15newBuy,
    this.k15newSell,
  });

  // Alias getters (UI convenience)
  int? get k16NewBuy => k16newBuy;
  int? get k16NewSell => k16newSell;
  int? get k15NewBuy => k15newBuy;
  int? get k15NewSell => k15newSell;

  /// Convert updatedAt into DateTime when possible.
  /// Supports DateTime, int ms, ISO string.
  DateTime? get updatedAtDateTime {
    final v = updatedAt;
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) {
      // treat as milliseconds since epoch
      return DateTime.fromMillisecondsSinceEpoch(v);
    }
    if (v is String) {
      final dt = DateTime.tryParse(v);
      if (dt != null) return dt;
    }
    return null;
  }

  GoldPriceLatest copyWith({
    String? date,
    String? time,
    dynamic updatedAt,
    String? imageUrl,
    int? ygea16,
    int? k16Buy,
    int? k16Sell,
    int? k16newBuy,
    int? k16newSell,
    int? k15Buy,
    int? k15Sell,
    int? k15newBuy,
    int? k15newSell,
  }) {
    return GoldPriceLatest(
      date: date ?? this.date,
      time: time ?? this.time,
      updatedAt: updatedAt ?? this.updatedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      ygea16: ygea16 ?? this.ygea16,
      k16Buy: k16Buy ?? this.k16Buy,
      k16Sell: k16Sell ?? this.k16Sell,
      k16newBuy: k16newBuy ?? this.k16newBuy,
      k16newSell: k16newSell ?? this.k16newSell,
      k15Buy: k15Buy ?? this.k15Buy,
      k15Sell: k15Sell ?? this.k15Sell,
      k15newBuy: k15newBuy ?? this.k15newBuy,
      k15newSell: k15newSell ?? this.k15newSell,
    );
  }

  // ---------- Mapping helpers ----------

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString());
  }

  static String? _toStr(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  /// Supports both snake_case/camelCase keys.
  factory GoldPriceLatest.fromMap(Map<String, dynamic> m) {
    return GoldPriceLatest(
      date: _toStr(m['date']),
      time: _toStr(m['time']),
      updatedAt: m['updatedAt'] ?? m['updated_at'],
      imageUrl: _toStr(m['image_url'] ?? m['imageUrl']),

      ygea16: _toInt(m['ygea16'] ?? m['ygea_16'] ?? m['ygea']),

      // 16 old
      k16Buy: _toInt(m['k16_buy'] ?? m['k16Buy'] ?? m['k16buy']),
      k16Sell: _toInt(m['k16_sell'] ?? m['k16Sell'] ?? m['k16sell']),

      // 16 new system
      k16newBuy: _toInt(m['k16new_buy'] ?? m['k16newBuy'] ?? m['k16NewBuy']),
      k16newSell:
          _toInt(m['k16new_sell'] ?? m['k16newSell'] ?? m['k16NewSell']),

      // 15 old
      k15Buy: _toInt(m['k15_buy'] ?? m['k15Buy'] ?? m['k15buy']),
      k15Sell: _toInt(m['k15_sell'] ?? m['k15Sell'] ?? m['k15sell']),

      // 15 new system
      k15newBuy: _toInt(m['k15new_buy'] ?? m['k15newBuy'] ?? m['k15NewBuy']),
      k15newSell:
          _toInt(m['k15new_sell'] ?? m['k15newSell'] ?? m['k15NewSell']),
    );
  }

  /// Backward-compatible map with mixed key styles.
  Map<String, dynamic> toMap({bool includeSnakeCase = false}) {
    final map = <String, dynamic>{
      'date': date,
      'time': time,
      'updatedAt': updatedAt,
      'imageUrl': imageUrl,
      'ygea16': ygea16,
      'k16Buy': k16Buy,
      'k16Sell': k16Sell,
      'k16newBuy': k16newBuy,
      'k16newSell': k16newSell,
      'k15Buy': k15Buy,
      'k15Sell': k15Sell,
      'k15newBuy': k15newBuy,
      'k15newSell': k15newSell,
    };

    if (includeSnakeCase) {
      map.addAll({
        'updated_at': updatedAt,
        'image_url': imageUrl,
        'ygea_16': ygea16,
        'k16_buy': k16Buy,
        'k16_sell': k16Sell,
        'k16new_buy': k16newBuy,
        'k16new_sell': k16newSell,
        'k15_buy': k15Buy,
        'k15_sell': k15Sell,
        'k15new_buy': k15newBuy,
        'k15new_sell': k15newSell,
      });
    }

    // remove nulls for cleaner writes
    map.removeWhere((key, value) => value == null);
    return map;
  }

  /// Preferred map for Supabase columns.
  Map<String, dynamic> toSupabaseMap() {
    final map = <String, dynamic>{
      'date': date,
      'time': time,
      'updated_at': updatedAt,
      'image_url': imageUrl,
      'ygea16': ygea16,
      'k16_buy': k16Buy,
      'k16_sell': k16Sell,
      'k16new_buy': k16newBuy,
      'k16new_sell': k16newSell,
      'k15_buy': k15Buy,
      'k15_sell': k15Sell,
      'k15new_buy': k15newBuy,
      'k15new_sell': k15newSell,
    };
    map.removeWhere((key, value) => value == null);
    return map;
  }
}
