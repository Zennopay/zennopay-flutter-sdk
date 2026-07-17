# zennopay_flutter

The Flutter SDK for [Zennopay](https://zennopay.com) — let your app's users
scan local merchant QR codes abroad and pay from their wallet balance.

One `await Zennopay.presentSheet(...)` presents the **PaymentSheet** — the
full pay experience (QR scan → amount + FX quote → slide-to-pay → result) —
and resolves with a single `PaymentResult`. The flow renders natively in
Dart; your app never leaves the foreground.

Full documentation: [Zennopay/zennopay-docs](https://github.com/Zennopay/zennopay-docs)

## Requirements

- Flutter 3.19+ / Dart 3.4+
- iOS and Android targets (the sheet uses the device camera via
  `mobile_scanner`)
- A backend session endpoint that creates the payment intent and mints the
  short-lived session JWT (your API keys never ship in the app)

## Installation

```yaml
# pubspec.yaml
dependencies:
  zennopay_flutter: ^0.2.0
```

> **Note:** publication to pub.dev is pending. Until then, use a git
> dependency:
>
> ```yaml
> dependencies:
>   zennopay_flutter:
>     git:
>       url: https://github.com/Zennopay/zennopay-flutter
>       ref: v0.2.0
> ```

### Platform setup

**iOS** — add the camera usage string to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Scan a merchant QR code to pay.</string>
```

**Android** — nothing to add: the plugin's manifest merges in the `CAMERA`
permission. On denial (or no camera), the sheet falls back to a paste-QR
field on both platforms.

## Quickstart

```dart
import 'package:flutter/material.dart';
import 'package:zennopay_flutter/zennopay_flutter.dart';

Future<void> scanAndPay(BuildContext context) async {
  // 1. Ask YOUR backend for a checkout session (intent + session JWT).
  final session = await walletApi.createCheckoutSession();

  // 2. Present the PaymentSheet and await the terminal result.
  final result = await Zennopay.presentSheet(
    context: context,
    intentId: session.intentId,
    sessionJwt: session.sessionJwt,
    refreshSession: (intentId) async {
      // Called on session expiry (401): re-mint for the SAME intent,
      // or return null if you can't.
      final refreshed = await walletApi.refreshSession(intentId);
      return refreshed?.sessionJwt;
    },
    config: ZennopayConfig.staging, // ZennopayConfig.production for live
  );

  // 3. One terminal case, exhaustively.
  switch (result) {
    case Completed(:final receipt):
      showReceipt(receipt); // money moved — debit your ledger
    case Pending():
      showPending(); // may still settle — reconcile via webhook/history
    case Canceled():
      break; // user backed out; no money moved
    case Failed(:final error):
      log('payment failed: ${error.code}');
  }
}
```

To present without a `BuildContext` (e.g. from a service layer), install the
SDK's navigator key on your `MaterialApp` —
`MaterialApp(navigatorKey: Zennopay.navigatorKey, ...)` — and omit
`context:`.

The SDK validates the session JWT's structure, expiry, and intent binding
before showing any UI; slide-to-pay confirms exactly once (the idempotency
key is reused on retry). `Pending` means status polling timed out before a
terminal state — the payment may still settle, so reconcile via your webhook
or transaction history rather than assuming failure.

### Theming

```dart
final appearance = ZennopayAppearance(
  mode: ThemeMode.system,
  colors: const ZennopayColors(
    primary: Color(0xFF1B4FD8),
    primaryDark: Color(0xFF6E8EF5),
  ),
  primaryButton: const ZennopayPrimaryButton(
    background: Color(0xFF1B4FD8),
    cornerRadius: 10,
  ),
  logo: const AssetImage('assets/wordmark.png'),
);
```

Pass nothing (`const ZennopayAppearance.automatic()`) for the default
Zennopay look with system light/dark.

### Analytics hook

`presentSheet` accepts an optional `onEvent` callback with a small,
privacy-safe event stream (`sheet_presented`, `scan_validated`,
`slide_committed`, `confirm_result`, …):

```dart
onEvent: (event, props) => analytics.track('zennopay_$event', props),
```

## Testing

On a simulator/emulator there is no usable camera — use the sheet's paste-QR
fallback with any VietQR payload string; the backend does the authoritative
parse.

## Versioning

Zennopay SDKs follow [semver](https://semver.org). `v0.x` releases are
pre-GA: minor versions may contain breaking API changes, called out in the
[CHANGELOG](CHANGELOG.md).

All four Zennopay SDKs — [iOS](https://github.com/Zennopay/zennopay-ios-sdk),
[Android](https://github.com/Zennopay/zennopay-android-sdk), Flutter, and
[React Native](https://github.com/Zennopay/zennopay-react-native) — release
in lockstep: the same `vX.Y.Z` tag and GitHub Release is cut in each repo
per release. These standalone repos are release mirrors (squashed release
commits, not full development history).

## License

MIT — see [LICENSE](LICENSE).
