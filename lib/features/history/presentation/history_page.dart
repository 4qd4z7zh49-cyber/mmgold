import 'package:flutter/material.dart';

import 'package:mmgold/features/calculator/data/history_store.dart';
import 'package:mmgold/features/calculator/domain/calculator_types.dart';
import 'package:mmgold/features/calculator/presentation/widgets/voucher_sheet.dart';
import 'package:mmgold/shared/utils/mm_weight.dart';
import 'package:mmgold/shared/ads/interstitial_ad_manager.dart';
import 'package:mmgold/shared/widgets/gradient_scaffold.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<Map<String, dynamic>>> _future;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _future = HistoryStore.load();
  }

  void _reload() {
    setState(() => _future = HistoryStore.load());
  }

  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  void _clearSelection() {
    if (_selectedIds.isEmpty) return;
    setState(() => _selectedIds.clear());
  }

  String _goldFormLabel(dynamic raw) {
    final v = (raw ?? '').toString();
    switch (v) {
      case 'bar':
        return 'အတုံး';
      case 'ornament':
        return 'အထည်';
      default:
        return '-';
    }
  }

  String _mmk(num v) {
    final s = v.toStringAsFixed(0);
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idx = s.length - i;
      b.write(s[i]);
      if (idx > 1 && idx % 3 == 1) b.write(',');
    }
    return b.toString();
  }

  String _fmtDateTime(dynamic raw) {
    final s = (raw ?? '').toString();
    final dt = DateTime.tryParse(s);
    if (dt == null) return '';
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year}  ${two(l.hour)}:${two(l.minute)}';
  }

  double _toNum(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse((raw ?? '').toString()) ?? 0;
  }

  String _normalizeNum(String raw) {
    return raw.trim().replaceAll(',', '').replaceAll(' ', '');
  }

  double _discountAmount({
    required String mode,
    required String unit,
    required double value,
    required double baseAmount,
  }) {
    switch (mode) {
      case 'mmk':
        return value;
      case 'percent':
        return baseAmount * (value / 100);
      case 'custom':
        if (unit == DiscountUnit.percent.name) {
          return baseAmount * (value / 100);
        }
        return value;
      case 'none':
      default:
        return 0;
    }
  }

  Future<void> _openVoucher(Map<String, dynamic> it) async {
    final action = (it['action'] ?? '').toString();
    final isBuy = action == 'buy';

    final market16 = (it['market16'] ?? 0).toDouble();
    final buyTime16 = it['buyTime16'];
    final paidAmount = it['paidAmount'];
    final profitLoss = it['profitLoss'];

    final weightKyattha = (it['weightKyattha'] ?? 0).toDouble();
    final discountWeightKyattha = (it['discountWeightKyattha'] ?? 0).toDouble();
    final netWeightKyattha = (it['netWeightKyattha'] ?? 0).toDouble();

    final baseAmount = (it['baseAmount'] ?? 0).toDouble();
    final discountAmount = (it['discountAmount'] ?? 0).toDouble();
    final finalAmount = (it['finalAmount'] ?? 0).toDouble();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => VoucherSheet(
        onClose: () => Navigator.of(sheetCtx).pop(),
        actionLabel: isBuy ? 'အဝယ်' : 'အရောင်း',
        goldFormLabel: _goldFormLabel(it['goldForm']),
        goldTypeLabel: (it['goldType'] ?? '').toString(),
        marketPrice16: market16,
        buyTimePrice16: (buyTime16 is num) ? buyTime16.toDouble() : null,
        paidAmount: (paidAmount is num) ? paidAmount.toDouble() : null,
        profitLoss: (profitLoss is num) ? profitLoss.toDouble() : null,
        weightKyattha: weightKyattha,
        discountWeightKyattha: discountWeightKyattha,
        netWeightKyattha: netWeightKyattha,
        baseAmount: baseAmount,
        discountAmount: discountAmount,
        finalAmount: finalAmount,
      ),
    );

    if (!mounted) return;
    InterstitialAdManager.instance.recordActionAndMaybeShow(
      placement: 'history_voucher_closed',
    );
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    await HistoryStore.deleteMany(_selectedIds);
    if (!mounted) return;
    setState(() => _selectedIds.clear());
    _reload();
  }

  Future<void> _deleteOne(Map<String, dynamic> item) async {
    final id = (item['id'] ?? '').toString();
    if (id.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete history'),
        content: const Text('ဒီ history row ကို ဖျက်မှာ သေချာပါသလား?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await HistoryStore.deleteMany({id});
    if (!mounted) return;
    setState(() => _selectedIds.remove(id));
    _reload();
  }

  Future<void> _openEditor(Map<String, dynamic> item) async {
    final id = (item['id'] ?? '').toString();
    if (id.isEmpty) return;

    final marketCtrl = TextEditingController(text: _toNum(item['market16']).toStringAsFixed(0));
    final weightCtrl = TextEditingController(text: _toNum(item['weightKyattha']).toStringAsFixed(6));
    final discountCtrl = TextEditingController(text: _toNum(item['discountValue']).toStringAsFixed(2));
    final paidCtrl = TextEditingController(
      text: item['paidAmount'] is num ? _toNum(item['paidAmount']).toStringAsFixed(0) : '',
    );

    var action = (item['action'] ?? ActionType.buy.name).toString();
    if (!ActionType.values.any((e) => e.name == action)) {
      action = ActionType.buy.name;
    }

    var goldForm = (item['goldForm'] ?? GoldForm.bar.name).toString();
    if (!GoldForm.values.any((e) => e.name == goldForm)) {
      goldForm = GoldForm.bar.name;
    }

    final purityList = GoldPurity.factor.keys.toList(growable: false);
    var goldType = (item['goldType'] ?? '').toString();
    if (!purityList.contains(goldType)) {
      goldType = purityList.first;
    }

    final discountModes = DiscountMode.values.map((e) => e.name).toList(growable: false);
    var discountMode = (item['discountMode'] ?? DiscountMode.none.name).toString();
    if (!discountModes.contains(discountMode)) {
      discountMode = DiscountMode.none.name;
    }

    var discountUnit = (item['discountUnit'] ?? DiscountUnit.mmk.name).toString();
    if (!DiscountUnit.values.any((e) => e.name == discountUnit)) {
      discountUnit = DiscountUnit.mmk.name;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialog) => AlertDialog(
            title: const Text('Edit history'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: action,
                      decoration: const InputDecoration(labelText: 'Action'),
                      items: const [
                        DropdownMenuItem(value: 'buy', child: Text('အဝယ်')),
                        DropdownMenuItem(value: 'sell', child: Text('အရောင်း')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setDialog(() => action = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: goldForm,
                      decoration: const InputDecoration(labelText: 'Gold form'),
                      items: const [
                        DropdownMenuItem(value: 'bar', child: Text('အတုံး')),
                        DropdownMenuItem(value: 'ornament', child: Text('အထည်')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setDialog(() => goldForm = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: goldType,
                      decoration: const InputDecoration(labelText: 'Gold type'),
                      items: [
                        for (final p in purityList)
                          DropdownMenuItem(value: p, child: Text(p)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setDialog(() => goldType = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: marketCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: '16 Price'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Weight (kyattha)'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: discountMode,
                      decoration: const InputDecoration(labelText: 'Discount mode'),
                      items: [
                        for (final m in discountModes)
                          DropdownMenuItem(value: m, child: Text(m)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setDialog(() => discountMode = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    if (discountMode == DiscountMode.custom.name)
                      DropdownButtonFormField<String>(
                        initialValue: discountUnit,
                        decoration: const InputDecoration(labelText: 'Discount unit'),
                        items: const [
                          DropdownMenuItem(value: 'mmk', child: Text('MMK')),
                          DropdownMenuItem(value: 'percent', child: Text('Percent')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setDialog(() => discountUnit = v);
                        },
                      ),
                    if (discountMode == DiscountMode.custom.name) const SizedBox(height: 10),
                    TextField(
                      controller: discountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Discount value'),
                    ),
                    if (action == ActionType.sell.name) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: paidCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Paid amount'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    if (saved != true) return;

    final market16 = double.tryParse(_normalizeNum(marketCtrl.text)) ?? 0;
    final weightKyattha = double.tryParse(_normalizeNum(weightCtrl.text)) ?? 0;
    final discountValue = double.tryParse(_normalizeNum(discountCtrl.text)) ?? 0;

    final paidAmount = action == ActionType.sell.name
        ? double.tryParse(_normalizeNum(paidCtrl.text))
        : null;

    if (market16 <= 0 || weightKyattha <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('16 price နဲ့ weight ကို မှန်ကန်စွာထည့်ပါ')),
      );
      return;
    }

    final factor = GoldPurity.factor[goldType] ?? 1.0;
    final baseAmount = market16 * weightKyattha * factor;

    final effectiveUnit = discountMode == DiscountMode.custom.name
        ? discountUnit
        : (discountMode == DiscountMode.percent.name
            ? DiscountUnit.percent.name
            : DiscountUnit.mmk.name);

    final discountAmount = _discountAmount(
      mode: discountMode,
      unit: effectiveUnit,
      value: discountValue,
      baseAmount: baseAmount,
    );

    final denom = market16 * factor;
    final discountWeightKyattha = (discountAmount <= 0 || denom <= 0)
        ? 0.0
        : discountAmount / denom;

    final netWeightKyattha = action == ActionType.buy.name
        ? (weightKyattha + discountWeightKyattha)
        : (weightKyattha - discountWeightKyattha);

    if (netWeightKyattha < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discount ကြောင့် net weight အနုတ်မဖြစ်ရပါ')),
      );
      return;
    }

    final finalAmount = market16 * netWeightKyattha * factor;

    double? buyTime16;
    if (action == ActionType.sell.name && paidAmount != null && paidAmount > 0) {
      final buyNetWeight = weightKyattha + discountWeightKyattha;
      if (buyNetWeight > 0 && factor > 0) {
        buyTime16 = paidAmount / (buyNetWeight * factor);
      }
    }

    final profitLoss =
        (action == ActionType.sell.name && paidAmount != null && paidAmount > 0)
            ? (finalAmount - paidAmount)
            : null;

    final updated = Map<String, dynamic>.from(item)
      ..['id'] = id
      ..['action'] = action
      ..['goldForm'] = goldForm
      ..['goldType'] = goldType
      ..['market16'] = market16
      ..['weightKyattha'] = weightKyattha
      ..['discountMode'] = discountMode
      ..['discountUnit'] = effectiveUnit
      ..['discountValue'] = discountValue
      ..['discountAmount'] = discountAmount
      ..['discountWeightKyattha'] = discountWeightKyattha
      ..['netWeightKyattha'] = netWeightKyattha
      ..['baseAmount'] = baseAmount
      ..['finalAmount'] = finalAmount
      ..['paidAmount'] = action == ActionType.sell.name ? paidAmount : null
      ..['buyTime16'] = action == ActionType.sell.name ? buyTime16 : null
      ..['profitLoss'] = profitLoss;

    await HistoryStore.updateById(id: id, value: updated);
    if (!mounted) return;
    _reload();
  }

  Future<void> _clearAll() async {
    await HistoryStore.clear();
    _selectedIds.clear();
    if (!mounted) return;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GradientScaffold(
      appBar: AppBar(
        title: Text(
            _isSelectionMode ? 'Selected: ${_selectedIds.length}' : 'History'),
        leading: _isSelectionMode
            ? IconButton(
                tooltip: 'Cancel selection',
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              )
            : null,
        actions: [
          if (_isSelectionMode)
            IconButton(
              tooltip: 'Delete selected',
              icon: const Icon(Icons.delete),
              onPressed: _deleteSelected,
            )
          else
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          final items = snap.data ?? const <Map<String, dynamic>>[];

          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (items.isEmpty) {
            return const Center(child: Text('History မရှိသေးပါ'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final it = items[i];
              final id = (it['id'] ?? '').toString();
              final selected = _selectedIds.contains(id);

              final action = (it['action'] ?? '').toString();
              final isBuy = action == 'buy';
              final accent = isBuy ? cs.primary : cs.error;

              final bg = selected
                  ? accent.withValues(alpha: 0.12)
                  : cs.surfaceContainerHighest;
              final border =
                  selected ? accent.withValues(alpha: 0.55) : cs.outlineVariant;

              final goldType = (it['goldType'] ?? '').toString();
              final goldForm = _goldFormLabel(it['goldForm']);

              final netW = (it['netWeightKyattha'] ?? 0).toDouble();
              final finalAmount = (it['finalAmount'] ?? 0).toDouble();
              final tsText = _fmtDateTime(it['ts']);

              final pl = it['profitLoss'];
              final plText = (pl is num)
                  ? (pl.toDouble() >= 0
                      ? '+${pl.toDouble().toStringAsFixed(0)}'
                      : pl.toDouble().toStringAsFixed(0))
                  : null;

              final plColor = (pl is num)
                  ? (pl.toDouble() >= 0 ? cs.primary : cs.error)
                  : cs.onSurfaceVariant;

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onLongPress: () {
                  if (id.isEmpty) return;
                  _toggleSelect(id);
                },
                onTap: () async {
                  if (id.isEmpty) return;
                  if (_isSelectionMode) {
                    _toggleSelect(id);
                    return;
                  }
                  await _openVoucher(it);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 46,
                        decoration: BoxDecoration(
                          color:
                              accent.withValues(alpha: selected ? 0.9 : 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  isBuy ? 'အဝယ်' : 'အရောင်း',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: selected ? accent : cs.onSurface,
                                  ),
                                ),
                                if (selected) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.check_circle,
                                    color: accent,
                                    size: 18,
                                  ),
                                ],
                                const Spacer(),
                                if (tsText.isNotEmpty)
                                  Text(
                                    tsText,
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$goldForm • $goldType • ${MmWeight.format(netW)}',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Total : ${_mmk(finalAmount)} ကျပ်',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: selected ? accent : cs.onSurface,
                              ),
                            ),
                            if (plText != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Profit/Loss: $plText ကျပ်',
                                style: TextStyle(
                                    color: plColor,
                                    fontWeight: FontWeight.w800),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!_isSelectionMode && id.isNotEmpty)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _openEditor(it),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: Icon(Icons.delete_outline, color: cs.error),
                              onPressed: () => _deleteOne(it),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
