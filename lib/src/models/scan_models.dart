/// DTOs for the SDK-facing REST contract (`docs/sdk-rest-contract.md`):
/// `POST /v1/payment_intents/{id}/scan`, `/confirm`, `GET /:id`.
library;

enum QrKind {
  dynamic_,
  static_;

  static QrKind fromWire(String? v) =>
      v == 'static' ? QrKind.static_ : QrKind.dynamic_;

  bool get isStatic => this == QrKind.static_;
}

class Merchant {
  const Merchant({
    this.scheme,
    this.name,
    this.city,
    this.country,
    this.mcc,
  });

  /// `promptpay` | `vietqr`.
  final String? scheme;

  /// Nullable — a personal/bank-account VietQR carries no merchant-name tag;
  /// callers fall back to "Recipient".
  final String? name;
  final String? city;
  final String? country;
  final String? mcc;

  factory Merchant.fromJson(Map<String, dynamic> j) => Merchant(
        scheme: j['scheme'] as String?,
        name: j['name'] as String?,
        city: j['city'] as String?,
        country: j['country'] as String?,
        mcc: j['mcc'] as String?,
      );

  /// Verified-badge network label, e.g. "PromptPay" / "VietQR".
  String get networkLabel => switch (scheme) {
        'promptpay' => 'PromptPay',
        'vietqr' => 'VietQR',
        _ => 'the payment network',
      };

  String get displayName => (name == null || name!.isEmpty) ? 'Recipient' : name!;
}

class Quote {
  const Quote({
    required this.quoteId,
    required this.quoteVersion,
    required this.amountUsdCents,
    required this.localAmountMinorUnits,
    required this.localCurrency,
    required this.expiresAt,
  });

  final String quoteId;
  final int quoteVersion;
  final int amountUsdCents;
  final int localAmountMinorUnits;

  /// Numeric ISO-4217 (`764` THB, `704` VND).
  final String localCurrency;

  /// Epoch millis when the quote expires (default TTL 30s).
  final int expiresAt;

  DateTime get expiresAtDate =>
      DateTime.fromMillisecondsSinceEpoch(expiresAt);

  bool get isExpired => DateTime.now().millisecondsSinceEpoch >= expiresAt;

  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
        quoteId: j['quote_id'] as String,
        quoteVersion: (j['quote_version'] as num).toInt(),
        amountUsdCents: (j['amount_usd_cents'] as num).toInt(),
        localAmountMinorUnits: (j['local_amount_minor_units'] as num).toInt(),
        localCurrency: j['local_currency'].toString(),
        expiresAt: (j['expires_at'] as num).toInt(),
      );
}

class ScanResult {
  const ScanResult({
    required this.intentId,
    required this.status,
    required this.merchant,
    required this.qrKind,
    required this.quote,
  });

  final String intentId;
  final String status;
  final Merchant merchant;
  final QrKind qrKind;
  final Quote quote;

  factory ScanResult.fromJson(Map<String, dynamic> j) => ScanResult(
        intentId: j['intent_id'].toString(),
        status: (j['status'] ?? 'created').toString(),
        merchant:
            Merchant.fromJson((j['merchant'] as Map).cast<String, dynamic>()),
        qrKind: QrKind.fromWire(j['qr_kind'] as String?),
        quote: Quote.fromJson((j['quote'] as Map).cast<String, dynamic>()),
      );
}

/// Terminal / poll projection of a payment intent (`GET /:id`, `/confirm`).
class PaymentIntentRecord {
  const PaymentIntentRecord({
    required this.id,
    required this.status,
    this.amountUsdCents,
    this.corridor,
    this.merchantName,
    this.localAmountMinorUnits,
    this.localCurrency,
    this.transactionId,
    this.verifiableQrData,
    this.limitReason,
  });

  final String id;

  /// `created` | `authorized` | `captured` | `failed` | `pending` | …
  final String status;
  final int? amountUsdCents;
  final String? corridor;
  final String? merchantName;
  final int? localAmountMinorUnits;
  final String? localCurrency;
  final String? transactionId;
  final String? verifiableQrData;

  /// `limit_daily` | `limit_monthly` when a VND cap was breached at confirm.
  final String? limitReason;

  bool get isCaptured => status == 'captured';
  bool get isFailed => status == 'failed';
  bool get isPending => status == 'pending' || status == 'processing';
  bool get isTerminal => isCaptured || isFailed;

  factory PaymentIntentRecord.fromJson(Map<String, dynamic> j) =>
      PaymentIntentRecord(
        id: (j['id'] ?? j['intent_id']).toString(),
        status: (j['status'] ?? 'pending').toString(),
        amountUsdCents: (j['amount_usd_cents'] as num?)?.toInt(),
        corridor: j['corridor'] as String?,
        merchantName: j['merchant_name'] as String? ??
            (j['merchant'] is Map
                ? (j['merchant'] as Map)['name'] as String?
                : null),
        localAmountMinorUnits:
            (j['local_amount_minor_units'] as num?)?.toInt(),
        localCurrency: j['local_currency']?.toString(),
        transactionId: j['transaction_id'] as String?,
        verifiableQrData: j['verifiable_qr_data'] as String?,
        limitReason: j['limit_exceeded'] as String? ?? j['limit_reason'] as String?,
      );
}
