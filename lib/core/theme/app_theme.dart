import 'package:flutter/material.dart';

import '../../models/enums.dart';

/// Brand palette & Material 3 theme for EcoRide.
class AppColors {
  AppColors._();
  static const primary = Color(0xFF12805C);
  static const primaryDark = Color(0xFF0B5C42);
  static const accent = Color(0xFFF5A524);
  static const info = Color(0xFF2563EB);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
  static const muted = Color(0xFF64748B);
  static const surface = Color(0xFFF6F8F7);

  static Color forDoc(DocStatus s) => switch (s) {
        DocStatus.pending => warning,
        DocStatus.approved => success,
        DocStatus.rejected => danger,
      };

  static Color forBooking(BookingStatus s) => switch (s) {
        BookingStatus.pending => warning,
        BookingStatus.accepted => success,
        BookingStatus.rejected => danger,
        BookingStatus.cancelled => muted,
      };

  static Color forTrip(TripStatus s) => switch (s) {
        TripStatus.scheduled => info,
        TripStatus.active => success,
        TripStatus.completed => muted,
        TripStatus.cancelled => danger,
      };

  static Color forAccount(AccountStatus s) => switch (s) {
        AccountStatus.active => success,
        AccountStatus.restricted => warning,
        AccountStatus.deactivated => danger,
      };
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: brightness == Brightness.light ? AppColors.primary : null,
    );
    final isLight = brightness == Brightness.light;
    final radius = BorderRadius.circular(14);

    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: c, width: w));

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isLight ? AppColors.surface : scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: isLight ? AppColors.surface : scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700, color: scheme.onSurface, letterSpacing: -0.2),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: border(scheme.outlineVariant),
        enabledBorder: border(scheme.outlineVariant),
        focusedBorder: border(scheme.primary, 1.8),
        errorBorder: border(scheme.error),
        focusedErrorBorder: border(scheme.error, 1.8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: isLight ? Colors.white : scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    );
  }
}
