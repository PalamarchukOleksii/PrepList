import 'package:flutter/material.dart';
import 'package:preplist/core/ui/top_message.dart';
import 'package:preplist/core/ui/responsive.dart';

import 'package:preplist/features/recipes/repositories/recipe_repository.dart';
import 'package:preplist/features/nutrition/services/nutrition_calculator.dart';
import 'package:preplist/features/recipes/models/recipe.dart';
import 'package:preplist/features/recipes/widgets/ingredient_editor.dart';
import 'package:preplist/features/recipes/widgets/nutrition_summary_view.dart';

class RecipesTab extends StatefulWidget {
  const RecipesTab({super.key});

  @override
  State<RecipesTab> createState() => _RecipesTabState();
}

class _RecipesTabState extends State<RecipesTab> {
  final RecipeRepository _repository = RecipeRepository();
  final NutritionCalculator _nutritionCalculator = NutritionCalculator();
  final TextEditingController _searchController = TextEditingController();

  List<Recipe> _recipes = [];

  Map<int, NutritionSummary> _recipeNutrition = {};
  Map<int, NutritionSummary> _servingNutrition = {};

  bool _isLoading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    try {
      final recipes = await _repository.getAll(query: _search);

      final recipeNutrition = <int, NutritionSummary>{};
      final servingNutrition = <int, NutritionSummary>{};

      for (final recipe in recipes) {
        final id = recipe.id;

        if (id == null) continue;

        recipeNutrition[id] = await _nutritionCalculator.forRecipe(recipe);
        servingNutrition[id] = await _nutritionCalculator.forRecipeServing(
          recipe,
        );
      }

      if (!mounted) return;

      setState(() {
        _recipes = recipes;
        _recipeNutrition = recipeNutrition;
        _servingNutrition = servingNutrition;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Could not load recipes: $error');
    }
  }

  void _showMessage(String message) {
    showTopMessage(context, message, isError: message.startsWith('Could not'));
  }

  Future<void> _openForm({Recipe? recipe}) async {
    final result = await showDialog<Recipe>(
      context: context,
      builder: (_) => _RecipeFormDialog(recipe: recipe),
    );

    if (!mounted || result == null) return;

    try {
      if (recipe == null) {
        await _repository.insert(result);
      } else {
        await _repository.update(result);
      }

      await _loadRecipes();
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not save recipe: $error');
    }
  }

  Future<void> _deleteRecipe(Recipe recipe) async {
    if (recipe.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: Text('Delete "${recipe.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      await _repository.delete(recipe.id!);
      await _loadRecipes();
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not delete recipe: $error');
    }
  }

  void _showDetails(Recipe recipe) {
    showDialog<void>(
      context: context,
      builder: (_) => _RecipeDetailsDialog(
        recipe: recipe,
        nutrition: _recipeNutrition[recipe.id] ?? NutritionSummary.zero,
        servingNutrition: _servingNutrition[recipe.id] ?? NutritionSummary.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recipes',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search recipes...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _search = '';
                                  _isLoading = true;
                                });
                                _loadRecipes();
                              },
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _search = value;
                        _isLoading = true;
                      });
                      _loadRecipes();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _recipes.isEmpty
                  ? _buildEmptyState(theme)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                      itemCount: _recipes.length,
                      itemBuilder: (context, index) {
                        final recipe = _recipes[index];
                        final id = recipe.id;

                        return _RecipeCard(
                          recipe: recipe,
                          nutrition: id == null
                              ? NutritionSummary.zero
                              : _recipeNutrition[id] ?? NutritionSummary.zero,
                          servingNutrition: id == null
                              ? NutritionSummary.zero
                              : _servingNutrition[id] ?? NutritionSummary.zero,
                          onTap: () => _showDetails(recipe),
                          onEdit: () => _openForm(recipe: recipe),
                          onDelete: () => _deleteRecipe(recipe),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              _search.isEmpty ? 'No recipes yet' : 'No recipes found',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              _search.isEmpty
                  ? 'Add your first recipe.'
                  : 'Try another search.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final NutritionSummary nutrition;
  final NutritionSummary servingNutrition;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecipeCard({
    required this.recipe,
    required this.nutrition,
    required this.servingNutrition,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      recipe.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              if (recipe.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  recipe.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _InfoLabel(
                    icon: Icons.schedule,
                    text: '${recipe.prepMinutes + recipe.cookMinutes} min',
                  ),
                  _InfoLabel(
                    icon: Icons.restaurant,
                    text: '${recipe.servings} servings',
                  ),
                  _InfoLabel(
                    icon: Icons.eco_outlined,
                    text: '${recipe.ingredients.length} ingredients',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text('Per serving', style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              NutritionSummaryView(compact: true, nutrition: servingNutrition),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _RecipeFormDialog extends StatefulWidget {
  final Recipe? recipe;

  const _RecipeFormDialog({this.recipe});

  @override
  State<_RecipeFormDialog> createState() => _RecipeFormDialogState();
}

class _RecipeFormDialogState extends State<_RecipeFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _instructions;
  late final TextEditingController _prep;
  late final TextEditingController _cook;
  late final TextEditingController _servings;

  late List<RecipeIngredient> _ingredients;

  @override
  void initState() {
    super.initState();

    final recipe = widget.recipe;

    _name = TextEditingController(text: recipe?.name ?? '');
    _description = TextEditingController(text: recipe?.description ?? '');
    _instructions = TextEditingController(text: recipe?.instructions ?? '');
    _prep = TextEditingController(text: '${recipe?.prepMinutes ?? 0}');
    _cook = TextEditingController(text: '${recipe?.cookMinutes ?? 0}');
    _servings = TextEditingController(text: '${recipe?.servings ?? 1}');

    _ingredients = List.of(recipe?.ingredients ?? []);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _instructions.dispose();
    _prep.dispose();
    _cook.dispose();
    _servings.dispose();
    super.dispose();
  }

  int _intValue(TextEditingController controller, int fallback) {
    return int.tryParse(controller.text.trim()) ?? fallback;
  }

  void _save() {
    final name = _name.text.trim();

    if (name.isEmpty) {
      showTopMessage(context, 'Recipe name is required.', isError: true);
      return;
    }

    final recipe = Recipe(
      id: widget.recipe?.id,
      name: name,
      description: _description.text.trim(),
      instructions: _instructions.text.trim(),
      prepMinutes: _intValue(_prep, 0).clamp(0, 9999),
      cookMinutes: _intValue(_cook, 0).clamp(0, 9999),
      servings: _intValue(_servings, 1).clamp(1, 999),
      ingredients: List.of(_ingredients),
    );

    Navigator.of(context).pop(recipe);
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.recipe == null ? 'New recipe' : 'Edit recipe'),
      content: SizedBox(
        width: dialogWidth(context),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field('Recipe name *', _name),
              _field('Description', _description, maxLines: 2),
              _field('Instructions', _instructions, maxLines: 4),
              const Divider(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ingredients',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              IngredientEditor(
                ingredients: _ingredients,
                onChanged: (ingredients) {
                  _ingredients = List.of(ingredients);
                },
              ),
              const Divider(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Preparation',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      'Prep (min)',
                      _prep,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _field(
                      'Cook (min)',
                      _cook,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              _field('Servings', _servings, keyboardType: TextInputType.number),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _RecipeDetailsDialog extends StatelessWidget {
  final Recipe recipe;
  final NutritionSummary nutrition;
  final NutritionSummary servingNutrition;

  const _RecipeDetailsDialog({
    required this.recipe,
    required this.nutrition,
    required this.servingNutrition,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(recipe.name),
      content: SizedBox(
        width: dialogWidth(context, max: 450),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (recipe.description.isNotEmpty) ...[
                Text(recipe.description),
                const SizedBox(height: 16),
              ],
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _InfoLabel(
                    icon: Icons.timer_outlined,
                    text: '${recipe.prepMinutes} min prep',
                  ),
                  _InfoLabel(
                    icon: Icons.soup_kitchen_outlined,
                    text: '${recipe.cookMinutes} min cooking',
                  ),
                  _InfoLabel(
                    icon: Icons.restaurant,
                    text: '${recipe.servings} servings',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Nutrition per serving', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              NutritionSummaryView(nutrition: servingNutrition),
              const SizedBox(height: 16),
              Text(
                'Nutrition for entire recipe',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              NutritionSummaryView(nutrition: nutrition),
              const SizedBox(height: 20),
              Text(
                'Ingredients (${recipe.ingredients.length})',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (recipe.ingredients.isEmpty)
                const Text('No ingredients added.')
              else
                ...recipe.ingredients.map((ingredient) {
                  final quantity = [
                    ingredient.amount,
                    ingredient.unit,
                  ].where((value) => value.isNotEmpty).join(' ');

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Icon(Icons.circle, size: 7),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            quantity.isEmpty
                                ? ingredient.name
                                : '$quantity ${ingredient.name}',
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 20),
              Text('Instructions', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                recipe.instructions.isEmpty
                    ? 'No instructions added.'
                    : recipe.instructions,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
