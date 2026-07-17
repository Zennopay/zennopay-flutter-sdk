import 'zennopay_error.dart';

/// A receipt returned on a completed (or soft-pending) payment.
///
/// The native SDKs are the source of truth for these values; the bridge
/// forwards whatever the native PaymentSheet surfaces. iOS currently returns a
/// bare `completed(intentID:)` with no line items, so on iOS [Receipt] is
/// `null`; Android populates the merchant + amount fields. Every field is
/// therefore nullable — treat a present field as authoritative and an absent
/// one as "not surfaced on this platform/transaction".
class Receipt {
  const Receipt({
    this.merchantName,
    this.localAmountMinorUnits,
    this.localCurrency,
    this.amountUsdCents,
    this.transactionId,
    this.verifiableQrData,
    this.pending = false,
  });

  final String? merchantName;

  /// Local amount paid, in minor units (satang for THB; VND has no minor unit).
  /// Derived from the native display amount + currency exponent; null when the
  /// native layer did not surface an amount.
  final int? localAmountMinorUnits;

  /// ISO-4217 currency, as surfaced by the native SDK (e.g. `"THB"`, `"VND"`).
  final String? localCurrency;

  /// USD debited from the partner wallet, in cents. Null when not surfaced.
  final int? amountUsdCents;

  final String? transactionId;

  /// TH verifiable-QR receipt payload; null for VN.
  final String? verifiableQrData;

  /// True when the payment is a soft-terminal `pending` (poll timeout / left
  /// while processing).
  final bool pending;

  /// Build a [Receipt] from the native channel map. Returns null when no
  /// receipt fields were surfaced (e.g. iOS `completed`).
  static Receipt? fromMap(Map<Object?, Object?>? map, {bool pending = false}) {
    if (map == null || map.isEmpty) return null;
    final currency = map['localCurrency'] as String?;
    return Receipt(
      merchantName: map['merchantName'] as String?,
      localAmountMinorUnits:
          _toMinorUnits(map['localAmount'] as String?, currency),
      localCurrency: currency,
      amountUsdCents: _majorStringToCents(map['usdDebited'] as String?),
      transactionId: map['transactionId'] as String?,
      verifiableQrData: map['verifiableQrData'] as String?,
      pending: pending,
    );
  }

  /// Currencies with no minor unit (zero-decimal, ISO-4217 exponent 0).
  static const Set<String> _zeroDecimal = {'VND', 'JPY', 'KRW'};

  static int? _toMinorUnits(String? display, String? currency) {
    if (display == null) return null;
    final exponent =
        (currency != null && _zeroDecimal.contains(currency.toUpperCase()))
            ? 0
            : 2;
    return _majorStringToUnits(display, exponent);
  }

  static int? _majorStringToCents(String? display) =>
      _majorStringToUnits(display, 2);

  /// Parse a decimal display string (e.g. `"120.50"`) into minor units for the
  /// given exponent, tolerating grouping separators.
  static int? _majorStringToUnits(String? display, int exponent) {
    if (display == null) return null;
    final cleaned = display.replaceAll(RegExp(r'[,\s]'), '');
    final value = double.tryParse(cleaned);
    if (value == null) return null;
    var factor = 1;
    for (var i = 0; i < exponent; i++) {
      factor *= 10;
    }
    return (value * factor).round();
  }
}

/// The single terminal outcome of a PaymentSheet, delivered as the resolved
/// value of `Zennopay.presentSheet`. Mirrors the unified `PaymentResult` shared
/// across all Zennopay SDKs. `pending` is a first-class case.
sealed class PaymentResult {
  const PaymentResult(this.intentId);

  final String intentId;

  /// Decode the terminal result map returned by the native bridge over the
  /// `zennopay_flutter` method channel. See README for the wire contract.
  factory PaymentResult.fromMap(String intentId, Map<Object?, Object?> map) {
    final status = map['status'] as String?;
    switch (status) {
      case 'completed':
        return Completed(
          map['intentId'] as String? ?? intentId,
          receipt: Receipt.fromMap(map['receipt'] as Map<Object?, Object?>?),
        );
      case 'pending':
        return Pending(
          map['intentId'] as String? ?? intentId,
          receipt: Receipt.fromMap(
            map['receipt'] as Map<Object?, Object?>?,
            pending: true,
          ),
        );
      case 'canceled':
        return Canceled(map['intentId'] as String? ?? intentId);
      case 'failed':
      default:
        return Failed(
          map['intentId'] as String? ?? intentId,
          ZennopayError.fromMap(map['error'] as Map<Object?, Object?>?),
        );
    }
  }
}

/// Wallet debited, payout captured.
final class Completed extends PaymentResult {
  const Completed(super.intentId, {this.receipt});

  final Receipt? receipt;
}

/// User dismissed pre-terminal; no money moved.
final class Canceled extends PaymentResult {
  const Canceled(super.intentId);
}

/// Terminal non-success or unrecoverable in-sheet failure.
final class Failed extends PaymentResult {
  const Failed(super.intentId, this.error);

  final ZennopayError error;
}

/// The payment was confirmed but had not reached a terminal state when the
/// sheet closed — the user left while it was processing ("Done" on the
/// processing screen) or status polling timed out. The payment may still
/// settle; reconcile via webhook / `GET /v1/payment_intents/:id`. If it does
/// not complete, the money is refunded to the wallet automatically.
final class Pending extends PaymentResult {
  const Pending(super.intentId, {this.receipt});

  final Receipt? receipt;
}
