import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A vertical "fuel column" that fills from the bottom like a loaded weight
/// stack. Protein is the hero (clay); fat shows a cap marker (a ceiling).
class FuelColumn extends StatefulWidget {
  const FuelColumn({
    super.key,
    required this.label,
    required this.value,
    required this.target,
    this.unit = 'g',
    this.color = AppColors.clay,
    this.cap = false,
    this.height = 132,
    this.hero = false,
  });

  final String label;
  final double value;
  final double target;
  final String unit;
  final Color color;
  final bool cap; // fat: target is a ceiling, not a goal
  final double height;
  final bool hero;

  @override
  State<FuelColumn> createState() => _FuelColumnState();
}

class _FuelColumnState extends State<FuelColumn> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _fill;
  double _lastFraction = 0;

  double get _fraction => widget.target <= 0 ? 0 : (widget.value / widget.target).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 720));
    _fill = Tween<double>(begin: 0, end: _fraction).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _lastFraction = _fraction;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _ctrl.value = 1.0;
    } else {
      _ctrl.forward();
    }
  }

  @override
  void didUpdateWidget(covariant FuelColumn old) {
    super.didUpdateWidget(old);
    if (_fraction != _lastFraction) {
      _fill = Tween<double>(begin: _lastFraction, end: _fraction)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _lastFraction = _fraction;
      if (reduceMotion(context)) {
        _ctrl.value = 1.0;
      } else {
        _ctrl
          ..reset()
          ..forward();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final over = widget.cap && widget.value > widget.target;
    final barColor = over ? AppColors.rose : widget.color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${widget.value.round()}',
          style: AppType.display(widget.hero ? 22 : 18, weight: FontWeight.w800, color: AppColors.ink),
        ),
        Text(
          '/${widget.target.round()}${widget.unit}',
          style: AppType.body(10, color: AppColors.sageGrey, weight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: widget.height,
          width: widget.hero ? 46 : 38,
          child: AnimatedBuilder(
            animation: _fill,
            builder: (context, _) {
              return CustomPaint(
                painter: _ColumnPainter(
                  fraction: _fill.value,
                  color: barColor,
                  showCap: widget.cap,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(widget.label.toUpperCase(), style: AppType.label(AppColors.sageGrey)),
      ],
    );
  }
}

class _ColumnPainter extends CustomPainter {
  _ColumnPainter({required this.fraction, required this.color, required this.showCap});
  final double fraction;
  final Color color;
  final bool showCap;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = const Radius.circular(10);
    final track = RRect.fromRectAndRadius(Offset.zero & size, radius);

    // Track (empty stack channel).
    final trackPaint = Paint()..color = AppColors.ink.withValues(alpha: 0.06);
    canvas.drawRRect(track, trackPaint);

    // Fill from the bottom.
    final fillHeight = size.height * fraction;
    if (fillHeight > 0) {
      final fillRect = Rect.fromLTWH(0, size.height - fillHeight, size.width, fillHeight);
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [color, color.withValues(alpha: 0.82)],
        ).createShader(fillRect);
      canvas.save();
      canvas.clipRRect(track);
      canvas.drawRRect(RRect.fromRectAndRadius(fillRect, radius), fillPaint);

      // "Loaded plate" notches every ~25% to read like a weight stack.
      final notch = Paint()
        ..color = AppColors.bone.withValues(alpha: 0.35)
        ..strokeWidth = 1.4;
      for (double f = 0.25; f < 1.0; f += 0.25) {
        final y = size.height - size.height * f;
        if (y > size.height - fillHeight) {
          canvas.drawLine(Offset(4, y), Offset(size.width - 4, y), notch);
        }
      }
      canvas.restore();
    }

    // Cap marker (fat ceiling) — a hairline at the top of the channel.
    if (showCap) {
      final capPaint = Paint()
        ..color = AppColors.rose
        ..strokeWidth = 2.4;
      canvas.drawLine(const Offset(-2, 2.4), Offset(size.width + 2, 2.4), capPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ColumnPainter old) =>
      old.fraction != fraction || old.color != color || old.showCap != showCap;
}
