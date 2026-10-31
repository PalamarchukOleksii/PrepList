import 'package:flutter/material.dart';

import 'package:preplist/core/ui/responsive.dart';
import 'package:preplist/features/foods/models/swiss_food.dart';
import 'package:preplist/features/foods/repositories/food_repository.dart';
import 'package:preplist/features/foods/widgets/food_editor_dialog.dart';
import 'package:preplist/features/foods/widgets/swiss_import_view.dart';

/// Manage the user's own foods and the optional Swiss database.
class FoodsScreen extends StatefulWidget {
  const FoodsScreen({super.key});

  @override
  State<FoodsScreen> createState() => _FoodsScreenState();
}

class _FoodsScreenState extends State<FoodsScreen> {
  final _repository = FoodRepository.instance;

  List<SwissFood> _foods = [];
  bool _imported = false;
  int _swissCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final foods = await _repository.getCustomFoods();
    final imported = await _repository.isImported();
    final swissCount = imported
        ? await _repository.getFoodCount(source: 'swiss')
        : 0;

    if (!mounted) return;

    setState(() {
      _foods = foods;
      _imported = imported;
      _swissCount = swissCount;
      _loading = false;
    });
  }

  Future<void> _edit([SwissFood? food]) async {
    final saved = await showDialog<SwissFood>(
      context: context,
      builder: (_) => FoodEditorDialog(food: food),
    );

    if (saved != null) await _load();
  }

  Future<void> _delete(SwissFood food) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete food?'),
        content: Text(
          '"${food.name}" will be removed. Recipes and meals that use it '
          'will keep the name, but it will no longer count toward '
          'nutrition totals.',
        ),
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

    if (confirmed != true) return;

    await _repository.deleteCustomFood(food.id);
    await _load();
  }

  Future<void> _import() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            SwissImportView(onFinished: (_) => Navigator.pop(context)),
      ),
    );

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My foods')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('New food'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ContentWidth(
              maxWidth: 640,
              child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Card(
                  child: ListTile(
                    leading: Icon(
                      _imported
                          ? Icons.check_circle_outline
                          : Icons.cloud_download_outlined,
                    ),
                    title: Text(
                      _imported
                          ? 'Swiss database imported'
                          : 'Swiss database not imported',
                    ),
                    subtitle: Text(
                      _imported
                          ? '$_swissCount foods available in search.'
                          : 'Download it to search thousands of foods.',
                    ),
                    trailing: TextButton(
                      onPressed: _import,
                      child: Text(_imported ? 'Update' : 'Import'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Your foods', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_foods.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'You have not created any foods yet.\n'
                        'Tap "New food" to add one.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  for (final food in _foods)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(food.name),
                      subtitle: Text(
                        '${food.calories.toStringAsFixed(0)} kcal'
                        ' · P ${food.protein.toStringAsFixed(1)} g'
                        ' · C ${food.carbs.toStringAsFixed(1)} g'
                        ' · F ${food.fat.toStringAsFixed(1)} g'
                        ' / 100 g',
                      ),
                      onTap: () => _edit(food),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete',
                        onPressed: () => _delete(food),
                      ),
                    ),
              ],
            ),
            ),
    );
  }
}
