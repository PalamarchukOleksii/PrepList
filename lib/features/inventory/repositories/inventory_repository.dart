import 'package:preplist/core/database/app_database.dart';

class InventoryItem {
  final int id;
  final String itemKey;
  final String name;
  final String amount;
  final String unit;

  const InventoryItem({
    required this.id,
    required this.itemKey,
    required this.name,
    required this.amount,
    required this.unit,
  });

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'] as int,
      itemKey: map['item_key'] as String,
      name: map['name'] as String,
      amount: map['amount'] as String? ?? '',
      unit: map['unit'] as String? ?? '',
    );
  }
}

class InventoryUsage {
  final int id;
  final String itemKey;
  final String name;
  final String amount;
  final String unit;
  final DateTime usedAt;
  final bool isUndone;

  const InventoryUsage({
    required this.id,
    required this.itemKey,
    required this.name,
    required this.amount,
    required this.unit,
    required this.usedAt,
    required this.isUndone,
  });

  factory InventoryUsage.fromMap(Map<String, dynamic> map) {
    return InventoryUsage(
      id: map['id'] as int,
      itemKey: map['item_key'] as String,
      name: map['name'] as String,
      amount: map['amount'] as String,
      unit: map['unit'] as String? ?? '',
      usedAt: DateTime.parse(map['used_at'] as String),
      isUndone: (map['is_undone'] as int? ?? 0) == 1,
    );
  }
}

class InventoryRepository {
  final AppDatabase _database = AppDatabase.instance;

  String _makeKey(String name, String unit) {
    return '${name.trim().toLowerCase()}|${unit.trim().toLowerCase()}';
  }

  double? _parseAmount(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  String _formatAmount(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  Future<List<InventoryItem>> getAll() async {
    final db = await _database.database;

    final rows = await db.query(
      'inventory_items',
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows.map(InventoryItem.fromMap).toList();
  }

  Future<List<InventoryUsage>> getRecentUsages({int limit = 10}) async {
    final db = await _database.database;

    final rows = await db.query(
      'inventory_usage',
      where: 'is_undone = 0',
      orderBy: 'used_at DESC',
      limit: limit,
    );

    return rows.map(InventoryUsage.fromMap).toList();
  }

  Future<void> add({
    required String name,
    required String amount,
    required String unit,
  }) async {
    final cleanName = name.trim();
    final cleanAmount = amount.trim();
    final cleanUnit = unit.trim();

    if (cleanName.isEmpty) return;

    final db = await _database.database;
    final key = _makeKey(cleanName, cleanUnit);

    await db.transaction((txn) async {
      final rows = await txn.query(
        'inventory_items',
        where: 'item_key = ?',
        whereArgs: [key],
        limit: 1,
      );

      if (rows.isEmpty) {
        await txn.insert('inventory_items', {
          'item_key': key,
          'name': cleanName,
          'amount': cleanAmount,
          'unit': cleanUnit,
        });
        return;
      }

      final oldAmount = rows.first['amount'] as String? ?? '';
      final oldNumber = _parseAmount(oldAmount);
      final newNumber = _parseAmount(cleanAmount);

      final combined = oldNumber != null && newNumber != null
          ? _formatAmount(oldNumber + newNumber)
          : cleanAmount.isNotEmpty
          ? cleanAmount
          : oldAmount;

      await txn.update(
        'inventory_items',
        {'amount': combined},
        where: 'item_key = ?',
        whereArgs: [key],
      );
    });
  }

  Future<void> consume(int id, double amountUsed) async {
    if (amountUsed <= 0) {
      throw ArgumentError('Amount used must be greater than zero.');
    }

    final db = await _database.database;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'inventory_items',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (rows.isEmpty) return;

      final item = rows.first;

      final currentAmount = _parseAmount(item['amount'] as String? ?? '');

      if (currentAmount == null) {
        throw StateError('This inventory item does not have a numeric amount.');
      }

      if (amountUsed > currentAmount) {
        throw ArgumentError('You cannot use more than the available amount.');
      }

      final itemKey = item['item_key'] as String;
      final name = item['name'] as String;
      final unit = item['unit'] as String? ?? '';

      // Save usage history before changing inventory.
      await txn.insert('inventory_usage', {
        'item_key': itemKey,
        'name': name,
        'amount': _formatAmount(amountUsed),
        'unit': unit,
        'used_at': DateTime.now().toIso8601String(),
        'is_undone': 0,
      });

      final remaining = currentAmount - amountUsed;

      if (remaining <= 0.000001) {
        await txn.delete('inventory_items', where: 'id = ?', whereArgs: [id]);
      } else {
        await txn.update(
          'inventory_items',
          {'amount': _formatAmount(remaining)},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  Future<void> undoUsage(int usageId) async {
    final db = await _database.database;

    await db.transaction((txn) async {
      final usageRows = await txn.query(
        'inventory_usage',
        where: 'id = ?',
        whereArgs: [usageId],
        limit: 1,
      );

      if (usageRows.isEmpty) return;

      final usage = usageRows.first;

      if ((usage['is_undone'] as int? ?? 0) == 1) return;

      final itemKey = usage['item_key'] as String;
      final name = usage['name'] as String;
      final unit = usage['unit'] as String? ?? '';
      final amount = usage['amount'] as String;

      final amountUsed = _parseAmount(amount);

      if (amountUsed == null || amountUsed <= 0) {
        throw StateError('Invalid usage amount.');
      }

      final inventoryRows = await txn.query(
        'inventory_items',
        where: 'item_key = ?',
        whereArgs: [itemKey],
        limit: 1,
      );

      if (inventoryRows.isEmpty) {
        await txn.insert('inventory_items', {
          'item_key': itemKey,
          'name': name,
          'amount': _formatAmount(amountUsed),
          'unit': unit,
        });
      } else {
        final oldAmount = inventoryRows.first['amount'] as String? ?? '';
        final oldNumber = _parseAmount(oldAmount);

        if (oldNumber == null) {
          throw StateError(
            'Cannot restore usage because the current inventory amount is not numeric.',
          );
        }

        await txn.update(
          'inventory_items',
          {'amount': _formatAmount(oldNumber + amountUsed)},
          where: 'item_key = ?',
          whereArgs: [itemKey],
        );
      }

      await txn.update(
        'inventory_usage',
        {'is_undone': 1},
        where: 'id = ?',
        whereArgs: [usageId],
      );
    });
  }

  Future<void> markUsed(int id) async {
    final db = await _database.database;

    await db.delete('inventory_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(int id) => markUsed(id);
}
