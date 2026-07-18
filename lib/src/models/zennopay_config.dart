/// REST/environment configuration. The environment is **never** hardcoded — it
/// comes from here (spec §6). Defaults to staging.
class ZennopayConfig {
  const ZennopayConfig({
    required this.apiBaseUrl,
    required this.environment,
    this.statusPollTimeout = const Duration(seconds: 90),
    this.maxPollInterval = const Duration(seconds: 4),
    this.defaultQuoteTtl = const Duration(seconds: 30),
    this.locale,
  });

  final String apiBaseUrl;
  final ZennopayEnvironment environment;
  final Duration statusPollTimeout;
  final Duration maxPollInterval;
  final Duration defaultQuoteTtl;

  /// Optional locale pin (e.g. `en`, `hi`, `th`, `vi`). Device locale by default.
  final String? locale;

  /// `api.staging.zennopay.in` — the default.
  static const ZennopayConfig staging = ZennopayConfig(
    apiBaseUrl: 'https://api.staging.zennopay.in',
    environment: ZennopayEnvironment.staging,
  );

  static const ZennopayConfig production = ZennopayConfig(
    apiBaseUrl: 'https://api.zennopay.in',
    environment: ZennopayEnvironment.production,
  );

  factory ZennopayConfig.custom(String apiBaseUrl) => ZennopayConfig(
        apiBaseUrl: apiBaseUrl,
        environment: ZennopayEnvironment.custom,
      );

  /// Whether the sandbox ribbon should be shown (any non-production env).
  bool get showSandboxRibbon => environment != ZennopayEnvironment.production;

  /// Serialize for the native bridge. The native SDKs derive their REST base
  /// and sandbox chrome from `environment` + `apiBaseUrl`; the poll/quote
  /// timings are forwarded so all surfaces share one budget.
  Map<String, Object?> toMap() => {
        'environment': environment.name,
        'apiBaseUrl': apiBaseUrl,
        'statusPollTimeoutSeconds': statusPollTimeout.inSeconds,
        'maxPollIntervalSeconds': maxPollInterval.inSeconds,
        'defaultQuoteTtlSeconds': defaultQuoteTtl.inSeconds,
        if (locale != null) 'locale': locale,
      };
}

enum ZennopayEnvironment { staging, production, custom }
