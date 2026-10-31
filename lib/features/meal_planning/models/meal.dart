class Meal {
  final int? id;
  final String date;
  final String category;
  final String name;
  final String itemType;
  final int? recipeId;
  final int? foodId;
  final String quantity;
  final String unit;

  const Meal({
    this.id,
    required this.date,
    required this.category,
    required this.name,
    this.itemType = 'ingredient',
    this.recipeId,
    this.foodId,
    this.quantity = '',
    this.unit = '',
  });

  bool get isRecipe => itemType == 'recipe';

  double get quantityValue {
    return double.tryParse(quantity.replaceAll(',', '.')) ?? 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'category': category,
      'name': name,
      'item_type': itemType,
      'recipe_id': recipeId,
      'food_id': foodId,
      'quantity': quantity,
      'unit': unit,
    };
  }

  factory Meal.fromMap(Map<String, dynamic> map) {
    return Meal(
      id: map['id'] as int?,
      date: map['date'] as String,
      category: map['category'] as String,
      name: map['name'] as String,
      itemType: map['item_type'] as String? ?? 'ingredient',
      recipeId: map['recipe_id'] as int?,
      foodId: map['food_id'] as int?,
      quantity: map['quantity'] as String? ?? '',
      unit: map['unit'] as String? ?? '',
    );
  }

  Meal copyWith({
    int? id,
    String? date,
    String? category,
    String? name,
    String? itemType,
    int? recipeId,
    int? foodId,
    String? quantity,
    String? unit,
  }) {
    return Meal(
      id: id ?? this.id,
      date: date ?? this.date,
      category: category ?? this.category,
      name: name ?? this.name,
      itemType: itemType ?? this.itemType,
      recipeId: recipeId ?? this.recipeId,
      foodId: foodId ?? this.foodId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
    );
  }
}
