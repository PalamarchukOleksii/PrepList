import 'package:flutter/material.dart';

import 'package:preplist/core/ui/responsive.dart';
import 'package:preplist/features/foods/repositories/food_repository.dart';
import 'package:preplist/features/foods/models/swiss_food.dart';
import 'package:preplist/features/foods/widgets/food_editor_dialog.dart';

class FoodPickerDialog extends StatefulWidget {
  const FoodPickerDialog({super.key});

  @override
  State<FoodPickerDialog> createState() => _FoodPickerDialogState();
}

class _FoodPickerDialogState extends State<FoodPickerDialog> {
  final _controller = TextEditingController();

  List<SwissFood> _foods = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);

    try {
      // With an empty query, show the user's own foods as quick picks.
      final results = query.trim().isEmpty
          ? await FoodRepository.instance.getCustomFoods()
          : await FoodRepository.instance.searchFoods(query);

      if (!mounted) return;

      setState(() {
        _foods = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _foods = [];
        _searching = false;
      });
    }
  }

  Future<void> _createFood() async {
    final food = await showDialog<SwissFood>(
      context: context,
      builder: (_) => FoodEditorDialog(initialName: _controller.text.trim()),
    );

    if (!mounted || food == null) return;

    // The new food is selected right away.
    Navigator.pop(context, food);
  }

  String get _emptyMessage {
    if (_controller.text.trim().isEmpty) {
      return 'Start typing to search foods,\nor create your own.';
    }

    return 'No foods found.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Select food'),
      content: SizedBox(
        width: dialogWidth(context),
        height: dialogHeight(context),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search foods...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _search,
            ),
            const SizedBox(height: 12),
            if (_searching) const LinearProgressIndicator(),
            Expanded(
              child: _foods.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_emptyMessage, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton.tonalIcon(
                            onPressed: _createFood,
                            icon: const Icon(Icons.add),
                            label: const Text('Create new food'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _foods.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final food = _foods[index];

                        return ListTile(
                          title: Text(food.name),
                          trailing: food.isCustom
                              ? Icon(
                                  Icons.person_outline,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                          subtitle: Text(
                            '${food.calories.toStringAsFixed(0)} kcal'
                            ' · P ${food.protein.toStringAsFixed(1)} g'
                            ' · C ${food.carbs.toStringAsFixed(1)} g'
                            ' · F ${food.fat.toStringAsFixed(1)} g'
                            ' / 100 g',
                          ),
                          onTap: () {
                            Navigator.pop(context, food);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _createFood,
          icon: const Icon(Icons.add),
          label: const Text('New food'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
