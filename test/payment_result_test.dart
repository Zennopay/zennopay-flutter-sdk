import 'package:flutter_test/flutter_test.dart';
import 'package:zennopay_flutter/zennopay_flutter.dart';

void main() {
  group('PaymentResult.fromMap', () {
    test('completed with a THB receipt scales to minor units (satang)', () {
      final result = PaymentResult.fromMap('zp_1', {
        'status': 'completed',
        'intentId': 'zp_override',
        'receipt': {
          'merchantName': 'Somtum Der',
          'localAmount': '120.50',
          'localCurrency': 'THB',
          'usdDebited': '3.48',
          'transactionId': 'txn_9',
        },
      });
      expect(result, isA<Completed>());
      // The intentId in the map wins over the fallback argument.
      expect(result.intentId, 'zp_override');
      final receipt = (result as Completed).receipt!;
      expect(receipt.localAmountMinorUnits, 12050);
      expect(receipt.amountUsdCents, 348);
      expect(receipt.localCurrency, 'THB');
      expect(receipt.merchantName, 'Somtum Der');
    });

    test('VND is zero-decimal and tolerates grouping separators', () {
      final result = PaymentResult.fromMap('zp_2', {
        'status': 'completed',
        'receipt': {
          'localAmount': '85,000',
          'localCurrency': 'VND',
        },
      });
      // No intentId in the map -> falls back to the argument.
      expect(result.intentId, 'zp_2');
      final receipt = (result as Completed).receipt!;
      expect(receipt.localAmountMinorUnits, 85000);
    });

    test('pending marks the receipt pending and stays a Pending result', () {
      final result = PaymentResult.fromMap('zp_3', {
        'status': 'pending',
        'receipt': {'localAmount': '1.00', 'localCurrency': 'THB'},
      });
      expect(result, isA<Pending>());
      expect((result as Pending).receipt!.pending, isTrue);
    });

    test('canceled carries the intent id and no receipt', () {
      final result = PaymentResult.fromMap('zp_4', {'status': 'canceled'});
      expect(result, isA<Canceled>());
      expect(result.intentId, 'zp_4');
    });

    test('unknown or missing status falls back to failed with error', () {
      final result = PaymentResult.fromMap('zp_5', {
        'status': 'weird',
        'error': {'code': 'quote_expired'},
      });
      expect(result, isA<Failed>());
      expect((result as Failed).error.code, ZennopayErrorCode.quoteExpired);
    });

    test('empty receipt map yields a null receipt (iOS bare completed)', () {
      final result = PaymentResult.fromMap('zp_6', {
        'status': 'completed',
        'receipt': <Object?, Object?>{},
      });
      expect((result as Completed).receipt, isNull);
    });
  });
}
