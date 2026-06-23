import 'models.dart';

/// Static program data for "The Log" — Phase 1 · Shape Back.
class Seed {
  // ---- Macro targets (Phase 1, current) ----
  static const trainingTargets = MacroTargets(calories: 2650, protein: 300, carbs: 235, fat: 70, fiber: 40);
  static const restTargets = MacroTargets(calories: 2300, protein: 270, carbs: 150, fat: 70, fiber: 40);

  static const phaseLabel = 'Phase 1 · Shape Back';
  static const phaseGoalWeight = 184.0; // dashed reference line on the trend chart

  // ---- Rehab / cramp-guard checklist ----
  static const checklistItems = <String>[
    'Electrolytes',
    'Magnesium (PM)',
    'Dynamic warm-up',
    'Row (easy)',
    'Piriformis stretch sequence',
    'Sitting breaks + cushion',
  ];

  // ---- Frequency note ----
  static const frequencyNote =
      'Chest 2× · Shoulders 2× · Arms 2× · Rear Delts 3× · Legs 1× cramp-safe';

  // ---- Training split (0=Sunday) ----
  static const List<TrainingDay> split = [
    TrainingDay(
      weekday: 0,
      title: 'Rest + Walk',
      focus: 'Recovery · dog walk · meal prep',
      rest: true,
      exercises: [],
    ),
    TrainingDay(
      weekday: 1,
      title: 'Chest + Triceps',
      focus: 'Push',
      exercises: [
        Exercise('Incline Barbell Press', '4x6-8', defaultSets: 4),
        Exercise('Flat DB Press', '4x8-10', defaultSets: 4),
        Exercise('Weighted Chest Dips', '3x8-12'),
        Exercise('Low-to-High Cable Fly', '3x12-15'),
        Exercise('Close-Grip Bench', '4x8-10', defaultSets: 4),
        Exercise('Overhead Cable Ext.', '3x12-15'),
        Exercise('Tricep Pushdown (rope)', '3x15'),
      ],
    ),
    TrainingDay(
      weekday: 2,
      title: 'Back Width + Biceps',
      focus: 'Pull',
      exercises: [
        Exercise('Weighted Pull-Ups', '4x6-10', defaultSets: 4),
        Exercise('Wide-Grip Lat Pulldown', '4x10-12', defaultSets: 4),
        Exercise('Straight-Arm Pulldown', '4x15', defaultSets: 4),
        Exercise('1-Arm DB Row (hip pull)', '4x10 ea', unilateral: true, defaultSets: 4),
        Exercise('Seated Cable Row (wide)', '3x12'),
        Exercise('EZ-Bar Curl', '4x10', defaultSets: 4),
        Exercise('Incline DB Curl', '3x12'),
        Exercise('Hammer Curl', '3x12'),
      ],
    ),
    TrainingDay(
      weekday: 3,
      title: 'Legs — Cramp-Safe',
      focus: 'Lower (EQ cramp-safe)',
      legDay: true,
      exercises: [
        Exercise('Leg Press (moderate)', '3x12-15'),
        Exercise('Hip Thrust', '3x12-15'),
        Exercise('Walking Lunges (light)', '2x10-12 ea', unilateral: true, defaultSets: 2),
        Exercise('Leg Curl', '3x12-15'),
        Exercise('Leg Extension', '3x15-20'),
        Exercise('Standing Calf Raise', '3x15-20'),
      ],
    ),
    TrainingDay(
      weekday: 4,
      title: 'Shoulders + Rear Delts',
      focus: 'Delts',
      exercises: [
        Exercise('Seated DB Overhead Press', '4x8-10', defaultSets: 4),
        Exercise('Reverse Pec Deck', '4x12-15', defaultSets: 4),
        Exercise('Cable Face Pulls', '4x20-25', defaultSets: 4),
        Exercise('Bent-Over Rear Delt Fly', '4x15-20', defaultSets: 4),
        Exercise('Cable Lateral Raise (1-arm)', '4x15 ea', unilateral: true, defaultSets: 4),
        Exercise('Wide-Grip Upright Row', '3x12'),
        Exercise('Barbell Shrug', '3x12-15'),
      ],
    ),
    TrainingDay(
      weekday: 5,
      title: 'Chest + Shoulders + Arms + Core',
      focus: 'Upper + core',
      exercises: [
        Exercise('Flat Barbell Bench', '4x8-12', defaultSets: 4),
        Exercise('Low-to-High Cable Fly', '4x12-15', defaultSets: 4),
        Exercise('Pec Deck', '3x15'),
        Exercise('Cable Lateral Raise (1-arm)', '3x15 ea', unilateral: true),
        Exercise('Cable Face Pulls', '3x20-25'),
        Exercise('EZ-Bar Curl', '3x10-12'),
        Exercise('Concentration Curl', '3x12'),
        Exercise('Skull Crusher', '3x10-12'),
        Exercise('Tricep Pushdown (bar)', '3x15'),
        Exercise('Stomach Vacuum', '3-5x30-60s', defaultSets: 4),
        Exercise('Hanging Leg Raise', '4x15', defaultSets: 4),
        Exercise('Cable Crunch', '3x20'),
      ],
    ),
    TrainingDay(
      weekday: 6,
      title: 'Back Thickness + Rear Delts',
      focus: 'Pull (thickness)',
      exercises: [
        Exercise('Conventional Deadlift', '4x5', defaultSets: 4),
        Exercise('Barbell Bent-Over Row', '4x8-10', defaultSets: 4),
        Exercise('T-Bar Row', '3x10'),
        Exercise('Chest-Supported DB Row', '3x12'),
        Exercise('Reverse Pec Deck', '4x15-20', defaultSets: 4),
        Exercise('Cable Face Pulls', '3x20'),
        Exercise('DB Pullovers', '3x12'),
      ],
    ),
  ];

