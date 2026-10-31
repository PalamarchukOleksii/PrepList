import 'package:preplist/features/meal_planning/models/meal.dart';
import 'package:preplist/features/recipes/models/recipe.dart';
import 'package:preplist/features/foods/models/swiss_food.dart';
import 'package:preplist/features/foods/repositories/food_repository.dart';
import 'package:preplist/features/recipes/repositories/recipe_repository.dart';

class NutritionCalculator {
  final FoodRepository database;
  final RecipeRepository recipeRepository;

  NutritionCalculator({
    FoodRepository? database,
    RecipeRepository? recipeRepository,
  }) : database = database ?? FoodRepository.instance,
       recipeRepository = recipeRepository ?? RecipeRepository();

  Future<NutritionSummary> forIngredients(
    List<RecipeIngredient> ingredients,
  ) async {
    var total = NutritionSummary.zero;

    for (final ingredient in ingredients) {
      if (ingredient.foodId == null) continue;
      if (ingredient.unit.toLowerCase() != 'g') continue;

      final grams = ingredient.grams;

      if (grams <= 0) continue;

      final food = await database.getFood(ingredient.foodId!);

      if (food == null) continue;

      total += NutritionSummary(
        calories: food.caloriesFor(grams),
        protein: food.proteinFor(grams),
        carbs: food.carbsFor(grams),
        fat: food.fatFor(grams),
      );
    }

    return total;
  }

  Future<NutritionSummary> forRecipe(Recipe recipe) async {
    return forIngredients(recipe.ingredients);
  }

  Future<NutritionSummary> forRecipeServing(Recipe recipe) async {
    final total = await forRecipe(recipe);
    final servings = recipe.servings > 0 ? recipe.servings : 1;

    return total / servings.toDouble();
  }

  Future<NutritionSummary> forMeal(Meal meal) async {
    if (meal.isRecipe) {
      if (meal.recipeId == null) return NutritionSummary.zero;

      final recipe = await recipeRepository.getById(meal.recipeId!);

      if (recipe == null) return NutritionSummary.zero;

      final servingNutrition = await forRecipeServing(recipe);
      final servings = meal.quantityValue;

      if (servings <= 0) return NutritionSummary.zero;

      return servingNutrition * servings;
    }

    if (meal.foodId == null || meal.unit.toLowerCase() != 'g') {
      return NutritionSummary.zero;
    }

    final grams = meal.quantityValue;

    if (grams <= 0) return NutritionSummary.zero;

    final SwissFood? food = await database.getFood(meal.foodId!);

    if (food == null) return NutritionSummary.zero;

    return NutritionSummary(
      calories: food.caloriesFor(grams),
      protein: food.proteinFor(grams),
      carbs: food.carbsFor(grams),
      fat: food.fatFor(grams),
    );
  }

  Future<NutritionSummary> forMeals(List<Meal> meals) async {
    var total = NutritionSummary.zero;

    for (final meal in meals) {
      total += await forMeal(meal);
    }

    return total;
  }
}

class NutritionSummary {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const NutritionSummary({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  static const zero = NutritionSummary(
    calories: 0,
    protein: 0,
    carbs: 0,
    fat: 0,
  );

  NutritionSummary operator +(NutritionSummary other) {
    return NutritionSummary(
      calories: calories + other.calories,
      protein: protein + other.protein,
      carbs: carbs + other.carbs,
      fat: fat + other.fat,
    );
  }

  NutritionSummary operator /(double divisor) {
    if (divisor == 0) return zero;

    return NutritionSummary(
      calories: calories / divisor,
      protein: protein / divisor,
      carbs: carbs / divisor,
      fat: fat / divisor,
    );
  }

  NutritionSummary operator *(double multiplier) {
    return NutritionSummary(
      calories: calories * multiplier,
      protein: protein * multiplier,
      carbs: carbs * multiplier,
      fat: fat * multiplier,
    );
  }

  String get formatted =>
      '${calories.round()} kcal · '
      'P ${protein.toStringAsFixed(1)} g · '
      'C ${carbs.toStringAsFixed(1)} g · '
      'F ${fat.toStringAsFixed(1)} g';
}
