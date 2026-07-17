import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/payment_result.dart';
import '../models/scan_models.dart';
import '../models/zennopay_config.dart';
import '../models/zennopay_error.dart';
import '../network/rest_client.dart';

/// Coarse screen the sheet is showing (spec §1).
enum CheckoutScreen { scanner, amount, confirmStatus }

/// Fine-grained state within the flow (mirrors `docs/sdk-state-machine.md`).
enum CheckoutState {
  scanning,
  quoting,
  amountEntry,
  confirming,
  polling,
  resultSuccess,
  resultFailed,
  resultPending,
}

/// The VND disbursement caps, enforced authoritatively by the backend. VND
/// has no minor unit, so minor units == the VND amount.
class VndLimits {
  static const int perTransaction = 5000000; // 5,000,000 ₫
  static const int perDay = 10000000; // 10,000,000 ₫
  static const int perMonth = 25000000; // 25,000,000 ₫
  static const String vndCurrency = '704';
}

/// Drives the scan → amount → confirm → status state machine and owns the REST
/// calls, silent re-quote, idempotency key, and terminal result. UI widgets
/// observe it via [ChangeNotifier].
class CheckoutController extends ChangeNotifier {
  CheckoutController({
    required this.intentId,
    required this.config,
    required ZennopayRestClient client,
    this.refreshSession,
    this.onEvent,
  }) : _client = client {
    _idempotencyKey = _newIdempotencyKey();
  }

  final String intentId;
  final ZennopayConfig config;
  final ZennopayRestClient _client;
  final Future<String?> Function(String intentId)? refreshSession;
  final void Function(String event, Map<String, Object?> props)? onEvent;

  CheckoutScreen screen = CheckoutScreen.scanner;
  CheckoutState state = CheckoutState.scanning;

  ScanResult? scan;
  PaymentIntentRecord? terminal;
  ZennopayError? error;

  /// The user-entered local amount for a static QR (minor units).
  int? enteredAmountMinorUnits;

  late String _idempotencyKey;
  bool _confirmStarted = false;
  Timer? _requoteTimer;
  bool _disposed = false;

  final Completer<PaymentResult> _completer = Completer<PaymentResult>();

  /// Resolves once with the terminal [PaymentResult].
  Future<PaymentResult> get result => _completer.future;

  Merchant? get merchant => scan?.merchant;
  Quote? get quote => scan?.quote;
  QrKind? get qrKind => scan?.qrKind;

  bool get isVnd => quote?.localCurrency == VndLimits.vndCurrency;

  /// The amount (minor units) the confirm will move: entered (static) or the
  /// quote-bound value (dynamic).
  int get effectiveLocalAmount =>
      enteredAmountMinorUnits ?? quote?.localAmountMinorUnits ?? 0;

  // --- Scanner -------------------------------------------------------------

  /// Submit the raw on-device-decoded EMVCo payload to `/scan`.
  Future<void> submitScannedPayload(
    String rawPayload, {
    int? localAmountMinorUnits,
  }) async {
    if (state == CheckoutState.quoting) return;
    _set(state: CheckoutState.quoting);
    _emit('qr_decoded', {'corridor_hint': null});
    await _runScan(rawPayload, localAmountMinorUnits: localAmountMinorUnits);
  }

  Future<void> _runScan(String rawPayload, {int? localAmountMinorUnits}) async {
    try {
      final res = await _guarded(() => _client.scan(
            qrPayload: rawPayload,
            localAmountMinorUnits: localAmountMinorUnits,
          ));
      scan = res;
      error = null;
      _emit('scan_validated', {
        'corridor': res.merchant.country,
        'qr_kind': res.qrKind.isStatic ? 'static' : 'dynamic',
        'scheme': res.merchant.scheme,
      });
      _lastPayload = rawPayload;
      _set(screen: CheckoutScreen.amount, state: CheckoutState.amountEntry);
      _scheduleReQuote();
    } on ZennopayError catch (e) {
      _emit('scan_rejected', {'error_code': e.code.wire});
      error = e;
      _set(screen: CheckoutScreen.scanner, state: CheckoutState.scanning);
    }
  }

  String? _lastPayload;

  // --- Amount --------------------------------------------------------------

  void setEnteredAmount(int minorUnits) {
    enteredAmountMinorUnits = minorUnits;
    notifyListeners();
  }

