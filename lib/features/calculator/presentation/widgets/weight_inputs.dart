import 'package:flutter/material.dart';

class WeightInputs extends StatelessWidget {
  final TextEditingController kyatCtrl;
  final TextEditingController paeCtrl;
  final TextEditingController ywayCtrl;
  final bool allowEmpty;
  final String helperText;

  const WeightInputs({
    super.key,
    required this.kyatCtrl,
    required this.paeCtrl,
    required this.ywayCtrl,
    this.allowEmpty = false,
    this.helperText = 'ပမာဏ ဥပမာ: ၁ ကျပ် ၅ ပဲ ၃ ရွေး',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    InputDecoration dec(String label) => InputDecoration(
          labelText: label,
          filled: true,
          fillColor: cs.surface.withValues(alpha: 0.9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        );

    Widget unitBadge(String text) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.28),
          ),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.primary,
              ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            unitBadge('ကျပ်'),
            const SizedBox(width: 8),
            unitBadge('ပဲ'),
            const SizedBox(width: 8),
            unitBadge('ရွေး'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: kyatCtrl,
                keyboardType: TextInputType.number,
                decoration: dec('ကျပ်'),
                validator: (v) {
                  final raw = (v ?? '').trim();
                  if (raw.isEmpty) return allowEmpty ? null : '0+';
                  final x = double.tryParse(raw);
                  if (x == null || x < 0) return '0+';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: paeCtrl,
                keyboardType: TextInputType.number,
                decoration: dec('ပဲ'),
                validator: (v) {
                  final raw = (v ?? '').trim();
                  if (raw.isEmpty) return allowEmpty ? null : '0+';
                  final x = double.tryParse(raw);
                  if (x == null || x < 0) return '0+';
                  if (x >= 16) return '<16';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: ywayCtrl,
                keyboardType: TextInputType.number,
                decoration: dec('ရွေး'),
                validator: (v) {
                  final raw = (v ?? '').trim();
                  if (raw.isEmpty) return allowEmpty ? null : '0+';
                  final x = double.tryParse(raw);
                  if (x == null || x < 0) return '0+';
                  if (x >= 8) return '<8';
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            helperText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}
