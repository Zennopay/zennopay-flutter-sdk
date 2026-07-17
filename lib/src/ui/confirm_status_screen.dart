import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'checkout_controller.dart';
import 'currency.dart';
import 'design_tokens.dart';
import 'widgets.dart';

/// Screen 3 — Confirm + Status (spec §1.3). The processing → terminal surface.
/// No Cancel while money is in flight (`confirming`/`polling`).
class ConfirmStatusScreen extends StatelessWidget {
  const ConfirmStatusScreen({
    super.key,
    required this.controller,
    required this.tokens,
  });

  final CheckoutController controller;
  final ZennoTokens tokens;

  @override
  Widget build(BuildContext context) {
    return switch (controller.state) {
      CheckoutState.confirming ||
      CheckoutState.polling =>
        _Processing(tokens: tokens, state: controller.state),
      CheckoutState.resultSuccess => _Success(controller: controller, tokens: tokens),
      CheckoutState.resultFailed => _FailedView(controller: controller, tokens: tokens),
      CheckoutState.resultPending => _PendingView(controller: controller, tokens: tokens),
      _ => const SizedBox.shrink(),
    };
  }
}

class _Processing extends StatelessWidget {
  const _Processing({required this.tokens, required this.state});

  final ZennoTokens tokens;
  final CheckoutState state;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final polling = state == CheckoutState.polling;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
                strokeWidth: 3, color: t.primary),
          ),
          const SizedBox(height: 20),
          Text(
            polling ? 'Processing your payment' : 'Processing payment…',
            style: t.text(size: 18, weight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            polling
                ? 'This usually takes under 10 seconds.'
                : "Your wallet hasn't been charged yet.",
            textAlign: TextAlign.center,
            style: t.text(size: 14, color: t.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Success extends StatelessWidget {
  const _Success({required this.controller, required this.tokens});

  final CheckoutController controller;
  final ZennoTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final rec = controller.terminal;
    final q = controller.quote;
    final ccy = rec?.localCurrency ?? q?.localCurrency ?? '';
    final local = rec?.localAmountMinorUnits ?? controller.effectiveLocalAmount;
    final usd = rec?.amountUsdCents ?? q?.amountUsdCents ?? 0;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: t.success, shape: BoxShape.circle),
            child: const Icon(Icons.check, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 20),
          Text('${Currency.format(local, ccy)} paid',
              style: t.text(size: 34, weight: FontWeight.w700, tabular: true)),
          const SizedBox(height: 10),
          if (rec?.merchantName != null)
            Text(rec!.merchantName!,
                style: t.text(size: 15, color: t.textSecondary)),
          const SizedBox(height: 4),
          Text('${Currency.usd(usd)} USD debited',
              style: t.text(size: 14, color: t.textSecondary, tabular: true)),
          if (rec?.transactionId != null) ...[
            const SizedBox(height: 8),
            _CopyableTxn(tokens: t, txnId: rec!.transactionId!),
          ],
          if (rec?.verifiableQrData != null) ...[
            const SizedBox(height: 8),
            Text('Verifiable receipt attached',
                style: t.text(size: 12, color: t.textTertiary)),
          ],
          const Spacer(),
          PrimaryButton(
            tokens: t,
            label: 'Done',
            enabled: true,
            onPressed: controller.finish,
          ),
        ],
      ),
    );
  }
}

class _CopyableTxn extends StatelessWidget {
  const _CopyableTxn({required this.tokens, required this.txnId});

  final ZennoTokens tokens;
  final String txnId;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return TextButton.icon(
      onPressed: () => Clipboard.setData(ClipboardData(text: txnId)),
      icon: Icon(Icons.copy, size: 14, color: t.textTertiary),
      label: Text(txnId,
          style: t.text(size: 12, color: t.textTertiary, tabular: true)),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.controller, required this.tokens});

  final CheckoutController controller;
  final ZennoTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final message = controller.error?.userMessage ??
        "Payment didn't go through. Your wallet was not charged.";
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: t.failureSoft, shape: BoxShape.circle),
            child: Icon(Icons.priority_high, color: t.failure, size: 30),
          ),
          const SizedBox(height: 20),
          Text("Payment didn't go through",
              style: t.text(size: 22, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: t.text(size: 14, color: t.textSecondary)),
          const Spacer(),
          PrimaryButton(
            tokens: t,
            label: 'Try again',
            enabled: true,
            onPressed: controller.retryConfirm,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: controller.finish,
            child: Text('Contact support',
                style: t.text(size: 14, color: t.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _PendingView extends StatelessWidget {
  const _PendingView({required this.controller, required this.tokens});

  final CheckoutController controller;
  final ZennoTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, color: t.pending, size: 48),
          const SizedBox(height: 20),
          Text('Taking a little longer',
              style: t.text(size: 22, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(
            "We'll finish this in the background. Check your transaction "
            'history for the final status.',
            textAlign: TextAlign.center,
            style: t.text(size: 14, color: t.textSecondary),
          ),
          const Spacer(),
          PrimaryButton(
            tokens: t,
            label: 'Done',
            enabled: true,
            onPressed: controller.finish,
          ),
        ],
      ),
    );
  }
}
