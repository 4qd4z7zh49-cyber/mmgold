import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryStore {
  static const _key = 'calculator_history_v2';
  static const _legacyKey = 'voucher_history';
  static const _typeField = 'historyType';
  static const _calculatorType = 'calculator';

  static final ValueNotifier<int> _revision = ValueNotifier<int>(0);
  static ValueListenable<int> get revision => _revision;

  static void _bumpRevision() {
    _revision.value++;
  }

  static Map<String, dynamic> _normalizeItem(Map<String, dynamic> item) {
    return Map<String, dynamic>.from(item)..[_typeField] = _calculatorType;
  }

  static bool _isCalculatorHistory(Map<String, dynamic> item) {
    final typed = (item[_typeField] ?? '').toString();
    if (typed.isNotEmpty) return typed == _calculatorType;

    return item.containsKey('action') &&
        item.containsKey('goldType') &&
        item.containsKey('finalAmount');
  }

  static Future<void> _migrateLegacyIfNeeded(SharedPreferences sp) async {
    final currentRaw = sp.getString(_key);
    if (currentRaw != null && currentRaw.isNotEmpty) return;

    final legacyRaw = sp.getString(_legacyKey);
    if (legacyRaw == null || legacyRaw.isEmpty) return;

    try {
      final decoded = jsonDecode(legacyRaw) as List;
      final migrated = decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>()))
          .where(_isCalculatorHistory)
          .map(_normalizeItem)
          .toList();

      await sp.setString(_key, jsonEncode(migrated));
      await sp.remove(_legacyKey);
      _bumpRevision();
    } catch (_) {
      // Keep legacy payload as-is if migration fails.
    }
  }

  static Future<List<Map<String, dynamic>>> load() async {
    final sp = await SharedPreferences.getInstance();
    await _migrateLegacyIfNeeded(sp);

    final raw = sp.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>()))
          .where(_isCalculatorHistory)
          .map(_normalizeItem)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<Map<String, dynamic>> list) async {
    final sp = await SharedPreferences.getInstance();
    final normalized = list.map(_normalizeItem).toList();
    await sp.setString(_key, jsonEncode(normalized));
    _bumpRevision();
  }

  static Future<void> add(Map<String, dynamic> item) async {
    final list = await load();
    list.insert(0, _normalizeItem(item));
    await saveAll(list);
  }

  static Future<void> deleteMany(Set<String> ids) async {
    final list = await load();
    list.removeWhere((e) => ids.contains((e['id'] ?? '').toString()));
    await saveAll(list);
  }

  static Future<void> updateById({
    required String id,
    required Map<String, dynamic> value,
  }) async {
    final list = await load();
    final index = list.indexWhere((e) => (e['id'] ?? '').toString() == id);
    if (index < 0) return;
    list[index] = _normalizeItem(value);
    await saveAll(list);
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key);
    _bumpRevision();
  }
}
