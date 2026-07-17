# Changelog

## 0.2.0

First public release, version-locked with the native Zennopay SDKs
(iOS / Android v0.2.0 — the PaymentSheet release).

- Package metadata now points at the public
  [zennopay-flutter](https://github.com/Zennopay/zennopay-flutter) repository.
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
