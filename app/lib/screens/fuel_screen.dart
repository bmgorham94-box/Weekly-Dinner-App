import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/seed_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/catalog_widgets.dart';
import '../widgets/fuel_column.dart';

/// Fuel — today's macro logging. Big day total, four fuel columns, the logged
/// meals list, a quick-add library, and a USDA custom-food search sheet.
class FuelScreen extends StatelessWidget {
  const FuelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = app.targets;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.clay,
          onRefresh: app.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl + 60),
            children: [
              // ----- Header -----
              Text(Seed.phaseLabel.toUpperCase(), style: AppType.label(AppColors.clay)),
              const SizedBox(height: AppSpacing.xs),
              Text('Fuel', style: AppType.display(34, weight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.md),

              // ----- Day total -----
              SoftCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionLabel(text: 'Calories today'),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(app.totalCal.round().toString(),
                                style: AppType.display(46, weight: FontWeight.w800, height: 1.0)),
                            const SizedBox(width: 6),
                            Text('/ ${t.calories} kcal',
                                style: AppType.body(15,
                                    color: AppColors.sageGrey, weight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ----- Mini macros row -----
              SoftCard(
                child: SizedBox(
                  height: 150,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FuelColumn(
                        label: 'Protein',
                        value: app.totalProtein,
                        target: t.protein.toDouble(),
                        color: AppColors.clay,
                        hero: true,
                        height: 110,
                      ),
                      FuelColumn(
                        label: 'Carbs',
                        value: app.totalCarbs,
                        target: t.carbs.toDouble(),
                        color: AppColors.amber,
                        height: 110,
                      ),
                      FuelColumn(
                        label: 'Fat',
                        value: app.totalFat,
                        target: t.fat.toDouble(),
                        color: AppColors.rose,
                        cap: true,
                        height: 110,
                      ),
                      FuelColumn(
                        label: 'Fiber',
                        value: app.totalFiber,
                        target: t.fiber.toDouble(),
                        color: AppColors.teal,
                        height: 110,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ----- Logged meals -----
              const SectionLabel(text: 'Logged today'),
              const SizedBox(height: AppSpacing.sm),
              if (app.meals.isEmpty)
                _EmptyMeals()
              else
                ...app.meals.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _MealRow(entry: m, onRemove: () => app.removeMeal(m.id!)),
                    )),
              const SizedBox(height: AppSpacing.lg),

              // ----- Quick-add library -----
              const SectionLabel(text: 'Quick add'),
              const SizedBox(height: AppSpacing.sm),
              FutureBuilder<List<Food>>(
                future: app.allFoods(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Center(
                          child: CircularProgressIndicator(color: AppColors.clay, strokeWidth: 2)),
                    );
                  }
                  final foods = snap.data!;
                  if (foods.isEmpty) {
                    return Text('No foods in your library yet.',
                        style: AppType.body(14, color: AppColors.sageGrey));
                  }
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: foods.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 1.7,
                    ),
                    itemBuilder: (context, i) {
                      final f = foods[i];
                      return _FoodTile(
                        food: f,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          app.addMeal(f);
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(SnackBar(content: Text('Added ${f.name}')));
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // ----- Add custom food -----
              PrimaryButton(
                label: 'Add custom food',
                icon: Icons.add_rounded,
                expand: true,
                onPressed: () => _openCustomFoodSheet(context, app),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCustomFoodSheet(BuildContext context, AppState app) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bone,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (_) => _UsdaSearchSheet(app: app),
    );
  }
}

class _EmptyMeals extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Row(
        children: [
          const Icon(Icons.restaurant_rounded, color: AppColors.sageGrey, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('No meals logged yet — add from the library below.',
                style: AppType.body(14, color: AppColors.sageGrey, weight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.entry, required this.onRemove});
  final MealEntry entry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 12, AppSpacing.sm, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name,
                    style: AppType.display(15, weight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${entry.cal.round()} kcal · ${entry.protein.round()}P  ${entry.carbs.round()}C  ${entry.fat.round()}F',
                  style: AppType.body(12, color: AppColors.sageGrey, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              onRemove();
            },
            icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.sageGrey),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({required this.food, required this.onTap});
  final Food food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(food.name,
              style: AppType.body(13, weight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${food.cal.round()} kcal',
                  style: AppType.body(12, color: AppColors.sageGrey, weight: FontWeight.w600)),
              const Spacer(),
              Text('${food.protein.round()}P',
                  style: AppType.display(14, weight: FontWeight.w800, color: AppColors.clay)),
            ],
          ),
        ],
      ),
    );
  }
}

/// USDA FoodData Central search, proxied via the coach server.
class _UsdaSearchSheet extends StatefulWidget {
  const _UsdaSearchSheet({required this.app});
  final AppState app;

  @override
  State<_UsdaSearchSheet> createState() => _UsdaSearchSheetState();
}

class _UsdaSearchSheetState extends State<_UsdaSearchSheet> {
  final _controller = TextEditingController();
  List<Food> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _searched = true;
    });
    final res = await widget.app.usda.search(q);
    if (!mounted) return;
    setState(() {
      _results = res;
      _loading = false;
    });
  }

  Future<void> _pick(Food food) async {
    await widget.app.addCustomFood(food);
    await widget.app.addMeal(food);
    if (!mounted) return;
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Added ${food.name}')));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.hairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Find a food', style: AppType.display(22, weight: FontWeight.w800)),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _run(),
                  decoration: InputDecoration(
                    hintText: 'e.g. chicken thigh, oats…',
                    filled: true,
                    fillColor: AppColors.card,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search_rounded, color: AppColors.clay),
                      onPressed: _run,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Powered by USDA FoodData Central. Falls back to DEMO_KEY — a free key '
                  'lifts rate limits (fdc.nal.usda.gov/api-key-signup).',
                  style: AppType.body(11, color: AppColors.sageGrey, height: 1.35),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(child: _resultsArea(scrollController)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _resultsArea(ScrollController controller) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.clay, strokeWidth: 2));
    }
    if (!_searched) {
      return Center(
        child: Text('Search USDA for a food to add.',
            style: AppType.body(14, color: AppColors.sageGrey)),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text('No matches or coach server offline.',
              textAlign: TextAlign.center,
              style: AppType.body(14, color: AppColors.sageGrey, weight: FontWeight.w500)),
        ),
      );
    }
    return ListView.separated(
      controller: controller,
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final f = _results[i];
        return _FoodTileWide(food: f, onTap: () => _pick(f));
      },
    );
  }
}

class _FoodTileWide extends StatelessWidget {
  const _FoodTileWide({required this.food, required this.onTap});
  final Food food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(food.name,
                    style: AppType.body(14, weight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${food.cal.round()} kcal · ${food.protein.round()}P  ${food.carbs.round()}C  ${food.fat.round()}F',
                  style: AppType.body(12, color: AppColors.sageGrey, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Icon(Icons.add_circle_outline_rounded, color: AppColors.clay),
        ],
      ),
    );
  }
}
