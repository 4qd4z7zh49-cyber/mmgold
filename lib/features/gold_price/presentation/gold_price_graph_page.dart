import 'package:flutter/material.dart';

import 'package:mmgold/shared/widgets/frosted_panel.dart';
import 'package:mmgold/shared/widgets/gradient_scaffold.dart';
import '../data/domain/gold_price_models.dart';
import '../data/domain/gold_price_repo.dart';

enum GraphType { ygea16, k16Sell, k15Sell }

class GoldPriceGraphPage extends StatefulWidget {
  const GoldPriceGraphPage({super.key});

  @override
  State<GoldPriceGraphPage> createState() => _GoldPriceGraphPageState();
}

class _GoldPriceGraphPageState extends State<GoldPriceGraphPage> {
  GraphType _type = GraphType.ygea16;

  int? _pick(GoldPriceLatest p) {
    switch (_type) {
      case GraphType.ygea16:
        return p.ygea16;
      case GraphType.k16Sell:
        return p.k16Sell;
      case GraphType.k15Sell:
        return p.k15Sell;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return GradientScaffold(
      appBar: AppBar(title: const Text('Graph')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            FrostedPanel(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              borderRadius: BorderRadius.circular(14),
              blurSigma: 8,
              child: DropdownButton<GraphType>(
                value: _type,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                onChanged: (v) => setState(() => _type = v!),
                items: const [
                  DropdownMenuItem(
                    value: GraphType.ygea16,
                    child: Text('ရွှေအသင်းပေါက်ဈေး'),
                  ),
                  DropdownMenuItem(
                    value: GraphType.k16Sell,
                    child: Text('၁၆ ပဲရည် (ရောင်းဈေး)'),
                  ),
                  DropdownMenuItem(
                    value: GraphType.k15Sell,
                    child: Text('၁၅ ပဲရည် (ရောင်းဈေး)'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<GoldPriceLatest>>(
                stream: GoldPriceRepo().historyStream(limit: 60),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return const Center(
                      child: Text('Graph service မချိတ်ဆက်ရသေးပါ'),
                    );
                  }
                  final items = snap.data!;
                  if (items.isEmpty) {
                    return const Center(child: Text('No data'));
                  }

                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final p = items[i];
                      final v = _pick(p);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FrostedPanel(
                          borderRadius: BorderRadius.circular(14),
                          blurSigma: 8,
                          startAlpha: 0.60,
                          endAlpha: 0.42,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text('${p.date ?? ''}  ${p.time ?? ''}'),
                              ),
                              Text(
                                v == null ? '-' : v.toString(),
                                style: tt.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
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
            ),
          ],
        ),
      ),
    );
  }
}
