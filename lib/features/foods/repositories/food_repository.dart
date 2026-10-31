import 'package:sqflite/sqflite.dart';

import 'package:preplist/core/database/app_database.dart';
import 'package:preplist/features/foods/models/swiss_food.dart';

class FoodRepository {
  FoodRepository._();

  static final FoodRepository instance = FoodRepository._();

  Future<bool> isImported() async {
    final db = await AppDatabase.instance.database;
    final result = await db.query(
      'metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['imported'],
      limit: 1,
    );

    return result.isNotEmpty && result.first['value'] == '1';
  }

  Future<String?> getImportedVersion() async {
    final db = await AppDatabase.instance.database;
    final result = await db.query(
      'metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['version'],
      limit: 1,
    );

    return result.isEmpty ? null : result.first['value'] as String?;
  }

  Future<int> getFoodCount() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) AS count FROM foods');
    return (result.first['count'] as int?) ?? 0;
  }

  Future<SwissFood?> getFood(int id) async {
    final db = await AppDatabase.instance.database;
    final result = await db.query(
      'foods',
      where: 'external_id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return result.isEmpty ? null : SwissFood.fromMap(result.first);
  }

  Future<List<SwissFood>> searchFoods(String query, {int limit = 50}) async {
    final db = await AppDatabase.instance.database;
    final term = '%${query.trim()}%';

    final results = await db.query(
      'foods',
      where: 'name LIKE ? OR synonyms LIKE ?',
      whereArgs: [term, term],
      orderBy: 'name COLLATE NOCASE',
      limit: limit,
    );

    return results.map(SwissFood.fromMap).toList();
  }

  Future<void> replaceAllFoods({
    required List<Map<String, dynamic>> foods,
    required String version,
  }) async {
    final db = await AppDatabase.instance.database;

    await db.transaction((txn) async {
      final batch = txn.batch();

      batch.delete('foods');

      for (final food in foods) {
        batch.insert('foods', food);
      }

      batch.insert('metadata', {
        'key': 'version',
        'value': version,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      batch.insert('metadata', {
        'key': 'imported',
        'value': '1',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await batch.commit(noResult: true);
    });
  }
}
