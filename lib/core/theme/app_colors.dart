import 'package:flutter/material.dart';

/// GigFolio Color System
/// Based on DESIGN.md (Figma editorial monochrome + pastel blocks)
/// and Sovereign Purple Identity design spec.
class AppColors {
  AppColors._();

  // ─── Brand Anchors ────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF34146C);
  static const Color primaryContainer = Color(0xFF4B2E83);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFBA9CF8);
  static const Color inversePrimary = Color(0xFFD2BBFF);

  // ─── Surface / Canvas ─────────────────────────────────────────────────────
  static const Color canvas = Color(0xFFFFFFFF);
  static const Color surfaceCanvas = Color(0xFFFAF9FC);
  static const Color surfaceSoft = Color(0xFFF7F7F5);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF0F3FF);
  static const Color surfaceContainerHighest = Color(0xFFD8E3FB);
  static const Color inverseCanvas = Color(0xFF000000);
  static const Color inverseInk = Color(0xFFFFFFFF);

  // ─── Ink / Text ───────────────────────────────────────────────────────────
  static const Color ink = Color(0xFF000000);
  static const Color onSurface = Color(0xFF111C2D);
  static const Color onSurfaceVariant = Color(0xFF494551);
  static const Color textSecondary = Color(0xFF64748B);

  // ─── Borders ──────────────────────────────────────────────────────────────
  static const Color hairline = Color(0xFFE6E6E6);
  static const Color hairlineSoft = Color(0xFFF1F1F1);
  static const Color cardBorder = Color(0xFFEDE9FE);
  static const Color cardBorderSubtle = Color(0xFFF1F5F9);
  static const Color outline = Color(0xFF7B7582);
  static const Color outlineVariant = Color(0xFFCBC4D2);

  // ─── Pastel Color Blocks (DESIGN.md signature) ────────────────────────────
  static const Color blockLime = Color(0xFFDCEEB1);
  static const Color blockLilac = Color(0xFFC5B0F4);
  static const Color blockCream = Color(0xFFF4ECD6);
  static const Color blockPink = Color(0xFFEFD4D4);
  static const Color blockMint = Color(0xFFC8E6CD);
  static const Color blockCoral = Color(0xFFF3C9B6);
  static const Color blockNavy = Color(0xFF1F1D3D);

  // ─── Accent ───────────────────────────────────────────────────────────────
  static const Color accentMagenta = Color(0xFFFF3D8B);

  // ─── Semantic Status ──────────────────────────────────────────────────────
  // Verified / Active
  static const Color statusVerifiedText = Color(0xFF16A34A);
  static const Color statusVerifiedAccent = Color(0xFF22C55E);
  static const Color statusVerifiedBg = Color(0xFFF0FDF4);
  static const Color statusVerifiedBorder = Color(0xFFBBF7D0);

  // Pending / Provisional
  static const Color statusPendingText = Color(0xFFD97706);
  static const Color statusPendingAccent = Color(0xFFF59E0B);
  static const Color statusPendingBg = Color(0xFFFFFBEB);
  static const Color statusPendingBorder = Color(0xFFFDE68A);

  // Inactive / Locked
  static const Color statusInactiveText = Color(0xFF64748B);
  static const Color statusInactiveBg = Color(0xFFF1F5F9);
  static const Color statusInactiveBorder = Color(0xFFCBD5E1);

  // Expired / Flagged
  static const Color statusExpiredText = Color(0xFFDC2626);
  static const Color statusExpiredBg = Color(0xFFFEF2F2);
  static const Color statusExpiredBorder = Color(0xFFFECACA);

  // Success
  static const Color semanticSuccess = Color(0xFF1EA64A);

  // ─── Reputation Tag Colors ────────────────────────────────────────────────
  static const Color reputationExcellent = Color(0xFF16A34A);
  static const Color reputationGood = Color(0xFF0D9488);
  static const Color reputationAverage = Color(0xFFD97706);
  static const Color reputationPoor = Color(0xFFEA580C);
  static const Color reputationWorst = Color(0xFFDC2626);

  // ─── Secondary / Tertiary ─────────────────────────────────────────────────
  static const Color secondary = Color(0xFF64587C);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFE3D3FD);
  static const Color onSecondaryContainer = Color(0xFF65597D);

  // ─── Error ────────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);

  // ─── Shadows ──────────────────────────────────────────────────────────────
  static const Color shadowPrimary = Color(0xFF4B2E83);
  static const Color overlayScrim = Color(0xFF000000);
}
