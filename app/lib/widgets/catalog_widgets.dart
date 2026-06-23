import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Strava-style stat block: big number / small uppercase label.
class StatBlock extends StatelessWidget {
  const StatBlock({
    super.key,
    required this.value,
    required this.label,
    this.accent = AppColors.ink,
    this.compact = false,
  });

  final String value;
  final String label;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppType.display(compact ? 28 : 34, weight: FontWeight.w800, color: accent, height: 1.0)),
        const SizedBox(height: 4),
        Text(label.toUpperCase(), style: AppType.label(AppColors.sageGrey)),
      ],
    );
  }
}

/// Three-across stat row with hairline dividers (Strava).
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.blocks});
  final List<StatBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      children.add(Expanded(child: blocks[i]));
      if (i < blocks.length - 1) {
        children.add(Container(width: 1, height: 44, color: AppColors.hairline, margin: const EdgeInsets.symmetric(horizontal: 12)));
      }
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: children);
  }
}

/// A styled coach text bubble.
class CoachMessage extends StatelessWidget {
  const CoachMessage({super.key, required this.text, this.tone = 'default'});
  final String text;
  final String tone;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (tone) {
      case 'hero':
        bg = AppColors.forest;
        fg = AppColors.onForest;
        break;
      case 'warning':
        bg = AppColors.rose.withValues(alpha: 0.14);
        fg = AppColors.ink;
        break;
      case 'good':
        bg = AppColors.sage.withValues(alpha: 0.18);
        fg = AppColors.ink;
        break;
      default:
        bg = AppColors.card;
        fg = AppColors.ink;
    }
    final isHero = tone == 'hero';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: tone == 'warning' ? Border.all(color: AppColors.rose.withValues(alpha: 0.4)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: isHero ? AppColors.clay : AppColors.clay.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text('L', style: AppType.display(14, color: isHero ? AppColors.bone : AppColors.clay)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppType.body(15, color: fg, height: 1.4, weight: isHero ? FontWeight.w600 : FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Before/after adjustment with an Apply action.
class AdjustmentCard extends StatelessWidget {
  const AdjustmentCard({
    super.key,
    required this.title,
    required this.before,
    required this.after,
    this.note,
    this.applyLabel = 'Apply',
    this.onApply,
  });

  final String title;
  final String before;
  final String after;
  final String? note;
  final String applyLabel;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppType.display(16, weight: FontWeight.w700)),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(note!, style: AppType.body(13, color: AppColors.sageGrey, height: 1.35)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _beforeAfter('NOW', before, AppColors.sageGrey),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.clay),
              ),
              _beforeAfter('NEW', after, AppColors.clay),
              const Spacer(),
              if (onApply != null)
                PrimaryButton(label: applyLabel, onPressed: onApply, style: 'tonal', dense: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _beforeAfter(String tag, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tag, style: AppType.label(AppColors.sageGrey)),
        const SizedBox(height: 2),
        Text(val, style: AppType.display(20, weight: FontWeight.w800, color: color)),
      ],
    );
  }
}

/// Old → new exercise swap with Apply.
class ExerciseSwapCard extends StatelessWidget {
  const ExerciseSwapCard({super.key, required this.from, required this.to, this.reason, this.onApply});
  final String from;
  final String to;
  final String? reason;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(text: 'Suggested swap'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(from, style: AppType.body(14, color: AppColors.sageGrey, weight: FontWeight.w600)),
              ),
              const Icon(Icons.swap_horiz_rounded, size: 20, color: AppColors.clay),
              const SizedBox(width: 8),
              Expanded(
                child: Text(to, style: AppType.display(15, weight: FontWeight.w700, color: AppColors.ink)),
              ),
            ],
          ),
          if (reason != null) ...[
            const SizedBox(height: 8),
            Text(reason!, style: AppType.body(13, color: AppColors.sageGrey, height: 1.35)),
          ],
          if (onApply != null) ...[
            const SizedBox(height: 12),
            PrimaryButton(label: 'Apply to today', onPressed: onApply, dense: true),
          ],
        ],
      ),
    );
  }
}

/// Two images + verdict text. Images are supplied by the host (client-side).
class PhotoCompareCard extends StatelessWidget {
  const PhotoCompareCard({
    super.key,
    required this.verdict,
    this.leftLabel = 'Last',
    this.rightLabel = 'Now',
    this.leftImage,
    this.rightImage,
  });

  final String verdict;
  final String leftLabel;
  final String rightLabel;
  final ImageProvider? leftImage;
  final ImageProvider? rightImage;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
            child: Row(
              children: [
                Expanded(child: _img(leftImage, leftLabel)),
                const SizedBox(width: 2),
                Expanded(child: _img(rightImage, rightLabel)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(verdict, style: AppType.body(14, height: 1.4, weight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _img(ImageProvider? provider, String label) {
    return AspectRatio(
      aspectRatio: 0.8,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (provider != null)
            Image(image: provider, fit: BoxFit.cover)
          else
            Container(color: AppColors.boneDeep, child: const Icon(Icons.photo_outlined, color: AppColors.sageGrey)),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.forest.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(8)),
              child: Text(label.toUpperCase(), style: AppType.label(AppColors.bone)),
            ),
          ),
        ],
      ),
    );
  }
}

/// A toggleable checklist chip.
class ChecklistChip extends StatelessWidget {
  const ChecklistChip({super.key, required this.label, required this.checked, this.onTap});
  final String label;
  final bool checked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: checked ? AppColors.sage.withValues(alpha: 0.22) : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(color: checked ? AppColors.sage : AppColors.hairline, width: checked ? 1.4 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(checked ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 16, color: checked ? AppColors.sage : AppColors.sageGrey),
            const SizedBox(width: 7),
            Text(label, style: AppType.body(13, weight: FontWeight.w600, color: checked ? AppColors.ink : AppColors.sageGrey)),
          ],
        ),
      ),
    );
  }
}

/// Primary button (filled clay or tonal) with haptics.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.style = 'filled',
    this.dense = false,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final String style; // 'filled' | 'tonal'
  final bool dense;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final filled = style == 'filled';
    final child = Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 14 : 20, vertical: dense ? 9 : 14),
      decoration: BoxDecoration(
        color: filled ? AppColors.clay : AppColors.clay.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 16 : 18, color: filled ? AppColors.bone : AppColors.clay),
            const SizedBox(width: 8),
          ],
          Text(label,
              style: AppType.body(dense ? 13 : 15, weight: FontWeight.w700, color: filled ? AppColors.bone : AppColors.clay)),
        ],
      ),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onPressed == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onPressed!();
              },
        child: child,
      ),
    );
  }
}

/// Label / value row.
class MetricRow extends StatelessWidget {
  const MetricRow({super.key, required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppType.body(14, color: AppColors.sageGrey, weight: FontWeight.w500)),
          Text(value, style: AppType.display(15, weight: FontWeight.w700, color: color ?? AppColors.ink)),
        ],
      ),
    );
  }
}

/// Hairline divider.
class HairlineDivider extends StatelessWidget {
  const HairlineDivider({super.key});
  @override
  Widget build(BuildContext context) => Container(height: 1, color: AppColors.hairline);
}

/// Uppercase section label.
class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: AppType.label(AppColors.sageGrey));
}

/// Thin progress bar.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.label, this.color = AppColors.clay});
  final double value;
  final String? label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label!, style: AppType.body(13, color: AppColors.sageGrey, weight: FontWeight.w600)),
              Text('${(value.clamp(0.0, 1.0) * 100).round()}%', style: AppType.body(13, weight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 6),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: AppColors.ink.withValues(alpha: 0.06),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
