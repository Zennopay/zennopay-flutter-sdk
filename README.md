# zennopay_flutter

The Flutter SDK for [Zennopay](https://zennopay.in) — let your app's users
scan local merchant QR codes abroad and pay from their wallet balance.

**This package is a native bridge.** One `await Zennopay.presentSheet(...)`
presents the **native** iOS/Android Zennopay PaymentSheet — the full pay
experience (QR scan → amount + FX quote → slide-to-pay → result) — and resolves
with a single `PaymentResult`. The sheet is rendered by the native Zennopay
SDKs, so Flutter partners get the exact same UI, animations, and platform
accessibility as every other Zennopay SDK. Nothing is re-implemented in Dart.

Full documentation: [Zennopay/zennopay-docs](https://github.com/Zennopay/zennopay-docs)

## Requirements

- Flutter 3.19+ / Dart 3.4+
- **iOS 16+** and **Android (minSdk 24)** targets
- A backend session endpoint that creates the payment intent and mints the
  short-lived session JWT (your API keys never ship in the app)

The native SDKs that render the sheet are declared as **transitive
dependencies** of this plugin — you do **not** add them by hand:

- iOS: the `Zennopay` CocoaPod, pulled in via the plugin's podspec
  (`pod install` resolves it).
- Android: `in.zennopay:sdk` from Maven Central, pulled in via the plugin's
  Gradle build.

## Installation

```yaml
# pubspec.yaml
dependencies:
  zennopay_flutter: ^0.4.0
```

> **Note:** if pub.dev hasn't propagated the release yet, use a git dependency:
>
> ```yaml
> dependencies:
>   zennopay_flutter:
>     git:
>       url: https://github.com/Zennopay/zennopay-flutter-sdk
>       ref: v0.4.0
> ```

### Platform setup

**iOS** — set the deployment target to **16.0** (or higher) in your
`ios/Podfile` (`platform :ios, '16.0'`), then add the camera usage string to
`ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Scan a merchant QR code to pay.</string>
```

Run `pod install` in `ios/` after adding the dependency.

**Android** — nothing to add: the plugin's manifest merges in the `CAMERA`
permission and the native SDK requests it at runtime, degrading to a paste-QR
field on denial. Your host `Activity` must be a `ComponentActivity`
(`FlutterActivity` already is).

## Quickstart

```dart
import 'package:zennopay_flutter/zennopay_flutter.dart';

Future<void> scanAndPay() async {
  // 1. Ask YOUR backend for a checkout session (intent + session JWT).
  final session = await walletApi.createCheckoutSession();

  // 2. Present the native PaymentSheet and await the terminal result.
  final result = await Zennopay.presentSheet(
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
      log('payment failed: ${error.code.wire}');
  }
}
```

No `BuildContext` is required: the native SDK presents over the top view
controller (iOS) / current `Activity` (Android). The native SDK validates the
session JWT's structure, expiry, and intent binding before showing any UI, and
confirms exactly once (the idempotency key is reused on retry). `Pending` means
status polling timed out before a terminal state — the payment may still settle,
so reconcile via your webhook or transaction history rather than assuming
failure.

### Reopening a receipt

`Zennopay.presentReceipt(...)` presents the **authoritative** native receipt for
a payment intent — the same receipt / pending / failure screens the sheet shows
at the end of a payment — so users can reopen "view receipt" from your history.
The native SDK fetches the receipt, polls a pending receipt through to a
terminal state, shows refund copy when the intent was refunded, and re-mints the
receipt token via `refreshReceiptToken` on a `401` mid-poll. The future
completes (with no value) once the user dismisses it.

```dart
Future<void> viewReceipt(String intentId) async {
  final receipt = await walletApi.mintReceiptToken(intentId);

  await Zennopay.presentReceipt(
    intentId: intentId,
    receiptToken: receipt.receiptToken,
    refreshReceiptToken: (intentId) async {
      // Called on receipt-token expiry (401 mid-poll): re-mint for the SAME
      // intent, or return null if you can't.
      final refreshed = await walletApi.mintReceiptToken(intentId);
      return refreshed.receiptToken;
    },
    config: ZennopayConfig.production,
  );
  // Completes when the user dismisses the receipt. It's read-only — there is no
  // PaymentResult to handle.
}
```

`presentReceipt` takes the same `ZennopayConfig` and `ZennopayAppearance` as
`presentSheet`; theming is applied identically by the native SDK.

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
);
```

`ZennopayAppearance` is serialized across the channel and applied by the native
SDK. Structural rules (radius cap ≤ 12px, accent-as-state, tabular-nums) are
enforced natively and are not overridable. Pass nothing
(`const ZennopayAppearance.automatic()`) for the default Zennopay look with
system light/dark. A partner `logo` set as an `AssetImage` is forwarded by name
and resolved best-effort by the native layer (ignored if it can't be resolved).

## Testing

On a simulator/emulator there is no usable camera — the native sheet falls back
to a paste-QR field; the backend does the authoritative parse.

## The channel contract

The plugin talks to the native SDKs over a single `MethodChannel`
(`zennopay_flutter`):

- **Dart → native `present`** — args `{ intentId, sessionJwt, config, appearance }`
  (structured maps), resolving once with a terminal result map
  `{ status, intentId, receipt?, error? }` that Dart decodes into a
  `PaymentResult`.
- **Dart → native `presentReceipt`** — args
  `{ intentId, receiptToken, config, appearance }` (structured maps), resolving
  with no value once the user dismisses the read-only native receipt.
- **native → Dart `refreshSession`** — arg `{ intentId }`, replying with a fresh
  session JWT string (or `null`). This services the `refreshSession` host hook
  without blocking the native SDK's async refresh.
- **native → Dart `refreshReceiptToken`** — arg `{ intentId }`, replying with a
  fresh receipt token string (or `null`). Services the `refreshReceiptToken`
  host hook when a pending receipt's token expires mid-poll.

The native SDKs map their richer, dotted error taxonomy
(e.g. `confirm.quote_expired`, `payment.declined`) onto the stable
`ZennopayErrorCode` wire codes before the error crosses the channel.

## Versioning

Zennopay SDKs follow [semver](https://semver.org). `v0.x` releases are
pre-GA: minor versions may contain breaking API changes, called out in the
[CHANGELOG](CHANGELOG.md). **0.4.0** adds `presentReceipt` (no breaking
changes); **0.3.0 was a breaking change** from the 0.2.x pure-Dart UI — see the
CHANGELOG for the migration notes.

All four Zennopay SDKs — [iOS](https://github.com/Zennopay/zennopay-ios-sdk),
[Android](https://github.com/Zennopay/zennopay-android-sdk), Flutter, and
[React Native](https://github.com/Zennopay/zennopay-react-native-sdk) — release
in lockstep: the same `vX.Y.Z` tag and GitHub Release is cut in each repo
per release. These standalone repos are release mirrors (squashed release
commits, not full development history).

## License

MIT — see [LICENSE](LICENSE).
