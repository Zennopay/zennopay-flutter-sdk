# Changelog

## 0.6.1

Packaging polish (no API or behavior changes).

### Changed

- Shortened the `pubspec.yaml` `description` to fit pub.dev's 60–180 character
  guidance (it was truncated in search results before). Recovers the "Follow
  Dart file conventions" pub points.

## 0.6.0

Partner-facing environment names. The config presets now match the docs and API
reference: **sandbox** and **production**.

### Added

- `ZennopayConfig.sandbox` — `https://api.sandbox.zennopay.in`, the environment
  partners integrate and test against. Now the default for `presentSheet` /
  `presentReceipt`.
- `ZennopayEnvironment.sandbox`.

### Changed

- `presentSheet` / `presentReceipt` default `config:` is now
  `ZennopayConfig.sandbox` (was `.staging`). Same behavior, partner-facing name.
- Native dependency bumped to `Zennopay ~> 0.6.0` (iOS). The Android native
  dependency stays at `in.zennopay:sdk:0.5.0` until `0.6.0` propagates to Maven
  Central; the Dart config passes `apiBaseUrl` explicitly, so the sandbox host
  is used regardless of the native default.

### Deprecated

- `ZennopayConfig.staging` and `ZennopayEnvironment.staging` are deprecated
  (`@Deprecated('Use ...sandbox')`) and are now compatibility aliases for the
  sandbox equivalents — `staging` points at `https://api.sandbox.zennopay.in`
  (previously `https://api.staging.zennopay.in`). Existing code keeps compiling;
  migrate to `sandbox`.

## 0.5.0

Version-aligned across all Zennopay SDKs (iOS/Android/Flutter) at 0.5.0. API
domain default migrated to `zennopay.in` (canonical) in the
`ZennopayConfig.staging` / `ZennopayConfig.production` base URLs. No API changes.
Native dependencies stay at `Zennopay ~> 0.3.0` (iOS) / `in.zennopay:sdk:0.3.0`
(Android) — those releases remain valid.

## 0.4.0

**New: `Zennopay.presentReceipt(...)` — reopen the authoritative receipt.** A
second entrypoint that presents the **native** iOS/Android Zennopay receipt for
a payment intent and completes (`Future<void>`) when the user dismisses it. The
native SDK fetches the receipt, renders the native receipt / pending / failure
screens, polls a pending receipt through to a terminal state, shows refund copy
when the intent was refunded, and — on a `401` mid-poll — asks the host to
re-mint the receipt token. Nothing is re-implemented in Dart; this mirrors
`presentSheet` as a thin bridge.

```dart
await Zennopay.presentReceipt(
  intentId: intentId,
  receiptToken: receiptToken,
  refreshReceiptToken: (intentId) => walletApi.refreshReceiptToken(intentId),
  config: ZennopayConfig.production,
);
```

- Dart API:
  `presentReceipt({required String intentId, required String receiptToken,
  ZennopayConfig? config, ZennopayAppearance? appearance,
  Future<String?> Function(String intentId)? refreshReceiptToken})`.
- New channel method `presentReceipt` + a native→Dart `refreshReceiptToken`
  callback round-trip (reusing the mechanism `refreshSession` uses).
- Native SDK dependency bump: iOS `Zennopay ~> 0.3.0`, Android
  `in.zennopay:sdk:0.3.0` — the releases that expose `presentReceipt`.

No changes to `presentSheet` or any existing public type.

## 0.3.0

**BREAKING — `zennopay_flutter` is now a native bridge.** The package no longer
ships its own pure-Dart PaymentSheet. `Zennopay.presentSheet(...)` now presents
the **native** iOS/Android Zennopay PaymentSheet — the exact same accessible
scan → amount → confirm → status flow as every other Zennopay SDK — over a
platform channel. Flutter partners get full native parity and accessibility for
free; there is no longer a separate Dart UI to keep in lockstep.

Converted to a proper Flutter **plugin** (`in.zennopay.flutter` /
`ZennopayFlutterPlugin`) that declares the native SDKs as transitive
dependencies — partners do not add them by hand:

- iOS: the `Zennopay` CocoaPod (via `s.dependency "Zennopay"`), iOS 16+.
- Android: `in.zennopay:sdk:0.2.1` from Maven Central.

### Breaking changes

- `presentSheet` signature: **removed** `context`, `navigatorKey`, and
  `onEvent`. New shape:
  `presentSheet({required String intentId, required String sessionJwt,
  ZennopayConfig? config, ZennopayAppearance? appearance,
  Future<String?> Function(String intentId)? refreshSession})`. The native SDK
  presents over the top view controller / current Activity, so no Flutter
  `BuildContext` is needed.
- **Removed** the display-only public models (`Merchant`, `Quote`, `ScanResult`,
  `PaymentIntentRecord`, `QrKind`) and the reusable EMVCo parser (`EmvCoParser`,
  `Tlv`) — the native SDK owns all scanning, networking, and EMVCo decoding.
- `Receipt` fields are now all nullable. The native SDKs are the source of truth
  for receipt data; iOS currently returns a bare completed result with no line
  items (so `receipt` is `null` on iOS), while Android populates the merchant +
  amount fields. `localAmountMinorUnits` / `amountUsdCents` are derived from the
  native display amounts.
- The Dart-only deps (`http`, `mobile_scanner`) are gone; the sheet's camera,
  REST, polling, retries, and slide-to-pay physics all live in the native SDK.

### Kept (stable public API)

- `Zennopay.presentSheet(...) → Future<PaymentResult>`.
- The `PaymentResult` sealed hierarchy (`Completed` / `Canceled` / `Failed` /
  `Pending`) + `Receipt`.
- `ZennopayError` + `ZennopayErrorCode` (the native dotted taxonomy is mapped to
  these stable wire codes natively before crossing the channel).
- `ZennopayConfig` (`staging` / `production` / `custom`) and the full
  `ZennopayAppearance` theming surface (colors, radii ≤ 12px, font,
  primaryButton, mode, logo) — serialized across the channel and applied by the
  native SDK.

## 0.2.0

First public release, version-locked with the native Zennopay SDKs
(iOS / Android v0.2.0 — the PaymentSheet release).

- Package metadata now points at the public
  [zennopay-flutter](https://github.com/Zennopay/zennopay-flutter-sdk) repository.
- Generic host-app wording in user-facing error copy.
- No API changes from 0.1.0.

## 0.1.0

Initial release of the Zennopay PaymentSheet for Flutter.

- `Zennopay.presentSheet(...)` — single entrypoint returning a
  `Future<PaymentResult>` (`Completed` / `Canceled` / `Failed` / `Pending`).
- Three-screen flow rendered natively in Dart: Scanner (camera via
  `mobile_scanner`, with torch / gallery / paste fallbacks), Amount (live
  USD-equivalent, static-QR numeric entry, silent quote re-fetch, VND
  per-transaction cap pre-check), and Confirm + Status (mass-spring
  slide-to-pay, processing, and success / failed / pending terminals).
- `ZennopayAppearance` theming (colors, radii ≤ 12px, font, logo, light/dark)
  defaulting to the `DESIGN.md` "solid as a real bank" tokens.
- REST client for `POST /v1/payment_intents/{id}/scan|confirm` and
  `GET /v1/payment_intents/{id}`, session-JWT `Authorization: Bearer`, on-device
  fail-fast JWT gate, `refreshSession` hook, reused idempotency key on retry,
  and the shared error taxonomy.
- SANDBOX ribbon on non-production environments; privacy-safe `onEvent`
  analytics stream.
- Ships a display-only EMVCo TLV parser for instant scan previews (the
  backend re-parses authoritatively).
