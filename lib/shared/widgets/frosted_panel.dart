import 'dart:ui';

import 'package:flutter/material.dart';

class FrostedPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blurSigma;
  final double startAlpha;
  final double endAlpha;
  final double borderAlpha;
  final List<BoxShadow>? boxShadow;
  final Color? tintColor;

  const FrostedPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blurSigma = 10,
    this.startAlpha = 0.58,
    this.endAlpha = 0.38,
    this.borderAlpha = 0.55,
    this.boxShadow,
    this.tintColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = tintColor ?? cs.surface;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                base.withValues(alpha: startAlpha),
                cs.surfaceContainerHighest.withValues(alpha: endAlpha),
              ],
            ),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: borderAlpha),
            ),
            borderRadius: borderRadius,
            boxShadow: boxShadow,
          ),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
