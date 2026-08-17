import 'package:flutter/material.dart';

/// Design tokens straight from the Figma design system spec
/// ("Training Pipeline Dashboard Dev"), used while restyling screens to
/// match that design. New screens should reference these rather than
/// inventing their own local color constants, so the app stays in sync
/// with a single source of truth as more screens get redesigned.
abstract final class FigmaTokens {
  // ── Primary brand ────────────────────────────────────────────────────────
  static const primaryPurple = Color(0xFF693D94);
  static const purpleHover = Color(0xFF5A3488);
  static const gradientEnd = Color(0xFFAA399F);
  static const heroGradient = LinearGradient(
    colors: [primaryPurple, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Backgrounds ──────────────────────────────────────────────────────────
  static const pageBackground = Color(0xFFF4F5F7);
  static const cardBackground = Color(0xFFFFFFFF);
  static const badgeBackground = Color(0xFFF0E8F7);
  static const topBarNavy = Color(0xFF1A1A2E);
  static const avatarPill = Color(0xFF2D2D4A);
  static const rowHover = Color(0xFFF8F8FF);
  static const imagePlaceholder = Color(0xFFF3F4F6);
  static const buttonBackground = Color(0xFFF8FAFC);
  static const activeNavMobile = Color(0xFFF5F5FF);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const cardTitles = Color(0xFF1E2939);
  static const modalLabels = Color(0xFF364153);
  static const noteBoldText = Color(0xFF4A5565);
  static const noteBodyText = Color(0xFF6A7282);
  static const closeButton = Color(0xFF99A1AF);

  // ── Borders & dividers ───────────────────────────────────────────────────
  static const cardBorders = Color(0xFFE5E7EB);
  static const modalInputBorders = Color(0xFFE5E7EB);

  // ── Status & utility ─────────────────────────────────────────────────────
  static const overdueError = Color(0xFFDC2626);
  static const overdueHover = Color(0xFFB91C1C);
  static const statusDots = Color(0xFFEF4444);
}
