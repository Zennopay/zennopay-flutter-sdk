/// Locale-aware currency formatting. Numbers always use tabular figures at the
/// widget layer (DESIGN.md); this only handles symbol + minor-unit rules.
/// Backend returns numeric ISO-4217 (`764` THB, `704` VND, `840` USD).
class Currency {
  const Currency._();

  static const Map<String, ({String symbol, int decimals, bool symbolBefore})>
      _map = {
    '764': (symbol: '฿', decimals: 2, symbolBefore: true), // THB (satang)
    '704': (symbol: '₫', decimals: 0, symbolBefore: false), // VND (no minor)
    '840': (symbol: r'$', decimals: 2, symbolBefore: true), // USD
  };

  /// Format a minor-unit integer for the given numeric ISO-4217 code.
  static String format(int minorUnits, String isoNumeric) {
    final info = _map[isoNumeric] ??
        (symbol: '', decimals: 2, symbolBefore: true);
    final major = minorUnits / _pow10(info.decimals);
    final digits = major.toStringAsFixed(info.decimals);
    final grouped = _group(digits);
    return info.symbolBefore ? '${info.symbol}$grouped' : '$grouped ${info.symbol}';
  }

  static String usd(int cents) => format(cents, '840');

  static int _pow10(int n) {
    var v = 1;
    for (var i = 0; i < n; i++) {
      v *= 10;
    }
    return v;
  }

  static String _group(String digits) {
    final parts = digits.split('.');
    final whole = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
      buf.write(whole[i]);
    }
    return parts.length > 1 ? '$buf.${parts[1]}' : buf.toString();
  }
}
