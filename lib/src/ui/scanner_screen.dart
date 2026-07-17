import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/emvco_parser.dart';
import '../models/zennopay_error.dart';
import 'checkout_controller.dart';
import 'design_tokens.dart';
import 'widgets.dart';

/// Screen 1 — Scanner (spec §1.1). Live camera decode is display-only; the raw
/// payload is submitted to `/scan` for the authoritative parse. Torch, gallery,
/// and paste are first-class fallbacks so the flow completes camera-free.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({
    super.key,
    required this.controller,
    required this.tokens,
  });

  final CheckoutController controller;
  final ZennoTokens tokens;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _scanner = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;
  bool _torchOn = false;
  bool _showPaste = false;
  final TextEditingController _paste = TextEditingController();

  @override
  void dispose() {
    _scanner.dispose();
    _paste.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    if (capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    _handled = true;
    _submit(raw);
  }

  void _submit(String raw) {
    // Display-only local hint for the "static QR needs amount" fast path.
    final isDynamic = EmvCoParser.isDynamic(raw);
    if (!isDynamic) {
      // Static QR: backend still classifies; amount is entered on Screen 2.
      widget.controller.submitScannedPayload(raw);
    } else {
      widget.controller.submitScannedPayload(raw);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final quoting = widget.controller.state == CheckoutState.quoting;
    final err = widget.controller.error;

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
                icon: Icon(Icons.close, color: t.textSecondary),
                onPressed: widget.controller.cancel,
                tooltip: 'Cancel',
              ),
            ],
          ),
          Text('Scan to pay',
              style: t.text(size: 24, weight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(
            "Point at the merchant's QR code. We'll show the amount before you "
            'pay.',
            textAlign: TextAlign.center,
            style: t.text(size: 14, color: t.textSecondary),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(t.radiusCard),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_showPaste)
                    _pasteFallback(t)
                  else
                    MobileScanner(
                      controller: _scanner,
                      onDetect: _onDetect,
                      errorBuilder: (context, error, child) =>
                          _cameraUnavailable(t),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: t.border),
                      borderRadius: BorderRadius.circular(t.radiusCard),
                    ),
                  ),
                  if (quoting)
                    ColoredBox(
                      color: Colors.black.withValues(alpha: 0.35),
                      child: Center(
                        child: Text('Checking…',
                            style: t.text(size: 16, color: Colors.white)),
                      ),
                    ),
                  if (!_showPaste)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 12,
                      child: _controlsRow(t),
                    ),
                ],
              ),
            ),
          ),
          if (err != null && err.code != ZennopayErrorCode.canceled) ...[
            const SizedBox(height: 12),
            InlineBanner(tokens: t, message: err.userMessage),
          ],
        ],
      ),
    );
  }

  Widget _controlsRow(ZennoTokens t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _circleButton(t, _torchOn ? Icons.flashlight_on : Icons.flashlight_off,
            'Torch', () {
          _scanner.toggleTorch();
          setState(() => _torchOn = !_torchOn);
        }),
        const SizedBox(width: 16),
        _circleButton(t, Icons.photo_library_outlined, 'Gallery', () async {
          await _scanner.analyzeImage('');
        }),
        const SizedBox(width: 16),
        _circleButton(t, Icons.keyboard_outlined, 'Paste',
            () => setState(() => _showPaste = true)),
      ],
    );
  }

  Widget _circleButton(
      ZennoTokens t, IconData icon, String label, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _cameraUnavailable(ZennoTokens t) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_showPaste) setState(() => _showPaste = true);
    });
    return _pasteFallback(t);
  }

  Widget _pasteFallback(ZennoTokens t) {
    return ColoredBox(
      color: t.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Paste the QR code data to continue.',
                style: t.text(size: 14, color: t.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: _paste,
              maxLines: 3,
              minLines: 2,
              style: t.text(size: 14),
              decoration: InputDecoration(
                hintText: '000201…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(t.radiusInput),
                ),
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              tokens: t,
              label: 'Continue',
              enabled: true,
              onPressed: () {
                final v = _paste.text.trim();
                if (v.isNotEmpty) _submit(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}
