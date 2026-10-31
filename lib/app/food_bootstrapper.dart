import 'package:flutter/material.dart';

import 'package:preplist/features/foods/repositories/food_repository.dart';
import 'package:preplist/data/services/swiss_food_import_service.dart';

class FoodBootstrapper extends StatefulWidget {
  final Widget child;

  const FoodBootstrapper({super.key, required this.child});

  @override
  State<FoodBootstrapper> createState() => _FoodBootstrapperState();
}

class _FoodBootstrapperState extends State<FoodBootstrapper> {
  bool _loading = true;
  bool _failed = false;

  int _completed = 0;
  int _total = 0;

  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _failed = false;
      _error = null;
      _completed = 0;
      _total = 0;
    });

    try {
      final database = FoodRepository.instance;

      if (await database.isImported()) {
        if (!mounted) return;

        setState(() => _loading = false);
        return;
      }

      final importer = SwissFoodImportService();

      await importer.importDatabase(
        onProgress: (completed, total) {
          if (!mounted) return;

          setState(() {
            _completed = completed;
            _total = total;
          });
        },
      );

      if (!mounted) return;

      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _failed = true;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && !_failed) {
      return widget.child;
    }

    final progress = _total == 0 ? null : _completed / _total;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _failed
                        ? 'Could not download food database'
                        : 'Preparing your food database',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _failed
                        ? 'An internet connection is required for the '
                              'initial download.'
                        : 'Downloading the Swiss Food Composition Database. '
                              'This is only required once.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_loading) ...[
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 12),
                    Text(
                      _total == 0
                          ? 'Connecting to Swiss database...'
                          : '$_completed / $_total foods',
                    ),
                  ],
                  if (_failed) ...[
                    Text(
                      _error ?? 'Unknown error',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _initialize,
                      child: const Text('Try again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
