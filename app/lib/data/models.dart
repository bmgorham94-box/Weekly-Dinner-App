import 'dart:convert';

/// Macro target set for a day type.
class MacroTargets {
  final int calories;
  final int protein;
  final int carbs;
  final int fat; // ceiling
  final int fiber;

  const MacroTargets({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
  });

  MacroTargets copyWith({int? calories, int? protein, int? carbs, int? fat, int? fiber}) {
    return MacroTargets(
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
    );
  }

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
      };

  factory MacroTargets.fromJson(Map<String, dynamic> j) => MacroTargets(
        calories: (j['calories'] as num).toInt(),
        protein: (j['protein'] as num).toInt(),
        carbs: (j['carbs'] as num).toInt(),
        fat: (j['fat'] as num).toInt(),
        fiber: (j['fiber'] as num).toInt(),
      );
}

/// One exercise within a day's split.
class Exercise {
  final String name;
  final String scheme; // e.g. "4x6-8"
  final bool unilateral; // shows "Lead with the LEFT" cue
  final int defaultSets;

  const Exercise(this.name, this.scheme, {this.unilateral = false, this.defaultSets = 3});
}

/// A weekday training day.
class TrainingDay {
  final int weekday; // 0=Sunday .. 6=Saturday
  final String title;
  final String focus;
  final bool rest;
  final bool legDay; // shows cramp banner
  final List<Exercise> exercises;

  const TrainingDay({
    required this.weekday,
    required this.title,
    required this.focus,
    required this.exercises,
    this.rest = false,
    this.legDay = false,
  });
}

/// A food item (quick-library or custom/USDA).
class Food {
  final int? id;
  final String name;
  final double cal;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final bool custom;

  const Food({
    this.id,
    required this.name,
    required this.cal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    this.custom = false,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'cal': cal,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'custom': custom ? 1 : 0,
      };

  factory Food.fromMap(Map<String, dynamic> m) => Food(
        id: m['id'] as int?,
        name: m['name'] as String,
        cal: (m['cal'] as num).toDouble(),
        protein: (m['protein'] as num).toDouble(),
        carbs: (m['carbs'] as num).toDouble(),
        fat: (m['fat'] as num).toDouble(),
        fiber: (m['fiber'] as num).toDouble(),
        custom: (m['custom'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toJson() => toMap();
}

/// A logged meal entry for a given day.
class MealEntry {
  final int? id;
  final String date; // yyyy-MM-dd
  final String name;
  final double cal;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final int createdAt; // epoch ms

  const MealEntry({
    this.id,
    required this.date,
    required this.name,
    required this.cal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'date': date,
        'name': name,
        'cal': cal,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'created_at': createdAt,
      };

  factory MealEntry.fromMap(Map<String, dynamic> m) => MealEntry(
        id: m['id'] as int?,
        date: m['date'] as String,
        name: m['name'] as String,
        cal: (m['cal'] as num).toDouble(),
        protein: (m['protein'] as num).toDouble(),
        carbs: (m['carbs'] as num).toDouble(),
        fat: (m['fat'] as num).toDouble(),
        fiber: (m['fiber'] as num).toDouble(),
        createdAt: (m['created_at'] as num).toInt(),
      );
}

/// A logged set for an exercise on a day.
class SetEntry {
  final int? id;
  final String date;
  final String exercise;
  final int setIndex;
  final double weight;
  final int reps;

  const SetEntry({
    this.id,
    required this.date,
    required this.exercise,
    required this.setIndex,
    required this.weight,
    required this.reps,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'date': date,
        'exercise': exercise,
        'set_index': setIndex,
        'weight': weight,
        'reps': reps,
      };

  factory SetEntry.fromMap(Map<String, dynamic> m) => SetEntry(
        id: m['id'] as int?,
        date: m['date'] as String,
        exercise: m['exercise'] as String,
        setIndex: (m['set_index'] as num).toInt(),
        weight: (m['weight'] as num).toDouble(),
        reps: (m['reps'] as num).toInt(),
      );
}

/// A bodyweight reading.
class WeightEntry {
  final int? id;
  final String date;
  final double weight;

  const WeightEntry({this.id, required this.date, required this.weight});

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'date': date,
        'weight': weight,
      };

  factory WeightEntry.fromMap(Map<String, dynamic> m) => WeightEntry(
        id: m['id'] as int?,
        date: m['date'] as String,
        weight: (m['weight'] as num).toDouble(),
      );
}

/// A check-in photo (stored locally; path on disk).
class CheckinPhoto {
  final int? id;
  final String date;
  final String path;
  final int createdAt;

  const CheckinPhoto({this.id, required this.date, required this.path, required this.createdAt});

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'date': date,
        'path': path,
        'created_at': createdAt,
      };

  factory CheckinPhoto.fromMap(Map<String, dynamic> m) => CheckinPhoto(
        id: m['id'] as int?,
        date: m['date'] as String,
        path: m['path'] as String,
        createdAt: (m['created_at'] as num).toInt(),
      );
}

/// Daily cramp-guard / rehab checklist state (one row per date).
class ChecklistState {
  final String date;
  final Map<String, bool> items;

  const ChecklistState({required this.date, required this.items});

  Map<String, dynamic> toMap() => {
        'date': date,
        'items': jsonEncode(items),
      };

  factory ChecklistState.fromMap(Map<String, dynamic> m) => ChecklistState(
        date: m['date'] as String,
        items: (jsonDecode(m['items'] as String) as Map).map((k, v) => MapEntry(k as String, v as bool)),
      );
}

/// A chat message in the Coach screen.
class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String text;
  ChatMessage(this.role, this.text);

  Map<String, dynamic> toJson() => {'role': role, 'text': text};
}
