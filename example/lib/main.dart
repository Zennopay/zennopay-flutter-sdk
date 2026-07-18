import 'package:flutter/material.dart';
import 'package:zennopay_flutter/zennopay_flutter.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zennopay Example',
      theme: ThemeData(useMaterial3: true),
      home: const CheckoutDemo(),
    );
  }
}

class CheckoutDemo extends StatefulWidget {
  const CheckoutDemo({super.key});

  @override
  State<CheckoutDemo> createState() => _CheckoutDemoState();
}

class _CheckoutDemoState extends State<CheckoutDemo> {
  String _status = 'Ready';

  Future<void> _pay() async {
    setState(() => _status = 'Presenting…');

    // In a real app, YOUR backend pre-creates the payment intent and mints the
    // short-lived, intent-bound session JWT. These placeholders let you wire the
    // flow against a sandbox backend — see the partner session-endpoint docs:
    // https://github.com/Zennopay/zennopay-docs
    const intentId = 'zp_demo_intent';
    const sessionJwt = 'header.payload.signature';

    final result = await Zennopay.presentSheet(
      intentId: intentId,
      sessionJwt: sessionJwt,
      // Called on session expiry (401): re-mint for the SAME intent, or return
      // null if you can't.
      refreshSession: (id) async => sessionJwt,
      appearance: const ZennopayAppearance.automatic(),
      config: ZennopayConfig.sandbox,
    );

    if (!mounted) return;
    setState(() {
      _status = switch (result) {
        Completed(:final intentId) => 'Completed: $intentId',
        Pending(:final intentId) => 'Pending: $intentId',
        Failed(:final error) => 'Failed: ${error.code.wire}',
        Canceled() => 'Canceled',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zennopay PaymentSheet')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_status),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _pay,
              child: const Text('Pay with Zennopay'),
            ),
          ],
        ),
      ),
    );
  }
}
