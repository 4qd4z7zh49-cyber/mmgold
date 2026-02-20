import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/floating_segmented.dart';
import '../../../shared/utils/mm_weight.dart';
import '../../../shared/ads/interstitial_ad_manager.dart';

import '../data/history_store.dart';
import '../domain/calculator_types.dart';

import 'widgets/weight_inputs.dart';
import 'widgets/voucher_sheet.dart';

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  final _formKey = GlobalKey<FormState>();

  // 5) market 16
  final _marketPriceCtrl = TextEditingController();

  // 1) buy/sell
  ActionType _action = ActionType.buy;

  // 2) gold form (bar/ornament)
  GoldForm _goldForm = GoldForm.bar;

  // 4) purity
  String _goldType = '16 ပဲရည်';

  // 6) weight
  final _wKyat = TextEditingController();
  final _wPae = TextEditingController();
  final _wYway = TextEditingController();

  // 7) discount weight
  final _dKyat = TextEditingController();
  final _dPae = TextEditingController();
  final _dYway = TextEditingController();

  // SELL: user enters paid amount
  final _paidAmountCtrl = TextEditingController();

  // SELL: auto-inferred buy-time 16-pae price
  final _buyTimePriceCtrl = TextEditingController();
  double? _buyTimePrice16;

  Widget _segmentLabel(String text) {
    return Text(
      text,
      maxLines: 1,
      softWrap: false,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        height: 1.08,
        leadingDistribution: TextLeadingDistribution.even,
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.surface.withValues(alpha: 0.58),
                cs.surfaceContainerHighest.withValues(alpha: 0.38),
              ],
            ),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(context, title, icon),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primaryContainer.withValues(alpha: 0.52),
                cs.secondaryContainer.withValues(alpha: 0.34),
              ],
            ),
            border: Border.all(
              color: cs.primary.withValues(alpha: 0.26),
            ),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.savings_outlined, color: cs.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ရွှေစုဘူး',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Premium Calculator Experience',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    // Recompute buy-time price whenever inputs change (SELL only).
    _paidAmountCtrl.addListener(_recomputeBuyTimePriceIfPossible);
    _wKyat.addListener(_recomputeBuyTimePriceIfPossible);
    _wPae.addListener(_recomputeBuyTimePriceIfPossible);
    _wYway.addListener(_recomputeBuyTimePriceIfPossible);
    _dKyat.addListener(_recomputeBuyTimePriceIfPossible);
    _dPae.addListener(_recomputeBuyTimePriceIfPossible);
    _dYway.addListener(_recomputeBuyTimePriceIfPossible);
    _marketPriceCtrl.addListener(_recomputeBuyTimePriceIfPossible);
  }

  @override
  void dispose() {
    _marketPriceCtrl.dispose();
    _wKyat.dispose();
    _wPae.dispose();
    _wYway.dispose();
    _dKyat.dispose();
    _dPae.dispose();
    _dYway.dispose();
    _paidAmountCtrl.dispose();
    _buyTimePriceCtrl.dispose();
    super.dispose();
  }

  void _reset() {
    _marketPriceCtrl.clear();
    _wKyat.clear();
    _wPae.clear();
    _wYway.clear();
    _dKyat.clear();
    _dPae.clear();
    _dYway.clear();
    _paidAmountCtrl.clear();
    _buyTimePriceCtrl.clear();

    setState(() {
      _action = ActionType.buy;
      _goldForm = GoldForm.bar;
      _goldType = '16 ပဲရည်';
      _buyTimePrice16 = null;
    });
  }

  double _parseInput(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 0.0;
    final cleaned = raw.replaceAll(',', '').replaceAll(' ', '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  double _toDouble(TextEditingController c) => _parseInput(c.text);

  double _discountWeightInputKyattha() {
    return MmWeight.toKyattha(
      kyat: _toDouble(_dKyat),
      pae: _toDouble(_dPae),
      yway: _toDouble(_dYway),
    );
  }

  double _discountAmountFromWeight({
    required double market16,
    required double factor,
    required double discountWeightKyattha,
  }) {
    if (market16 <= 0 || factor <= 0 || discountWeightKyattha <= 0) return 0.0;
    return market16 * factor * discountWeightKyattha;
  }

  // SELL: Paid amount -> infer buy-time 16-pae price
  void _recomputeBuyTimePriceIfPossible() {
    if (!mounted) return;

    if (_action != ActionType.sell) {
      if (_buyTimePrice16 != null || _buyTimePriceCtrl.text.isNotEmpty) {
        setState(() => _buyTimePrice16 = null);
        _buyTimePriceCtrl.clear();
      }
      return;
    }

    final paid = _toDouble(_paidAmountCtrl);

    final weightKyattha = MmWeight.toKyattha(
      kyat: _toDouble(_wKyat),
      pae: _toDouble(_wPae),
      yway: _toDouble(_wYway),
    );

    final dW = _discountWeightInputKyattha();

    // buy-time inference uses BUY rule: add discount weight
    final buyTimeNetWeight = weightKyattha + dW;

    final factor = GoldPurity.factor[_goldType] ?? 1.0;
    if (paid <= 0 || buyTimeNetWeight <= 0 || factor <= 0) {
      if (_buyTimePrice16 != null || _buyTimePriceCtrl.text.isNotEmpty) {
        setState(() => _buyTimePrice16 = null);
        _buyTimePriceCtrl.clear();
      }
      return;
    }

    final inferred = paid / (buyTimeNetWeight * factor);
    setState(() => _buyTimePrice16 = inferred);
    _buyTimePriceCtrl.text = inferred.toStringAsFixed(0);
  }

  Future<void> _calculate() async {
    if (!_formKey.currentState!.validate()) return;

    final market16 = _toDouble(_marketPriceCtrl);
    final factor = GoldPurity.factor[_goldType] ?? 1.0;

    final weightKyattha = MmWeight.toKyattha(
      kyat: _toDouble(_wKyat),
      pae: _toDouble(_wPae),
      yway: _toDouble(_wYway),
    );

    final baseAmount = market16 * weightKyattha * factor;
    final discountWeightKyattha = _discountWeightInputKyattha();
    final discountAmount = _discountAmountFromWeight(
      market16: market16,
      factor: factor,
      discountWeightKyattha: discountWeightKyattha,
    );

    final netWeightKyattha = (_action == ActionType.buy)
        ? (weightKyattha + discountWeightKyattha)
        : (weightKyattha - discountWeightKyattha);

    if (netWeightKyattha < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('အလျော့တွက်က အလေးချိန်ထက် မကြီးရပါ')),
      );
      return;
    }

    final finalAmount = market16 * netWeightKyattha * factor;

    final paidAmount =
        (_action == ActionType.sell) ? _toDouble(_paidAmountCtrl) : null;
    final profitLoss =
        (_action == ActionType.sell && paidAmount != null && paidAmount > 0)
            ? (finalAmount - paidAmount)
            : null;

    // History save
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await HistoryStore.add({
      'id': id,
      'historyType': 'calculator',
      'ts': DateTime.now().toIso8601String(),
      'action': _action.name,
      'goldForm': _goldForm.name,
      'goldType': _goldType,
      'market16': market16,
      'buyTime16': _buyTimePrice16,
      'paidAmount': paidAmount,
      'profitLoss': profitLoss,
      'weightKyattha': weightKyattha,
      'discountWeightKyattha': discountWeightKyattha,
      'netWeightKyattha': netWeightKyattha,
      'baseAmount': baseAmount,
      'discountAmount': discountAmount,
      'discountMode': DiscountMode.mmk.name,
      'discountUnit': DiscountUnit.mmk.name,
      'discountValue': discountAmount,
      'discountKyat': _toDouble(_dKyat),
      'discountPae': _toDouble(_dPae),
      'discountYway': _toDouble(_dYway),
      'finalAmount': finalAmount,
    });

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      // ⚠️ useRootNavigator: true မထည့်ပါနဲ့ (ရှိရင် ဖယ်)
      builder: (sheetCtx) => VoucherSheet(
        onClose: () => Navigator.of(sheetCtx).pop(), // ✅ THIS IS THE KEY
        actionLabel: _action == ActionType.buy ? 'အဝယ်' : 'အရောင်း',
        goldFormLabel: _goldForm.label,
        goldTypeLabel: _goldType,
        marketPrice16: market16,
        buyTimePrice16: (_action == ActionType.sell) ? _buyTimePrice16 : null,
        paidAmount: paidAmount,
        profitLoss: profitLoss,
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
      placement: 'calculator_voucher_closed',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final floatingNavClearance = MediaQuery.paddingOf(context).bottom + 112;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('မြန်မာ့ရွှေ Calculator'),
        actions: [
          IconButton(
            onPressed: _reset,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, floatingNavClearance),
          children: [
            _heroHeader(context),
            const SizedBox(height: 16),

            // 1) Buy / Sell
            _sectionCard(
              context: context,
              title: 'Buy / Sell',
              icon: Icons.swap_horiz_rounded,
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FloatingSegmented<ActionType>(
                  segments: [
                    ButtonSegment(
                      value: ActionType.buy,
                      label: _segmentLabel('အဝယ်'),
                    ),
                    ButtonSegment(
                      value: ActionType.sell,
                      label: _segmentLabel('အရောင်း'),
                    ),
                  ],
                  selected: {_action},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) {
                    HapticFeedback.selectionClick();
                    setState(() => _action = s.first);
                    _recomputeBuyTimePriceIfPossible();
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2) Gold form (အတုံး/အထည်)
            _sectionCard(
              context: context,
              title: 'ရွှေအမျိုးအစား (အတုံး / အထည်)',
              icon: Icons.category_outlined,
              child: SizedBox(
                width: double.infinity,
                child: FloatingSegmented<GoldForm>(
                  segments: [
                    ButtonSegment(
                      value: GoldForm.bar,
                      label: _segmentLabel('အတုံး'),
                    ),
                    ButtonSegment(
                      value: GoldForm.ornament,
                      label: _segmentLabel('အထည်'),
                    ),
                  ],
                  selected: {_goldForm},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) {
                    HapticFeedback.selectionClick();
                    setState(() => _goldForm = s.first);
                    _recomputeBuyTimePriceIfPossible();
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3) Discount
            _sectionCard(
              context: context,
              title: 'အလျော့တွက် (ကျပ် / ပဲ / ရွေး)',
              icon: Icons.local_offer_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WeightInputs(
                    kyatCtrl: _dKyat,
                    paeCtrl: _dPae,
                    ywayCtrl: _dYway,
                    allowEmpty: true,
                    helperText:
                        'အလျော့ချိန်ကို ကျပ်/ပဲ/ရွေး နဲ့ထည့်ပါ (မထည့်လျှင် 0)',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4) Purity (16/15...)
            _sectionCard(
              context: context,
              title: 'ရွှေအရည်အသွေး',
              icon: Icons.workspace_premium_outlined,
              child: DropdownButtonFormField<String>(
                key: ValueKey(_goldType),
                initialValue: _goldType,
                decoration: const InputDecoration(
                  labelText: 'ရွေးချယ်ပါ',
                  prefixIcon: Icon(Icons.workspace_premium_outlined),
                ),
                items: GoldPurity.factor.keys
                    .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                    .toList(),
                onChanged: (v) {
                  setState(() => _goldType = v ?? '16 ပဲရည်');
                  _recomputeBuyTimePriceIfPossible();
                },
              ),
            ),
            const SizedBox(height: 16),

            // 5) Market price 16
            _sectionCard(
              context: context,
              title: 'လက်ရှိ ၁၆ ပဲရည် ပေါက်ဈေး',
              icon: Icons.payments_outlined,
              child: TextFormField(
                controller: _marketPriceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ကျပ် (ဥပမာ 10,500,000)',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (v) {
                  final x = _parseInput(v);
                  if (x <= 0) return 'ပေါက်ဈေး ထည့်ပါ';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),

            // 6) Weight
            _sectionCard(
              context: context,
              title: 'အလေးချိန် (ကျပ် / ပဲ / ရွေး)',
              icon: Icons.scale_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.45),
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'အလေးချိန် ထည့်သွင်းပါ',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        WeightInputs(
                          kyatCtrl: _wKyat,
                          paeCtrl: _wPae,
                          ywayCtrl: _wYway,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _action == ActionType.sell ? 1.0 : 0.35,
                    child: IgnorePointer(
                      ignoring: _action != ActionType.sell,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _paidAmountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'ဝယ်ခဲ့စဉ် ပေးခဲ့ရတဲ့စျေး (ကျပ်)',
                              helperText: 'Sell mode မှာသာ လိုအပ်ပါသည်',
                              prefixIcon: Icon(Icons.receipt_long_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _buyTimePriceCtrl,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText:
                                  'မိမိဝယ်ချိန်မှ ၁၆ ပဲရည် ရွှေဈေး (Auto) (ကျပ်)',
                              prefixIcon: Icon(Icons.price_change_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: cs.primary,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _calculate();
                    },
                    child: const Text(
                      'Calculate',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _reset();
                    },
                    child: const Text(
                      'Reset',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
