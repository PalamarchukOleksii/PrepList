import 'package:sqflite/sqflite.dart';

import 'package:preplist/core/database/app_database.dart';
import 'package:preplist/features/foods/models/swiss_food.dart';

class FoodRepository {
  FoodRepository._();

  static final FoodRepository instance = FoodRepository._();

  static const _choiceKey = 'import_choice';
  static const choiceSwiss = 'swiss';
  static const choiceSkipped = 'skipped';

  // ---------------------------------------------------------------------------
  // Metadata helpers
  // ---------------------------------------------------------------------------

  Future<String?> _getMeta(String key) async {
    final db = await AppDatabase.instance.database;
    final result = await db.query(
      'metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    return result.isEmpty ? null : result.first['value'] as String?;
  }

  Future<void> _setMeta(String key, String value) async {
    final db = await AppDatabase.instance.database;
    await db.insert('metadata', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------------------------------------------------------------------------
  // Swiss database state
  // ---------------------------------------------------------------------------

  Future<bool> isImported() async => (await _getMeta('imported')) == '1';

  Future<String?> getImportedVersion() => _getMeta('version');

  /// True once the user has made the first-run decision, or when the Swiss
  /// database was already imported by an earlier version of the app.
  Future<bool> hasImportChoice() async {
    if (await isImported()) return true;
    return (await _getMeta(_choiceKey)) != null;
  }

  Future<void> setImportChoice(String choice) => _setMeta(_choiceKey, choice);

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  Future<int> getFoodCount({String? source}) async {
    final db = await AppDatabase.instance.database;
    final result = source == null
        ? await db.rawQuery('SELECT COUNT(*) AS count FROM foods')
        : await db.rawQuery(
            'SELECT COUNT(*) AS count FROM foods WHERE source = ?',
            [source],
          );

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

  /// Searches all foods. The user's own foods are listed first.
  Future<List<SwissFood>> searchFoods(String query, {int limit = 50}) async {
    final db = await AppDatabase.instance.database;
    final term = '%${query.trim()}%';

    final results = await db.query(
      'foods',
      where: 'name LIKE ? OR synonyms LIKE ?',
      whereArgs: [term, term],
      orderBy:
          "CASE source WHEN 'custom' THEN 0 ELSE 1 END, name COLLATE NOCASE",
      limit: limit,
    );

    return results.map(SwissFood.fromMap).toList();
  }

  Future<List<SwissFood>> getCustomFoods() async {
    final db = await AppDatabase.instance.database;
    final results = await db.query(
      'foods',
      where: 'source = ?',
      whereArgs: ['custom'],
      orderBy: 'name COLLATE NOCASE',
    );

    return results.map(SwissFood.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // Custom foods
  // ---------------------------------------------------------------------------

  /// Creates a user-defined food. Custom foods use negative IDs so they can
  /// never collide with the (positive) IDs of the Swiss database.
  Future<SwissFood> createCustomFood({
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    final db = await AppDatabase.instance.database;

    return db.transaction((txn) async {
      // IDs are never reused, even after a food is deleted, so old recipes
      // can't end up pointing at a different food.
      final minResult = await txn.rawQuery(
        'SELECT MIN(external_id) AS min_id FROM foods',
      );
      final minInTable = (minResult.first['min_id'] as int?) ?? 0;

      final metaResult = await txn.query(
        'metadata',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['last_custom_id'],
        limit: 1,
      );
      final lastUsed = metaResult.isEmpty
          ? 0
          : int.tryParse(metaResult.first['value'] as String? ?? '') ?? 0;

      var lowest = minInTable < lastUsed ? minInTable : lastUsed;
      if (lowest > 0) lowest = 0;

      final id = lowest - 1;

      await txn.insert('metadata', {
        'key': 'last_custom_id',
        'value': '$id',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final food = SwissFood(
        id: id,
        name: name.trim(),
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        source: 'custom',
      );

      await txn.insert('foods', _toRow(food));

      return food;
    });
  }

  Future<void> updateCustomFood(SwissFood food) async {
    if (!food.isCustom) return;

    final db = await AppDatabase.instance.database;
    await db.update(
      'foods',
      _toRow(food),
      where: 'external_id = ? AND source = ?',
      whereArgs: [food.id, 'custom'],
    );
  }

  /// Deletes a custom food. Recipes and meals that used it keep their name but
  /// no longer contribute to nutrition totals.
  Future<void> deleteCustomFood(int id) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'foods',
      where: 'external_id = ? AND source = ?',
      whereArgs: [id, 'custom'],
    );
  }

  Map<String, Object?> _toRow(SwissFood food) => {
    'external_id': food.id,
    'name': food.name,
    'synonyms': food.synonyms.join('|'),
    'calories': food.calories,
    'protein': food.protein,
    'carbs': food.carbs,
    'fat': food.fat,
    'source': food.source,
  };

  // ---------------------------------------------------------------------------
  // Swiss import
  // ---------------------------------------------------------------------------

  /// Replaces the imported Swiss foods. Custom foods are left untouched.
  Future<void> replaceAllFoods({
    required List<Map<String, dynamic>> foods,
    required String version,
  }) async {
    final db = await AppDatabase.instance.database;

    await db.transaction((txn) async {
      final batch = txn.batch();

      batch.delete('foods', where: 'source = ?', whereArgs: ['swiss']);

      for (final food in foods) {
        batch.insert('foods', {...food, 'source': 'swiss'});
      }

      batch.insert('metadata', {
        'key': 'version',
        'value': version,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      batch.insert('metadata', {
        'key': 'imported',
        'value': '1',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      batch.insert('metadata', {
        'key': _choiceKey,
        'value': choiceSwiss,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await batch.commit(noResult: true);
    });
  }
}
