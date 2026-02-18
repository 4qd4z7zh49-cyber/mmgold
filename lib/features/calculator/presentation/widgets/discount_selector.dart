import 'package:flutter/material.dart';

import '../../../../shared/widgets/floating_segmented.dart';
import '../../domain/calculator_types.dart';

class DiscountSelector extends StatefulWidget {
  final bool isOrnament;
  final DiscountValue value;
  final ValueChanged<DiscountValue> onChanged;

  const DiscountSelector({
    super.key,
    required this.isOrnament,
    required this.value,
    required this.onChanged,
  });

  @override
  State<DiscountSelector> createState() => _DiscountSelectorState();
}

class _DiscountSelectorState extends State<DiscountSelector> {
  final TextEditingController _customCtrl = TextEditingController();
  DiscountUnit _customUnit = DiscountUnit.percent;

  bool get _isCustom => widget.value.mode == DiscountMode.custom;

  @override
  void initState() {
    super.initState();
    _syncFromValue();

    _customCtrl.addListener(() {
      if (!_isCustom) return;
      final raw =
          _customCtrl.text.trim().replaceAll(',', '').replaceAll(' ', '');
      final v = double.tryParse(raw) ?? 0;
      widget.onChanged(DiscountValue.custom(v, _customUnit));
    });
  }

  @override
  void didUpdateWidget(covariant DiscountSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value.mode != widget.value.mode ||
        oldWidget.value.value != widget.value.value ||
        oldWidget.value.unit != widget.value.unit) {
      _syncFromValue();
    }
  }

  void _syncFromValue() {
    if (widget.value.mode == DiscountMode.custom) {
      _customUnit = widget.value.unit;

      // keep text in sync (percent may be decimal)
      final txt = widget.value.value == 0
          ? ''
          : (widget.value.isPercent
              ? widget.value.value.toString()
              : widget.value.value.toStringAsFixed(0));

      if (_customCtrl.text != txt) _customCtrl.text = txt;
    } else {
      if (_customCtrl.text.isNotEmpty) _customCtrl.clear();
    }
  }

  Widget _segmentLabel(String text) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          height: 1.05,
          leadingDistribution: TextLeadingDistribution.even,
        ),
      ),
    );
  }

  List<ButtonSegment<DiscountValue>> _ornamentSegments() {
    // Ornament: NO, 9%, 9.5%, 10%, 12%
    final presets = <double>[0, 9, 9.5, 10, 12];
    return presets.map((p) {
      final label = p == 0
          ? 'NO'
          : '${p % 1 == 0 ? p.toStringAsFixed(0) : p.toStringAsFixed(1)}%';
      final val = p == 0 ? DiscountValue.none : DiscountValue.percent(p);
      return ButtonSegment(value: val, label: _segmentLabel(label));
    }).toList();
  }

  List<ButtonSegment<DiscountValue>> _barSegments() {
    // Bar: NO, 5000, 10000, 15000 (MMK)
    final presets = <double>[0, 5000, 10000, 15000];
    return presets.map((m) {
      final label = m == 0 ? 'NO' : m.toStringAsFixed(0);
      final val = m == 0 ? DiscountValue.none : DiscountValue.mmk(m);
      return ButtonSegment(value: val, label: _segmentLabel(label));
    }).toList();
  }

  DiscountValue _selectedPreset(List<ButtonSegment<DiscountValue>> segments) {
    // If current value matches a preset (mode+value), use it; else default to none.
    for (final s in segments) {
      final a = widget.value;
      final b = s.value;

      if (a.mode != b.mode) continue;

      if (a.mode == DiscountMode.none) return b;

      if (a.mode == DiscountMode.custom) {
        // custom is not a preset selection
        continue;
      }

      if (a.value == b.value) return b;
    }
    return DiscountValue.none;
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final segments = widget.isOrnament ? _ornamentSegments() : _barSegments();
    final selected = _isCustom ? DiscountValue.none : _selectedPreset(segments);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Presets row
        SizedBox(
          width: double.infinity,
          child: FloatingSegmented<DiscountValue>(
            segments: segments,
            selected: {selected},
            showSelectedIcon: false,
            onSelectionChanged: (s) {
              widget.onChanged(s.first);
            },
          ),
        ),

        const SizedBox(height: 10),

        // Custom (only for Ornament per your requirement)
        if (widget.isOrnament) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                // enable custom mode
                final raw = _customCtrl.text
                    .trim()
                    .replaceAll(',', '')
                    .replaceAll(' ', '');
                final v = double.tryParse(raw) ?? 0;
                widget.onChanged(DiscountValue.custom(v, _customUnit));
                setState(() {});
              },
              icon: Icon(Icons.edit_outlined, color: cs.primary),
              label: Text(
                'ကိုယ်တိုင်ရွေးမယ်',
                style:
                    TextStyle(fontWeight: FontWeight.w800, color: cs.primary),
              ),
            ),
          ),
          if (_isCustom) ...[
            const SizedBox(height: 10),

            // % / MMK toggle (stored in model => no heuristic)
            SizedBox(
              width: double.infinity,
              child: FloatingSegmented<DiscountUnit>(
                segments: const [
                  ButtonSegment(value: DiscountUnit.percent, label: Text('%')),
                  ButtonSegment(value: DiscountUnit.mmk, label: Text('MMK')),
                ],
                selected: {_customUnit},
                showSelectedIcon: false,
                onSelectionChanged: (s) {
                  setState(() => _customUnit = s.first);

                  final raw = _customCtrl.text
                      .trim()
                      .replaceAll(',', '')
                      .replaceAll(' ', '');
                  final v = double.tryParse(raw) ?? 0;

                  widget.onChanged(DiscountValue.custom(v, _customUnit));
                },
              ),
            ),

            const SizedBox(height: 10),

            TextFormField(
              controller: _customCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _customUnit == DiscountUnit.percent
                    ? 'အလျော့ (%)'
                    : 'အလျော့ (ကျပ်)',
                prefixIcon: const Icon(Icons.edit_outlined),
              ),
            ),
          ],
        ],
      ],
    );
  }
}
