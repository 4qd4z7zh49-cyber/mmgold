import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/floating_segmented.dart';
import '../../../shared/utils/mm_weight.dart';
import '../../../shared/ads/interstitial_ad_manager.dart';

import '../data/history_store.dart';
import '../domain/calculator_types.dart';

import 'widgets/weight_inputs.dart';
import 'widgets/discount_selector.dart';
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

  // SELL: user enters paid amount
  final _paidAmountCtrl = TextEditingController();

  // SELL: auto-inferred buy-time 16-pae price
  final _buyTimePriceCtrl = TextEditingController();
  double? _buyTimePrice16;

  // 3) discount (NEW)
  DiscountValue _discountValue = DiscountValue.none;

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
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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
    _marketPriceCtrl.addListener(_recomputeBuyTimePriceIfPossible);
  }

  @override
  void dispose() {
    _marketPriceCtrl.dispose();
    _wKyat.dispose();
    _wPae.dispose();
    _wYway.dispose();
    _paidAmountCtrl.dispose();
    _buyTimePriceCtrl.dispose();
    super.dispose();
  }

  void _reset() {
    _marketPriceCtrl.clear();
    _wKyat.clear();
    _wPae.clear();
    _wYway.clear();
    _paidAmountCtrl.clear();
    _buyTimePriceCtrl.clear();

    setState(() {
      _action = ActionType.buy;
      _goldForm = GoldForm.bar;
      _discountValue = DiscountValue.none;
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

  // Discount amount supports MMK / Percent (including CUSTOM)
  double _discountAmount(double baseAmount) {
    switch (_discountValue.mode) {
      case DiscountMode.none:
        return 0;

      case DiscountMode.mmk:
        return _discountValue.value;

      case DiscountMode.percent:
        return baseAmount * (_discountValue.value / 100);

      case DiscountMode.custom:
        return _discountValue.unit == DiscountUnit.percent
            ? baseAmount * (_discountValue.value / 100)
            : _discountValue.value;
    }
  }

  double _discountWeightKyattha({
    required double market16,
    required double factor,
    required double discountAmount,
  }) {
    final denom = market16 * factor;
    if (discountAmount <= 0 || denom <= 0) return 0.0;
    return discountAmount / denom;
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

    final market16 = _toDouble(_marketPriceCtrl);
    final factor = GoldPurity.factor[_goldType] ?? 1.0;

    final baseAmount = market16 * weightKyattha * factor;
    final discountAmount = _discountAmount(baseAmount);

    final dW = _discountWeightKyattha(
      market16: market16,
      factor: factor,
      discountAmount: discountAmount,
    );

    // buy-time inference uses BUY rule: add discount weight
    final buyTimeNetWeight = weightKyattha + dW;

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
    final discountAmount = _discountAmount(baseAmount);

    final discountWeightKyattha = _discountWeightKyattha(
      market16: market16,
      factor: factor,
      discountAmount: discountAmount,
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
      'discountMode': _discountValue.mode.name,
      'discountValue': _discountValue.value,
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
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                      setState(() {
                        _goldForm = s.first;
                        _discountValue = DiscountValue.none;
                      });
                      _recomputeBuyTimePriceIfPossible();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3) Discount
              _sectionCard(
                context: context,
                title: 'အလျော့တွက်',
                icon: Icons.local_offer_outlined,
                child: DiscountSelector(
                  isOrnament: _goldForm == GoldForm.ornament,
                  value: _discountValue,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    setState(() => _discountValue = v);
                    _recomputeBuyTimePriceIfPossible();
                  },
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
                    WeightInputs(
                        kyatCtrl: _wKyat, paeCtrl: _wPae, ywayCtrl: _wYway),
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
      ),
    );
  }
}
