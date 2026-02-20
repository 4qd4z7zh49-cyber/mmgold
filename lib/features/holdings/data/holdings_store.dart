import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class HoldingsStore {
  static const _key = 'my_holdings_v1';

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
}
