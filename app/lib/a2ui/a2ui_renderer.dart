import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/catalog_widgets.dart';
import '../widgets/fuel_column.dart';
import 'a2ui_models.dart';

/// An apply-event emitted by an A2UI surface back to the host app.
class A2Event {
  final String action;
  final dynamic value;
  const A2Event(this.action, this.value);
}

/// Renders a live A2UI surface from the trusted component catalog.
/// Unknown component types degrade to nothing; a failed stream degrades to
/// [A2Surface.fallbackText]. Apply buttons emit [A2Event]s via [onEvent].
class A2SurfaceView extends StatelessWidget {
  const A2SurfaceView({
    super.key,
    required this.surface,
    required this.onEvent,
    this.imageResolver,
    this.padding = EdgeInsets.zero,
  });

  final A2Surface surface;
  final void Function(A2Event event) onEvent;

  /// Supplies images for PhotoCompareCard (left/right) — client-side only.
  final (ImageProvider?, ImageProvider?) Function()? imageResolver;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: surface,
      builder: (context, _) {
        // Hard failure with no components → plain-text fallback.
        if (surface.failed && surface.isEmpty) {
          return Padding(
            padding: padding,
            child: CoachMessage(
              text: surface.fallbackText ??
                  "Coach is offline right now. Check the server is running, then pull to retry.",
              tone: 'warning',
            ),
          );
        }

        final root = surface.root;
        if (root == null) {
          if (surface.streaming) {
            return Padding(padding: padding, child: const _ThinkingRow());
          }
          return const SizedBox.shrink();
        }

        return Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _build(context, root),
              if (surface.streaming) ...[
                const SizedBox(height: 12),
                const _ThinkingRow(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _build(BuildContext context, A2Component c) {
    switch (c.type) {
      case 'Column':
        final gap = (c.props['gap'] as num?)?.toDouble() ?? 12;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _interleave(_childWidgets(context, c), gap),
        );
      case 'Row':
        final gap = (c.props['gap'] as num?)?.toDouble() ?? 12;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _interleaveRow(
            _childWidgets(context, c).map((w) => Expanded(child: w)).toList(),
            gap,
          ),
        );
      case 'CoachMessage':
        return CoachMessage(text: c.props['text']?.toString() ?? '', tone: c.props['tone']?.toString() ?? 'default');
      case 'StatBlock':
        return StatBlock(
          value: c.props['value']?.toString() ?? '—',
          label: c.props['label']?.toString() ?? '',
          accent: AppColors.named(c.props['accent']?.toString(), fallback: AppColors.ink),
        );
      case 'FuelColumn':
        return Center(
          child: FuelColumn(
            label: c.props['label']?.toString() ?? '',
            value: (c.props['value'] as num?)?.toDouble() ?? 0,
            target: (c.props['target'] as num?)?.toDouble() ?? 1,
            unit: c.props['unit']?.toString() ?? 'g',
            color: AppColors.named(c.props['color']?.toString()),
            cap: c.props['cap'] == true,
          ),
        );
      case 'AdjustmentCard':
        final action = c.props['applyAction']?.toString();
        return AdjustmentCard(
          title: c.props['title']?.toString() ?? '',
          before: c.props['before']?.toString() ?? '',
          after: c.props['after']?.toString() ?? '',
          note: c.props['note']?.toString(),
          applyLabel: c.props['applyLabel']?.toString() ?? 'Apply',
          onApply: action == null ? null : () => onEvent(A2Event(action, c.props['applyValue'])),
        );
      case 'ExerciseSwapCard':
        final action = c.props['applyAction']?.toString() ?? 'swap_exercise';
        final value = c.props['applyValue'] ?? {'from': c.props['from'], 'to': c.props['to']};
        return ExerciseSwapCard(
          from: c.props['from']?.toString() ?? '',
          to: c.props['to']?.toString() ?? '',
          reason: c.props['reason']?.toString(),
          onApply: () => onEvent(A2Event(action, value)),
        );
      case 'PhotoCompareCard':
        final imgs = imageResolver?.call() ?? (null, null);
        return PhotoCompareCard(
          verdict: c.props['verdict']?.toString() ?? '',
          leftLabel: c.props['leftLabel']?.toString() ?? 'Last',
          rightLabel: c.props['rightLabel']?.toString() ?? 'Now',
          leftImage: imgs.$1,
          rightImage: imgs.$2,
        );
      case 'ChecklistChip':
        return Align(
          alignment: Alignment.centerLeft,
          child: ChecklistChip(
            label: c.props['label']?.toString() ?? '',
            checked: c.props['checked'] == true,
            onTap: () => onEvent(A2Event('toggle_checklist', c.props['label'])),
          ),
        );
      case 'PrimaryButton':
        final action = c.props['action']?.toString();
        return Align(
          alignment: Alignment.centerLeft,
          child: PrimaryButton(
            label: c.props['label']?.toString() ?? '',
            style: c.props['style']?.toString() ?? 'filled',
            onPressed: action == null ? null : () => onEvent(A2Event(action, c.props['value'])),
          ),
        );
      case 'MetricRow':
        return MetricRow(label: c.props['label']?.toString() ?? '', value: c.props['value']?.toString() ?? '');
      case 'Divider':
        return const HairlineDivider();
      case 'SectionLabel':
        return SectionLabel(text: c.props['text']?.toString() ?? '');
      case 'ProgressBar':
        return ProgressBar(
          value: (c.props['value'] as num?)?.toDouble() ?? 0,
          label: c.props['label']?.toString(),
          color: AppColors.named(c.props['color']?.toString(), fallback: AppColors.clay),
        );
      default:
        // Component not in the trusted catalog → render nothing.
        return const SizedBox.shrink();
    }
  }

  List<Widget> _childWidgets(BuildContext context, A2Component c) {
    return c.children
        .map((id) => surface.components[id])
        .where((child) => child != null)
        .map((child) => _build(context, child!))
        .toList();
  }

  List<Widget> _interleave(List<Widget> widgets, double gap) {
    final out = <Widget>[];
    for (var i = 0; i < widgets.length; i++) {
      out.add(widgets[i]);
      if (i < widgets.length - 1) out.add(SizedBox(height: gap));
    }
    return out;
  }

  List<Widget> _interleaveRow(List<Widget> widgets, double gap) {
    final out = <Widget>[];
    for (var i = 0; i < widgets.length; i++) {
      out.add(widgets[i]);
      if (i < widgets.length - 1) out.add(SizedBox(width: gap));
    }
    return out;
  }
}

/// A small "coach is thinking" affordance shown while a surface streams.
class _ThinkingRow extends StatefulWidget {
  const _ThinkingRow();
  @override
  State<_ThinkingRow> createState() => _ThinkingRowState();
}

class _ThinkingRowState extends State<_ThinkingRow> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) {
      return Row(children: [
        const SizedBox(width: 4),
        Text('Coach is thinking…', style: AppType.body(13, color: AppColors.sageGrey)),
      ]);
    }
    return Row(
      children: [
        ...List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = ((_c.value + i * 0.18) % 1.0);
              final scale = 0.6 + 0.4 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
              return Container(
                margin: const EdgeInsets.only(right: 5),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: AppColors.clay.withValues(alpha: 0.4 + 0.6 * scale),
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
        const SizedBox(width: 4),
        Text('Coach is thinking…', style: AppType.body(13, color: AppColors.sageGrey)),
      ],
    );
  }
}
