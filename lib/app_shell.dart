import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mmgold/shared/navigation/app_shell_controller.dart';

import 'features/calculator/presentation/calculator_page.dart';
import 'features/history/presentation/history_page.dart';
import 'features/holdings/presentation/my_holdings_page.dart';
import 'features/gold_price/presentation/gold_price_page.dart';

class AppShell extends StatefulWidget {
  final int initialIndex;

  const AppShell({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const int _tabCount = 4;

  int _index = 0;

  @override
  void initState() {
    super.initState();
    _index = _clampIndex(widget.initialIndex);
    final queued = AppShellController.takeQueuedInitialTab();
    if (queued != null) {
      _index = _clampIndex(queued);
    }
    AppShellController.markAttached();
    AppShellController.tabRequests.addListener(_handleTabRequest);
  }

  final List<Widget> pages = const [
    GoldPricePage(),
    MyHoldingsPage(),
    CalculatorPage(),
    HistoryPage(),
  ];

  int _clampIndex(int value) {
    if (value < 0) return 0;
    if (value >= _tabCount) return _tabCount - 1;
    return value;
  }

  void _handleTabRequest() {
    final requested = AppShellController.tabRequests.value;
    if (requested == null) return;
    if (!mounted) return;
    setState(() => _index = _clampIndex(requested));
    AppShellController.consumeRequest();
  }

  @override
  void dispose() {
    AppShellController.tabRequests.removeListener(_handleTabRequest);
    AppShellController.markDetached();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: pages,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _TelegramStyleNavBar(
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
            ),
          ),
        ],
      ),
    );
  }
}

class _TelegramStyleNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _TelegramStyleNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  static const _tabs = <_NavTab>[
    _NavTab(
      icon: Icons.currency_exchange_rounded,
      label: 'ဈေး',
    ),
    _NavTab(
      icon: Icons.savings_outlined,
      label: 'စုဘူး',
    ),
    _NavTab(
      icon: Icons.calculate_rounded,
      label: 'တွက်ချက်',
    ),
    _NavTab(
      icon: Icons.history_rounded,
      label: 'မှတ်တမ်း',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selectedBg = Color.alphaBlend(
      const Color(0xFFE2C35A).withValues(alpha: 0.22),
      cs.surface,
    );
    final selectedFg = const Color(0xFFB8860B);

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.60),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final selected = i == currentIndex;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? selectedBg : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            tab.icon,
                            size: 23,
                            color: selected ? selectedFg : cs.onSurfaceVariant,
                          ),
                          if (selected)
                            Flexible(
                              child: AnimatedSize(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text(
                                    tab.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                    style: TextStyle(
                                      color: selectedFg,
                                      fontWeight: FontWeight.w800,
                                      height: 1.05,
                                      leadingDistribution:
                                          TextLeadingDistribution.even,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  final IconData icon;
  final String label;

  const _NavTab({
    required this.icon,
    required this.label,
  });
}
