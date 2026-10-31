import 'package:flutter/material.dart';

import 'package:preplist/features/recipes/models/recipe.dart';
import 'package:preplist/features/foods/models/swiss_food.dart';
import 'package:preplist/features/foods/widgets/food_picker_dialog.dart';

class IngredientEditor extends StatefulWidget {
  final List<RecipeIngredient> ingredients;
  final ValueChanged<List<RecipeIngredient>> onChanged;

  const IngredientEditor({
    super.key,
    required this.ingredients,
    required this.onChanged,
  });

  @override
  State<IngredientEditor> createState() => _IngredientEditorState();
}

class _IngredientEditorState extends State<IngredientEditor> {
  late List<RecipeIngredient> _ingredients;

  @override
  void initState() {
    super.initState();
    _ingredients = List.of(widget.ingredients);
  }

  void _notifyChanged() {
    widget.onChanged(List.unmodifiable(_ingredients));
  }

  Future<void> _addIngredient() async {
    final food = await showDialog<SwissFood>(
      context: context,
      builder: (_) => const FoodPickerDialog(),
    );

    if (!mounted || food == null) return;

    final amount = await _askForAmount(title: food.name, initialAmount: '');

    if (!mounted || amount == null) return;

    final grams = _parseGrams(amount);

    if (grams == null || grams <= 0) {
      _showInvalidAmount();
      return;
    }

    setState(() {
      _ingredients.add(
        RecipeIngredient(
          foodId: food.id,
          name: food.name,
          amount: amount,
          unit: 'g',
        ),
      );
    });

    _notifyChanged();
  }

  Future<void> _editIngredient(int index) async {
    if (index < 0 || index >= _ingredients.length) return;

    final ingredient = _ingredients[index];

    final amount = await _askForAmount(
      title: ingredient.name,
      initialAmount: ingredient.amount,
    );

    if (!mounted || amount == null) return;

    final grams = _parseGrams(amount);

    if (grams == null || grams <= 0) {
      _showInvalidAmount();
      return;
    }

    if (index >= _ingredients.length ||
        _ingredients[index].id != ingredient.id) {
      return;
    }

    setState(() {
      _ingredients[index] = RecipeIngredient(
        id: ingredient.id,
        recipeId: ingredient.recipeId,
        foodId: ingredient.foodId,
        name: ingredient.name,
        amount: amount,
        unit: ingredient.unit,
      );
    });

    _notifyChanged();
  }

  Future<String?> _askForAmount({
    required String title,
    required String initialAmount,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) =>
          _IngredientAmountDialog(title: title, initialAmount: initialAmount),
    );
  }

  double? _parseGrams(String value) {
    return double.tryParse(value.replaceAll(',', '.'));
  }

  void _showInvalidAmount() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enter a valid amount greater than zero grams.'),
      ),
    );
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
    });

    _notifyChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addIngredient,
            icon: const Icon(Icons.add),
            label: const Text('Add food from Swiss database'),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Ingredients',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_ingredients.length}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_ingredients.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No ingredients added yet',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          ...List.generate(_ingredients.length, (index) {
            final ingredient = _ingredients[index];

            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                title: Text(ingredient.name),
                subtitle: Text('${ingredient.amount} g'),
                leading: const Icon(Icons.eco_outlined),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit ingredient',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editIngredient(index),
                    ),
                    IconButton(
                      tooltip: 'Remove ingredient',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeIngredient(index),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _IngredientAmountDialog extends StatefulWidget {
  final String title;
  final String initialAmount;

  const _IngredientAmountDialog({
    required this.title,
    required this.initialAmount,
  });

  @override
  State<_IngredientAmountDialog> createState() =>
      _IngredientAmountDialogState();
}

class _IngredientAmountDialogState extends State<_IngredientAmountDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialAmount);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Amount',
          suffixText: 'g',
          hintText: '150',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (value) {
          Navigator.pop(context, value.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, _controller.text.trim());
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
