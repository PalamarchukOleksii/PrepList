import 'package:sqflite/sqflite.dart';

import 'package:preplist/features/recipes/models/recipe.dart';
import 'package:preplist/core/database/app_database.dart';

class RecipeRepository {
  final AppDatabase _database = AppDatabase.instance;

  Future<List<Recipe>> getAll({String query = ''}) async {
    final db = await _database.database;
    final trimmed = query.trim();

    final rows = await db.query(
      'recipes',
      where: trimmed.isEmpty ? null : 'name LIKE ?',
      whereArgs: trimmed.isEmpty ? null : ['%$trimmed%'],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    final recipes = <Recipe>[];

    for (final row in rows) {
      recipes.add(await _getRecipeWithIngredients(db, row));
    }

    return recipes;
  }

  Future<Recipe?> getById(int id) async {
    final db = await _database.database;

    final rows = await db.query(
      'recipes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return _getRecipeWithIngredients(db, rows.first);
  }

  Future<Recipe> _getRecipeWithIngredients(
    DatabaseExecutor db,
    Map<String, Object?> row,
  ) async {
    final ingredientRows = await db.query(
      'recipe_ingredients',
      where: 'recipe_id = ?',
      whereArgs: [row['id']],
      orderBy: 'id ASC',
    );

    return Recipe.fromMap(
      Map<String, dynamic>.from(row),
      ingredients: ingredientRows
          .map(
            (ingredient) =>
                RecipeIngredient.fromMap(Map<String, dynamic>.from(ingredient)),
          )
          .toList(),
    );
  }

  Future<int> insert(Recipe recipe) async {
    final db = await _database.database;

    return db.transaction((txn) async {
      final recipeId = await txn.insert('recipes', recipe.toMap());

      for (final ingredient in recipe.ingredients) {
        await txn.insert('recipe_ingredients', {
          'recipe_id': recipeId,
          'food_id': ingredient.foodId,
          'name': ingredient.name,
          'amount': ingredient.amount,
          'unit': ingredient.unit,
        });
      }

      return recipeId;
    });
  }

  Future<void> update(Recipe recipe) async {
    final recipeId = recipe.id;

    if (recipeId == null) {
      throw ArgumentError('Recipe ID cannot be null');
    }

    final db = await _database.database;

    await db.transaction((txn) async {
      await txn.update(
        'recipes',
        recipe.toMap(),
        where: 'id = ?',
        whereArgs: [recipeId],
      );

      await txn.delete(
        'recipe_ingredients',
        where: 'recipe_id = ?',
        whereArgs: [recipeId],
      );

      for (final ingredient in recipe.ingredients) {
        await txn.insert('recipe_ingredients', {
          'recipe_id': recipeId,
          'food_id': ingredient.foodId,
          'name': ingredient.name,
          'amount': ingredient.amount,
          'unit': ingredient.unit,
        });
      }
    });
  }

  Future<void> delete(int id) async {
    final db = await _database.database;

    await db.delete('recipes', where: 'id = ?', whereArgs: [id]);
  }
}
