import 'package:mmgold/shared/supabase/supabase_provider.dart';

import 'gold_price_models.dart';

class GoldPriceRepo {
  static const _latestTable = 'gold_price_latest';
  static const _historyTable = 'gold_price_history';

  Future<GoldPriceLatest?> fetchLatest() async {
    final client = SupabaseProvider.client;

    final row =
        await client.from(_latestTable).select().eq('id', 1).maybeSingle();

    if (row == null) return null;
    return GoldPriceLatest.fromMap(Map<String, dynamic>.from(row));
  }

  Stream<List<GoldPriceLatest>> historyStream({int limit = 50}) {
    final client = SupabaseProvider.client;

    return client
        .from(_historyTable)
        .stream(primaryKey: ['id'])
        .order('updated_at', ascending: false)
        .limit(limit)
        .map(
          (rows) => rows
              .map((r) => GoldPriceLatest.fromMap(Map<String, dynamic>.from(r)))
              .toList(),
        );
  }

  Future<void> updateLatestAutoHistory(GoldPriceLatest newValue) async {
    final client = SupabaseProvider.client;

    final prev =
        await client.from(_latestTable).select().eq('id', 1).maybeSingle();

    if (prev != null && prev.isNotEmpty) {
      final history = Map<String, dynamic>.from(prev)
        ..remove('id')
        ..['archived_at'] = DateTime.now().toIso8601String();

      await client.from(_historyTable).insert(history);
    }

    final now = DateTime.now();
    final map = newValue.toSupabaseMap();
    map['id'] = 1;
    map['date'] = map['date'] ?? _fmtDate(now);
    map['time'] = map['time'] ?? _fmtTime(now);
    map['updated_at'] = DateTime.now().toIso8601String();

    await client.from(_latestTable).upsert(map, onConflict: 'id');
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${h.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} $ampm';
  }
}
