class SwissFood {
  final int id;
  final String name;
  final List<String> synonyms;

  // Nutritional values per 100 g.
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const SwissFood({
    required this.id,
    required this.name,
    this.synonyms = const [],
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  factory SwissFood.fromMap(Map<String, Object?> map) {
    return SwissFood(
      id: _toInt(map['external_id']),
      name: map['name']?.toString() ?? '',
      synonyms: (map['synonyms']?.toString() ?? '')
          .split('|')
          .where((value) => value.isNotEmpty)
          .toList(),
      calories: _toDouble(map['calories']),
      protein: _toDouble(map['protein']),
      carbs: _toDouble(map['carbs']),
      fat: _toDouble(map['fat']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double caloriesFor(double grams) => calories * grams / 100;

  double proteinFor(double grams) => protein * grams / 100;

  double carbsFor(double grams) => carbs * grams / 100;

  double fatFor(double grams) => fat * grams / 100;
}
