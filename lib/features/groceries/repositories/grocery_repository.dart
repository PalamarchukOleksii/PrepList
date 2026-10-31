import 'package:preplist/core/database/app_database.dart';
import 'package:preplist/features/recipes/models/recipe.dart';

import 'package:preplist/features/meal_planning/repositories/meal_repository.dart';
import 'package:preplist/features/recipes/repositories/recipe_repository.dart';

class GroceryItem {
  final int id;
  final String itemKey;
  final String name;
  final String amount;
  final String unit;
  final bool isBought;
  final bool inventoryAdded;

  const GroceryItem({
    required this.id,
    required this.itemKey,
    required this.name,
    required this.amount,
    required this.unit,
    required this.isBought,
    required this.inventoryAdded,
  });

  factory GroceryItem.fromMap(Map<String, dynamic> map) {
    return GroceryItem(
      id: map['id'] as int,
      itemKey: map['item_key'] as String,
      name: map['name'] as String,
      amount: map['amount'] as String? ?? '',
      unit: map['unit'] as String? ?? '',
      isBought: (map['is_bought'] as int? ?? 0) == 1,
      inventoryAdded: (map['inventory_added'] as int? ?? 0) == 1,
    );
  }
}

class _GroceryDraft {
  final String name;
  final String unit;
  double? numericAmount;
  String amount;

  _GroceryDraft({
    required this.name,
    required this.unit,
    required this.amount,
    this.numericAmount,
  });
}

class GroceryRepository {
  final AppDatabase _database = AppDatabase.instance;
  final MealRepository _mealRepository = MealRepository();
  final RecipeRepository _recipeRepository = RecipeRepository();

  String _normalize(String value) => value.trim().toLowerCase();

  String _makeKey(String name, String unit) {
    return '${_normalize(name)}|${_normalize(unit)}';
  }

  double? _parseAmount(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  String _formatAmount(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  Future<List<GroceryItem>> getAll() async {
    final db = await _database.database;

    final rows = await db.query(
      'grocery_items',
      orderBy: 'is_bought ASC, name COLLATE NOCASE ASC',
    );

    return rows.map(GroceryItem.fromMap).toList();
  }

  Future<void> syncFromFuturePlan() async {
    final meals = await _mealRepository.getAll();
    final recipes = <int, Recipe>{};

    final today = _dateKey(DateTime.now());
    final futureMeals = meals.where((meal) => meal.date.compareTo(today) >= 0);

    final grouped = <String, _GroceryDraft>{};

    void addIngredient(String name, String amount, String unit) {
      final cleanName = name.trim();
      if (cleanName.isEmpty) return;

      final cleanUnit = unit.trim();
      final key = _makeKey(cleanName, cleanUnit);
      final parsedAmount = _parseAmount(amount);
      final existing = grouped[key];

      if (existing == null) {
        grouped[key] = _GroceryDraft(
          name: cleanName,
          unit: cleanUnit,
          amount: amount.trim(),
          numericAmount: parsedAmount,
        );
        return;
      }

      if (existing.numericAmount != null && parsedAmount != null) {
        existing.numericAmount = existing.numericAmount! + parsedAmount;
        existing.amount = _formatAmount(existing.numericAmount!);
      } else if (existing.amount.isEmpty) {
        existing.amount = amount.trim();
      }
    }

    for (final meal in futureMeals) {
      if (meal.isRecipe && meal.recipeId != null) {
        final recipeId = meal.recipeId!;

        final recipe =
            recipes[recipeId] ?? await _recipeRepository.getById(recipeId);

        if (recipe == null) continue;

        recipes[recipeId] = recipe;

        final multiplier = _parseAmount(meal.quantity) ?? 1;

        for (final ingredient in recipe.ingredients) {
          final baseAmount = _parseAmount(ingredient.amount);

          final amount = baseAmount == null
              ? ingredient.amount
              : _formatAmount(baseAmount * multiplier);

          addIngredient(ingredient.name, amount, ingredient.unit);
        }
      } else {
        addIngredient(meal.name, meal.quantity, meal.unit);
      }
    }

    final db = await _database.database;

    await db.transaction((txn) async {
      final existingRows = await txn.query('grocery_items');

      final existingByKey = <String, Map<String, dynamic>>{
        for (final row in existingRows) row['item_key'] as String: row,
      };

      // Get items already available in inventory.
      final inventoryRows = await txn.query('inventory_items');

      final inventoryKeys = inventoryRows
          .map((row) => row['item_key'] as String)
          .toSet();

      // Remove old, unbought grocery items.
      await txn.delete('grocery_items', where: 'is_bought = 0');

      for (final entry in grouped.entries) {
        final key = entry.key;
        final draft = entry.value;
        final previous = existingByKey[key];

        // Don't recreate items already in inventory.
        if (inventoryKeys.contains(key)) continue;

        final amount = draft.numericAmount == null
            ? draft.amount
            : _formatAmount(draft.numericAmount!);

        if (previous != null && (previous['is_bought'] as int? ?? 0) == 1) {
          await txn.update(
            'grocery_items',
            {'name': draft.name, 'amount': amount, 'unit': draft.unit},
            where: 'item_key = ?',
            whereArgs: [key],
          );
        } else {
          await txn.insert('grocery_items', {
            'item_key': key,
            'name': draft.name,
            'amount': amount,
            'unit': draft.unit,
            'is_bought': 0,
            'inventory_added': 0,
          });
        }
      }
    });
  }

  Future<void> toggleBought(int groceryId) async {
    final db = await _database.database;

    await db.rawUpdate(
      '''
      UPDATE grocery_items
      SET is_bought = CASE WHEN is_bought = 1 THEN 0 ELSE 1 END
      WHERE id = ?
      ''',
      [groceryId],
    );
  }

  Future<void> addBoughtToInventory(int groceryId) async {
    final db = await _database.database;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'grocery_items',
        where: 'id = ?',
        whereArgs: [groceryId],
        limit: 1,
      );

      if (rows.isEmpty) return;

      final grocery = rows.first;

      final isBought = (grocery['is_bought'] as int? ?? 0) == 1;
      final alreadyAdded = (grocery['inventory_added'] as int? ?? 0) == 1;

      if (!isBought || alreadyAdded) return;

      final itemKey = grocery['item_key'] as String;
      final amount = grocery['amount'] as String? ?? '';
      final unit = grocery['unit'] as String? ?? '';

      final inventoryRows = await txn.query(
        'inventory_items',
        where: 'item_key = ?',
        whereArgs: [itemKey],
        limit: 1,
      );

      if (inventoryRows.isEmpty) {
        await txn.insert('inventory_items', {
          'item_key': itemKey,
          'name': grocery['name'],
          'amount': amount,
          'unit': unit,
        });
      } else {
        final oldAmount = inventoryRows.first['amount'] as String? ?? '';
        final oldNumber = _parseAmount(oldAmount);
        final newNumber = _parseAmount(amount);

        final combinedAmount = oldNumber != null && newNumber != null
            ? _formatAmount(oldNumber + newNumber)
            : amount.isNotEmpty
            ? amount
            : oldAmount;

        await txn.update(
          'inventory_items',
          {'amount': combinedAmount, 'unit': unit},
          where: 'item_key = ?',
          whereArgs: [itemKey],
        );
      }

      // Remove the item from groceries after inventory transfer.
      await txn.delete(
        'grocery_items',
        where: 'id = ?',
        whereArgs: [groceryId],
      );
    });
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
