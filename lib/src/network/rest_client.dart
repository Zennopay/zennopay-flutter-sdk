import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/scan_models.dart';
import '../models/zennopay_config.dart';
import '../models/zennopay_error.dart';

/// Thin REST client over the SDK-facing contract
/// (`docs/sdk-rest-contract.md`). The session JWT is held in memory only and
/// sent as `Authorization: Bearer` on every call — never placed in a URL.
///
/// The client does not itself decide retry/refresh policy; it surfaces a typed
/// [ZennopayError] and lets the controller apply the taxonomy.
class ZennopayRestClient {
  ZennopayRestClient({
    required this.config,
    required this.intentId,
    required String sessionJwt,
    http.Client? httpClient,
  })  : _sessionJwt = sessionJwt,
        _http = httpClient ?? http.Client();

  final ZennopayConfig config;
  final String intentId;
  final http.Client _http;

  String _sessionJwt;

  /// Swap in a freshly minted session JWT (from `refreshSession`).
  void updateSessionJwt(String jwt) => _sessionJwt = jwt;

  Uri _uri(String suffix) =>
      Uri.parse('${config.apiBaseUrl}/v1/payment_intents/$intentId$suffix');

  Map<String, String> _headers({String? idempotencyKey}) => {
        'Authorization': 'Bearer $_sessionJwt',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
      };

  /// `POST /v1/payment_intents/{id}/scan` — jti is NOT consumed, so this may be
  /// re-run freely (e.g. silent re-quote on expiry).
  Future<ScanResult> scan({
    required String qrPayload,
    int? localAmountMinorUnits,
  }) async {
    final res = await _send(() => _http.post(
          _uri('/scan'),
          headers: _headers(),
          body: jsonEncode({
            'qr_payload': qrPayload,
            if (localAmountMinorUnits != null)
              'local_amount_minor_units': localAmountMinorUnits,
          }),
        ));
    return ScanResult.fromJson(_json(res));
  }

  /// `POST /v1/payment_intents/{id}/confirm` — consumes the jti (single-use).
  /// The [idempotencyKey] MUST be reused across retries.
  Future<PaymentIntentRecord> confirm({
    required String idempotencyKey,
    String? quoteId,
    int? quoteVersion,
  }) async {
    final res = await _send(() => _http.post(
          _uri('/confirm'),
          headers: _headers(idempotencyKey: idempotencyKey),
          body: jsonEncode({
            if (quoteId != null) 'quote_id': quoteId,
            if (quoteVersion != null) 'quote_version': quoteVersion,
          }),
        ));
    return PaymentIntentRecord.fromJson(_json(res));
  }

  /// `GET /v1/payment_intents/{id}` — poll until terminal (jti NOT consumed).
  Future<PaymentIntentRecord> status() async {
    final res = await _send(() => _http.get(_uri(''), headers: _headers()));
    return PaymentIntentRecord.fromJson(_json(res));
  }

  // --- internals -----------------------------------------------------------

  Future<http.Response> _send(Future<http.Response> Function() run) async {
    final http.Response res;
    try {
      res = await run();
    } catch (_) {
      throw const ZennopayError(code: ZennopayErrorCode.networkError);
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return res;
    throw _mapError(res);
  }

  Map<String, dynamic> _json(http.Response res) =>
      (jsonDecode(res.body) as Map).cast<String, dynamic>();

  ZennopayError _mapError(http.Response res) {
    String? wire;
    String? requestId;
    String? message;
    try {
      final err = (jsonDecode(res.body) as Map)['error'];
      if (err is Map) {
        wire = err['code'] as String?;
        requestId = err['request_id'] as String?;
        message = err['message'] as String?;
      }
    } catch (_) {/* non-JSON body */}

    // Map the wire code through the taxonomy; fall back on HTTP status.
    ZennopayErrorCode code;
    if (wire != null) {
      code = ZennopayErrorCode.fromWire(wire);
    } else if (res.statusCode >= 500) {
      code = ZennopayErrorCode.networkError;
    } else if (res.statusCode == 401) {
      code = ZennopayErrorCode.invalidJwt;
    } else {
      code = ZennopayErrorCode.networkError;
    }
    return ZennopayError(
      code: code,
      requestId: requestId,
      developerMessage: message,
    );
  }

  void close() => _http.close();
}
