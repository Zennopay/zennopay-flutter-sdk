import 'package:flutter/material.dart';

import '../models/scan_models.dart';
import 'design_tokens.dart';

/// Accent-fill primary action (DESIGN.md Component Vocabulary).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.tokens,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final ZennoTokens tokens;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final btn = t.appearance.primaryButton;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: btn.background,
            foregroundColor: btn.textColor,
            disabledBackgroundColor: t.border,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(btn.cornerRadius),
            ),
          ),
          child: Text(
            label,
            style: t.text(size: 16, weight: FontWeight.w500, color: btn.textColor),
          ),
        ),
      ),
    );
  }
}

/// A low, calm inline banner — muted brick for failures (never a red wall).
class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.tokens,
    required this.message,
    this.neutral = false,
  });

  final ZennoTokens tokens;
  final String message;
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final bg = neutral ? t.surface : t.failureSoft;
    final fg = neutral ? t.textSecondary : t.failure;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(t.radiusCard),
      ),
      child: Row(
        children: [
          Icon(neutral ? Icons.info_outline : Icons.error_outline,
              size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: t.text(size: 14, color: fg))),
        ],
      ),
    );
  }
}

/// Merchant name + city, no card chrome (DESIGN.md Merchant Block).
class MerchantBlock extends StatelessWidget {
  const MerchantBlock({super.key, required this.tokens, required this.merchant});

  final ZennoTokens tokens;
  final Merchant merchant;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(merchant.displayName,
            style: t.text(size: 16, weight: FontWeight.w500)),
        if (merchant.city != null && merchant.city!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(merchant.city!,
                style: t.text(size: 14, color: t.textSecondary)),
          ),
        const SizedBox(height: 6),
        VerifiedMerchantBadge(tokens: t, merchant: merchant),
      ],
    );
  }
}

/// "Verified on {network} network" — accent green, seal glyph (spec §1.1).
class VerifiedMerchantBadge extends StatelessWidget {
  const VerifiedMerchantBadge(
      {super.key, required this.tokens, required this.merchant});

  final ZennoTokens tokens;
  final Merchant merchant;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Semantics(
      label: 'Verified merchant on ${merchant.networkLabel} network',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined, size: 15, color: t.primary),
          const SizedBox(width: 5),
          Text('Verified on ${merchant.networkLabel} network',
              style: t.text(size: 12, color: t.primary)),
        ],
      ),
    );
  }
}

/// Persistent SANDBOX pill for non-production environments (spec §6).
class SandboxRibbon extends StatelessWidget {
  const SandboxRibbon({super.key, required this.tokens});

  final ZennoTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('SANDBOX',
          style: t.text(
              size: 11, weight: FontWeight.w500, color: t.textTertiary)),
    );
  }
}
