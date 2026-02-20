import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:mmgold/features/calculator/data/history_store.dart';
import 'package:mmgold/features/calculator/presentation/widgets/voucher_sheet.dart';
import 'package:mmgold/shared/ads/interstitial_ad_manager.dart';
import 'package:mmgold/shared/utils/mm_weight.dart';
import 'package:mmgold/shared/widgets/gradient_scaffold.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<Map<String, dynamic>>> _future;
  late final VoidCallback _historyRevisionListener;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _future = HistoryStore.load();
    _historyRevisionListener = _reload;
    HistoryStore.revision.addListener(_historyRevisionListener);
  }

  @override
  void dispose() {
    HistoryStore.revision.removeListener(_historyRevisionListener);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _future = HistoryStore.load());
  }

  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  void _toggleSelect(String id) {
    if (id.isEmpty) return;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

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

  double _toNum(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse((raw ?? '').toString()) ?? 0;
  }

  String _mmk(num v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }

  String _fmtDateTime(dynamic raw) {
    final s = (raw ?? '').toString();
    final dt = DateTime.tryParse(s);
    if (dt == null) return '';
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year}  ${two(l.hour)}:${two(l.minute)}';
  }

  Future<void> _openVoucher(Map<String, dynamic> it) async {
    final action = (it['action'] ?? '').toString();
    final isBuy = action == 'buy';

    final market16 = _toNum(it['market16']);
    final buyTime16 = it['buyTime16'];
    final paidAmount = it['paidAmount'];
    final profitLoss = it['profitLoss'];

    final weightKyattha = _toNum(it['weightKyattha']);
    final discountWeightKyattha = _toNum(it['discountWeightKyattha']);
    final netWeightKyattha = _toNum(it['netWeightKyattha']);

    final baseAmount = _toNum(it['baseAmount']);
    final discountAmount = _toNum(it['discountAmount']);
    final finalAmount = _toNum(it['finalAmount']);

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

  Future<void> _deleteSelectedFromTopButton() async {
    if (_selectedIds.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ဖျက်မယ့် history row တွေကို long-press / tap နဲ့ အရင်ရွေးပါ',
          ),
        ),
      );
      return;
    }

    final count = _selectedIds.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected history'),
        content: Text('ရွေးထားသော $count ခုကို ဖျက်မှာ သေချာပါသလား?'),
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

    await HistoryStore.deleteMany(_selectedIds);
    if (!mounted) return;
    setState(() => _selectedIds.clear());
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final floatingNavClearance = MediaQuery.paddingOf(context).bottom + 112;

    return GradientScaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode
              ? 'ရွေးထားသည်: ${_selectedIds.length}'
              : 'Calculator History',
        ),
        leading: _isSelectionMode
            ? IconButton(
                tooltip: 'Cancel selection',
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              )
            : null,
        actions: [
          IconButton(
            tooltip: 'Delete selected',
            icon: Icon(_isSelectionMode ? Icons.delete : Icons.delete_outline),
            onPressed: _deleteSelectedFromTopButton,
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
            return const Center(child: Text('Calculator history မရှိသေးပါ'));
          }

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(16, 16, 16, floatingNavClearance),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final it = items[i];
              final id = (it['id'] ?? '').toString();
              final selected = id.isNotEmpty && _selectedIds.contains(id);

              final action = (it['action'] ?? '').toString();
              final isBuy = action == 'buy';
              final accent = isBuy ? cs.primary : cs.error;

              final bg = selected
                  ? accent.withValues(alpha: 0.12)
                  : cs.surface.withValues(alpha: 0.56);
              final border =
                  selected ? accent.withValues(alpha: 0.55) : cs.outlineVariant;

              final goldType = (it['goldType'] ?? '').toString();
              final goldForm = _goldFormLabel(it['goldForm']);

              final netW = _toNum(it['netWeightKyattha']);
              final finalAmount = _toNum(it['finalAmount']);
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
                onLongPress: () => _toggleSelect(id),
                onTap: () async {
                  if (id.isEmpty) return;
                  if (_isSelectionMode) {
                    _toggleSelect(id);
                    return;
                  }
                  await _openVoucher(it);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
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
                              color: accent.withValues(
                                  alpha: selected ? 0.9 : 0.55),
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
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _isSelectionMode
                                ? (selected
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked)
                                : Icons.chevron_right_rounded,
                            color: _isSelectionMode
                                ? (selected ? accent : cs.outline)
                                : cs.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
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
