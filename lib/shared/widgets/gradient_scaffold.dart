import 'dart:ui';

import 'package:flutter/material.dart';

class GradientScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;

  const GradientScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
  });

  PreferredSizeWidget? _resolveAppBar(BuildContext context) {
    if (appBar is! AppBar) return appBar;

    final cs = Theme.of(context).colorScheme;
    final raw = appBar as AppBar;
    final baseFrost = ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cs.surface.withValues(alpha: 0.50),
                cs.surface.withValues(alpha: 0.22),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.38),
              ),
            ),
          ),
        ),
      ),
    );

    final mergedFlexible = raw.flexibleSpace == null
        ? baseFrost
        : Stack(
            fit: StackFit.expand,
            children: [
              baseFrost,
              raw.flexibleSpace!,
            ],
          );

    return AppBar(
      leading: raw.leading,
      automaticallyImplyLeading: raw.automaticallyImplyLeading,
      title: raw.title,
      actions: raw.actions,
      bottom: raw.bottom,
      centerTitle: raw.centerTitle,
      titleSpacing: raw.titleSpacing,
      leadingWidth: raw.leadingWidth,
      toolbarHeight: raw.toolbarHeight,
      elevation: raw.elevation,
      scrolledUnderElevation: raw.scrolledUnderElevation,
      foregroundColor: raw.foregroundColor,
      iconTheme: raw.iconTheme,
      actionsIconTheme: raw.actionsIconTheme,
      titleTextStyle: raw.titleTextStyle,
      toolbarTextStyle: raw.toolbarTextStyle,
      shape: raw.shape,
      systemOverlayStyle: raw.systemOverlayStyle,
      shadowColor: raw.shadowColor,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      flexibleSpace: mergedFlexible,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surface,
            cs.surfaceContainerHighest,
            cs.surface.withValues(alpha: 0.98),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -110,
            right: -80,
            child: _GlowCircle(
              size: 260,
              color: cs.secondaryContainer.withValues(alpha: 0.65),
            ),
          ),
          Positioned(
            left: -70,
            bottom: 120,
            child: _GlowCircle(
              size: 220,
              color: cs.primaryContainer.withValues(alpha: 0.7),
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: _resolveAppBar(context),
            body: body,
            bottomNavigationBar: bottomNavigationBar,
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}
