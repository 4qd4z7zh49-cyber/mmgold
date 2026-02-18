import 'package:flutter/material.dart';

class FloatingSegmented<T> extends StatelessWidget {
  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final void Function(Set<T>) onSelectionChanged;
  final bool showSelectedIcon;

  const FloatingSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
    this.showSelectedIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.72),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SegmentedButton<T>(
        segments: segments,
        selected: selected,
        showSelectedIcon: showSelectedIcon,
        onSelectionChanged: onSelectionChanged,
        style: ButtonStyle(
          side: WidgetStatePropertyAll(
            BorderSide(color: cs.outlineVariant.withValues(alpha: 0.65)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return cs.primaryContainer;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return cs.onPrimaryContainer;
            }
            return cs.onSurfaceVariant;
          }),
          textStyle: WidgetStatePropertyAll(
            const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              height: 1.12,
              leadingDistribution: TextLeadingDistribution.even,
            ),
          ),
          visualDensity: VisualDensity.standard,
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ),
    );
  }
}
