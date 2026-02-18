import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'features/access/presentation/welcome_gate.dart';
import 'features/gold_price/presentation/gold_price_admin_page.dart';
import 'shared/ads/interstitial_ad_manager.dart';
import 'shared/supabase/supabase_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseProvider.initialize();

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await MobileAds.instance.initialize();
    await InterstitialAdManager.instance.initialize();
  }

  runApp(const MyanmarGoldApp());
}

class MyanmarGoldApp extends StatelessWidget {
  const MyanmarGoldApp({super.key});

  static const bool _adminOnlyWebBuild =
      bool.fromEnvironment('ADMIN_ONLY_WEB', defaultValue: false);

  bool _isAdminWebRoute() {
    if (!kIsWeb) return false;
    final path = Uri.base.path.toLowerCase();
    final fragment = Uri.base.fragment.toLowerCase();
    return path == '/admin' ||
        path == 'admin' ||
        fragment == '/admin' ||
        fragment == 'admin';
  }

  TextTheme _buildTextTheme(ColorScheme cs) {
    const baseHeight = 1.16;
    const leading = TextLeadingDistribution.even;

    return const TextTheme(
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    ).apply(
      bodyColor: cs.onSurface,
      displayColor: cs.onSurface,
      fontFamily: 'Padauk',
      fontFamilyFallback: const ['NotoSansMyanmar'],
    ).copyWith(
      titleLarge: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: baseHeight,
        leadingDistribution: leading,
      ),
      titleMedium: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: baseHeight,
        leadingDistribution: leading,
      ),
      bodyLarge: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.2,
        leadingDistribution: leading,
      ),
      bodyMedium: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.2,
        leadingDistribution: leading,
      ),
      labelMedium: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.1,
        leadingDistribution: leading,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdminWeb = kIsWeb && (_adminOnlyWebBuild || _isAdminWebRoute());

    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFFC79A2A),
      brightness: Brightness.light,
    );
    final cs = base.copyWith(
      primary: const Color(0xFFC79A2A),
      onPrimary: const Color(0xFF2D2004),
      primaryContainer: const Color(0xFFF8E4AE),
      onPrimaryContainer: const Color(0xFF4E3800),
      secondary: const Color(0xFF9E7A1E),
      onSecondary: const Color(0xFF2A1F05),
      secondaryContainer: const Color(0xFFF2DEAA),
      onSecondaryContainer: const Color(0xFF4B390A),
      surface: const Color(0xFFF9F4E8),
      onSurface: const Color(0xFF2C2720),
      surfaceContainerHighest: const Color(0xFFF1E7D2),
      outlineVariant: const Color(0xFFD8C8A3),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'မြန်မာ့ရွှေ Calculator',
      routes: {
        '/admin': (_) => const GoldPriceAdminPage(),
      },
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Padauk',
        fontFamilyFallback: const ['NotoSansMyanmar'],
        colorScheme: cs,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: cs.onSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 24,
            height: 1.1,
            leadingDistribution: TextLeadingDistribution.even,
          ),
          iconTheme: IconThemeData(color: cs.onSurface),
        ),
        cardTheme: CardThemeData(
          color: cs.surface.withValues(alpha: 0.92),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cs.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: cs.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: cs.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: cs.primary, width: 1.6),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.onSurface,
            side: BorderSide(color: cs.outlineVariant),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        textTheme: _buildTextTheme(cs),
      ),
      home: isAdminWeb ? const GoldPriceAdminPage() : const WelcomeGate(),
    );
  }
}
