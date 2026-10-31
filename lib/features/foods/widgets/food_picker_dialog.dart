import 'package:flutter/material.dart';

import 'package:preplist/features/foods/repositories/food_repository.dart';
import 'package:preplist/features/foods/models/swiss_food.dart';

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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _foods = []);
      return;
    }

    setState(() => _searching = true);

    try {
      final results = await FoodRepository.instance.searchFoods(query);

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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select food'),
      content: SizedBox(
        width: 500,
        height: 450,
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
                      child: Text(
                        _controller.text.isEmpty
                            ? 'Start typing to search foods'
                            : 'No foods found',
                      ),
                    )
                  : ListView.separated(
                      itemCount: _foods.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final food = _foods[index];

                        return ListTile(
                          title: Text(food.name),
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
