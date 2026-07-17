import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/scan_models.dart';
import 'checkout_controller.dart';
import 'currency.dart';
import 'design_tokens.dart';
import 'slide_to_pay.dart';
import 'widgets.dart';

/// Screen 2 — Amount (spec §1.2). Shows the local amount, the USD debited, and
/// the FX/fee context, then slide-to-pay. Dynamic QR amount is read-only;
/// static QR takes native numeric entry with a live USD-equivalent and a
/// client-side per-transaction VND cap pre-check.
class AmountScreen extends StatefulWidget {
  const AmountScreen({
    super.key,
    required this.controller,
    required this.tokens,
  });

  final CheckoutController controller;
  final ZennoTokens tokens;

  @override
  State<AmountScreen> createState() => _AmountScreenState();
}

class _AmountScreenState extends State<AmountScreen> {
  final TextEditingController _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final c = widget.controller;
    final quote = c.quote;
    final merchant = c.merchant;
    if (quote == null || merchant == null) {
      return const SizedBox.shrink();
    }
    final isStatic = c.qrKind == QrKind.static_;
    final localCcy = quote.localCurrency;
    final displayAmount =
        isStatic ? c.effectiveLocalAmount : quote.localAmountMinorUnits;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                iconSize: 24,
                constraints:
                    const BoxConstraints.tightFor(width: 44, height: 44),
                icon: Icon(Icons.arrow_back, color: t.textSecondary),
                onPressed: c.cancel,
                tooltip: 'Cancel',
              ),
            ],
          ),
          const SizedBox(height: 8),
          MerchantBlock(tokens: t, merchant: merchant),
          const SizedBox(height: 28),
          // Amount headline — the LARGEST element.
          if (isStatic)
            _StaticAmountField(
              tokens: t,
              controller: _amount,
              currency: localCcy,
              onChanged: (minor) => c.setEnteredAmount(minor),
            )
          else
            Center(
              child: Text(
                Currency.format(displayAmount, localCcy),
                style: t.text(size: 56, weight: FontWeight.w700, tabular: true),
              ),
            ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '${Currency.usd(quote.amountUsdCents)} from your wallet',
              style: t.text(size: 15, color: t.textSecondary, tabular: true),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              '≈ ${Currency.format(displayAmount, localCcy)}',
              style: t.text(size: 12, color: t.textTertiary, tabular: true),
            ),
          ),
          const Spacer(),
          if (c.exceedsPerTransactionLimit)
            InlineBanner(
              tokens: t,
              message:
                  'This is above the 5,000,000 ₫ limit per payment. Enter a '
                  'smaller amount.',
            )
          else if (isStatic && c.effectiveLocalAmount <= 0)
            InlineBanner(
              tokens: t,
              neutral: true,
              message: 'Enter the amount in ${localCcy == '764' ? 'THB' : 'VND'}.',
            ),
          const SizedBox(height: 12),
          Text(
            "Your wallet won't be charged until the merchant confirms.",
            textAlign: TextAlign.center,
            style: t.text(size: 12, color: t.textTertiary),
          ),
          const SizedBox(height: 10),
          SlideToPay(
            tokens: t,
            label: 'Slide to pay ${Currency.usd(quote.amountUsdCents)}',
            enabled: c.canSlideToPay,
            onConfirmed: c.commitSlideToPay,
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
        ],
      ),
    );
  }
}

class _StaticAmountField extends StatelessWidget {
  const _StaticAmountField({
    required this.tokens,
    required this.controller,
    required this.currency,
    required this.onChanged,
  });

  final ZennoTokens tokens;
  final TextEditingController controller;
  final String currency;
  final ValueChanged<int> onChanged;

  int _toMinor(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    // The keypad enters whole local units; convert to minor units. THB has 2
    // minor digits (satang), VND has none.
    final value = int.tryParse(digits) ?? 0;
    final decimals = currency == '764' ? 2 : 0;
    return value * (decimals == 2 ? 100 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Center(
      child: IntrinsicWidth(
        child: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: t.text(size: 56, weight: FontWeight.w700, tabular: true),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: '0',
            prefixText: currency == '764' ? '฿' : '₫',
            prefixStyle: t.text(size: 40, color: t.textTertiary),
          ),
          onChanged: (v) => onChanged(_toMinor(v)),
        ),
      ),
    );
  }
}
