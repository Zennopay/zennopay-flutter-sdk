import 'package:flutter_test/flutter_test.dart';
import 'package:zennopay_flutter/zennopay_flutter.dart';

void main() {
  group('ZennopayConfig host resolution (spec §6)', () {
    test('sandbox targets the sandbox gateway', () {
      expect(
        ZennopayConfig.sandbox.apiBaseUrl,
        'https://api.sandbox.zennopay.in',
      );
      expect(ZennopayConfig.sandbox.environment, ZennopayEnvironment.sandbox);
    });

    test('production targets the live gateway', () {
      expect(ZennopayConfig.production.apiBaseUrl, 'https://api.zennopay.in');
      expect(
        ZennopayConfig.production.environment,
        ZennopayEnvironment.production,
      );
    });

    test('staging is a deprecated alias that resolves to sandbox', () {
      // ignore: deprecated_member_use_from_same_package
      expect(
        ZennopayConfig.staging.apiBaseUrl,
        ZennopayConfig.sandbox.apiBaseUrl,
      );
    });

    test('custom preserves the given base url', () {
      final config = ZennopayConfig.custom('https://api.example.test');
      expect(config.apiBaseUrl, 'https://api.example.test');
      expect(config.environment, ZennopayEnvironment.custom);
    });

    test('showSandboxRibbon is off only in production', () {
      expect(ZennopayConfig.sandbox.showSandboxRibbon, isTrue);
      expect(ZennopayConfig.custom('x').showSandboxRibbon, isTrue);
      expect(ZennopayConfig.production.showSandboxRibbon, isFalse);
    });
  });

  group('ZennopayConfig.toMap', () {
    test('serializes environment, base url and poll/quote timings', () {
      final map = ZennopayConfig.production.toMap();
      expect(map['environment'], 'production');
      expect(map['apiBaseUrl'], 'https://api.zennopay.in');
      expect(map['statusPollTimeoutSeconds'], 90);
      expect(map['maxPollIntervalSeconds'], 4);
      expect(map['defaultQuoteTtlSeconds'], 30);
      expect(map.containsKey('locale'), isFalse);
    });

    test('includes locale only when pinned', () {
      const config = ZennopayConfig(
        apiBaseUrl: 'https://api.zennopay.in',
        environment: ZennopayEnvironment.production,
        locale: 'th',
      );
      expect(config.toMap()['locale'], 'th');
    });
  });
}
