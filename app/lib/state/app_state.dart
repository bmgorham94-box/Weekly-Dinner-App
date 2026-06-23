import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../a2ui/a2ui_renderer.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../data/seed_data.dart';
import '../services/coach_service.dart';
import '../services/usda_service.dart';

/// App-wide reactive state. Single source of truth for the day's logging,
/// targets, day-type, and the live coach connection.
class AppState extends ChangeNotifier {
  final AppDatabase _db = AppDatabase.instance;

  // ----- Coach connection -----
  String serverUrl = 'http://10.0.2.2:8787'; // Android emulator default; override in Settings
  late CoachService coach = CoachService(serverUrl);
  late UsdaService usda = UsdaService(serverUrl);

  // ----- The "today" context -----
  DateTime _date = DateTime.now();
  DateTime get date => _date;
  String get dateKey => DateFormat('yyyy-MM-dd').format(_date);

  bool _isTrainingDay = true; // Train/Rest toggle
  bool get isTrainingDay => _isTrainingDay;

  // Per-day session swaps (exercise name → replacement). Lives in memory + kv.
  final Map<String, String> _sessionSwaps = {};

  // Today's data
  List<MealEntry> meals = [];
  List<SetEntry> sets = [];
  ChecklistState checklist = ChecklistState(date: '', items: {});
  double? bodyweight;

  // Target overrides emitted by the coach (Apply). Null = use phase defaults.
  MacroTargets? _overrideTargets;

  bool _loading = true;
  bool get loading => _loading;

  TrainingDay get todaysSplit => Seed.dayFor(_date.weekday % 7);

  /// Active targets: coach override > day-type default.
  MacroTargets get targets {
    if (_overrideTargets != null) return _overrideTargets!;
    return _isTrainingDay ? Seed.trainingTargets : Seed.restTargets;
  }

  Future<void> init() async {
    // Load persisted server url + day type.
    final url = await _db.getKv('server_url');
    if (url != null && url.isNotEmpty) {
      serverUrl = url;
      coach.baseUrl = url;
      usda.baseUrl = url;
    }
    final dayType = await _db.getKv('day_type_${dateKey}');
    _isTrainingDay = dayType != null ? dayType == 'train' : !todaysSplit.rest;

    final overrideJson = await _db.getKv('targets_override_$dateKey');
    if (overrideJson != null) {
      try {
        _overrideTargets = MacroTargets.fromJson(jsonDecode(overrideJson));
      } catch (_) {}
    }
    final swapsJson = await _db.getKv('swaps_$dateKey');
    if (swapsJson != null) {
      try {
        (jsonDecode(swapsJson) as Map).forEach((k, v) => _sessionSwaps[k.toString()] = v.toString());
      } catch (_) {}
    }

    await _reloadDay();
    _loading = false;
    notifyListeners();
  }

  Future<void> _reloadDay() async {
    meals = await _db.mealsFor(dateKey);
    sets = await _db.setsFor(dateKey);
    checklist = await _db.checklistFor(dateKey);
    bodyweight = await _db.weightFor(dateKey);
    notifyListeners();
  }

  Future<void> refresh() => _reloadDay();

  // ----- Day type toggle -----
  Future<void> setTrainingDay(bool training) async {
    _isTrainingDay = training;
    await _db.setKv('day_type_$dateKey', training ? 'train' : 'rest');
    notifyListeners();
  }

  // ----- Server URL -----
  Future<void> setServerUrl(String url) async {
    serverUrl = url.trim();
    coach.baseUrl = serverUrl;
    usda.baseUrl = serverUrl;
    await _db.setKv('server_url', serverUrl);
    notifyListeners();
  }

  // ----- Macro totals -----
  double get totalCal => meals.fold(0, (s, m) => s + m.cal);
  double get totalProtein => meals.fold(0, (s, m) => s + m.protein);
  double get totalCarbs => meals.fold(0, (s, m) => s + m.carbs);
  double get totalFat => meals.fold(0, (s, m) => s + m.fat);
  double get totalFiber => meals.fold(0, (s, m) => s + m.fiber);

