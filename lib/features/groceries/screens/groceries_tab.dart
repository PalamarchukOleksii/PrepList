import 'package:flutter/material.dart';
import 'package:preplist/core/ui/top_message.dart';

import 'package:preplist/features/groceries/repositories/grocery_repository.dart';

class GroceriesTab extends StatefulWidget {
  const GroceriesTab({super.key});

  @override
  State<GroceriesTab> createState() => _GroceriesTabState();
}

class _GroceriesTabState extends State<GroceriesTab> {
  final GroceryRepository _repository = GroceryRepository();

  List<GroceryItem> _items = [];
  bool _loading = true;
  String? _error;

  List<GroceryItem> get _toBuy =>
      _items.where((item) => !item.isBought).toList();

  List<GroceryItem> get _bought =>
      _items.where((item) => item.isBought).toList();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _repository.syncFromFuturePlan();
      final items = await _repository.getAll();

      if (!mounted) return;

      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleBought(GroceryItem item) async {
    try {
      await _repository.toggleBought(item.id);
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not update grocery: $error');
    }
  }

  Future<void> _addToInventory(GroceryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add to inventory?'),
          content: Text(
            'Add ${item.name} (${_amountLabel(item)}) to your inventory?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add to inventory'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    try {
      await _repository.addBoughtToInventory(item.id);
      await _refresh();

      if (!mounted) return;

      _showMessage('${item.name} added to Inventory');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not update inventory: $error');
    }
  }

  String _amountLabel(GroceryItem item) {
    return [
      item.amount,
      item.unit,
    ].where((value) => value.isNotEmpty).join(' ');
  }

  void _showMessage(String message) {
    showTopMessage(context, message, isError: message.startsWith('Could not'));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_toBuy.length} items to buy',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: _loading ? null : _refresh,
                tooltip: 'Refresh from Week Plan',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Could not load groceries:\n$_error'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _buildSectionHeader(title: 'To buy', count: _toBuy.length),
                  if (_toBuy.isEmpty)
                    _buildEmptyMessage('Nothing left to buy.')
                  else
                    ..._toBuy.map(_buildToBuyItem),
                  const SizedBox(height: 24),
                  _buildSectionHeader(title: 'Bought', count: _bought.length),
                  if (_bought.isEmpty)
                    _buildEmptyMessage('Bought items will appear here.')
                  else
                    ..._bought.map(_buildBoughtItem),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHeader({required String title, required int count}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Text('$count', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildEmptyMessage(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildToBuyItem(GroceryItem item) {
    final amount = _amountLabel(item);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        value: false,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(item.name),
        subtitle: amount.isEmpty ? null : Text(amount),
        secondary: const Icon(Icons.shopping_cart_outlined),
        onChanged: (_) => _toggleBought(item),
      ),
    );
  }

  Widget _buildBoughtItem(GroceryItem item) {
    final amount = _amountLabel(item);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            CheckboxListTile(
              value: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                item.name,
                style: const TextStyle(decoration: TextDecoration.lineThrough),
              ),
              subtitle: amount.isEmpty ? null : Text(amount),
              secondary: const Icon(Icons.check_circle_outline),
              onChanged: (_) => _toggleBought(item),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  if (item.inventoryAdded)
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 17),
                          SizedBox(width: 6),
                          Text('In inventory'),
                        ],
                      ),
                    )
                  else
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _addToInventory(item),
                          icon: const Icon(Icons.inventory_2_outlined),
                          label: const Text('Add to inventory'),
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed: () => _toggleBought(item),
                    child: const Text('Undo'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
