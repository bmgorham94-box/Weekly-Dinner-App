import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/seed_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/catalog_widgets.dart';
import '../widgets/exercise_card.dart';

class TrainScreen extends StatelessWidget {
  const TrainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final split = app.todaysSplit;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.clay,
          onRefresh: app.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TRAIN', style: AppType.label(AppColors.clay)),
                      const SizedBox(height: 2),
                      Text(split.title, style: AppType.display(24, weight: FontWeight.w800)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.forest, borderRadius: BorderRadius.circular(AppRadius.pill)),
                    child: Text(Seed.phaseLabel, style: AppType.body(11, weight: FontWeight.w700, color: AppColors.bone)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // ---- Streaks (three-across Strava stat block) ----
              SoftCard(
                child: FutureBuilder<List<int>>(
                  future: Future.wait([app.trainingStreak(), app.proteinStreak()]),
                  builder: (context, snap) {
                    final training = snap.hasData ? '${snap.data![0]}' : '—';
                    final protein = snap.hasData ? '${snap.data![1]}' : '—';
                    return StatRow(blocks: [
                      StatBlock(value: training, label: 'Day Streak', accent: AppColors.clay),
                      StatBlock(value: protein, label: 'Protein Streak', accent: AppColors.sage),
                      StatBlock(value: '${split.exercises.length}', label: 'Lifts Today', accent: AppColors.ink),
                    ]);
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Text(Seed.frequencyNote, style: AppType.body(12, color: AppColors.sageGrey)),
              const SizedBox(height: AppSpacing.md),

              if (split.legDay) _crampBanner(),

              if (split.rest)
                _restState()
              else
                ...split.exercises.map((ex) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: ExerciseCard(exercise: ex),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _crampBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.clay.withValues(alpha: 0.16), AppColors.rose.withValues(alpha: 0.16)]),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.rose),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cramp-safe legs. No heavy barbell squats. Electrolytes in, controlled tempo, stop a set early if a cramp threatens.',
              style: AppType.body(13, weight: FontWeight.w600, height: 1.35, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _restState() {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.self_improvement_rounded, color: AppColors.sage, size: 30),
          const SizedBox(height: 12),
          Text('Rest + Walk', style: AppType.display(20, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Recovery, dog walk, meal prep. The win today is protein and your piriformis stretch sequence.',
              style: AppType.body(14, color: AppColors.sageGrey, height: 1.4)),
        ],
      ),
    );
  }
}
