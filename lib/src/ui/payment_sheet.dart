import 'package:flutter/material.dart';

import '../appearance/zennopay_appearance.dart';
import '../models/zennopay_config.dart';
import 'amount_screen.dart';
import 'checkout_controller.dart';
import 'confirm_status_screen.dart';
import 'design_tokens.dart';
import 'scanner_screen.dart';
import 'widgets.dart';

/// The modal host that renders the current screen for a [CheckoutController]
/// and applies the [ZennopayAppearance]. Rebuilds as the controller advances
/// through the state machine.
class ZennopayPaymentSheet extends StatelessWidget {
  const ZennopayPaymentSheet({
    super.key,
    required this.controller,
    required this.appearance,
    required this.config,
  });

  final CheckoutController controller;
  final ZennopayAppearance appearance;
  final ZennopayConfig config;

  Brightness _brightness(BuildContext context) => switch (appearance.mode) {
        ThemeMode.light => Brightness.light,
        ThemeMode.dark => Brightness.dark,
        ThemeMode.system => MediaQuery.platformBrightnessOf(context),
      };

  @override
  Widget build(BuildContext context) {
    final tokens = ZennoTokens(appearance, _brightness(context));
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final body = switch (controller.screen) {
          CheckoutScreen.scanner =>
            ScannerScreen(controller: controller, tokens: tokens),
          CheckoutScreen.amount =>
            AmountScreen(controller: controller, tokens: tokens),
          CheckoutScreen.confirmStatus =>
            ConfirmStatusScreen(controller: controller, tokens: tokens),
        };
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && controller.isCancelable) controller.cancel();
          },
          child: Material(
            color: tokens.background,
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(child: body),
                  if (config.showSandboxRibbon)
                    Positioned(
                      top: 8,
                      right: 12,
                      child: SandboxRibbon(tokens: tokens),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
