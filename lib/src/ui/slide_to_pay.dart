import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'design_tokens.dart';

/// The one expressive moment (spec §1.3). A 12px-radius track with a
/// forest-green handle; completing past ~90% fires [onConfirmed] exactly once.
/// On release below threshold the handle returns with a mass-spring decay
/// ("sliding a metal latch"). Reduced-motion snaps instead of springs and
/// exposes a semantic button so a screen-reader user can double-tap to confirm.
class SlideToPay extends StatefulWidget {
  const SlideToPay({
    super.key,
    required this.tokens,
    required this.label,
    required this.enabled,
    required this.onConfirmed,
  });

  final ZennoTokens tokens;
  final String label;
  final bool enabled;
  final VoidCallback onConfirmed;

  @override
  State<SlideToPay> createState() => _SlideToPayState();
}

class _SlideToPayState extends State<SlideToPay>
    with SingleTickerProviderStateMixin {
  static const double _handleSize = 56;
  static const double _threshold = 0.9;

  late final AnimationController _spring = AnimationController.unbounded(
    vsync: this,
  )..addListener(() => setState(() => _dx = _spring.value));

  double _dx = 0;
  bool _fired = false;

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  void _fire() {
    if (_fired) return;
    _fired = true;
    widget.onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackW = constraints.maxWidth;
        final maxDx = (trackW - _handleSize).clamp(0.0, double.infinity);

        return Semantics(
          button: true,
          enabled: widget.enabled,
          label: widget.label,
          hint: 'Double-tap and hold, then slide to confirm payment',
          onTap: widget.enabled ? _fire : null,
          child: GestureDetector(
            onHorizontalDragUpdate: widget.enabled
                ? (d) => setState(
                    () => _dx = (_dx + d.delta.dx).clamp(0.0, maxDx))
                : null,
            onHorizontalDragEnd: widget.enabled
                ? (_) {
                    if (maxDx > 0 && _dx / maxDx >= _threshold) {
                      setState(() => _dx = maxDx);
                      _fire();
                    } else if (reduceMotion) {
                      setState(() => _dx = 0);
                    } else {
                      // Mass-spring decay back to rest.
                      _spring.animateWith(
                        SpringSimulation(
                          const SpringDescription(
                              mass: 1, stiffness: 180, damping: 18),
                          _dx,
                          0,
                          0,
                        ),
                      );
                    }
                  }
                : null,
            child: Container(
              height: _handleSize + 8,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: t.surface,
                border: Border.all(color: t.border),
                borderRadius: BorderRadius.circular(t.radiusSlide),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    widget.label,
                    style: t.text(
                      size: 16,
                      weight: FontWeight.w500,
                      color: widget.enabled ? t.textSecondary : t.textTertiary,
                      tabular: true,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Transform.translate(
                      offset: Offset(_dx, 0),
                      child: Container(
                        width: _handleSize,
                        height: _handleSize,
                        decoration: BoxDecoration(
                          color: widget.enabled
                              ? t.primary
                              : t.textTertiary.withValues(alpha: 0.4),
                          borderRadius:
                              BorderRadius.circular(t.radiusSlide),
                        ),
                        child: const Icon(Icons.arrow_forward,
                            color: Colors.white),
                      ),
                    ),
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
