import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mmgold/shared/widgets/frosted_panel.dart';
import 'package:mmgold/shared/widgets/gradient_scaffold.dart';
import '../data/domain/gold_price_repo.dart';
import '../data/domain/gold_price_models.dart';
import 'gold_price_history_page.dart';

class GoldPricePage extends StatefulWidget {
  const GoldPricePage({super.key});

  @override
  State<GoldPricePage> createState() => _GoldPricePageState();
}

class _GoldPricePageState extends State<GoldPricePage> {
  final _repo = GoldPriceRepo();
  late Future<_GoldPriceViewData> _latestFuture;

  @override
  void initState() {
    super.initState();
    _latestFuture = _loadData();
  }

  Future<void> _refresh() async {
    setState(() {
      _latestFuture = _loadData();
    });
    await _latestFuture;
  }

  Future<_GoldPriceViewData> _loadData() async {
    final latest = await _repo.fetchLatest();
    final prev = await _repo.fetchLatestHistory();
    return _GoldPriceViewData(current: latest, previous: prev);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final floatingNavClearance = MediaQuery.paddingOf(context).bottom + 112;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('မြန်မာ့ရွှေဈေး Update'),
        centerTitle: false,
        actions: [
          if (kIsWeb)
            IconButton(
              tooltip: 'Admin Dashboard',
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () => Navigator.pushNamed(context, '/admin'),
            ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GoldPriceHistoryPage()),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<_GoldPriceViewData>(
        future: _latestFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Gold price service မချိတ်ဆက်ရသေးပါ'),
            );
          }

          final p = snapshot.data?.current;
          final prev = snapshot.data?.previous;
          if (p == null) {
            return const Center(child: Text('ဈေးအချက်အလက် မရှိသေးပါ'));
          }

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, floatingNavClearance),
            child: FrostedPanel(
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.all(16),
              startAlpha: 0.60,
              endAlpha: 0.40,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== Header =====
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(p.date ?? '', style: t.labelMedium),
                      Text(p.time ?? '', style: t.labelMedium),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ရွှေအသင်းပေါက်ဈေး',
                    style: t.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _money(p.ygea16),
                    style: t.titleLarge,
                  ),
                  if (p.imageUrl != null && p.imageUrl!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        p.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          alignment: Alignment.center,
                          color: cs.surface.withValues(alpha: 0.42),
                          child: const Text('Image မဖော်နိုင်ပါ'),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  Divider(color: cs.outlineVariant),
                  const SizedBox(height: 12),

                  Text('ပြင်ပပေါက်ဈေးများ', style: t.titleMedium),
                  const SizedBox(height: 12),

                  // ===== 16 K =====
                  _sectionTitle(context, '၁၆ ပဲရည်'),
                  if (_delta(p.k16Sell, prev?.k16Sell) != null) ...[
                    _deltaBadge(context, _delta(p.k16Sell, prev?.k16Sell)!),
                    const SizedBox(height: 8),
                  ],
                  _priceRow(
                    context,
                    buy: p.k16Buy,
                    sell: p.k16Sell,
                  ),

                  const SizedBox(height: 12),

                  // ===== 16 New =====
                  _sectionTitle(context, '၁၆ ပဲရည် စနစ်သစ်'),
                  if (_delta(p.k16NewSell, prev?.k16NewSell) != null) ...[
                    _deltaBadge(
                        context, _delta(p.k16NewSell, prev?.k16NewSell)!),
                    const SizedBox(height: 8),
                  ],
                  _priceRow(
                    context,
                    buy: p.k16NewBuy,
                    sell: p.k16NewSell,
                  ),

                  const SizedBox(height: 12),

                  // ===== 15 K =====
                  _sectionTitle(context, '၁၅ ပဲရည်'),
                  if (_delta(p.k15Sell, prev?.k15Sell) != null) ...[
                    _deltaBadge(context, _delta(p.k15Sell, prev?.k15Sell)!),
                    const SizedBox(height: 8),
                  ],
                  _priceRow(
                    context,
                    buy: p.k15Buy,
                    sell: p.k15Sell,
                  ),

                  const SizedBox(height: 12),

                  // ===== 15 New =====
                  _sectionTitle(context, '၁၅ ပဲရည် စနစ်သစ်'),
                  if (_delta(p.k15NewSell, prev?.k15NewSell) != null) ...[
                    _deltaBadge(
                        context, _delta(p.k15NewSell, prev?.k15NewSell)!),
                    const SizedBox(height: 8),
                  ],
                  _priceRow(
                    context,
                    buy: p.k15NewBuy,
                    sell: p.k15NewSell,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===== Widgets =====

  Widget _sectionTitle(BuildContext context, String title) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: t.titleMedium,
      ),
    );
  }

  Widget _priceRow(
    BuildContext context, {
    int? buy,
    int? sell,
  }) {
    return Row(
      children: [
        Expanded(
          child: _priceBox(
            context,
            label: 'ဝယ်',
            value: buy,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _priceBox(
            context,
            label: 'ရောင်း',
            value: sell,
          ),
        ),
      ],
    );
  }

  Widget _deltaBadge(BuildContext context, int delta) {
    final cs = Theme.of(context).colorScheme;

    final Color fg;
    final Color bg;
    if (delta > 0) {
      fg = Colors.green.shade700;
      bg = Colors.green.withValues(alpha: 0.12);
    } else if (delta < 0) {
      fg = Colors.red.shade700;
      bg = Colors.red.withValues(alpha: 0.12);
    } else {
      fg = cs.onSurfaceVariant;
      bg = cs.surfaceContainerHighest;
    }

    final sign = delta > 0 ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$sign${_money(delta)}',
        style: TextStyle(fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _priceBox(
    BuildContext context, {
    required String label,
    int? value,
  }) {
    final t = Theme.of(context).textTheme;
    return FrostedPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(14),
      blurSigma: 8,
      startAlpha: 0.62,
      endAlpha: 0.44,
      borderAlpha: 0.56,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.labelMedium),
          const SizedBox(height: 6),
          Text(
            _money(value),
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  int? _delta(int? current, int? previous) {
    if (current == null || previous == null) return null;
    return current - previous;
  }

  // ===== Utils =====

  String _money(int? v) {
    if (v == null) return '-';
    final s = v.toString();
    return s.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
  }
}

class _GoldPriceViewData {
  final GoldPriceLatest? current;
  final GoldPriceLatest? previous;

  const _GoldPriceViewData({required this.current, required this.previous});
}