  /// Client-side per-transaction VND cap pre-check (static QR fast-path).
  bool get exceedsPerTransactionLimit =>
      isVnd &&
      qrKind == QrKind.static_ &&
      effectiveLocalAmount > VndLimits.perTransaction;

  bool get canSlideToPay {
    if (scan == null) return false;
    if (effectiveLocalAmount <= 0) return false;
    if (exceedsPerTransactionLimit) return false;
    return state == CheckoutState.amountEntry;
  }

  /// Silent re-quote: `/scan` does not burn the jti, so on quote expiry we
  /// re-run it and update the USD-equivalent in place — no banner (spec §1.2).
  void _scheduleReQuote() {
    _requoteTimer?.cancel();
    final q = quote;
    if (q == null || _lastPayload == null) return;
    final ms = q.expiresAt - DateTime.now().millisecondsSinceEpoch;
    final delay = Duration(milliseconds: max(ms, 1000));
    _requoteTimer = Timer(delay, () async {
      if (_disposed || state != CheckoutState.amountEntry) return;
      try {
        final res = await _client.scan(
          qrPayload: _lastPayload!,
          localAmountMinorUnits: qrKind == QrKind.static_
              ? enteredAmountMinorUnits
              : null,
        );
        final material =
            res.quote.localAmountMinorUnits != quote?.localAmountMinorUnits ||
                res.quote.amountUsdCents != quote?.amountUsdCents;
        scan = res;
        _emit('quote_refreshed', {'material_change': material});
        notifyListeners();
        _scheduleReQuote();
      } on ZennopayError {
        // Keep the stale quote; confirm will re-validate server-side.
      }
    });
  }

  // --- Confirm + Status ----------------------------------------------------

  /// Fired exactly once when slide-to-pay crosses the threshold.
  Future<void> commitSlideToPay() async {
    if (_confirmStarted) return;
    _confirmStarted = true;
    _requoteTimer?.cancel();
    _emit('slide_committed', const {});
    _set(screen: CheckoutScreen.confirmStatus, state: CheckoutState.confirming);
    await _confirm();
  }

  Future<void> _confirm() async {
    try {
      final rec = await _guarded(() => _client.confirm(
            idempotencyKey: _idempotencyKey,
            quoteId: quote?.quoteId,
            quoteVersion: quote?.quoteVersion,
          ));
      _handleIntentRecord(rec);
    } on ZennopayError catch (e) {
      // On a network error mid-confirm the debit may have landed — recover via
      // GET before assuming failure.
      if (e.code == ZennopayErrorCode.networkError) {
        await _pollOnce();
        if (state == CheckoutState.confirming) {
          _fail(e);
        }
      } else if (e.code == ZennopayErrorCode.jtiReplay) {
        // Confirm already ran once: learn the true terminal status.
        await _pollOnce();
      } else {
        _fail(e);
      }
    }
  }

  void _handleIntentRecord(PaymentIntentRecord rec) {
    terminal = rec;
    if (rec.isCaptured) {
      _emit('confirm_result', {'status': 'captured'});
      _succeed(rec);
    } else if (rec.isFailed) {
      _emit('confirm_result', {'status': 'failed', 'error_code': rec.limitReason});
      _fail(ZennopayError(
        code: rec.limitReason != null
            ? ZennopayErrorCode.limitExceeded
            : ZennopayErrorCode.confirmFailed,
        developerMessage: rec.limitReason,
      ));
    } else {
      _startPolling();
    }
  }

  void _startPolling() {
    _set(state: CheckoutState.polling);
    _pollLoop();
  }

  Future<void> _pollLoop() async {
    final deadline = DateTime.now().add(config.statusPollTimeout);
    var interval = const Duration(seconds: 1);
    while (!_disposed && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(interval);
      if (_disposed) return;
      try {
        final rec = await _client.status();
        terminal = rec;
        if (rec.isCaptured) {
          _emit('confirm_result', {'status': 'captured'});
          _succeed(rec);
          return;
        }
        if (rec.isFailed) {
          _emit('confirm_result', {'status': 'failed'});
          _fail(const ZennopayError(code: ZennopayErrorCode.confirmFailed));
          return;
        }
      } on ZennopayError {
        // transient; keep polling within the deadline
      }
      interval = Duration(
        seconds: min(interval.inSeconds + 1, config.maxPollInterval.inSeconds),
      );
    }
    // Hard timeout → soft-terminal pending.
    _emit('confirm_result', {'status': 'pending'});
    _pending(terminal);
  }