  static TrainingDay dayFor(int weekday) => split[weekday % 7];

  // ---- Meal quick-library (per serving: cal, protein, carbs, fat, fiber) ----
  static const List<Food> mealLibrary = [
    Food(name: 'Starbucks cold brew', cal: 230, protein: 3, carbs: 26, fat: 11, fiber: 0),
    Food(name: 'Nurri can', cal: 150, protein: 30, carbs: 3, fat: 2.5, fiber: 0),
    Food(name: 'MFF Beast Mode Breakfast', cal: 430, protein: 49, carbs: 28, fat: 13, fiber: 3),
    Food(name: 'MFF Carrot Cake Oatmeal', cal: 460, protein: 37, carbs: 48, fat: 13, fiber: 8),
    Food(name: 'MFF Harissa Chicken Bowl', cal: 400, protein: 54, carbs: 30, fat: 7, fiber: 6),
    Food(name: 'MFF Moroccan Chicken', cal: 420, protein: 55, carbs: 32, fat: 8, fiber: 5),
    Food(name: 'MFF Marine Corps Mash', cal: 490, protein: 51, carbs: 37, fat: 15, fiber: 3),
    Food(name: 'MFF Boujee Mac', cal: 530, protein: 50, carbs: 46, fat: 17, fiber: 3),
    Food(name: 'Post-WO shake (whey+banana)', cal: 330, protein: 48, carbs: 33, fat: 3, fiber: 3),
    Food(name: 'Griddle dinner (anchor)', cal: 600, protein: 60, carbs: 35, fat: 18, fiber: 10),
    Food(name: 'Banana', cal: 105, protein: 1, carbs: 27, fat: 0, fiber: 3),
    Food(name: 'Rice cakes (2)', cal: 70, protein: 1, carbs: 15, fat: 0, fiber: 0),
    Food(name: 'Greek yogurt + berries', cal: 150, protein: 16, carbs: 18, fat: 1, fiber: 2),
    Food(name: 'Griddle eggs + turkey', cal: 380, protein: 42, carbs: 6, fat: 20, fiber: 0),
  ];
}
