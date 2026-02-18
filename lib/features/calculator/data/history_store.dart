import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryStore {
  static const _key = 'voucher_history';

  static Future<List<Map<String, dynamic>>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<void> saveAll(List<Map<String, dynamic>> list) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(list));
  }

  static Future<void> add(Map<String, dynamic> item) async {
    final list = await load();
    list.insert(0, item);
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
    list[index] = value;
    await saveAll(list);
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key);
  }
}
