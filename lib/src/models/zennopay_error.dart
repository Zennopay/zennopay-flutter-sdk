/// The single shared error taxonomy (mirrors `docs/sdk-error-taxonomy.md`).
///
/// Every wire `error.code` and every SDK-local condition maps to one of these
/// cases. Copy is fixed by the taxonomy doc so all platforms render identical,
/// calm, plain-English text (muted brick, never a red wall).
enum ZennopayErrorCode {
  invalidJwt('invalid_jwt'),
  jwtExpired('jwt_expired'),
  jtiReplay('jti_replay'),
  intentMismatch('intent_mismatch'),
  cameraDenied('camera_denied'),
  qrUnsupported('qr_unsupported'),
  qrInvalid('qr_invalid'),
  invalidCorridor('invalid_corridor'),
  quoteExpired('quote_expired'),
  amountNotAllowed('amount_not_allowed'),
  confirmFailed('confirm_failed'),
  limitExceeded('limit_exceeded'),
  networkError('network_error'),
  canceled('canceled'),
  timedOut('timed_out');

  const ZennopayErrorCode(this.wire);

  /// The stable wire string emitted by the backend / used in telemetry.
  final String wire;

  static ZennopayErrorCode fromWire(String? code) {
    for (final c in ZennopayErrorCode.values) {
      if (c.wire == code) return c;
    }
    return ZennopayErrorCode.networkError;
  }
}

class ZennopayError implements Exception {
  const ZennopayError({
    required this.code,
    this.requestId,
    this.developerMessage,
  });

  final ZennopayErrorCode code;

  /// Correlates to server logs; never shown to the user.
  final String? requestId;

  /// Developer-facing detail; never shown to the user.
  final String? developerMessage;

  /// Decode the `{ code, requestId, message }` error map returned by the native
  /// bridge. The native layer maps its richer, dotted taxonomy (e.g.
  /// `confirm.quote_expired`, `payment.declined`) onto the stable wire codes in
  /// [ZennopayErrorCode] before it crosses the channel.
  factory ZennopayError.fromMap(Map<Object?, Object?>? map) {
    if (map == null) {
      return const ZennopayError(code: ZennopayErrorCode.networkError);
    }
    return ZennopayError(
      code: ZennopayErrorCode.fromWire(map['code'] as String?),
      requestId: map['requestId'] as String?,
      developerMessage: map['message'] as String?,
    );
  }

  /// Whether the same operation may be retried (advisory; see taxonomy).
  bool get isRetryable => switch (code) {
        ZennopayErrorCode.jwtExpired ||
        ZennopayErrorCode.cameraDenied ||
        ZennopayErrorCode.qrUnsupported ||
        ZennopayErrorCode.qrInvalid ||
        ZennopayErrorCode.invalidCorridor ||
        ZennopayErrorCode.quoteExpired ||
        ZennopayErrorCode.amountNotAllowed ||
        ZennopayErrorCode.confirmFailed ||
        ZennopayErrorCode.networkError =>
          true,
        _ => false,
      };

  /// Whether this triggers the `refreshSession(intentId)` host hook.
  bool get triggersRefresh => code == ZennopayErrorCode.jwtExpired;

  /// Verbatim user-facing copy (from `docs/sdk-error-taxonomy.md`).
  String get userMessage => switch (code) {
        ZennopayErrorCode.invalidJwt ||
        ZennopayErrorCode.intentMismatch =>
          'Something went wrong starting this payment. Please return to the app '
              'and try again.',
        ZennopayErrorCode.jwtExpired =>
          'Your session expired. Please return to '
              'the app and try again.',
        ZennopayErrorCode.jtiReplay => 'Checking your payment status…',
        ZennopayErrorCode.cameraDenied =>
          'Camera access is off. Allow camera in Settings, or paste the QR data '
              'instead.',
        ZennopayErrorCode.qrUnsupported =>
          "This QR type isn't supported yet. Try a PromptPay (Thailand) or "
              'VietQR (Vietnam) code.',
        ZennopayErrorCode.qrInvalid =>
          "That code couldn't be read. Make sure it's a merchant payment QR and "
              'try scanning again.',
        ZennopayErrorCode.invalidCorridor =>
          'We can only pay merchants in Thailand and Vietnam right now.',
        ZennopayErrorCode.quoteExpired =>
          'Rate refreshed, please review the new amount.',
        ZennopayErrorCode.amountNotAllowed =>
          "This merchant set a fixed amount for this QR. We've set it for you.",
        ZennopayErrorCode.confirmFailed =>
          "Payment didn't go through. Your wallet was not charged. Try again, "
              'or pay in cash.',
        ZennopayErrorCode.limitExceeded =>
          'This payment would go over your limit for Vietnam. Try a smaller '
              'amount.',
        ZennopayErrorCode.networkError => 'Network issue. Try again.',
        ZennopayErrorCode.timedOut =>
          "We'll finish this in the background. Check your transaction history "
              'for the final status.',
        ZennopayErrorCode.canceled => '',
      };

  @override
  String toString() =>
      'ZennopayError(${code.wire}${requestId != null ? ', req=$requestId' : ''})';
}
