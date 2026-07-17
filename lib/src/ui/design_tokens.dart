import 'package:flutter/widgets.dart';

import '../appearance/zennopay_appearance.dart';

/// Resolves a [ZennopayAppearance] against the current brightness into concrete
/// tokens the widgets read. Keeps all "which mode?" logic in one place.
class ZennoTokens {
  ZennoTokens(this.appearance, this.brightness);

  final ZennopayAppearance appearance;
  final Brightness brightness;

  bool get _dark => brightness == Brightness.dark;
  ZennopayColors get _c => appearance.colors;

  Color get primary => _dark ? _c.primaryDark : _c.primary;
  Color get background => _dark ? _c.backgroundDark : _c.background;
  Color get surface => _dark ? _c.surfaceDark : _c.surface;
  Color get textPrimary => _dark ? _c.textPrimaryDark : _c.textPrimary;
  Color get textSecondary => _dark ? _c.textSecondaryDark : _c.textSecondary;
  Color get textTertiary => _dark ? _c.textTertiaryDark : _c.textTertiary;
  Color get border => _dark ? _c.borderDark : _c.border;
  Color get success => _dark ? _c.successDark : _c.success;
  Color get pending => _dark ? _c.pendingDark : _c.pending;
  Color get failure => _dark ? _c.failureDark : _c.failure;

  /// 8% (light) / 12% (dark) tint of failure — the terminal-failure halo.
  Color get failureSoft => failure.withValues(alpha: _dark ? 0.12 : 0.08);

  double get radiusInput => appearance.shapes.input;
  double get radiusCard => appearance.shapes.card;
  double get radiusSlide => appearance.shapes.slide;

  String? get fontFamily => appearance.typography.fontFamily;
  double get textScale => appearance.typography.scale;

  /// `tabular-nums` is mandatory on every numeric (DESIGN.md).
  static const List<FontFeature> tabularNums = [FontFeature.tabularFigures()];

  TextStyle text({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
    bool tabular = false,
  }) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size * textScale,
        fontWeight: weight,
        color: color ?? textPrimary,
        fontFeatures: tabular ? tabularNums : null,
        height: 1.2,
      );
}
