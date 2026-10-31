import 'package:flutter/material.dart';

import 'package:preplist/core/constants/measurement_units.dart';
import 'package:preplist/features/inventory/repositories/inventory_repository.dart';

class InventoryTab extends StatefulWidget {
  const InventoryTab({super.key});

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  final InventoryRepository _repository = InventoryRepository();

  List<InventoryItem> _items = [];
  List<InventoryUsage> _recentUsages = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        _repository.getAll(),
        _repository.getRecentUsages(),
      ]);

      if (!mounted) return;

      setState(() {
        _items = results[0] as List<InventoryItem>;
        _recentUsages = results[1] as List<InventoryUsage>;
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

  Future<void> _addItem() async {
    final input = await showDialog<_InventoryInput>(
      context: context,
      builder: (_) => const _AddInventoryDialog(),
    );

    if (input == null) return;

    await _repository.add(
      name: input.name,
      amount: input.amount,
      unit: input.unit,
    );

    await _refresh();
  }

  Future<void> _consumeItem(InventoryItem item) async {
    final available = double.tryParse(item.amount.trim().replaceAll(',', '.'));

    if (available == null || available <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This item has no usable numeric quantity.'),
        ),
      );
      return;
    }

    final amountUsed = await showDialog<double>(
      context: context,
      builder: (_) => _ConsumeInventoryDialog(item: item, available: available),
    );

    if (amountUsed == null) return;

    try {
      await _repository.consume(item.id, amountUsed);

      if (!mounted) return;

      await _refresh();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Used ${_formatAmount(amountUsed)} ${item.unit} of ${item.name}.',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              _undoLatestUsage();
            },
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _undoUsage(InventoryUsage usage) async {
    try {
      await _repository.undoUsage(usage.id);

      if (!mounted) return;

      await _refresh();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${usage.name} restored to inventory.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _undoLatestUsage() async {
    if (_recentUsages.isEmpty) return;

    await _undoUsage(_recentUsages.first);
  }

  String _formatAmount(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();

    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day.$month.$year · $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_items.length} items in inventory',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: _loading ? null : _refresh,
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                onPressed: _addItem,
                tooltip: 'Add item',
                icon: const Icon(Icons.add),
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
                child: Text('Could not load inventory:\n$_error'),
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'Your inventory is empty.\nBought groceries will appear here.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ..._items.map((item) {
                      final quantity = [
                        item.amount,
                        item.unit,
                      ].where((value) => value.isNotEmpty).join(' ');

                      return ListTile(
                        leading: const Icon(Icons.kitchen_outlined),
                        title: Text(item.name),
                        subtitle: quantity.isEmpty
                            ? null
                            : Text('$quantity available'),
                        trailing: IconButton(
                          tooltip: 'Use some amount',
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => _consumeItem(item),
                        ),
                        onTap: () => _consumeItem(item),
                      );
                    }),
                  if (_recentUsages.isNotEmpty) ...[
                    const Divider(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.history, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Recently used',
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    ..._recentUsages.map((usage) {
                      final quantity = [
                        usage.amount,
                        usage.unit,
                      ].where((value) => value.isNotEmpty).join(' ');

                      return ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(usage.name),
                        subtitle: Text(
                          '$quantity · ${_formatDate(usage.usedAt)}',
                        ),
                        trailing: TextButton.icon(
                          onPressed: () => _undoUsage(usage),
                          icon: const Icon(Icons.undo, size: 18),
                          label: const Text('Undo'),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _InventoryInput {
  final String name;
  final String amount;
  final String unit;

  const _InventoryInput({
    required this.name,
    required this.amount,
    required this.unit,
  });
}

class _AddInventoryDialog extends StatefulWidget {
  const _AddInventoryDialog();

  @override
  State<_AddInventoryDialog> createState() => _AddInventoryDialogState();
}

class _AddInventoryDialogState extends State<_AddInventoryDialog> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  String _selectedUnit = 'g';

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();

    if (name.isEmpty) return;

    Navigator.of(context).pop(
      _InventoryInput(
        name: name,
        amount: _amountController.text.trim(),
        unit: _selectedUnit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Add inventory item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Ingredient name',
              hintText: 'Chicken breast',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount',
              hintText: '500',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedUnit,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Unit'),
            items: measurementUnits.map((unit) {
              return DropdownMenuItem(
                value: unit.value,
                child: Text(unit.label),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedUnit = value;
                });
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

class _ConsumeInventoryDialog extends StatefulWidget {
  final InventoryItem item;
  final double available;

  const _ConsumeInventoryDialog({required this.item, required this.available});

  @override
  State<_ConsumeInventoryDialog> createState() =>
      _ConsumeInventoryDialogState();
}

class _ConsumeInventoryDialogState extends State<_ConsumeInventoryDialog> {
  final _amountController = TextEditingController();

  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', '.'),
    );

    if (amount == null || amount <= 0) {
      setState(() {
        _error = 'Enter a valid amount greater than zero.';
      });
      return;
    }

    if (amount > widget.available) {
      setState(() {
        _error = 'You only have ${widget.available} available.';
      });
      return;
    }

    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text('Use ${widget.item.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Available: ${widget.item.amount} ${widget.item.unit}'),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount used (${widget.item.unit})',
              hintText: 'Enter amount',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Use')),
      ],
    );
  }
}
