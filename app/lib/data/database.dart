import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';
import 'seed_data.dart';

/// Local persistence for The Log. All storage is on-device (sqflite).
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    if (kIsWeb) {
      // Web: the ffi-web factory (set in main()) persists to IndexedDB.
      // path_provider / dart:io are unavailable in the browser.
      _db = await openDatabase('the_log.db', version: 1, onCreate: _onCreate);
    } else {
      final docs = await getApplicationDocumentsDirectory();
      final path = p.join(docs.path, 'the_log.db');
      _db = await openDatabase(path, version: 1, onCreate: _onCreate);
    }
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE meals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        name TEXT NOT NULL,
        cal REAL, protein REAL, carbs REAL, fat REAL, fiber REAL,
        created_at INTEGER NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        exercise TEXT NOT NULL,
        set_index INTEGER NOT NULL,
        weight REAL, reps INTEGER
      );
    ''');
    await db.execute('''
      CREATE TABLE weights (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        weight REAL NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        bytes BLOB NOT NULL,
        created_at INTEGER NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE custom_foods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        cal REAL, protein REAL, carbs REAL, fat REAL, fiber REAL,
        custom INTEGER DEFAULT 1
      );
    ''');
    await db.execute('''
      CREATE TABLE checklist (
        date TEXT PRIMARY KEY,
        items TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE kv (
        k TEXT PRIMARY KEY,
        v TEXT NOT NULL
      );
    ''');
  }

  // ---------- Meals ----------
  Future<List<MealEntry>> mealsFor(String date) async {
    final d = await db;
    final rows = await d.query('meals', where: 'date = ?', whereArgs: [date], orderBy: 'created_at ASC');
    return rows.map(MealEntry.fromMap).toList();
  }

  Future<int> addMeal(MealEntry m) async {
    final d = await db;
    return d.insert('meals', m.toMap());
  }

  Future<void> removeMeal(int id) async {
    final d = await db;
    await d.delete('meals', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<MealEntry>> mealsBetween(String startDate, String endDate) async {
    final d = await db;
    final rows = await d.query('meals',
        where: 'date >= ? AND date <= ?', whereArgs: [startDate, endDate], orderBy: 'date ASC, created_at ASC');
    return rows.map(MealEntry.fromMap).toList();
  }

  // ---------- Sets ----------
  Future<List<SetEntry>> setsFor(String date) async {
    final d = await db;
    final rows = await d.query('sets', where: 'date = ?', whereArgs: [date], orderBy: 'id ASC');
    return rows.map(SetEntry.fromMap).toList();
  }

  Future<int> addSet(SetEntry s) async {
    final d = await db;
    return d.insert('sets', s.toMap());
  }

  Future<void> updateSet(SetEntry s) async {
    final d = await db;
    await d.update('sets', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
  }

  Future<void> removeSet(int id) async {
    final d = await db;
    await d.delete('sets', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Weights ----------
  Future<List<WeightEntry>> allWeights() async {
    final d = await db;
    final rows = await d.query('weights', orderBy: 'date ASC');
    return rows.map(WeightEntry.fromMap).toList();
  }

  Future<void> upsertWeight(String date, double weight) async {
    final d = await db;
    final existing = await d.query('weights', where: 'date = ?', whereArgs: [date]);
    if (existing.isEmpty) {
      await d.insert('weights', {'date': date, 'weight': weight});
    } else {
      await d.update('weights', {'weight': weight}, where: 'date = ?', whereArgs: [date]);
    }
  }

  Future<double?> weightFor(String date) async {
    final d = await db;
    final rows = await d.query('weights', where: 'date = ?', whereArgs: [date]);
    if (rows.isEmpty) return null;
    return (rows.first['weight'] as num).toDouble();
  }

  // ---------- Photos ----------
  Future<List<CheckinPhoto>> allPhotos() async {
    final d = await db;
    final rows = await d.query('photos', orderBy: 'created_at DESC');
    return rows.map(CheckinPhoto.fromMap).toList();
  }

  Future<int> addPhoto(CheckinPhoto photo) async {
    final d = await db;
    return d.insert('photos', photo.toMap());
  }

  Future<void> removePhoto(int id) async {
    final d = await db;
    await d.delete('photos', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Custom foods ----------
  Future<List<Food>> customFoods() async {
    final d = await db;
    final rows = await d.query('custom_foods', orderBy: 'name ASC');
    return rows.map(Food.fromMap).toList();
  }

  Future<int> addCustomFood(Food f) async {
    final d = await db;
    return d.insert('custom_foods', f.toMap());
  }

  Future<void> removeCustomFood(int id) async {
    final d = await db;
    await d.delete('custom_foods', where: 'id = ?', whereArgs: [id]);
  }

  /// Quick-library + custom foods combined.
  Future<List<Food>> allFoods() async {
    final custom = await customFoods();
    return [...Seed.mealLibrary, ...custom];
  }

  // ---------- Checklist ----------
  Future<ChecklistState> checklistFor(String date) async {
    final d = await db;
    final rows = await d.query('checklist', where: 'date = ?', whereArgs: [date]);
    if (rows.isEmpty) {
      return ChecklistState(date: date, items: {for (final i in Seed.checklistItems) i: false});
    }
    final state = ChecklistState.fromMap(rows.first);
    // Ensure all current items present.
    final merged = {for (final i in Seed.checklistItems) i: state.items[i] ?? false};
    return ChecklistState(date: date, items: merged);
  }

  Future<void> saveChecklist(ChecklistState state) async {
    final d = await db;
    await d.insert('checklist', state.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------- KV (settings: server url, day-type overrides, target overrides) ----------
  Future<String?> getKv(String key) async {
    final d = await db;
    final rows = await d.query('kv', where: 'k = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['v'] as String;
  }

  Future<void> setKv(String key, String value) async {
    final d = await db;
    await d.insert('kv', {'k': key, 'v': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
