import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta extraída del diseño de referencia (fantasy oscuro / pergamino).
class AppColors {
  static const bg = Color(0xFF16171B); // fondo principal
  static const bgAlt = Color(0xFF1C1E23); // app bar / nav
  static const panel = Color(0xFF22252B); // cards
  static const panelAlt = Color(0xFF2A2D33);
  static const border = Color(0xFF3A3D44);

  static const gold = Color(0xFFC9A86A); // acento principal
  static const goldDim = Color(0xFF8A8270);

  static const parchment = Color(0xFFF1EAD9); // texto claro
  static const parchmentDim = Color(0xFFDDD6C8);
  static const muted = Color(0xFF9B958A); // texto apagado

  static const orange = Color(0xFFE0935F);
  static const red = Color(0xFFC75C4D); // daño / hostil
  static const green = Color(0xFF6FAE6A); // cura / aliado
  static const blue = Color(0xFF3A6EA5);

  // --- tokens del diseño de referencia ---
  static const frame = Color(0xFF141519); // fondo del "device frame"
  static const card = Color(0xFF1C1E23); // fondo de cards
  static const cardBorder = Color(0x0FFFFFFF); // blanco .06
  static const label = Color(0xFF7C766A); // labels chiquitos
  static const sub = Color(0xFF9B958A); // subtítulos
  static const listText = Color(0xFFDDD6C8); // texto de filas
  static const name = Color(0xFFF1EAD9); // nombres / valores fuertes

  static const hpValue = Color(0xFFE8B3AA);
  static const hpLabel = Color(0xFFC98A80);
  static const hpTrack = Color(0xFF2A1D1B);
  static const hpFillA = Color(0xFFA8463A);
  static const hpFillB = Color(0xFFC75C4D);
  static const healText = Color(0xFF9FCE9A);

  static const tokenYou = Color(0xFF3A6EA5);
  static const tokenAlly = Color(0xFF3F7A4E);
  static const tokenEnemy = Color(0xFF9C3B32);
  static const target = Color(0xFFE0935F);
}

/// Estilos Cinzel reutilizables (los números/títulos del diseño).
TextStyle cinzel(double size, {Color color = AppColors.name, FontWeight weight = FontWeight.w700, double height = 1.15}) =>
    GoogleFonts.cinzel(fontSize: size, fontWeight: weight, color: color, height: height);

ThemeData buildAppTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);

  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.gold,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.gold,
    onPrimary: AppColors.bgAlt,
    secondary: AppColors.orange,
    surface: AppColors.panel,
    onSurface: AppColors.parchment,
    error: AppColors.red,
  );

  final body = GoogleFonts.signikaTextTheme(base.textTheme).apply(
    bodyColor: AppColors.parchment,
    displayColor: AppColors.parchment,
  );

  TextStyle cinzel(TextStyle? s, Color c) =>
      GoogleFonts.cinzel(textStyle: s, fontWeight: FontWeight.w600, color: c);

  final textTheme = body.copyWith(
    titleLarge: cinzel(body.titleLarge, AppColors.parchment),
    titleMedium: cinzel(body.titleMedium, AppColors.gold),
    titleSmall: cinzel(body.titleSmall, AppColors.gold),
  );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.frame,
    canvasColor: AppColors.frame,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bgAlt,
      foregroundColor: AppColors.gold,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.cinzel(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.gold,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.bgAlt,
      indicatorColor: AppColors.gold.withAlpha(48),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? AppColors.gold
              : AppColors.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 11, color: AppColors.parchmentDim),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.gold.withAlpha(48)
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.gold
              : AppColors.muted,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.panelAlt,
      selectedColor: AppColors.gold.withAlpha(48),
      side: BorderSide(color: AppColors.gold.withAlpha(36)),
      labelStyle: const TextStyle(color: AppColors.parchment),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.bgAlt,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: const OutlineInputBorder(),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.gold),
      ),
    ),
    dividerColor: AppColors.border,
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: AppColors.gold),
  );
}
