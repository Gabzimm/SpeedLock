import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tokens copiados diretamente de `design/speedlock-screens.html` — se o
/// mockup mudar uma cor, atualizar aqui em vez de espalhar hex codes
/// pelos ecrãs.
class SpeedLockColors {
  SpeedLockColors._();

  static const bgApp = Color(0xFF0B0710);
  static const surface1 = Color(0xFF17111F);
  static const surface2 = Color(0xFF201A2B);
  static const line = Color(0x17FFFFFF); // rgba(255,255,255,.09)
  static const lineAccent = Color(0x668B5CF6); // rgba(139,92,246,.4)
  static const accent = Color(0xFF8B5CF6); // chamado "--lime" no CSS, mas é o roxo principal
  static const accentInk = Color(0xFFFFFFFF);
  static const text1 = Color(0xFFF4F2F7);
  static const text2 = Color(0xFF9C93AC);
  static const danger = Color(0xFFFF6B5B);

  static const primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFA855F7), Color(0xFF6D28D9)],
  );
}

/// Fontes: `Space Grotesk` para títulos/números grandes (gauge, saldo),
/// `Manrope` para o resto — tal como no mockup. Usa `google_fonts`, que
/// descarrega/faz cache das fontes sozinho — não é preciso empacotar
/// ficheiros .ttf nem declarar `fonts:` no pubspec.
class SpeedLockTheme {
  SpeedLockTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final bodyTextTheme = GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: SpeedLockColors.text1,
      displayColor: SpeedLockColors.text1,
    );

    return base.copyWith(
      scaffoldBackgroundColor: SpeedLockColors.bgApp,
      colorScheme: base.colorScheme.copyWith(
        surface: SpeedLockColors.bgApp,
        primary: SpeedLockColors.accent,
        onPrimary: SpeedLockColors.accentInk,
        secondary: SpeedLockColors.accent,
        error: SpeedLockColors.danger,
      ),
      textTheme: bodyTextTheme.copyWith(
        headlineSmall: GoogleFonts.spaceGrotesk(
          fontWeight: FontWeight.w600,
          fontSize: 21,
          color: SpeedLockColors.text1,
        ),
        titleMedium: GoogleFonts.spaceGrotesk(
          fontWeight: FontWeight.w600,
          fontSize: 19,
          color: SpeedLockColors.text1,
        ),
        bodySmall: TextStyle(
          fontSize: 13.5,
          color: SpeedLockColors.text2,
          height: 1.4,
          fontFamily: GoogleFonts.manrope().fontFamily,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SpeedLockColors.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SpeedLockColors.lineAccent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SpeedLockColors.lineAccent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SpeedLockColors.accent, width: 1.5),
        ),
        labelStyle: const TextStyle(color: SpeedLockColors.text2, fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: SpeedLockColors.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: SpeedLockColors.lineAccent),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: SpeedLockColors.line),
          foregroundColor: SpeedLockColors.text1,
          padding: const EdgeInsets.all(14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
        ),
      ),
    );
  }
}
