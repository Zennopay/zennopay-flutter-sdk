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

  /// Serialize for the native bridge. Colors are `#RRGGBB` strings; the light
  /// value sits at the top level and its dark counterpart under `colors.dark`
  /// (Android currently applies a single value per slot, iOS builds a dynamic
  /// light/dark colour from the pair). Radii and the primary-button radius are
  /// re-clamped natively to the DESIGN.md ≤ 12 ceiling.
  Map<String, Object?> toMap() => {
        'mode': switch (mode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'automatic',
        },
        'colors': {
          'primary': _hex(colors.primary),
          'background': _hex(colors.background),
          'surface': _hex(colors.surface),
          'textPrimary': _hex(colors.textPrimary),
          'textSecondary': _hex(colors.textSecondary),
          'textTertiary': _hex(colors.textTertiary),
          'border': _hex(colors.border),
          'success': _hex(colors.success),
          'pending': _hex(colors.pending),
          'failure': _hex(colors.failure),
          'dark': {
            'primary': _hex(colors.primaryDark),
            'background': _hex(colors.backgroundDark),
            'surface': _hex(colors.surfaceDark),
            'textPrimary': _hex(colors.textPrimaryDark),
            'textSecondary': _hex(colors.textSecondaryDark),
            'textTertiary': _hex(colors.textTertiaryDark),
            'border': _hex(colors.borderDark),
            'success': _hex(colors.successDark),
            'pending': _hex(colors.pendingDark),
            'failure': _hex(colors.failureDark),
          },
        },
        'cornerRadius': {
          'input': shapes.input,
          'card': shapes.card,
          'slide': shapes.slide,
        },
        'font': {
          if (typography.fontFamily != null) 'family': typography.fontFamily,
          'scale': typography.scale,
        },
        'primaryButton': {
          'background': _hex(primaryButton.background),
          'textColor': _hex(primaryButton.textColor),
          'cornerRadius': primaryButton.cornerRadius,
        },
        // A partner logo bundled as a Flutter asset; native resolves it
        // best-effort by name and ignores it if it can't (see README).
        if (logo is AssetImage) 'logo': (logo as AssetImage).assetName,
      };

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
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
  })  : input = input < 0 ? 0 : (input > 12 ? 12 : input),
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
