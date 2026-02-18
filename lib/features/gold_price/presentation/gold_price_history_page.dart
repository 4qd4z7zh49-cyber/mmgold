import 'package:flutter/material.dart';
import 'package:mmgold/shared/widgets/gradient_scaffold.dart';
import '../data/domain/gold_price_repo.dart';
import '../data/domain/gold_price_models.dart';

class GoldPriceHistoryPage extends StatelessWidget {
  const GoldPriceHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('မြန်မာ့ရွှေဈေး History'),
        centerTitle: false, // price page နဲ့一致
      ),
      body: StreamBuilder<List<GoldPriceLatest>>(
        stream: GoldPriceRepo().historyStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Gold price history service မချိတ်ဆက်ရသေးပါ'),
            );
          }

          final list = snapshot.data;
          if (list == null || list.isEmpty) {
            return const Center(child: Text('History မရှိသေးပါ'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final p = list[i];

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ===== Date / Time =====
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              p.date ?? '',
                              style: t.labelMedium,
                            ),
                            Text(
                              p.time ?? '',
                              style: t.labelMedium,
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                        Divider(color: cs.outlineVariant),
                        const SizedBox(height: 8),

                        // ===== External Market Price =====
                        Text(
                          'ပြင်ပပေါက်ဈေး',
                          style: t.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _money(p.ygea16),
                          style: t.titleLarge,
                        ),
                        if (p.imageUrl != null &&
                            p.imageUrl!.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              p.imageUrl!,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox(),
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // ===== Sections =====
                        _section(context, '၁၆ ပဲရည်',
                            buy: p.k16Buy, sell: p.k16Sell),
                        _section(context, '၁၆ ပဲရည် စနစ်သစ်',
                            buy: p.k16NewBuy, sell: p.k16NewSell),
                        _section(context, '၁၅ ပဲရည်',
                            buy: p.k15Buy, sell: p.k15Sell),
                        _section(context, '၁၅ ပဲရည် စနစ်သစ်',
                            buy: p.k15NewBuy, sell: p.k15NewSell),
                      ],
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

  // ===== UI helpers =====

  Widget _section(
    BuildContext context,
    String title, {
    int? buy,
    int? sell,
  }) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.titleMedium),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _priceBox(context, 'ဝယ်', buy),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _priceBox(context, 'ရောင်း', sell),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceBox(BuildContext context, String label, int? value) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: Offset(0, 3), // subtle 3D feel
          ),
        ],
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.labelMedium),
          const SizedBox(height: 4),
          Text(
            _money(value),
            style: t.bodyLarge,
          ),
        ],
      ),
    );
  }

  // ===== Utils =====

  String _money(int? v) {
    if (v == null) return '-';
    final s = v.toString();
    return s.replaceAllMapped(
      RegExp(r'\\B(?=(\\d{3})+(?!\\d))'),
      (m) => ',',
    );
  }
}
