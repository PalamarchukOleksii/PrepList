import 'package:flutter/material.dart';

import 'package:preplist/app/widgets/app_logo.dart';
import 'package:preplist/data/services/swiss_food_import_service.dart';

/// Downloads the Swiss Food Composition Database and shows progress.
///
/// Calls [onFinished] with `true` when the import succeeded, or `false` when
/// the user backs out after a failure.
class SwissImportView extends StatefulWidget {
  final ValueChanged<bool> onFinished;

  const SwissImportView({super.key, required this.onFinished});

  @override
  State<SwissImportView> createState() => _SwissImportViewState();
}

class _SwissImportViewState extends State<SwissImportView> {
  bool _failed = false;
  int _completed = 0;
  int _total = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _import();
  }

  Future<void> _import() async {
    setState(() {
      _failed = false;
      _error = null;
      _completed = 0;
      _total = 0;
    });

    try {
      await SwissFoodImportService().importDatabase(
        onProgress: (completed, total) {
          if (!mounted) return;

          setState(() {
            _completed = completed;
            _total = total;
          });
        },
      );

      if (!mounted) return;

      widget.onFinished(true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _failed = true;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  const AppLogo(size: 96),
                  const SizedBox(height: 24),
                  Text(
                    _failed
                        ? 'Could not download food database'
                        : 'Downloading food database',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _failed
                        ? 'An internet connection is required for the '
                              'download.'
                        : 'Downloading the Swiss Food Composition Database. '
                              'This is only required once.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (!_failed) ...[
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 12),
                    Text(
                      _total == 0
                          ? 'Connecting to Swiss database...'
                          : '$_completed / $_total foods',
                    ),
                  ] else ...[
                    Text(
                      _error ?? 'Unknown error',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _import,
                      child: const Text('Try again'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => widget.onFinished(false),
                      child: const Text('Go back'),
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
