import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/catalog_widgets.dart';
import '../widgets/exercise_card.dart';

/// Focused full-session view launched from "Start lift".
class LiftSessionScreen extends StatelessWidget {
  const LiftSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final split = app.todaysSplit;
    final totalSets = split.exercises.fold<int>(0, (s, e) => s + e.defaultSets);
    final loggedSets = app.sets.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(split.title, style: AppType.display(18, weight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: split.rest
          ? Center(child: Text('Rest day — no lift to log.', style: AppType.body(15, color: AppColors.sageGrey)))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                  child: ProgressBar(
                    value: totalSets == 0 ? 0 : loggedSets / totalSets,
                    label: 'Session · $loggedSets sets logged',
                    color: AppColors.clay,
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 40),
                    children: [
                      if (split.legDay)
                        Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.rose.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(color: AppColors.rose.withValues(alpha: 0.35)),
                          ),
                          child: Text('Cramp-safe legs · controlled tempo · stop early if a cramp threatens.',
                              style: AppType.body(13, weight: FontWeight.w600, color: AppColors.ink)),
                        ),
                      ...split.exercises.map((ex) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: ExerciseCard(exercise: ex),
                          )),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
