import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mmgold/shared/widgets/gradient_scaffold.dart';
import '../data/domain/gold_price_repo.dart';
import '../data/domain/gold_price_models.dart';
import 'gold_price_history_page.dart';

class GoldPricePage extends StatelessWidget {
  const GoldPricePage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

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
      body: FutureBuilder<GoldPriceLatest?>(
        future: GoldPriceRepo().fetchLatest(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Gold price service မချိတ်ဆက်ရသေးပါ'),
            );
          }

          final p = snapshot.data;
          if (p == null) {
            return const Center(child: Text('ဈေးအချက်အလက် မရှိသေးပါ'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
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
                    if (p.imageUrl != null &&
                        p.imageUrl!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          p.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 120,
                            alignment: Alignment.center,
                            color: cs.surfaceContainerHighest,
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
                    _priceRow(
                      context,
                      buy: p.k16Buy,
                      sell: p.k16Sell,
                    ),

                    const SizedBox(height: 12),

                    // ===== 16 New =====
                    _sectionTitle(context, '၁၆ ပဲရည် စနစ်သစ်'),
                    _priceRow(
                      context,
                      buy: p.k16NewBuy,
                      sell: p.k16NewSell,
                    ),

                    const SizedBox(height: 12),

                    // ===== 15 K =====
                    _sectionTitle(context, '၁၅ ပဲရည်'),
                    _priceRow(
                      context,
                      buy: p.k15Buy,
                      sell: p.k15Sell,
                    ),

                    const SizedBox(height: 12),

                    // ===== 15 New =====
                    _sectionTitle(context, '၁၅ ပဲရည် စနစ်သစ်'),
                    _priceRow(
                      context,
                      buy: p.k15NewBuy,
                      sell: p.k15NewSell,
                    ),
                  ],
                ),
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

  Widget _priceBox(
    BuildContext context, {
    required String label,
    int? value,
  }) {
    final t = Theme.of(context).textTheme;

    // Background color ကို page/card အရောင်နဲ့လိုက်အောင် (soft)
    final cs = Theme.of(context).colorScheme;
    final base = cs.surface.withValues(alpha: 0.9);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(14),

        // 3D / raised look
        boxShadow: [
          // Drop shadow (အောက်ဘက်)
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
          // Soft shadow (နားလည်သန့်)
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
          // Highlight (အပေါ်ဘက် ကြွသလို)
          BoxShadow(
            color: cs.surface.withValues(alpha: 0.72),
            blurRadius: 10,
            offset: const Offset(-4, -4),
          ),
        ],

        // Border သေးသေးလေး ထည့်ရင် ပို premium
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
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
