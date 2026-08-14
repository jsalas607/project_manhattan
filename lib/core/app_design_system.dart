import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sistema de diseño global de la app.
/// Centraliza colores, tipografía, tema y guía de voz.
/// Importar desde cualquier pantalla:
///   import 'package:project_manhattan/core/app_design_system.dart';

// ============================================================
// COLORES
// ============================================================

class AppColors {
  AppColors._();

  // Principales
  static const Color azulControl = Color(0xFF1E3A8A);
  static const Color naranjaAccion = Color(0xFFF97316);
  static const Color verdeExito = Color(0xFF10B981);
  static const Color rojoAlerta = Color(0xFFEF4444);

  // Fondo
  static const Color fondoOscuro = Color(0xFF0F172A);

  // Texto claro (sobre fondo oscuro)
  static const Color textoClaroAlto = Color(0xFFF8FAFC);
  static const Color textoClaroMedio = Color(0xFFCBD5F5);

  // Texto oscuro (sobre fondo claro)
  static const Color textoOscuroAlto = Color(0xFF020617);
  static const Color textoOscuroMedio = Color(0xFF334155);
}

// ============================================================
// TIPOGRAFÍA
// ============================================================

class AppTypography {
  AppTypography._();

  /// Fuente principal — UI general, operación.
  static TextStyle inter({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Fuente alternativa — títulos, dashboard del dueño.
  static TextStyle plusJakarta({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // Estilos predefinidos (sobre fondo oscuro)
  static TextStyle get displayLarge => plusJakarta(
        size: 32,
        weight: FontWeight.w700,
        color: AppColors.textoClaroAlto,
      );

  static TextStyle get headlineLarge => plusJakarta(
        size: 24,
        weight: FontWeight.w700,
        color: AppColors.textoClaroAlto,
      );

  static TextStyle get titleLarge => inter(
        size: 18,
        weight: FontWeight.w600,
        color: AppColors.textoClaroAlto,
      );

  static TextStyle get titleMedium => inter(
        size: 16,
        weight: FontWeight.w600,
        color: AppColors.textoClaroAlto,
      );

  static TextStyle get bodyLarge => inter(
        size: 16,
        weight: FontWeight.w400,
        color: AppColors.textoClaroAlto,
      );

  static TextStyle get bodyMedium => inter(
        size: 14,
        weight: FontWeight.w400,
        color: AppColors.textoClaroMedio,
      );

  static TextStyle get labelLarge => inter(
        size: 14,
        weight: FontWeight.w600,
        color: AppColors.textoClaroAlto,
        letterSpacing: 0.2,
      );

  static TextStyle get caption => inter(
        size: 12,
        weight: FontWeight.w400,
        color: AppColors.textoClaroMedio,
      );
}

// ============================================================
// TEMA
// ============================================================

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.fondoOscuro,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.azulControl,
        secondary: AppColors.naranjaAccion,
        tertiary: AppColors.verdeExito,
        error: AppColors.rojoAlerta,
        surface: AppColors.fondoOscuro,
        onPrimary: AppColors.textoClaroAlto,
        onSecondary: AppColors.textoClaroAlto,
        onSurface: AppColors.textoClaroAlto,
        onError: AppColors.textoClaroAlto,
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge,
        headlineLarge: AppTypography.headlineLarge,
        titleLarge: AppTypography.titleLarge,
        titleMedium: AppTypography.titleMedium,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        labelLarge: AppTypography.labelLarge,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.naranjaAccion,
          foregroundColor: AppColors.textoClaroAlto,
          textStyle: AppTypography.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// VOZ — SISTEMA DE COMUNICACIÓN
// ============================================================

/// Guía de tono y voz para textos de UI.
///
/// La app tiene DOS audiencias con estilos distintos:
///
/// 1. OPERACIÓN (mesero, cocina, cajero)
///    - Tono: cercano, directo
///    - Formato: corto, tipo comando
///    - Ejemplos válidos:
///        "Nueva orden"
///        "Enviar a cocina"
///        "Cobrar"
///        "Lista"
///        "Mesa 4"
///    - Evitar: frases largas, jerga técnica, gerundios pasivos.
///
/// 2. ANÁLISIS (gerente / dueño)
///    - Tono: profesional, analítico
///    - Formato: claro, sin tecnicismos pesados
///    - Ejemplos válidos:
///        "Ventas del día"
///        "Ganancia estimada"
///        "Inventario bajo"
///        "Diferencia en caja"
///    - Evitar: lenguaje infantil, abreviaturas, slang.
///
/// Regla general: si el usuario está EJECUTANDO una acción, usa OPERACIÓN.
/// Si está REVISANDO información, usa ANÁLISIS.
class AppVoice {
  AppVoice._();

  /// Marcadores opcionales para clasificar textos por audiencia.
  static const String operacion = 'operacion';
  static const String analisis = 'analisis';
}
