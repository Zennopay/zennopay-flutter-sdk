import 'package:flutter/services.dart';

import 'appearance/zennopay_appearance.dart';
import 'models/payment_result.dart';
import 'models/zennopay_config.dart';
import 'models/zennopay_error.dart';

/// The public entrypoint for the Zennopay PaymentSheet on Flutter.
///
/// This package is a **native bridge**: one `await Zennopay.presentSheet(...)`
/// presents the native iOS/Android Zennopay PaymentSheet — the full pay
/// experience (QR scan → amount + FX quote → slide-to-pay → result) rendered by
/// the native SDK, with full platform accessibility — and resolves with a
/// single [PaymentResult]. Nothing here re-implements the UI in Dart.
///
/// ```dart
/// final result = await Zennopay.presentSheet(
///   intentId: 'zp_abc123',
///   sessionJwt: sessionJwt,
///   refreshSession: (intentId) => yourBackend.remintJwt(intentId),
///   appearance: const ZennopayAppearance.automatic(),
///   config: ZennopayConfig.sandbox,
/// );
/// switch (result) {
///   case Completed(): showReceipt(result);
///   case Failed(:final error): showError(error);
///   case Canceled(): dismiss();
///   case Pending(): showPending();
/// }
/// ```
abstract final class Zennopay {
  const Zennopay._();

  /// The platform channel shared with `ZennopayFlutterPlugin` on both
  /// platforms. `present` is Dart→native (resolves with the terminal result
  /// map); `refreshSession` is native→Dart (services the host hook without
  /// blocking the native SDK).
  static const MethodChannel _channel = MethodChannel('zennopay_flutter');

  static bool _handlerInstalled = false;

  /// The `refreshSession` hook for the in-flight [presentSheet] call. Only one
  /// checkout can be live at a time (the native sheet covers the host), so a
  /// single slot is sufficient.
  static Future<String?> Function(String intentId)? _activeRefresh;

  /// The `refreshReceiptToken` hook for the in-flight [presentReceipt] call.
  /// Only one receipt can be live at a time (the native receipt covers the
  /// host), so a single slot is sufficient.
  static Future<String?> Function(String intentId)? _activeReceiptRefresh;

