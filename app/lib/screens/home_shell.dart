import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'today_screen.dart';
import 'train_screen.dart';
import 'fuel_screen.dart';
import 'progress_screen.dart';
import 'coach_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _screens = const [
    TodayScreen(),
    TrainScreen(),
    FuelScreen(),
    ProgressScreen(),
  ];

  void _openCoach() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CoachScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.clay)),
      );
    }

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCoach,
        backgroundColor: AppColors.forest,
        foregroundColor: AppColors.bone,
        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
        label: Text('Coach', style: AppType.body(14, weight: FontWeight.w700, color: AppColors.bone)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.bone,
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                _tab(0, Icons.today_rounded, 'Today'),
                _tab(1, Icons.fitness_center_rounded, 'Train'),
                _tab(2, Icons.local_fire_department_rounded, 'Fuel'),
                _tab(3, Icons.insights_rounded, 'Progress'),
                _settingsTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(int i, IconData icon, String label) {
    final selected = _index == i;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _index = i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: selected ? AppColors.clay : AppColors.sageGrey),
            const SizedBox(height: 3),
            Text(label, style: AppType.body(10, weight: FontWeight.w700, color: selected ? AppColors.clay : AppColors.sageGrey)),
          ],
        ),
      ),
    );
  }

  Widget _settingsTab() {
    return Expanded(
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.tune_rounded, size: 22, color: AppColors.sageGrey),
            const SizedBox(height: 3),
            Text('Setup', style: AppType.body(10, weight: FontWeight.w700, color: AppColors.sageGrey)),
          ],
        ),
      ),
    );
  }
}
