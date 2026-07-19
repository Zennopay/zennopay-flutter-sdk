import 'package:flutter_test/flutter_test.dart';
import 'package:zennopay_flutter/zennopay_flutter.dart';

void main() {
  group('ZennopayErrorCode.fromWire', () {
    test('maps known wire codes to their enum case', () {
      expect(
        ZennopayErrorCode.fromWire('quote_expired'),
        ZennopayErrorCode.quoteExpired,
      );
      expect(
        ZennopayErrorCode.fromWire('jwt_expired'),
        ZennopayErrorCode.jwtExpired,
      );
    });

    test('unknown or null wire codes fall back to networkError', () {
      expect(
        ZennopayErrorCode.fromWire('not_a_real_code'),
        ZennopayErrorCode.networkError,
      );
      expect(ZennopayErrorCode.fromWire(null), ZennopayErrorCode.networkError);
    });
  });

  group('ZennopayError', () {
    test('fromMap decodes code, requestId and developer message', () {
      final error = ZennopayError.fromMap({
        'code': 'limit_exceeded',
        'requestId': 'req_42',
        'message': 'over VN limit',
      });
      expect(error.code, ZennopayErrorCode.limitExceeded);
      expect(error.requestId, 'req_42');
      expect(error.developerMessage, 'over VN limit');
    });

    test('a null map decodes to a network error', () {
      expect(ZennopayError.fromMap(null).code, ZennopayErrorCode.networkError);
    });

    test('only jwt_expired triggers a session refresh', () {
      const expired = ZennopayError(code: ZennopayErrorCode.jwtExpired);
      const invalid = ZennopayError(code: ZennopayErrorCode.invalidJwt);
      expect(expired.triggersRefresh, isTrue);
      expect(invalid.triggersRefresh, isFalse);
    });

    test('retryable classification matches the taxonomy', () {
      const network = ZennopayError(code: ZennopayErrorCode.networkError);
      const replay = ZennopayError(code: ZennopayErrorCode.jtiReplay);
      expect(network.isRetryable, isTrue);
      expect(replay.isRetryable, isFalse);
    });

    test('canceled has empty user copy; others render plain-English copy', () {
      const canceled = ZennopayError(code: ZennopayErrorCode.canceled);
      const network = ZennopayError(code: ZennopayErrorCode.networkError);
      expect(canceled.userMessage, isEmpty);
      expect(network.userMessage, 'Network issue. Try again.');
    });
  });
}
