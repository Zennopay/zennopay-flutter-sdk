import 'zennopay_error.dart';

/// A receipt returned on a completed (or soft-pending) payment.
class Receipt {
  const Receipt({
    this.merchantName,
    required this.localAmountMinorUnits,
    required this.localCurrency,
    required this.amountUsdCents,
    this.transactionId,
    this.verifiableQrData,
    this.pending = false,
  });

  final String? merchantName;

  /// Local amount paid, in minor units (satang for THB; VND has no minor unit).
  final int localAmountMinorUnits;

  /// Numeric ISO-4217 code, e.g. `"764"` THB, `"704"` VND.
  final String localCurrency;

  /// USD debited from the partner wallet, in cents.
  final int amountUsdCents;

  final String? transactionId;

  /// TH verifiable-QR receipt payload; null for VN.
  final String? verifiableQrData;

  /// True when the payment is a soft-terminal `pending` (poll timeout).
  final bool pending;
}

/// The single terminal outcome of a PaymentSheet, delivered as the resolved
/// value of [Zennopay.presentSheet]. Mirrors the unified `PaymentResult`
/// (spec §4.5). `pending` is promoted to a first-class case per the design
/// recommendation (§12.1).
sealed class PaymentResult {
  const PaymentResult(this.intentId);

  final String intentId;
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
/// sheet closed — the user chose to leave while it was processing ("Done" on
/// the processing screen) or status polling timed out. The payment may still
/// settle; reconcile via webhook / `GET /v1/payment_intents/:id`. If it does
/// not complete, the money is refunded to the wallet automatically.
final class Pending extends PaymentResult {
  const Pending(super.intentId, {this.receipt});

  final Receipt? receipt;
}
