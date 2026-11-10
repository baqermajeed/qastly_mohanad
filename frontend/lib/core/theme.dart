import 'package:flutter/material.dart';

class AppTheme {
  static const String fontFamily = 'LamaSans';

  static const Color background = Color(0xFFF6FCFF);
  static const Color basic = Color(0xFF002E45);
  static const Color soft = Color(0xFF069BAF);
  static const Color softShadow = Color(0x3B069BAF);
  static const Color phone = Color(0xFF1E7AA8);
  static const Color cardNavy = Color(0x2B22577A);
  static const Color cardTeal = Color(0x3B069BAF);
  static const Color cardMint = Color(0xFFD2E9E6);
  static const Color cardGold = Color(0x1FC38508);
  static const Color statusCompleted = Color(0x660E8A61);
  static const Color statusWaiting = Color(0x66FFE330);
  static const Color statusCanceled = Color(0x66EB0101);
  static const Color statusMissed = Color(0x4D002E45);

  static const Color primary = soft;
  static const Color accent = soft;
  static const Color late = Color(0xFFC0392B);
  static const Color paid = Color(0xFF2E86C1);
  static const Color completed = Color(0xFF0E8A61);
  static const Color bg = background;

  static List<BoxShadow> get softGlow => const [
        BoxShadow(
          color: softShadow,
          blurRadius: 10,
          offset: Offset.zero,
        ),
      ];

  static TextStyle text({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      color: color ?? basic,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: soft,
        primary: soft,
        secondary: soft,
        surface: Colors.white,
        onPrimary: background,
        onSurface: basic,
      ),
      scaffoldBackgroundColor: background,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: fontFamily,
        bodyColor: basic,
        displayColor: basic,
      ),
      primaryTextTheme: base.primaryTextTheme.apply(
        fontFamily: fontFamily,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: basic,
        foregroundColor: background,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: background,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: soft,
        foregroundColor: background,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shadowColor: softShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