  Future<void> _pollOnce() async {
    try {
      final rec = await _client.status();
      _handleIntentRecord(rec);
    } on ZennopayError {
      // leave state as-is; caller decides
    }
  }

  /// Retry after `result.failed` — re-enters confirm with the SAME idempotency
  /// key (never mint a new one; spec §1.3 retry semantics).
  Future<void> retryConfirm() async {
    if (state != CheckoutState.resultFailed) return;
    error = null;
    _set(screen: CheckoutScreen.confirmStatus, state: CheckoutState.confirming);
    await _confirm();
  }

  // --- Cancel / terminal delivery -----------------------------------------

  /// Cancel is only allowed pre-confirm (spec §1.3 / cancelability matrix).
  bool get isCancelable =>
      state == CheckoutState.scanning ||
      state == CheckoutState.quoting ||
      state == CheckoutState.amountEntry;

  void cancel() {
    if (!isCancelable) return;
    _emit('sheet_dismissed', {'result': 'canceled'});
    _deliver(Canceled(intentId));
  }

  void _succeed(PaymentIntentRecord rec) {
    _set(screen: CheckoutScreen.confirmStatus, state: CheckoutState.resultSuccess);
    _emit('sheet_dismissed', {'result': 'completed'});
  }

  void _fail(ZennopayError e) {
    error = e;
    _set(screen: CheckoutScreen.confirmStatus, state: CheckoutState.resultFailed);
  }

  void _pending(PaymentIntentRecord? rec) {
    _set(screen: CheckoutScreen.confirmStatus, state: CheckoutState.resultPending);
    _emit('sheet_dismissed', {'result': 'pending'});
  }

  /// Called by the terminal screen's primary "Done" button.
  void finish() {
    switch (state) {
      case CheckoutState.resultSuccess:
        _deliver(Completed(intentId, receipt: _receipt()));
      case CheckoutState.resultPending:
        _deliver(Pending(intentId, receipt: _receipt(pending: true)));
      case CheckoutState.resultFailed:
        _deliver(Failed(intentId,
            error ?? const ZennopayError(code: ZennopayErrorCode.confirmFailed)));
      default:
        break;
    }
  }

  Receipt? _receipt({bool pending = false}) {
    final rec = terminal;
    final q = quote;
    if (rec == null && q == null) return null;
    return Receipt(
      merchantName: rec?.merchantName ?? merchant?.name,
      localAmountMinorUnits:
          rec?.localAmountMinorUnits ?? effectiveLocalAmount,
      localCurrency: rec?.localCurrency ?? q?.localCurrency ?? '',
      amountUsdCents: rec?.amountUsdCents ?? q?.amountUsdCents ?? 0,
      transactionId: rec?.transactionId,
      verifiableQrData: rec?.verifiableQrData,
      pending: pending,
    );
  }

  void _deliver(PaymentResult result) {
    if (!_completer.isCompleted) _completer.complete(result);
  }

  // --- helpers -------------------------------------------------------------

  /// Runs a REST op; on `jwt_expired` invokes `refreshSession` once and retries.
  Future<T> _guarded<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on ZennopayError catch (e) {
      if (e.triggersRefresh && refreshSession != null) {
        _emit('session_refreshed', const {'success': false});
        final fresh = await refreshSession!(intentId);
        if (fresh != null) {
          _client.updateSessionJwt(fresh);
          _emit('session_refreshed', const {'success': true});
          return await op();
        }
      }
      rethrow;
    }
  }

  void _set({CheckoutScreen? screen, CheckoutState? state}) {
    if (screen != null) this.screen = screen;
    if (state != null) this.state = state;
    notifyListeners();
  }

  void _emit(String event, Map<String, Object?> props) {
    onEvent?.call(event, {'intent_id': intentId, ...props});
  }

  String _newIdempotencyKey() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  void dispose() {
    _disposed = true;
    _requoteTimer?.cancel();
    _client.close();
    if (!_completer.isCompleted) _completer.complete(Canceled(intentId));
    super.dispose();
  }
}