  // ----- Meals -----
  Future<void> addMeal(Food food) async {
    final entry = MealEntry(
      date: dateKey,
      name: food.name,
      cal: food.cal,
      protein: food.protein,
      carbs: food.carbs,
      fat: food.fat,
      fiber: food.fiber,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _db.addMeal(entry);
    await _reloadDay();
  }

  Future<void> removeMeal(int id) async {
    await _db.removeMeal(id);
    await _reloadDay();
  }

  Future<List<Food>> allFoods() => _db.allFoods();
  Future<void> addCustomFood(Food f) => _db.addCustomFood(f);

  // ----- Sets -----
  List<SetEntry> setsForExercise(String exercise) =>
      sets.where((s) => s.exercise == exercise).toList()..sort((a, b) => a.setIndex.compareTo(b.setIndex));

  Future<void> logSet(String exercise, int setIndex, double weight, int reps) async {
    final existing = sets.where((s) => s.exercise == exercise && s.setIndex == setIndex).toList();
    if (existing.isEmpty) {
      await _db.addSet(SetEntry(date: dateKey, exercise: exercise, setIndex: setIndex, weight: weight, reps: reps));
    } else {
      await _db.updateSet(SetEntry(id: existing.first.id, date: dateKey, exercise: exercise, setIndex: setIndex, weight: weight, reps: reps));
    }
    await _reloadDay();
  }

  Future<void> removeSet(int id) async {
    await _db.removeSet(id);
    await _reloadDay();
  }

  // ----- Checklist -----
  Future<void> toggleChecklist(String item) async {
    final items = Map<String, bool>.from(checklist.items);
    items[item] = !(items[item] ?? false);
    checklist = ChecklistState(date: dateKey, items: items);
    await _db.saveChecklist(checklist);
    notifyListeners();
  }

  int get checklistDone => checklist.items.values.where((v) => v).length;
  int get checklistTotal => checklist.items.length;

  // ----- Bodyweight -----
  Future<void> setBodyweight(double w) async {
    await _db.upsertWeight(dateKey, w);
    bodyweight = w;
    notifyListeners();
  }

  Future<List<WeightEntry>> allWeights() => _db.allWeights();

  // ----- Session swaps -----
  String resolveExercise(String name) => _sessionSwaps[name] ?? name;
  bool isSwapped(String name) => _sessionSwaps.containsKey(name);

  Future<void> swapExercise(String from, String to) async {
    _sessionSwaps[from] = to;
    await _db.setKv('swaps_$dateKey', jsonEncode(_sessionSwaps));
    notifyListeners();
  }

  // ----- Streaks -----
  Future<int> trainingStreak() async {
    // Count back consecutive days that have at least one logged set or were rest days.
    int streak = 0;
    var cursor = DateTime.now();
    for (int i = 0; i < 60; i++) {
      final key = DateFormat('yyyy-MM-dd').format(cursor);
      final daySets = await _db.setsFor(key);
      final isRest = Seed.dayFor(cursor.weekday % 7).rest;
      if (daySets.isNotEmpty) {
        streak++;
      } else if (isRest && i != 0) {
        // rest days don't break the streak but don't add either
      } else if (i == 0) {
        // today not yet logged — don't break, just stop counting forward
      } else {
        break;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<int> proteinStreak() async {
    int streak = 0;
    var cursor = DateTime.now();
    for (int i = 0; i < 60; i++) {
      final key = DateFormat('yyyy-MM-dd').format(cursor);
      final dayMeals = await _db.mealsFor(key);
      final p = dayMeals.fold<double>(0, (s, m) => s + m.protein);
      final target = Seed.dayFor(cursor.weekday % 7).rest ? Seed.restTargets.protein : Seed.trainingTargets.protein;
      if (p >= target * 0.9) {
        streak++;
      } else if (i == 0 && dayMeals.isEmpty) {
        // today incomplete — skip without breaking
      } else {
        break;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // ----- Live coach context (injected per request) -----
  Future<Map<String, dynamic>> buildCoachContext() async {
    final weights = await _db.allWeights();
    final recentWeight = weights.isNotEmpty ? weights.last.weight : null;
    return {
      'date': dateKey,
      'phase': Seed.phaseLabel,
      'phaseGoalWeight': Seed.phaseGoalWeight,
      'dayType': _isTrainingDay ? 'training' : 'rest',
      'splitToday': todaysSplit.title,
      'splitFocus': todaysSplit.focus,
      'currentBodyweight': recentWeight ?? bodyweight,
      'targets': targets.toJson(),
      'todayTotals': {
        'calories': totalCal.round(),
        'protein': totalProtein.round(),
        'carbs': totalCarbs.round(),
        'fat': totalFat.round(),
        'fiber': totalFiber.round(),
      },
      'checklistDone': '$checklistDone/$checklistTotal',
      'frequencyNote': Seed.frequencyNote,
      'notes': 'Left-leg piriformis rehab; EQ cramp risk (legs cramp-safe); consistency-after-travel is the core challenge.',
    };
  }

  Future<List<Map<String, dynamic>>> buildLogsPayload({int days = 14}) async {
    final out = <Map<String, dynamic>>[];
    for (int i = days - 1; i >= 0; i--) {
      final day = DateTime.now().subtract(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(day);
      final m = await _db.mealsFor(key);
      final s = await _db.setsFor(key);
      final w = await _db.weightFor(key);
      if (m.isEmpty && s.isEmpty && w == null) continue;
      out.add({
        'date': key,
        'split': Seed.dayFor(day.weekday % 7).title,
        'calories': m.fold<double>(0, (a, b) => a + b.cal).round(),
        'protein': m.fold<double>(0, (a, b) => a + b.protein).round(),
        'carbs': m.fold<double>(0, (a, b) => a + b.carbs).round(),
        'fat': m.fold<double>(0, (a, b) => a + b.fat).round(),
        'setsLogged': s.length,
        'bodyweight': w,
      });
    }
    return out;
  }

  // ----- A2UI Apply-event dispatch (coach → local state) -----
  Future<String?> handleA2Event(A2Event event) async {
    switch (event.action) {
      case 'set_targets':
        if (event.value is Map) {
          final v = (event.value as Map).cast<String, dynamic>();
          _overrideTargets = MacroTargets(
            calories: (v['calories'] as num?)?.toInt() ?? targets.calories,
            protein: (v['protein'] as num?)?.toInt() ?? targets.protein,
            carbs: (v['carbs'] as num?)?.toInt() ?? targets.carbs,
            fat: (v['fat'] as num?)?.toInt() ?? targets.fat,
            fiber: (v['fiber'] as num?)?.toInt() ?? targets.fiber,
          );
          await _db.setKv('targets_override_$dateKey', jsonEncode(_overrideTargets!.toJson()));
          notifyListeners();
          return 'Targets updated';
        }
        return null;
      case 'set_protein_target':
        final p = (event.value as num?)?.toInt();
        if (p != null) {
          _overrideTargets = targets.copyWith(protein: p);
          await _db.setKv('targets_override_$dateKey', jsonEncode(_overrideTargets!.toJson()));
          notifyListeners();
          return 'Protein target set to ${p}g';
        }
        return null;
      case 'swap_exercise':
        if (event.value is Map) {
          final v = (event.value as Map).cast<String, dynamic>();
          final from = v['from']?.toString();
          final to = v['to']?.toString();
          if (from != null && to != null) {
            await swapExercise(from, to);
            return 'Swapped $from → $to';
          }
        }
        return null;
      case 'log_food':
        if (event.value is Map) {
          final v = (event.value as Map).cast<String, dynamic>();
          await addMeal(Food(
            name: v['name']?.toString() ?? 'Coach add',
            cal: (v['cal'] as num?)?.toDouble() ?? 0,
            protein: (v['protein'] as num?)?.toDouble() ?? 0,
            carbs: (v['carbs'] as num?)?.toDouble() ?? 0,
            fat: (v['fat'] as num?)?.toDouble() ?? 0,
            fiber: (v['fiber'] as num?)?.toDouble() ?? 0,
          ));
          return 'Logged ${v['name']}';
        }
        return null;
      case 'toggle_checklist':
        final label = event.value?.toString();
        if (label != null && checklist.items.containsKey(label)) {
          await toggleChecklist(label);
          return null;
        }
        return null;
      case 'dismiss':
        return null;
      default:
        debugPrint('Unknown A2UI action: ${event.action}');
        return null;
    }
  }

  @override
  void dispose() {
    coach.dispose();
    super.dispose();
  }
}
