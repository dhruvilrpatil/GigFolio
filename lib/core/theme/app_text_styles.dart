import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// GigFolio Typography System
/// Adapted from DESIGN.md (figmaSans → Inter via google_fonts)
class AppTextStyles {
  AppTextStyles._();

  // ─── Display ──────────────────────────────────────────────────────────────
  static TextStyle get displayLg => GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.8,
    color: AppColors.onSurface,
  );

  static TextStyle get displayMd => GoogleFonts.inter(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.30,
    letterSpacing: -0.52,
    color: AppColors.onSurface,
  );

  // ─── Headline ─────────────────────────────────────────────────────────────
  static TextStyle get headlineLg => GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.27,
    letterSpacing: -0.33,
    color: AppColors.onSurface,
  );

  static TextStyle get headlineMd => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.40,
    letterSpacing: -0.20,
    color: AppColors.onSurface,
  );

  static TextStyle get headlineSm => GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.41,
    letterSpacing: -0.085,
    color: AppColors.onSurface,
  );

  // ─── Card Title ───────────────────────────────────────────────────────────
  static TextStyle get cardTitle => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.45,
    letterSpacing: 0,
    color: AppColors.onSurface,
  );

  // ─── Title ────────────────────────────────────────────────────────────────
  static TextStyle get titleMd => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.33,
    letterSpacing: 0,
    color: AppColors.onSurface,
  );

  // ─── Body ─────────────────────────────────────────────────────────────────
  static TextStyle get bodyLg => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.50,
    letterSpacing: -0.14,
    color: AppColors.onSurface,
  );

  static TextStyle get bodyMd => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.43,
    letterSpacing: 0,
    color: AppColors.onSurface,
  );

  static TextStyle get bodySm => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.33,
    letterSpacing: 0.12,
    color: AppColors.onSurface,
  );

  // ─── Label (Eyebrow / Caption) ────────────────────────────────────────────
  static TextStyle get labelLg => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.38,
    letterSpacing: 0.26,
    color: AppColors.onSurface,
  );

  static TextStyle get labelMd => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.27,
    letterSpacing: 0.44,
    color: AppColors.onSurface,
  );

  static TextStyle get eyebrow => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.30,
    letterSpacing: 1.10,
    color: AppColors.textSecondary,
  );

  // ─── Button ───────────────────────────────────────────────────────────────
  static TextStyle get button => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.40,
    letterSpacing: -0.10,
    color: AppColors.onPrimary,
  );

  static TextStyle get buttonSm => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.40,
    letterSpacing: -0.05,
    color: AppColors.onPrimary,
  );

  // ─── Credential Mono (ID numbers, hashes) ─────────────────────────────────
  static TextStyle get credentialMono => GoogleFonts.robotoMono(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.33,
    letterSpacing: 1.80,
    color: AppColors.primary,
  );

  // ─── Score Display ────────────────────────────────────────────────────────
  static TextStyle get scoreDisplay => GoogleFonts.inter(
    fontSize: 64,
    fontWeight: FontWeight.w800,
    height: 1.0,
    letterSpacing: -1.28,
    color: AppColors.onSurface,
  );

  static TextStyle get scoreMd => GoogleFonts.inter(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: -0.72,
    color: AppColors.onSurface,
  );
}
