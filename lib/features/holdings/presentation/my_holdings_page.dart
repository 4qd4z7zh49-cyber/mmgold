import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:mmgold/features/calculator/domain/calculator_types.dart';
import 'package:mmgold/features/holdings/data/holdings_store.dart';
import 'package:mmgold/features/gold_price/data/domain/gold_price_repo.dart';
import 'package:mmgold/shared/utils/mm_weight.dart';
import 'package:mmgold/shared/widgets/frosted_panel.dart';
import 'package:mmgold/shared/widgets/gradient_scaffold.dart';

class MyHoldingsPage extends StatefulWidget {
  const MyHoldingsPage({super.key});

  @override
  State<MyHoldingsPage> createState() => _MyHoldingsPageState();
}

class _MyHoldingsPageState extends State<MyHoldingsPage>
    with SingleTickerProviderStateMixin {
  final _repo = GoldPriceRepo();
  final _wKyatCtrl = TextEditingController();
  final _wPaeCtrl = TextEditingController();
  final _wYwayCtrl = TextEditingController();
  final _buyPriceCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  late final AnimationController _chartPulseCtrl;

  bool _loading = true;
  bool _hideBalance = false;
  List<_HoldingItem> _items = const [];

  String _goldForm = GoldForm.bar.name;
  String _goldType = '16 ပဲရည်';

  @override
  void initState() {
    super.initState();
    _chartPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _loadHoldings();
  }

  @override
  void dispose() {
    _chartPulseCtrl.dispose();
    _wKyatCtrl.dispose();
    _wPaeCtrl.dispose();
    _wYwayCtrl.dispose();
    _buyPriceCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHoldings() async {
    final rows = await HoldingsStore.load();
    if (!mounted) return;
    setState(() {
      _items = rows.map(_HoldingItem.fromMap).toList();
      _loading = false;
    });
  }

  Future<void> _saveHoldings() async {
    await HoldingsStore.saveAll(_items.map((e) => e.toMap()).toList());
  }

  double _toNum(String raw) {
    final cleaned = raw.trim().replaceAll(',', '').replaceAll(' ', '');
    return double.tryParse(cleaned) ?? 0;
  }

  Future<void> _addHolding() async {
    final kyat = _toNum(_wKyatCtrl.text);
    final pae = _toNum(_wPaeCtrl.text);
    final yway = _toNum(_wYwayCtrl.text);
    final buyPrice16 = _toNum(_buyPriceCtrl.text);
    final feeAmount = _toNum(_feeCtrl.text);

    if (kyat < 0 || pae < 0 || yway < 0 || pae >= 16 || yway >= 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('အလေးချိန်ဖော်ပြချက်: ပဲ < 16, ရွေး < 8 ဖြစ်ရပါမည်')),
      );
      return;
    }

    final weight = MmWeight.toKyattha(kyat: kyat, pae: pae, yway: yway);

    if (weight <= 0 || buyPrice16 <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('အလေးချိန် နဲ့ ဝယ်ယူခဲ့သောဈေး ကို မှန်ကန်စွာထည့်ပါ')),
      );
      return;
    }

    final item = _HoldingItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      goldForm: _goldForm,
      goldType: _goldType,
      weightKyattha: weight,
      buyPrice16: buyPrice16,
      feeAmount: feeAmount,
    );

    setState(() {
      _items = [item, ..._items];
      _wKyatCtrl.clear();
      _wPaeCtrl.clear();
      _wYwayCtrl.clear();
      _buyPriceCtrl.clear();
      _feeCtrl.clear();
    });
    await _saveHoldings();
  }

  int _current16Price(dynamic latest) {
    final v = latest?.k16Buy ?? latest?.k16newBuy ?? latest?.ygea16;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  double _factorOf(String goldType) => GoldPurity.factor[goldType] ?? 1.0;

  String _money(num v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }

  String _goldFormLabel(String v) {
    return v == GoldForm.ornament.name ? 'အထည်' : 'အတုံး';
  }

  double _assetCurrentValue(_HoldingItem e, int current16) {
    if (current16 <= 0) return 0;
    return current16 * e.weightKyattha * _factorOf(e.goldType);
  }

  double _assetCostValue(_HoldingItem e) {
    return (e.buyPrice16 * e.weightKyattha * _factorOf(e.goldType)) +
        e.feeAmount;
  }

  List<_BreakdownRow> _buildBreakdownRows(int current16) {
    final grouped = <String, _BreakdownRow>{};
    for (final e in _items) {
      final key = '${_goldFormLabel(e.goldForm)} • ${e.goldType}';
      final existing = grouped[key];
      final current = _assetCurrentValue(e, current16);
      final cost = _assetCostValue(e);
      if (existing == null) {
        grouped[key] = _BreakdownRow(label: key, current: current, cost: cost);
      } else {
        grouped[key] = _BreakdownRow(
          label: key,
          current: existing.current + current,
          cost: existing.cost + cost,
        );
      }
    }
    final list = grouped.values.toList();
    list.sort((a, b) => b.current.compareTo(a.current));
    return list;
  }

  Widget _panel(BuildContext context, Widget child) {
    return FrostedPanel(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(18),
      startAlpha: 0.60,
      endAlpha: 0.40,
      borderAlpha: 0.58,
      child: child,
    );
  }

  Widget _buildBalanceCard({
    required BuildContext context,
    required double totalCurrent,
    required double netPnL,
    required int current16,
  }) {
    final cs = Theme.of(context).colorScheme;
    final pnlUp = netPnL >= 0;
    final pnlColor = pnlUp ? const Color(0xFF139C5B) : cs.error;

    return Container(
      constraints: const BoxConstraints(minHeight: 320),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surface.withValues(alpha: 0.96),
            cs.primaryContainer.withValues(alpha: 0.42),
          ],
        ),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: cs.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'လက်ရှိစုငွေ',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              IconButton(
                tooltip: _hideBalance ? 'Show amount' : 'Hide amount',
                onPressed: () => setState(() => _hideBalance = !_hideBalance),
                icon: Icon(
                  _hideBalance
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Container(
                key: ValueKey(
                    '${_hideBalance}_${totalCurrent.toStringAsFixed(0)}'),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: _hideBalance
                      ? const Text(
                          '•••••••',
                          style: TextStyle(
                            fontSize: 46,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        )
                      : Text.rich(
                          textAlign: TextAlign.center,
                          TextSpan(
                            children: [
                              TextSpan(
                                text: _money(totalCurrent),
                                style: const TextStyle(
                                  fontSize: 46,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                ),
                              ),
                              TextSpan(
                                text: ' ကျပ်',
                                style: TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w900,
                                  color: cs.onSurface.withValues(alpha: 0.92),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: pnlColor.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _hideBalance
                  ? 'အတိုး/အလျော့: •••••••'
                  : 'အတိုး/အလျော့: ${pnlUp ? '+' : ''}${_money(netPnL)} ကျပ်',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: pnlColor,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            current16 > 0
                ? (_hideBalance
                    ? 'လက်ရှိ 16ပဲရည် ဝယ်ဈေး: •••••••'
                    : 'လက်ရှိ 16ပဲရည် ဝယ်ဈေး: ${_money(current16)} ကျပ်')
                : 'လက်ရှိဈေး မရသေးပါ',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoldingChartBadge(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _chartPulseCtrl,
      builder: (_, __) {
        final t = Curves.easeInOutSine.transform(_chartPulseCtrl.value);
        final ringScale = 1.0 + (t * 0.22);
        final ringOpacity = 0.16 * (1 - t);

        return SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: ringOpacity,
                child: Transform.scale(
                  scale: ringScale,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.7),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primaryContainer.withValues(alpha: 0.9),
                  border: Border.all(
                    color: cs.primary.withValues(alpha: 0.40),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.donut_large_rounded,
                  size: 18,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final floatingNavClearance = MediaQuery.paddingOf(context).bottom + 112;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('ရွှေစုဘူး'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Tooltip(
              message: 'Holding ခွဲကြည့်ရန်',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _HoldingsInsightPage(
                          items: List<_HoldingItem>.from(_items),
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: _buildHoldingChartBadge(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder(
              stream: _repo.latestStream(),
              builder: (context, snap) {
                final latest = snap.data;
                final current16 = _current16Price(latest);

                final totalCurrent = _items.fold<double>(
                  0,
                  (sum, e) =>
                      sum +
                      (current16 * e.weightKyattha * _factorOf(e.goldType)),
                );
                final totalCost = _items.fold<double>(
                  0,
                  (sum, e) =>
                      sum +
                      (e.buyPrice16 * e.weightKyattha * _factorOf(e.goldType)) +
                      e.feeAmount,
                );
                final netPnL = totalCurrent - totalCost;

                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    floatingNavClearance,
                  ),
                  children: [
                    _buildBalanceCard(
                      context: context,
                      totalCurrent: totalCurrent,
                      netPnL: netPnL,
                      current16: current16,
                    ),
                    const SizedBox(height: 10),
                    _panel(
                      context,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Form / Type Breakdown',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_items.isEmpty)
                            const Text('Asset မရှိသေးပါ')
                          else
                            for (final row in _buildBreakdownRows(current16))
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(row.label),
                                subtitle: Text(
                                  'Cost: ${_money(row.cost)} ကျပ်',
                                ),
                                trailing: Text(
                                  '${_money(row.current)} ကျပ်',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _panel(
                      context,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Asset ထည့်ရန်',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: _goldForm,
                            decoration: const InputDecoration(
                                labelText: 'အတုံး / အထည်'),
                            items: const [
                              DropdownMenuItem(
                                value: 'bar',
                                child: Text('အတုံး'),
                              ),
                              DropdownMenuItem(
                                value: 'ornament',
                                child: Text('အထည်'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _goldForm = v);
                            },
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: _goldType,
                            decoration: const InputDecoration(
                              labelText:
                                  '၁၆ပဲ / ၁၅ပဲ / ၁၄ပဲ ၂ပြား / ၁၄ပဲ / ၁၃ပဲ ၂ပြား / ၁၃ပဲ / ၁၂ပဲ ၂ပြား / ၁၂ပဲ',
                            ),
                            items: [
                              for (final t in GoldPurity.factor.keys)
                                DropdownMenuItem(value: t, child: Text(t)),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _goldType = v);
                            },
                          ),
                          const SizedBox(height: 10),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'ကိုင်ထားသော အလေးချိန်',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _wKyatCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'ကျပ်',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _wPaeCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'ပဲ',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _wYwayCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'ရွေး',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'မှတ်ချက်: ၁၆ ပဲ = ၁ ကျပ်, ၈ ရွေး = ၁ ပဲ',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _buyPriceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'ဝယ်ယူခဲ့သောဈေး (16ပဲရည်အညွှန်းဈေး)',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _feeCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'အလျော့တွက် / လက်ခ (ကျပ်)',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: _addHolding,
                              icon: const Icon(Icons.add),
                              label: const Text('ထည့်မည်'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _HoldingsInsightPage extends StatefulWidget {
  final List<_HoldingItem> items;

  const _HoldingsInsightPage({required this.items});

  @override
  State<_HoldingsInsightPage> createState() => _HoldingsInsightPageState();
}

class _HoldingsInsightPageState extends State<_HoldingsInsightPage>
    with SingleTickerProviderStateMixin {
  final GoldPriceRepo _repo = GoldPriceRepo();
  late final AnimationController _entryCtrl;
  late final Animation<double> _chartFade;
  late final Animation<double> _chartScale;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _chartFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.82, curve: Curves.easeOut),
    );
    _chartScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.9, curve: Curves.easeOutCubic),
      ),
    );
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  List<Color> get _chartPalette => const [
        Color(0xFFE63946),
        Color(0xFF2A9D8F),
        Color(0xFF457B9D),
        Color(0xFFF4A261),
        Color(0xFF1D3557),
        Color(0xFF8D5A97),
        Color(0xFF43AA8B),
        Color(0xFFF94144),
        Color(0xFFE9C46A),
        Color(0xFF577590),
      ];

  int _current16Price(dynamic latest) {
    final v = latest?.k16Buy ?? latest?.k16newBuy ?? latest?.ygea16;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  double _factorOf(String goldType) => GoldPurity.factor[goldType] ?? 1.0;

  double _currentValue(_HoldingItem e, int current16) {
    final price16 = current16 > 0 ? current16 : e.buyPrice16;
    return price16 * e.weightKyattha * _factorOf(e.goldType);
  }

  String _goldFormLabel(String v) {
    return v == GoldForm.ornament.name ? 'အထည်' : 'အတုံး';
  }

  String _money(num v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }

  Widget _panel(BuildContext context, Widget child) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.65)),
      ),
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }

  List<PieChartSectionData> _buildSections({required int current16}) {
    final values = widget.items
        .map((e) => _currentValue(e, current16))
        .toList(growable: false);
    final total = values.fold<double>(0, (a, b) => a + b);

    return List.generate(widget.items.length, (i) {
      final value = values[i];
      final percent = total > 0 ? (value / total) * 100 : 0;
      return PieChartSectionData(
        value: value <= 0 ? 0.01 : value,
        color: _chartPalette[i % _chartPalette.length],
        radius: 56,
        title: '${percent.toStringAsFixed(1)}%',
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      );
    });
  }

  Widget _buildAnimatedListItem({
    required int index,
    required Widget child,
  }) {
    double start = 0.25 + (index * 0.06);
    if (start > 0.82) start = 0.82;
    double end = start + 0.28;
    if (end > 1.0) end = 1.0;

    final curve = CurvedAnimation(
      parent: _entryCtrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Holding Overview'),
      ),
      body: StreamBuilder(
        stream: _repo.latestStream(),
        builder: (context, snap) {
          final current16 = _current16Price(snap.data);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _panel(
                context,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Holding Pie Chart',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 270,
                      child: widget.items.isEmpty
                          ? const Center(child: Text('Asset မရှိသေးပါ'))
                          : FadeTransition(
                              opacity: _chartFade,
                              child: ScaleTransition(
                                scale: _chartScale,
                                child: PieChart(
                                  PieChartData(
                                    centerSpaceRadius: 52,
                                    sectionsSpace: 2,
                                    sections:
                                        _buildSections(current16: current16),
                                  ),
                                  duration: const Duration(milliseconds: 2200),
                                  curve: Curves.easeInOutCubic,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _panel(
                context,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ကိုယ်ကိုင်ထားသော ပမာဏ',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (widget.items.isEmpty)
                      const Text('Asset မရှိသေးပါ')
                    else
                      for (int i = 0; i < widget.items.length; i++)
                        _buildAnimatedListItem(
                          index: i,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            decoration: BoxDecoration(
                              color: _chartPalette[i % _chartPalette.length]
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _chartPalette[i % _chartPalette.length]
                                    .withValues(alpha: 0.32),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(top: 6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        _chartPalette[i % _chartPalette.length],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${_goldFormLabel(widget.items[i].goldForm)} • ${widget.items[i].goldType}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'ပမာဏ: ${MmWeight.format(widget.items[i].weightKyattha)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'လက်ရှိတန်ဖိုး: ${_money(_currentValue(widget.items[i], current16))} ကျပ်',
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HoldingItem {
  final String id;
  final String goldForm;
  final String goldType;
  final double weightKyattha;
  final double buyPrice16;
  final double feeAmount;

  const _HoldingItem({
    required this.id,
    required this.goldForm,
    required this.goldType,
    required this.weightKyattha,
    required this.buyPrice16,
    required this.feeAmount,
  });

  factory _HoldingItem.fromMap(Map<String, dynamic> map) {
    double n(dynamic v) => v is num ? v.toDouble() : 0;

    final rawType = (map['goldType'] ?? '').toString();
    final safeType =
        GoldPurity.factor.containsKey(rawType) ? rawType : '16 ပဲရည်';

    final rawForm = (map['goldForm'] ?? '').toString();
    final safeForm = rawForm == GoldForm.ornament.name
        ? GoldForm.ornament.name
        : GoldForm.bar.name;

    return _HoldingItem(
      id: (map['id'] ?? '').toString(),
      goldForm: safeForm,
      goldType: safeType,
      weightKyattha: n(map['weightKyattha']),
      buyPrice16: n(map['buyPrice16']),
      feeAmount: n(map['feeAmount']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goldForm': goldForm,
      'goldType': goldType,
      'weightKyattha': weightKyattha,
      'buyPrice16': buyPrice16,
      'feeAmount': feeAmount,
    };
  }
}

class _BreakdownRow {
  final String label;
  final double current;
  final double cost;

  const _BreakdownRow({
    required this.label,
    required this.current,
    required this.cost,
  });
}
