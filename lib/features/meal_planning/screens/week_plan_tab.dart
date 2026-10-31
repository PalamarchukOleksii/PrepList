import 'package:flutter/material.dart';
import 'package:preplist/core/ui/top_message.dart';

import 'package:preplist/features/meal_planning/repositories/meal_repository.dart';
import 'package:preplist/features/recipes/repositories/recipe_repository.dart';
import 'package:preplist/features/nutrition/services/nutrition_calculator.dart';
import 'package:preplist/features/meal_planning/models/meal.dart';
import 'package:preplist/features/recipes/models/recipe.dart';
import 'package:preplist/features/foods/models/swiss_food.dart';
import 'package:preplist/features/recipes/widgets/nutrition_summary_view.dart';

import 'package:preplist/features/foods/widgets/food_picker_dialog.dart';

class WeekPlanTab extends StatefulWidget {
  const WeekPlanTab({super.key});

  @override
  State<WeekPlanTab> createState() => _WeekPlanTabState();
}

class _WeekPlanTabState extends State<WeekPlanTab> {
  final MealRepository _mealRepository = MealRepository();
  final RecipeRepository _recipeRepository = RecipeRepository();
  final NutritionCalculator _nutritionCalculator = NutritionCalculator();

  DateTime _selectedDate = _today();
  bool _isLoading = true;

  List<Meal> _meals = [];

  NutritionSummary _dailyNutrition = NutritionSummary.zero;
  Map<int, NutritionSummary> _mealNutrition = {};

