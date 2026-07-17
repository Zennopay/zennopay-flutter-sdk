import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';

/// Theming API (spec §5). Partners set colors, corner radius, font, logo, and
/// light/dark so the sheet reads as part of their app while honoring
/// `DESIGN.md`'s structural rules. Radii are clamped to ≤ 12px; the accent is
/// reserved for state; `tabular-nums` is mandatory. Values outside the allowed
/// range are clamped (a warning is logged in sandbox).
///
/// Field-for-field mirror of the native `ZennopayAppearance` on iOS
/// (`mode/colors/cornerRadius/font/primaryButton/logo`) and Android
/// (`mode/colors/shapes/typography/primaryButton/logo`) — the three surfaces
/// must stay in lockstep so a partner theme ports across platforms unchanged.
@immutable
class ZennopayAppearance {
  const ZennopayAppearance({
    this.mode = ThemeMode.system,
    this.colors = const ZennopayColors(),
    this.shapes = const ZennopayShapes(),
    this.typography = const ZennopayTypography(),
    this.primaryButton = const ZennopayPrimaryButton(),
    this.logo,
  });

  /// The `DESIGN.md` defaults with system light/dark — a partner who passes
  /// nothing gets the bank-solid Zennopay look.
  const ZennopayAppearance.automatic()
      : mode = ThemeMode.system,
        colors = const ZennopayColors(),
        shapes = const ZennopayShapes(),
        typography = const ZennopayTypography(),
        primaryButton = const ZennopayPrimaryButton(),
        logo = null;

  final ThemeMode mode;
  final ZennopayColors colors;
  final ZennopayShapes shapes;
  final ZennopayTypography typography;
  final ZennopayPrimaryButton primaryButton;
  final ImageProvider? logo;
}

/// Each color is a light/dark pair; a single value applies to both modes.
@immutable
class ZennopayColors {
  const ZennopayColors({
    this.primary = const Color(0xFF1B6B2F),
    this.primaryDark = const Color(0xFF4DA866),
    this.background = const Color(0xFFFAFAF8),
    this.backgroundDark = const Color(0xFF0F1217),
    this.surface = const Color(0xFFFFFFFF),
    this.surfaceDark = const Color(0xFF1A1E25),
    this.textPrimary = const Color(0xFF0A0F14),
    this.textPrimaryDark = const Color(0xFFF0F2F4),
    this.textSecondary = const Color(0xFF5A6675),
    this.textSecondaryDark = const Color(0xFFA0A8B3),
    this.textTertiary = const Color(0xFF8A949F),
    this.textTertiaryDark = const Color(0xFF6B7480),
    this.border = const Color(0xFFE8E9EC),
    this.borderDark = const Color(0xFF2A3038),
    this.success = const Color(0xFF15803D),
    this.successDark = const Color(0xFF4DA866),
    this.pending = const Color(0xFF7C5E1A),
    this.pendingDark = const Color(0xFFC9A24B),
    this.failure = const Color(0xFFA53939),
    this.failureDark = const Color(0xFFC26464),
  });

  final Color primary, primaryDark;
  final Color background, backgroundDark;
  final Color surface, surfaceDark;
  final Color textPrimary, textPrimaryDark;
  final Color textSecondary, textSecondaryDark;
  final Color textTertiary, textTertiaryDark;
  final Color border, borderDark;
  final Color success, successDark;
  final Color pending, pendingDark;
  final Color failure, failureDark;
}

/// Corner radii. All clamped to ≤ 12px (DESIGN.md anti-slop rule).
@immutable
class ZennopayShapes {
  const ZennopayShapes({
    double input = 4,
    double card = 8,
    double slide = 12,
  })  : input = input < 0
            ? 0
            : (input > 12 ? 12 : input),
        card = card < 0 ? 0 : (card > 12 ? 12 : card),
        slide = slide < 0 ? 0 : (slide > 12 ? 12 : slide);

  final double input;
  final double card;
  final double slide;
}

@immutable
class ZennopayTypography {
  const ZennopayTypography({
    this.fontFamily,
    double scale = 1.0,
  }) : scale = scale > 1.5 ? 1.5 : (scale < 1.0 ? 1.0 : scale);

  /// Default "General Sans"; must resolve `tabular-nums`.
  final String? fontFamily;

  /// Honors Dynamic Type up to 1.5×.
  final double scale;
}

@immutable
class ZennopayPrimaryButton {
  const ZennopayPrimaryButton({
    this.background = const Color(0xFF1B6B2F),
    this.textColor = const Color(0xFFFFFFFF),
    double cornerRadius = 8,
  }) : cornerRadius =
            cornerRadius < 0 ? 0 : (cornerRadius > 12 ? 12 : cornerRadius);

  final Color background;
  final Color textColor;
  final double cornerRadius;
}
