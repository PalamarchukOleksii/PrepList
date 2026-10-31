import 'package:flutter/material.dart';

import 'package:preplist/features/foods/models/swiss_food.dart';
import 'package:preplist/features/foods/repositories/food_repository.dart';

/// Creates a new custom food, or edits an existing one.
///
/// Saves to the database and pops with the saved [SwissFood].
class FoodEditorDialog extends StatefulWidget {
  final SwissFood? food;
  final String? initialName;

  const FoodEditorDialog({super.key, this.food, this.initialName});

  @override
  State<FoodEditorDialog> createState() => _FoodEditorDialogState();
}

class _FoodEditorDialogState extends State<FoodEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;

  bool _saving = false;

  bool get _isEditing => widget.food != null;

  @override
  void initState() {
    super.initState();

    final food = widget.food;

    _name = TextEditingController(text: food?.name ?? widget.initialName ?? '');
    _calories = TextEditingController(text: _format(food?.calories));
    _protein = TextEditingController(text: _format(food?.protein));
    _carbs = TextEditingController(text: _format(food?.carbs));
    _fat = TextEditingController(text: _format(food?.fat));
  }

  @override
  void dispose() {
    _name.dispose();
    _calories.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  String _format(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  double _parse(TextEditingController controller) {
    final text = controller.text.trim().replaceAll(',', '.');
    return double.tryParse(text) ?? 0;
  }

  String? _validateNumber(String? value) {
    final text = (value ?? '').trim();

    // Empty means 0.
    if (text.isEmpty) return null;

    final number = double.tryParse(text.replaceAll(',', '.'));

    if (number == null) return 'Enter a number';
    if (number < 0) return 'Cannot be negative';

    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final repository = FoodRepository.instance;
    final SwissFood saved;

    if (_isEditing) {
      final old = widget.food!;

      saved = SwissFood(
        id: old.id,
        name: _name.text.trim(),
        synonyms: old.synonyms,
        calories: _parse(_calories),
        protein: _parse(_protein),
        carbs: _parse(_carbs),
        fat: _parse(_fat),
        source: 'custom',
      );

      await repository.updateCustomFood(saved);
    } else {
      saved = await repository.createCustomFood(
        name: _name.text,
        calories: _parse(_calories),
        protein: _parse(_protein),
        carbs: _parse(_carbs),
        fat: _parse(_fat),
      );
    }

    if (!mounted) return;

    Navigator.pop(context, saved);
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    String suffix,
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      validator: _validateNumber,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit food' : 'New food'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _name,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter a name'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Nutrition per 100 g',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              _numberField(_calories, 'Calories', 'kcal'),
              const SizedBox(height: 12),
              _numberField(_protein, 'Protein', 'g'),
              const SizedBox(height: 12),
              _numberField(_carbs, 'Carbohydrates', 'g'),
              const SizedBox(height: 12),
              _numberField(_fat, 'Fat', 'g'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
