/// EMVCo Merchant-Presented-Mode TLV parser.
///
/// This on-device decode is **display-only**: it previews the merchant/amount
/// so the Scanner screen can advance quickly. The raw payload is always
/// submitted to `POST /v1/payment_intents/{id}/scan`, where the backend
/// authoritatively re-parses the EMVCo TLV (CRC-16, tag validation,
/// merchant/beneficiary extraction). The client never trusts a local parse for
/// money movement.
library;

class Tlv {
  const Tlv({required this.tag, required this.length, required this.value});

  final String tag;
  final String length;
  final String value;

  @override
  String toString() => 'Tag: $tag, Length: $length, Value: $value';
}

class EmvCoParser {
  const EmvCoParser._();

  static Map<String, Tlv> parse(String qr) {
    final Map<String, Tlv> result = {};
    int index = 0;

    try {
      while (index < qr.length - 4) {
        if (index + 4 > qr.length) break;
        final String tag = qr.substring(index, index + 2);
        final String lenStr = qr.substring(index + 2, index + 4);
        final int length = int.parse(lenStr);
        index += 4;

        if (index + length > qr.length) break;
        final String value = qr.substring(index, index + length);
        index += length;

        result[tag] = Tlv(tag: tag, length: lenStr, value: value);
      }
    } catch (_) {
      // Gracefully handle malformed QR codes — the backend is authoritative.
    }

    return result;
  }

  static String getCountry(String qr) {
    final parsed = parse(qr);
    final countryTlv = parsed['58'];
    if (countryTlv != null) {
      final code = countryTlv.value.toUpperCase();
      switch (code) {
        case 'VN':
          return 'Vietnam';
        case 'TH':
          return 'Thailand';
        default:
          return code;
      }
    }
    return 'Unknown';
  }

  static double? getAmount(String qr) {
    final parsed = parse(qr);
    final amountTlv = parsed['54'];
    if (amountTlv != null) {
      return double.tryParse(amountTlv.value);
    }
    return null;
  }

  static String getMerchantName(String qr) {
    final parsed = parse(qr);
    final nameTlv = parsed['59'];
    return nameTlv?.value ?? 'Recipient';
  }

  /// EMVCo tag 01 ("Point of Initiation Method"): `11` = static, `12` =
  /// dynamic. Absence defaults to static. This is a display-only hint; the
  /// backend classifies authoritatively.
  static bool isDynamic(String qr) {
    final parsed = parse(qr);
    final poi = parsed['01']?.value;
    return poi == '12';
  }
}
