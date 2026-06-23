import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'catalog_widgets.dart';

/// An exercise with inline set logging (weight × reps). Default 3 sets, add set.
/// Unilateral moves show the "Lead with the LEFT" cue. Honors coach swaps.
class ExerciseCard extends StatefulWidget {
  const ExerciseCard({super.key, required this.exercise});
  final Exercise exercise;

  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  late int _setCount;

  @override
  void initState() {
    super.initState();
    _setCount = widget.exercise.defaultSets;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final resolved = app.resolveExercise(widget.exercise.name);
    final swapped = app.isSwapped(widget.exercise.name);
    final logged = app.setsForExercise(resolved);
    final count = _setCount > logged.length ? _setCount : logged.length;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(resolved, style: AppType.display(16, weight: FontWeight.w700, height: 1.1)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(widget.exercise.scheme, style: AppType.body(12, color: AppColors.sageGrey, weight: FontWeight.w600)),
                        if (swapped) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.clay.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(6)),
                            child: Text('COACH SWAP', style: AppType.label(AppColors.clay)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.exercise.unilateral) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: AppColors.forest.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.swipe_left_rounded, size: 15, color: AppColors.forest),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Lead with the LEFT — it sets the weight, right matches.',
                        style: AppType.body(12, weight: FontWeight.w600, color: AppColors.forest)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...List.generate(count, (i) => _setRow(app, resolved, i, logged)),
          const SizedBox(height: 4),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _setCount = count + 1);
                },
                child: Row(
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.clay),
                    const SizedBox(width: 6),
                    Text('Add set', style: AppType.body(13, weight: FontWeight.w700, color: AppColors.clay)),
                  ],
                ),
              ),
              const Spacer(),
              Text('${logged.length}/$count logged', style: AppType.body(11, color: AppColors.sageGrey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _setRow(AppState app, String exercise, int index, List<SetEntry> logged) {
    final existing = logged.where((s) => s.setIndex == index).toList();
    final entry = existing.isNotEmpty ? existing.first : null;
    final done = entry != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done ? AppColors.sage.withValues(alpha: 0.22) : AppColors.boneDeep,
              shape: BoxShape.circle,
            ),
            child: Text('${index + 1}', style: AppType.body(12, weight: FontWeight.w700, color: done ? AppColors.sage : AppColors.sageGrey)),
          ),
          const SizedBox(width: 12),
          Expanded(child: _numField(app, exercise, index, entry, isWeight: true)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('×', style: AppType.body(15, color: AppColors.sageGrey)),
          ),
          Expanded(child: _numField(app, exercise, index, entry, isWeight: false)),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(done ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 20, color: done ? AppColors.sage : AppColors.hairline),
            onPressed: entry == null ? null : () => app.removeSet(entry.id!),
          ),
        ],
      ),
    );
  }

  Widget _numField(AppState app, String exercise, int index, SetEntry? entry, {required bool isWeight}) {
    final controller = TextEditingController(
      text: entry == null ? '' : (isWeight ? _trim(entry.weight) : '${entry.reps}'),
    );
    controller.selection = TextSelection.collapsed(offset: controller.text.length);
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: isWeight),
      textAlign: TextAlign.center,
      style: AppType.display(16, weight: FontWeight.w700),
      decoration: InputDecoration(
        isDense: true,
        hintText: isWeight ? 'lb' : 'reps',
        hintStyle: AppType.body(12, color: AppColors.sageGrey),
        filled: true,
        fillColor: AppColors.boneDeep.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
      onSubmitted: (_) => _commit(app, exercise, index, entry, controller, isWeight),
      onEditingComplete: () => _commit(app, exercise, index, entry, controller, isWeight),
    );
  }

  void _commit(AppState app, String exercise, int index, SetEntry? entry, TextEditingController controller, bool isWeight) {
    final weight = isWeight ? double.tryParse(controller.text.trim()) : entry?.weight;
    final reps = !isWeight ? int.tryParse(controller.text.trim()) : entry?.reps;
    final w = weight ?? entry?.weight ?? 0;
    final r = reps ?? entry?.reps ?? 0;
    if (w == 0 && r == 0) return;
    HapticFeedback.lightImpact();
    app.logSet(exercise, index, w, r);
  }

  String _trim(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
