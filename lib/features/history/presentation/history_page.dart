import 'package:flutter/material.dart';

import 'package:mmgold/features/calculator/data/history_store.dart';
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
  final Set<String> _selectedIds = {}; // multi-select

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
    _selectedIds.clear();
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
