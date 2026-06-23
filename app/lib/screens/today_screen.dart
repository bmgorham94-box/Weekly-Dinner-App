import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../a2ui/a2ui_models.dart';
import '../a2ui/a2ui_renderer.dart';
import '../data/seed_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/catalog_widgets.dart';
import '../widgets/fuel_column.dart';
import 'lift_session_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final A2Surface _coachSurface = A2Surface();
  bool _coachRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCoach());
  }

  Future<void> _loadCoach() async {
    final app = context.read<AppState>();
    setState(() => _coachRequested = true);
    final ctx = await app.buildCoachContext();
    await app.coach.dailyCheckin(context: ctx, surface: _coachSurface);
  }

  @override
  void dispose() {
    _coachSurface.dispose();
    super.dispose();
  }

  Future<void> _onCoachEvent(A2Event e) async {
    final app = context.read<AppState>();
    final msg = await app.handleA2Event(e);
    if (msg != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final split = app.todaysSplit;
    final t = app.targets;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.clay,
          onRefresh: () async {
            await app.refresh();
            await _loadCoach();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
            children: [
              _header(app),
              const SizedBox(height: AppSpacing.md),

              // ---- Coach card (A2UI surface) ----
              _coachCard(),
              const SizedBox(height: AppSpacing.lg),

              // ---- Day type toggle + split ----
              _dayTypeAndSplit(app, split),
              const SizedBox(height: AppSpacing.lg),

              // ---- Calorie total + fuel columns ----
              _fuelSection(app, t),
              const SizedBox(height: AppSpacing.lg),

              // ---- Protein cue ----
              _proteinCue(app, t),
              const SizedBox(height: AppSpacing.lg),

              // ---- Rehab / cramp-guard chips ----
              _checklist(app),
              const SizedBox(height: AppSpacing.lg),

              // ---- Today's lift preview ----
              if (!split.rest) _liftPreview(app, split) else _restCard(),
              const SizedBox(height: AppSpacing.lg),

              // ---- Bodyweight ----
              _bodyweight(app),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(AppState app) {
    final dateStr = DateFormat('EEEE, MMM d').format(app.date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TODAY', style: AppType.label(AppColors.clay)),
                const SizedBox(height: 2),
                Text(dateStr, style: AppType.display(26, weight: FontWeight.w800)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.forest,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(Seed.phaseLabel, style: AppType.body(11, weight: FontWeight.w700, color: AppColors.bone)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _coachCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.clay.withValues(alpha: 0.10), AppColors.sage.withValues(alpha: 0.10)],
        ),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 15, color: AppColors.clay),
                const SizedBox(width: 6),
                Text('YOUR COACH', style: AppType.label(AppColors.clay)),
              ],
            ),
          ),
          if (!_coachRequested)
            const Padding(padding: EdgeInsets.all(12), child: Text('…'))
          else
            A2SurfaceView(
              surface: _coachSurface,
              onEvent: _onCoachEvent,
              padding: const EdgeInsets.all(4),
            ),
        ],
      ),
    );
  }

  Widget _dayTypeAndSplit(AppState app, split) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _toggleChip('Train', app.isTrainingDay, () => app.setTrainingDay(true)),
              const SizedBox(width: 8),
              _toggleChip('Rest', !app.isTrainingDay, () => app.setTrainingDay(false)),
              const Spacer(),
              Text(Seed.dayFor(app.date.weekday % 7).focus, style: AppType.body(12, color: AppColors.sageGrey, weight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          Text(split.title, style: AppType.display(22, weight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(Seed.frequencyNote, style: AppType.body(12, color: AppColors.sageGrey)),
        ],
      ),
    );
  }

  Widget _toggleChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.clay : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: active ? AppColors.clay : AppColors.hairline),
        ),
        child: Text(label,
            style: AppType.body(14, weight: FontWeight.w700, color: active ? AppColors.bone : AppColors.sageGrey)),
      ),
    );
  }

  Widget _fuelSection(AppState app, t) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${app.totalCal.round()}', style: AppType.display(42, weight: FontWeight.w800, height: 1.0)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('/ ${t.calories} kcal', style: AppType.body(15, color: AppColors.sageGrey, weight: FontWeight.w600)),
              ),
              const Spacer(),
              Text('${(t.calories - app.totalCal).round()} left', style: AppType.body(13, color: AppColors.sageGrey)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FuelColumn(label: 'Protein', value: app.totalProtein, target: t.protein.toDouble(), color: AppColors.clay, hero: true),
              FuelColumn(label: 'Carbs', value: app.totalCarbs, target: t.carbs.toDouble(), color: AppColors.amber),
              FuelColumn(label: 'Fat', value: app.totalFat, target: t.fat.toDouble(), color: AppColors.rose, cap: true),
              FuelColumn(label: 'Fiber', value: app.totalFiber, target: t.fiber.toDouble(), color: AppColors.teal),
            ],
          ),
          const SizedBox(height: 8),
          Center(child: Text('Fat is a ceiling · protein is the priority', style: AppType.body(11, color: AppColors.sageGrey))),
        ],
      ),
    );
  }

  Widget _proteinCue(AppState app, t) {
    final remaining = (t.protein - app.totalProtein).round();
    final hit = remaining <= 0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: hit ? AppColors.sage.withValues(alpha: 0.18) : AppColors.clay.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Icon(hit ? Icons.check_circle_rounded : Icons.bolt_rounded, color: hit ? AppColors.sage : AppColors.clay),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hit
                  ? 'Protein hit. That\'s the day\'s win — everything else is bonus.'
                  : '$remaining g protein to go. Lead with protein; the rest falls in line.',
              style: AppType.body(14, weight: FontWeight.w600, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _checklist(AppState app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SectionLabel(text: 'Cramp-guard · Rehab'),
            const Spacer(),
            Text('${app.checklistDone}/${app.checklistTotal}', style: AppType.body(12, weight: FontWeight.w700, color: AppColors.sageGrey)),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: app.checklist.items.entries
              .map((e) => ChecklistChip(label: e.key, checked: e.value, onTap: () => app.toggleChecklist(e.key)))
              .toList(),
        ),
      ],
    );
  }

  Widget _liftPreview(AppState app, split) {
    final preview = split.exercises.take(3).toList();
    return SoftCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LiftSessionScreen())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SectionLabel(text: "Today's lift"),
              const Spacer(),
              if (split.legDay)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.rose.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
                  child: Text('CRAMP-SAFE', style: AppType.label(AppColors.rose)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...preview.map((ex) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.clay, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(app.resolveExercise(ex.name), style: AppType.body(14, weight: FontWeight.w600))),
                    Text(ex.scheme, style: AppType.body(12, color: AppColors.sageGrey)),
                  ],
                ),
              )),
          if (split.exercises.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('+ ${split.exercises.length - 3} more', style: AppType.body(12, color: AppColors.sageGrey)),
            ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Start lift',
            icon: Icons.play_arrow_rounded,
            expand: true,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LiftSessionScreen())),
          ),
        ],
      ),
    );
  }

  Widget _restCard() {
    return SoftCard(
      child: Row(
        children: [
          const Icon(Icons.self_improvement_rounded, color: AppColors.sage, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rest + Walk', style: AppType.display(18, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Recovery · dog walk · meal prep. Showing up on rest days is hitting protein.',
                    style: AppType.body(13, color: AppColors.sageGrey, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bodyweight(AppState app) {
    return SoftCard(
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel(text: 'Bodyweight'),
              const SizedBox(height: 4),
              Text(app.bodyweight != null ? '${app.bodyweight!.toStringAsFixed(1)} lb' : '—',
                  style: AppType.display(26, weight: FontWeight.w800)),
            ],
          ),
          const Spacer(),
          PrimaryButton(
            label: app.bodyweight != null ? 'Update' : 'Log',
            style: 'tonal',
            dense: true,
            onPressed: () => _logWeight(app),
          ),
        ],
      ),
    );
  }

  Future<void> _logWeight(AppState app) async {
    final controller = TextEditingController(text: app.bodyweight?.toStringAsFixed(1) ?? '');
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bone,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's bodyweight", style: AppType.display(20, weight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(suffixText: 'lb', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Save',
              expand: true,
              onPressed: () {
                final v = double.tryParse(controller.text.trim());
                Navigator.pop(ctx, v);
              },
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      await app.setBodyweight(result);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bodyweight logged')));
    }
  }
}
