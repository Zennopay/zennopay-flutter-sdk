import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'appearance/zennopay_appearance.dart';
import 'models/payment_result.dart';
import 'models/zennopay_config.dart';
import 'models/zennopay_error.dart';
import 'network/rest_client.dart';
import 'ui/checkout_controller.dart';
import 'ui/payment_sheet.dart';

/// The public entrypoint for the Zennopay PaymentSheet on Flutter (spec §4.3).
///
/// Mirrors Stripe Flutter's `Stripe.instance.presentPaymentSheet()` shape: one
/// `Future<PaymentResult>`, and the terminal case is the resolved value.
///
/// ```dart
/// final result = await Zennopay.presentSheet(
///   context: context,
///   intentId: 'zp_abc123',
///   sessionJwt: sessionJwt,
///   refreshSession: (intentId) => yourBackend.remintJwt(intentId),
///   appearance: const ZennopayAppearance.automatic(),
///   config: ZennopayConfig.staging,
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

  /// A navigator key the host may install so [presentSheet] can be called
  /// without a [BuildContext] (e.g. from a service layer). Optional — passing
  /// `context` takes precedence.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Present the native pay experience and resolve once with a [PaymentResult].
  ///
  /// Camera permission, scanning, quoting, confirm, polling, retries, session
  /// refresh, and relaunch recovery are all internal.
  ///
  /// A [context] (or an installed [navigatorKey]) is required to present the
  /// modal. Providing neither resolves immediately with
  /// `Failed(intentId, invalidJwt)` — a fail-fast integration error.
  static Future<PaymentResult> presentSheet({
    required String intentId,
    required String sessionJwt,
    BuildContext? context,
    Future<String?> Function(String intentId)? refreshSession,
    ZennopayAppearance appearance = const ZennopayAppearance.automatic(),
    ZennopayConfig config = ZennopayConfig.staging,
    void Function(String event, Map<String, Object?> props)? onEvent,
  }) async {
    // Fail-fast gate (spec §4.6): validate token shape + intent binding BEFORE
    // presenting any UI.
    final gateError = _preflight(intentId: intentId, sessionJwt: sessionJwt);
    if (gateError != null) {
      return Failed(intentId, gateError);
    }

    final navigator = context != null
        ? Navigator.of(context, rootNavigator: true)
        : navigatorKey.currentState;
    if (navigator == null) {
      return Failed(
        intentId,
        const ZennopayError(
          code: ZennopayErrorCode.invalidJwt,
          developerMessage:
              'No BuildContext or installed Zennopay.navigatorKey to present '
              'the sheet.',
        ),
      );
    }

    final client = ZennopayRestClient(
      config: config,
      intentId: intentId,
      sessionJwt: sessionJwt,
    );
    final controller = CheckoutController(
      intentId: intentId,
      config: config,
      client: client,
      refreshSession: refreshSession,
      onEvent: onEvent,
    );
    onEvent?.call('sheet_presented', {
      'intent_id': intentId,
      'environment': config.environment.name,
    });

    await navigator.push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: const Color(0x66000000),
        pageBuilder: (_, __, ___) => ZennopayPaymentSheet(
          controller: controller,
          appearance: appearance,
          config: config,
        ),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
              parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );

    final result = await controller.result;
    controller.dispose();
    return result;
  }

  /// On-device JWT structure / `exp` / `intent_id`-binding check (no signature
  /// verification — the backend is authority). Returns an error to fail fast,
  /// or null if the token passes the local gate.
  static ZennopayError? _preflight({
    required String intentId,
    required String sessionJwt,
  }) {
    final jwt = sessionJwt.trim();
    if (jwt.isEmpty) {
      return const ZennopayError(code: ZennopayErrorCode.invalidJwt);
    }
    final parts = jwt.split('.');
    if (parts.length != 3) {
      return const ZennopayError(code: ZennopayErrorCode.invalidJwt);
    }
    final claims = _decodeClaims(parts[1]);
    if (claims == null) {
      return const ZennopayError(code: ZennopayErrorCode.invalidJwt);
    }
    final boundIntent = claims['zennopay:intent_id'] ?? claims['intent_id'];
    if (boundIntent is String && boundIntent != intentId) {
      return const ZennopayError(code: ZennopayErrorCode.intentMismatch);
    }
    final exp = claims['exp'];
    if (exp is num) {
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
      if (DateTime.now()
          .isAfter(expiry.subtract(const Duration(seconds: 5)))) {
        // Expired/near-expiry before presenting → benign, but with no way to
        // refresh yet we surface it as a gate failure the host can re-mint on.
        return const ZennopayError(code: ZennopayErrorCode.jwtExpired);
      }
    }
    return null;
  }

  static Map<String, dynamic>? _decodeClaims(String segment) {
    try {
      final decoded = utf8.decode(base64Url.decode(base64Url.normalize(segment)));
      final v = jsonDecode(decoded);
      return v is Map ? v.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }
}