  /// Present the native Zennopay PaymentSheet and resolve once with a
  /// [PaymentResult].
  ///
  /// Camera permission, scanning, quoting, confirm, polling, retries, session
  /// refresh, and relaunch recovery are all owned by the native SDK.
  ///
  /// - [intentId]: the Zennopay payment intent your backend pre-created.
  /// - [sessionJwt]: the partner-minted, intent-bound session JWT (≤5 min).
  /// - [refreshSession]: optional host hook invoked on a 401/expiry. Re-mint a
  ///   fresh session JWT for the SAME intent, or return null if you can't.
  /// - [appearance]: partner theming; defaults to the bank-solid Zennopay look.
  /// - [config]: REST/environment configuration; defaults to sandbox.
  static Future<PaymentResult> presentSheet({
    required String intentId,
    required String sessionJwt,
    ZennopayConfig? config,
    ZennopayAppearance? appearance,
    Future<String?> Function(String intentId)? refreshSession,
  }) async {
    // Cheap fail-fast for the obvious integration mistake, without a channel
    // hop. The native SDK performs the authoritative JWT structure / expiry /
    // intent-binding gate.
    if (intentId.trim().isEmpty || sessionJwt.trim().isEmpty) {
      return Failed(
        intentId,
        const ZennopayError(code: ZennopayErrorCode.invalidJwt),
      );
    }

    _installHandler();
    _activeRefresh = refreshSession;

    final resolvedConfig = config ?? ZennopayConfig.sandbox;
    final resolvedAppearance =
        appearance ?? const ZennopayAppearance.automatic();

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'present',
        <String, Object?>{
          'intentId': intentId,
          'sessionJwt': sessionJwt,
          'config': resolvedConfig.toMap(),
          'appearance': resolvedAppearance.toMap(),
        },
      );
      if (result == null) {
        return Failed(
          intentId,
          const ZennopayError(code: ZennopayErrorCode.networkError),
        );
      }
      return PaymentResult.fromMap(intentId, result);
    } on PlatformException catch (e) {
      // An integration-level failure raised by the native bridge (e.g. no
      // Activity/UIViewController to present over) surfaces as a Failed rather
      // than throwing, so the caller always gets exactly one PaymentResult.
      return Failed(
        intentId,
        ZennopayError(
          code: ZennopayErrorCode.fromWire(e.code),
          developerMessage: e.message,
        ),
      );
    } finally {
      _activeRefresh = null;
    }
  }

  /// Present the native Zennopay receipt for a completed (or pending / refunded
  /// / failed) payment intent and complete once the user dismisses it.
  ///
  /// This reopens the **authoritative** receipt: the native SDK fetches the
  /// receipt, renders the native receipt / pending / failure screens, polls a
  /// pending receipt through to a terminal state, shows refund copy when the
  /// intent was refunded, and — on a `401` mid-poll — asks the host to re-mint
  /// the receipt token via [refreshReceiptToken]. Nothing is re-implemented in
  /// Dart. The returned future completes (with no value) when the receipt is
  /// dismissed.
  ///
  /// - [intentId]: the Zennopay payment intent to show the receipt for.
  /// - [receiptToken]: the partner-minted, intent-bound receipt token.
  /// - [config]: REST/environment configuration; defaults to sandbox.
  /// - [appearance]: partner theming; defaults to the bank-solid Zennopay look.
  /// - [refreshReceiptToken]: optional host hook invoked on a 401/expiry mid
  ///   poll. Re-mint a fresh receipt token for the SAME intent, or return null
  ///   if you can't.
  static Future<void> presentReceipt({
    required String intentId,
    required String receiptToken,
    ZennopayConfig? config,
    ZennopayAppearance? appearance,
    Future<String?> Function(String intentId)? refreshReceiptToken,
  }) async {
    // Cheap fail-fast for the obvious integration mistake, without a channel
    // hop. The native SDK performs the authoritative token structure / expiry /
    // intent-binding gate.
    if (intentId.trim().isEmpty || receiptToken.trim().isEmpty) {
      return;
    }

    _installHandler();
    _activeReceiptRefresh = refreshReceiptToken;

    final resolvedConfig = config ?? ZennopayConfig.sandbox;
    final resolvedAppearance =
        appearance ?? const ZennopayAppearance.automatic();

    try {
      await _channel.invokeMethod<void>(
        'presentReceipt',
        <String, Object?>{
          'intentId': intentId,
          'receiptToken': receiptToken,
          'config': resolvedConfig.toMap(),
          'appearance': resolvedAppearance.toMap(),
        },
      );
    } on PlatformException {
      // An integration-level failure raised by the native bridge (e.g. no
      // Activity/UIViewController to present over) resolves the future without
      // throwing — the receipt is a read-only surface, so there is no terminal
      // result to report; the caller simply observes the dismissal.
    } finally {
      _activeReceiptRefresh = null;
    }
  }

  static void _installHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'refreshSession':
          return _serviceRefresh(call.arguments, _activeRefresh);
        case 'refreshReceiptToken':
          return _serviceRefresh(call.arguments, _activeReceiptRefresh);
      }
      return null;
    });
  }

  /// Service a native→Dart token-refresh callback (`refreshSession` /
  /// `refreshReceiptToken`) against the given host hook, swallowing errors so a
  /// throwing hook degrades to "couldn't refresh" rather than crossing the
  /// channel as an exception.
  static Future<String?> _serviceRefresh(
    Object? arguments,
    Future<String?> Function(String intentId)? refresh,
  ) async {
    if (refresh == null) return null;
    final args = (arguments as Map?)?.cast<Object?, Object?>();
    final intentId = args?['intentId'] as String? ?? '';
    try {
      return await refresh(intentId);
    } catch (_) {
      return null;
    }
  }
}
