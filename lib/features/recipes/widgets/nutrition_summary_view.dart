import 'package:flutter/material.dart';

import 'package:preplist/features/nutrition/services/nutrition_calculator.dart';

class NutritionSummaryView extends StatelessWidget {
  final NutritionSummary nutrition;
  final bool compact;

  const NutritionSummaryView({
    super.key,
    required this.nutrition,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (compact) {
      return Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          _value(theme, 'kcal', nutrition.calories.round().toString()),
          _value(theme, 'P', '${nutrition.protein.round()} g'),
          _value(theme, 'C', '${nutrition.carbs.round()} g'),
          _value(theme, 'F', '${nutrition.fat.round()} g'),
        ],
      );
    }

    final values = [
      ('Calories', '${nutrition.calories.round()} kcal'),
      ('Protein', '${nutrition.protein.toStringAsFixed(1)} g'),
      ('Carbs', '${nutrition.carbs.toStringAsFixed(1)} g'),
      ('Fat', '${nutrition.fat.toStringAsFixed(1)} g'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: values.map((item) {
          return Expanded(
            child: Column(
              children: [
                Text(
                  item.$2,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.$1,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _value(ThemeData theme, String label, String value) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      style: theme.textTheme.bodySmall,
    );
  }
}
