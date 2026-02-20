import 'package:flutter/material.dart';

import '../../../app_shell.dart';
import '../../../shared/navigation/app_shell_controller.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class WelcomeGate extends StatefulWidget {
  const WelcomeGate({super.key});

  @override
  State<WelcomeGate> createState() => _WelcomeGateState();
}

class _WelcomeGateState extends State<WelcomeGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _titleScale;
  late final Animation<double> _subtitleOpacity;
  late final Animation<double> _haloOpacity;
  late final Animation<double> _haloScale;
  late final Animation<double> _buttonOpacity;
  late final Animation<Offset> _buttonSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    _titleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.05, 0.42, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.30),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.05, 0.45, curve: Curves.easeOutCubic),
      ),
    );
    _titleScale = Tween<double>(
      begin: 0.82,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.08, 0.48, curve: Curves.easeOutBack),
      ),
    );
    _subtitleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.40, 0.65, curve: Curves.easeOut),
    );
    _haloOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.10, 0.70, curve: Curves.easeOut),
    );
    _haloScale = Tween<double>(begin: 0.70, end: 1.18).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.12, 0.85, curve: Curves.easeOutCubic),
      ),
    );
    _buttonOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.68, 1.00, curve: Curves.easeOut),
    );
    _buttonSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.68, 1.00, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final titleFontSize = width < 360 ? 60.0 : (width < 520 ? 72.0 : 86.0);

    return GradientScaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 44, 24, 24),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 280,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.scale(
                                scale: _haloScale.value,
                                child: Opacity(
                                  opacity: _haloOpacity.value * 0.95,
                                  child: Container(
                                    width: 248,
                                    height: 248,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          cs.primary.withValues(alpha: 0.22),
                                          cs.secondaryContainer.withValues(
                                            alpha: 0.08,
                                          ),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.10, 0.56, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              FadeTransition(
                                opacity: _titleOpacity,
                                child: SlideTransition(
                                  position: _titleSlide,
                                  child: ScaleTransition(
                                    scale: _titleScale,
                                    child: ShaderMask(
                                      blendMode: BlendMode.srcIn,
                                      shaderCallback: (bounds) {
                                        return const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFFE8C76B),
                                            Color(0xFFC79A2A),
                                            Color(0xFF9C7113),
                                          ],
                                        ).createShader(bounds);
                                      },
                                      child: Text(
                                        'ရွှေစုဘူး',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: titleFontSize,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'NotoSansMyanmar',
                                          fontFamilyFallback: const ['Padauk'],
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        FadeTransition(
                          opacity: _subtitleOpacity,
                          child: Text(
                            'နေ့စဉ်ရွှေဈေးတွက်ချက်ဖို့ လွယ်ကူတဲ့\nသင့်ရဲ့ Gold companion',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.78),
                              height: 1.32,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            SlideTransition(
              position: _buttonSlide,
              child: FadeTransition(
                opacity: _buttonOpacity,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final initialTab =
                          AppShellController.takeQueuedInitialTab() ?? 0;
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => AppShell(initialIndex: initialTab),
                        ),
                      );
                    },
                    child: const Text('Get Started'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
