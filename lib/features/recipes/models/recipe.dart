class Recipe {
  final int? id;
  final String name;
  final String description;
  final String instructions;
  final int prepMinutes;
  final int cookMinutes;
  final int servings;
  final List<RecipeIngredient> ingredients;

  const Recipe({
    this.id,
    required this.name,
    this.description = '',
    this.instructions = '',
    this.prepMinutes = 0,
    this.cookMinutes = 0,
    this.servings = 1,
    this.ingredients = const [],
  });

  factory Recipe.fromMap(
    Map<String, dynamic> map, {
    List<RecipeIngredient> ingredients = const [],
  }) {
    return Recipe(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      instructions: map['instructions'] as String? ?? '',
      prepMinutes: (map['prep_minutes'] as num?)?.toInt() ?? 0,
      cookMinutes: (map['cook_minutes'] as num?)?.toInt() ?? 0,
      servings: (map['servings'] as num?)?.toInt() ?? 1,
      ingredients: ingredients,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'instructions': instructions,
      'prep_minutes': prepMinutes,
      'cook_minutes': cookMinutes,
      'servings': servings,
    };
  }
}

class RecipeIngredient {
  final int? id;
  final int? recipeId;
  final int? foodId;
  final String name;
  final String amount;
  final String unit;

  const RecipeIngredient({
    this.id,
    this.recipeId,
    this.foodId,
    required this.name,
    this.amount = '',
    this.unit = 'g',
  });

  double get grams {
    if (unit.toLowerCase() != 'g') return 0;

    return double.tryParse(amount.replaceAll(',', '.')) ?? 0;
  }

  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    return RecipeIngredient(
      id: map['id'] as int?,
      recipeId: map['recipe_id'] as int?,
      foodId: map['food_id'] as int?,
      name: map['name'] as String? ?? '',
      amount: map['amount'] as String? ?? '',
      unit: map['unit'] as String? ?? 'g',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recipe_id': recipeId,
      'food_id': foodId,
      'name': name,
      'amount': amount,
      'unit': unit,
    };
  }
}
