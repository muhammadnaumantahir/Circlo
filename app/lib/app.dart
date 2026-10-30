import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/widgets.dart';
import 'router.dart';

ThemeData _theme(Brightness brightness) {
  final isLight = brightness == Brightness.light;
  final background = isLight ? CircloPalette.canvas : CircloPalette.darkCanvas;
  final surface = isLight ? const Color(0xFFFFFFFF) : CircloPalette.darkSurface;
  final border = isLight ? CircloPalette.borderLight : CircloPalette.borderDark;
  final input = isLight ? CircloPalette.inputLight : const Color(0xFF101B2C);
  final scheme = ColorScheme.fromSeed(seedColor: CircloPalette.brand, brightness: brightness).copyWith(
    primary: isLight ? CircloPalette.brand : CircloPalette.brandDark,
    onPrimary: Colors.white,
    secondary: CircloPalette.mint,
    tertiary: CircloPalette.violet,
    error: CircloPalette.danger,
    surface: surface,
    onSurface: isLight ? CircloPalette.ink : const Color(0xFFE7EEF8),
    outline: border,
    outlineVariant: border,
  );
  final base = ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme);
  final radius = BorderRadius.circular(17);
  return base.copyWith(
    scaffoldBackgroundColor: background,
    canvasColor: background,
    textTheme: base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(color: scheme.onSurface, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1.8, height: 1.05),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w900, letterSpacing: -1.1),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w900, letterSpacing: -.8),
      titleLarge: base.textTheme.titleLarge?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w900, letterSpacing: -.45),
      titleMedium: base.textTheme.titleMedium?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w800, letterSpacing: -.2),
      titleSmall: base.textTheme.titleSmall?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w800),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(color: scheme.onSurface, height: 1.5),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(color: scheme.onSurface, height: 1.45),
      bodySmall: base.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      labelMedium: base.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background, foregroundColor: scheme.onSurface, surfaceTintColor: Colors.transparent,
      elevation: 0, scrolledUnderElevation: 0, centerTitle: false, toolbarHeight: 68,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(color: scheme.onSurface, fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -.45),
      actionsIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
    ),
    cardTheme: CardThemeData(
      color: surface, surfaceTintColor: Colors.transparent, elevation: 0, clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: border.withValues(alpha: isLight ? .88 : .8))),
      margin: const EdgeInsets.symmetric(vertical: 4),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: input,
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 17),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: .78)),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      prefixIconColor: scheme.onSurfaceVariant, suffixIconColor: scheme.onSurfaceVariant,
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: border.withValues(alpha: .55))),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: border.withValues(alpha: .72))),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.primary, width: 1.7)),
      errorBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.error)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.error, width: 1.7)),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      backgroundColor: scheme.primary, foregroundColor: scheme.onPrimary, minimumSize: const Size(48, 50),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
    )),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      side: BorderSide(color: border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
    )),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
      minimumSize: const Size(48, 44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
    )),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(
      minimumSize: const Size(44, 44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    )),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary, foregroundColor: scheme.onPrimary, elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface, indicatorColor: scheme.primary.withValues(alpha: .13), elevation: 0, height: 78,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
        fontSize: 11, fontWeight: states.contains(WidgetState.selected) ? FontWeight.w900 : FontWeight.w700,
        color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
      )),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
        color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
      )),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent, indicatorColor: scheme.primary.withValues(alpha: .12),
      useIndicator: true, groupAlignment: -.72, minExtendedWidth: 224,
      selectedIconTheme: IconThemeData(color: scheme.primary), unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      selectedLabelTextStyle: TextStyle(color: scheme.primary, fontWeight: FontWeight.w900),
      unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant, textColor: scheme.onSurface, minVerticalPadding: 12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: input, selectedColor: scheme.primary.withValues(alpha: .13), side: BorderSide(color: border.withValues(alpha: .72)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelStyle: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700),
      secondaryLabelStyle: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    ),
    dividerTheme: DividerThemeData(color: border.withValues(alpha: .72), thickness: 1, space: 1),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface, modalBackgroundColor: surface, surfaceTintColor: Colors.transparent, showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface, surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      constraints: const BoxConstraints(maxWidth: 560),
      titleTextStyle: TextStyle(color: scheme.onSurface, fontSize: 21, fontWeight: FontWeight.w900),
      contentTextStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15, height: 1.45),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isLight ? const Color(0xFF17253B) : const Color(0xFF1E2B3D),
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary, linearTrackColor: scheme.primaryContainer.withValues(alpha: .55)),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 450), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: scheme.inverseSurface, borderRadius: BorderRadius.circular(10)),
      textStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class CircloApp extends ConsumerWidget {
  const CircloApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Circlo',
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// Shown when the build has no Firebase configuration (see .env.example).
class SetupRequiredApp extends StatelessWidget {
  const SetupRequiredApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Circlo',
        theme: _theme(Brightness.light),
        home: const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Circlo is not connected to Firebase yet.\n\n'
                'Build with the FIREBASE_* --dart-define values described in README.md '
                '(or USE_FIREBASE_EMULATOR=true for local development).',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}