  final List<String> _categories = ['Breakfast', 'Lunch', 'Dinner', 'Snacks'];

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);

    return normalized.subtract(
      Duration(days: normalized.weekday - DateTime.monday),
    );
  }

  DateTime _endOfWeek(DateTime date) {
    return _startOfWeek(date).add(const Duration(days: 6));
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  bool _isPastDate(DateTime date) {
    return date.isBefore(_today());
  }

  List<Meal> _mealsForDate(String category) {
    return _meals.where((meal) {
      return meal.category == category && meal.date == _dateKey(_selectedDate);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadMeals();
  }

  Future<void> _loadMeals() async {
    try {
      final meals = await _mealRepository.getByDate(_dateKey(_selectedDate));

      final nutritionResults = await Future.wait(
        meals.map(_nutritionCalculator.forMeal),
      );

      var dailyTotal = NutritionSummary.zero;
      final nutritionByMeal = <int, NutritionSummary>{};

      for (var i = 0; i < meals.length; i++) {
        final nutrition = nutritionResults[i];

        dailyTotal += nutrition;

        final id = meals[i].id;

        if (id != null) {
          nutritionByMeal[id] = nutrition;
        }
      }

      if (!mounted) return;

      setState(() {
        _meals = meals;
        _dailyNutrition = dailyTotal;
        _mealNutrition = nutritionByMeal;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showError('Failed to load meals: $e');
    }
  }

  Future<void> _loadSelectedDateMeals() async {
    setState(() {
      _isLoading = true;
    });

    await _loadMeals();
  }

  Future<void> _changeWeek(int offset) async {
    final currentWeek = _startOfWeek(_today());
    final targetDate = _selectedDate.add(Duration(days: offset * 7));
    final targetWeek = _startOfWeek(targetDate);

    if (targetWeek.isBefore(currentWeek)) return;

    setState(() {
      _selectedDate = targetDate;
    });

    await _loadSelectedDateMeals();
  }

  Future<void> _selectDate() async {
    final today = _today();

    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
      firstDate: today,
      lastDate: DateTime(2100),
      helpText: 'Select planning date',
    );

    if (!mounted || selected == null) return;

    setState(() {
      _selectedDate = selected;
    });

    await _loadSelectedDateMeals();
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return months[month - 1];
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_monthName(date.month)}';
  }

  String _weekTitle() {
    final start = _startOfWeek(_selectedDate);
    final end = _endOfWeek(_selectedDate);

    if (start.month == end.month) {
      return '${_monthName(start.month)} ${start.year}';
    }

    if (start.year == end.year) {
      return '${_monthName(start.month)} - '
          '${_monthName(end.month)} ${end.year}';
    }

    return '${_monthName(start.month)} ${start.year} - '
        '${_monthName(end.month)} ${end.year}';
  }

  bool get _canGoToPreviousWeek {
    return _startOfWeek(_selectedDate).isAfter(_startOfWeek(_today()));
  }

  Future<void> _addMeal(String category) async {
    if (_isPastDate(_selectedDate)) {
      _showError('You cannot plan meals for past dates.');
      return;
    }

    try {
      final recipes = await _recipeRepository.getAll();

      if (!mounted) return;

      final draft = await showDialog<_MealDraft>(
        context: context,
        builder: (context) {
          return _AddMealDialog(category: category, recipes: recipes);
        },
      );

      if (!mounted || draft == null) return;

      await _saveMeal(category, draft);
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to load recipes: $e');
    }
  }

  Future<void> _saveMeal(String category, _MealDraft draft) async {
    if (_isPastDate(_selectedDate)) {
      _showError('You cannot plan meals for past dates.');
      return;
    }

    try {
      final meal = Meal(
        date: _dateKey(_selectedDate),
        category: category,
        name: draft.name,
        itemType: draft.itemType,
        recipeId: draft.recipeId,
        foodId: draft.foodId,
        quantity: draft.quantity,
        unit: draft.unit,
      );

      await _mealRepository.insert(meal);

      await _loadSelectedDateMeals();
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to save meal: $e');
    }
  }

  Future<void> _removeMeal(Meal meal) async {
    if (meal.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove item'),
          content: Text('Remove "${meal.name}" from your plan?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _mealRepository.delete(meal.id!);
      await _loadSelectedDateMeals();
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to remove item: $e');
    }
  }

  void _showError(String message) {
    showTopMessage(context, message, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadSelectedDateMeals,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildWeekDays(),
                            const SizedBox(height: 24),
                            _buildSelectedDateHeader(),
                            const SizedBox(height: 12),
                            NutritionSummaryView(nutrition: _dailyNutrition),
                            const SizedBox(height: 20),
                            ..._categories.map(_buildMealCategory),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Week Plan',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Select date',
                onPressed: _selectDate,
                icon: const Icon(Icons.calendar_month),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                tooltip: 'Previous week',
                onPressed: _canGoToPreviousWeek ? () => _changeWeek(-1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    _weekTitle(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next week',
                onPressed: () => _changeWeek(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekDays() {
    final start = _startOfWeek(_selectedDate);

    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Row(
      children: List.generate(7, (index) {
        final date = start.add(Duration(days: index));
        final isSelected = _isSameDay(date, _selectedDate);
        final isToday = _isSameDay(date, _today());
        final isPast = _isPastDate(date);
        final colorScheme = Theme.of(context).colorScheme;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: isPast
                  ? null
                  : () async {
                      setState(() {
                        _selectedDate = date;
                      });

                      await _loadSelectedDateMeals();
                    },
              child: Opacity(
                opacity: isPast ? 0.35 : 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary
                        : isToday
                        ? colorScheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isToday && !isSelected
                        ? Border.all(color: colorScheme.primary)
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        weekdays[index],
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? colorScheme.onPrimary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (isToday)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.onPrimary
                                : colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSelectedDateHeader() {
    final isToday = _isSameDay(_selectedDate, _today());

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isToday ? 'Today' : _formatDate(_selectedDate),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _selectedDate.year.toString(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (!_isPastDate(_selectedDate))
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedDate = _today();
              });
              _loadSelectedDateMeals();
            },
            icon: const Icon(Icons.today),
            label: const Text('Today'),
          ),
      ],
    );
  }

  Widget _buildMealCategory(String category) {
    final meals = _mealsForDate(category);

    final icon = switch (category) {
      'Breakfast' => Icons.wb_sunny_outlined,
      'Lunch' => Icons.lunch_dining_outlined,
      'Dinner' => Icons.dinner_dining_outlined,
      _ => Icons.cookie_outlined,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${meals.length} items',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                IconButton(
                  tooltip: 'Add to $category',
                  onPressed: _isPastDate(_selectedDate)
                      ? null
                      : () => _addMeal(category),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (meals.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Nothing planned yet',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ...meals.map(_buildMealItem),
          ],
        ),
      ),
    );
  }

  Widget _buildMealItem(Meal meal) {
    final isRecipe = meal.isRecipe;
    final nutrition = meal.id == null
        ? NutritionSummary.zero
        : _mealNutrition[meal.id] ?? NutritionSummary.zero;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isRecipe ? Icons.menu_book_outlined : Icons.restaurant_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 3),
                Text(
                  isRecipe
                      ? 'Recipe • ${meal.quantity} ${meal.unit}'
                      : '${meal.quantity} ${meal.unit}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 5),
                NutritionSummaryView(compact: true, nutrition: nutrition),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            onPressed: () => _removeMeal(meal),
            icon: const Icon(Icons.close, size: 19),
          ),
        ],
      ),
    );
  }
}

class _MealDraft {
  final String name;
  final String itemType;
  final int? recipeId;
  final int? foodId;
  final String quantity;
  final String unit;

  const _MealDraft({
    required this.name,
    required this.itemType,
    required this.recipeId,
    required this.foodId,
    required this.quantity,
    required this.unit,
  });
}

class _AddMealDialog extends StatefulWidget {
  final String category;
  final List<Recipe> recipes;

  const _AddMealDialog({required this.category, required this.recipes});

  @override
  State<_AddMealDialog> createState() => _AddMealDialogState();
}

class _AddMealDialogState extends State<_AddMealDialog> {
  String _type = 'recipe';

  Recipe? _selectedRecipe;
  SwissFood? _selectedFood;

  final _amountController = TextEditingController(text: '100');

  @override
  void initState() {
    super.initState();

    if (widget.recipes.isEmpty) {
      _type = 'ingredient';
    } else {
      _selectedRecipe = widget.recipes.first;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    if (_type == 'recipe') {
      final recipe = _selectedRecipe;

      if (recipe == null) return;

      Navigator.pop(
        context,
        _MealDraft(
          name: recipe.name,
          itemType: 'recipe',
          recipeId: recipe.id,
          foodId: null,
          quantity: '1',
          unit: 'serving',
        ),
      );

      return;
    }

    final food = _selectedFood;
    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', '.'),
    );

    if (food == null || amount == null || amount <= 0) {
      showTopMessage(
        context,
        'Select a food and enter a valid amount.',
        isError: true,
      );
      return;
    }

    Navigator.pop(
      context,
      _MealDraft(
        name: food.name,
        itemType: 'ingredient',
        recipeId: null,
        foodId: food.id,
        quantity: amount.toString(),
        unit: 'g',
      ),
    );
  }

  Future<void> _selectFood() async {
    final food = await showDialog<SwissFood>(
      context: context,
      builder: (_) => const FoodPickerDialog(),
    );

    if (!mounted || food == null) return;

    setState(() {
      _selectedFood = food;
    });
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 400;

    return AlertDialog(
      title: Text('Add to ${widget.category}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'recipe',
                  label: Text('Recipe'),
                  icon: compact ? null : const Icon(Icons.menu_book_outlined),
                ),
                ButtonSegment(
                  value: 'ingredient',
                  label: Text('Ingredient'),
                  icon: compact ? null : const Icon(Icons.restaurant_outlined),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) {
                setState(() {
                  _type = selection.first;
                });
              },
            ),
            const SizedBox(height: 20),
            if (_type == 'recipe') ...[
              if (widget.recipes.isEmpty)
                const Text('No saved recipes. Create one in the Recipes tab.')
              else
                DropdownButtonFormField<Recipe>(
                  initialValue: _selectedRecipe,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Select recipe',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.recipes.map((recipe) {
                    return DropdownMenuItem(
                      value: recipe,
                      child: Text(recipe.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (recipe) {
                    setState(() {
                      _selectedRecipe = recipe;
                    });
                  },
                ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _selectFood,
                  icon: const Icon(Icons.search),
                  label: Text(
                    _selectedFood?.name ?? 'Select food from database',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  suffixText: 'g',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _type == 'recipe' && widget.recipes.isEmpty ? null : _save,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
