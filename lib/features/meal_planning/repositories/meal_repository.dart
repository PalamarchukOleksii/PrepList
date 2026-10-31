import 'package:preplist/features/meal_planning/models/meal.dart';
import 'package:preplist/core/database/app_database.dart';

class MealRepository {
  final AppDatabase _database = AppDatabase.instance;

  Future<List<Meal>> getAll() async {
    final db = await _database.database;

    final rows = await db.query('meals', orderBy: 'date ASC, id ASC');

    return rows
        .map((row) => Meal.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<Meal>> getByDate(String date) async {
    final db = await _database.database;

    final rows = await db.query(
      'meals',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'id ASC',
    );

    return rows
        .map((row) => Meal.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<int> insert(Meal meal) async {
    final db = await _database.database;
    final values = meal.toMap()..remove('id');

    return db.insert('meals', values);
  }

  Future<void> update(Meal meal) async {
    if (meal.id == null) {
      throw ArgumentError('Meal ID cannot be null');
    }

    final db = await _database.database;
    final values = meal.toMap()..remove('id');

    await db.update('meals', values, where: 'id = ?', whereArgs: [meal.id]);
  }

  Future<void> delete(int id) async {
    final db = await _database.database;

    await db.delete('meals', where: 'id = ?', whereArgs: [id]);
  }
}
