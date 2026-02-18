import 'package:flutter/material.dart';

class WeightInputs extends StatelessWidget {
  final TextEditingController kyatCtrl;
  final TextEditingController paeCtrl;
  final TextEditingController ywayCtrl;

  const WeightInputs({
    super.key,
    required this.kyatCtrl,
    required this.paeCtrl,
    required this.ywayCtrl,
  });

  @override
  Widget build(BuildContext context) {
    InputDecoration dec(String label) => InputDecoration(labelText: label);

    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: kyatCtrl,
            keyboardType: TextInputType.number,
            decoration: dec('ကျပ်'),
            validator: (v) {
              final x = double.tryParse((v ?? '').trim());
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
              final x = double.tryParse((v ?? '').trim());
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
              final x = double.tryParse((v ?? '').trim());
              if (x == null || x < 0) return '0+';
              if (x >= 8) return '<8';
              return null;
            },
          ),
        ),
      ],
    );
  }
}