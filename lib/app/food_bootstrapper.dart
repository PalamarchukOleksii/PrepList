import 'package:flutter/material.dart';

import 'package:preplist/app/widgets/app_logo.dart';
import 'package:preplist/features/foods/repositories/food_repository.dart';
import 'package:preplist/features/foods/widgets/swiss_import_view.dart';

enum _Stage { checking, choice, importing, ready }

/// Decides what to show on startup:
///  * the first-run choice (import the Swiss database, or start without it),
///  * the import progress screen, or
///  * the app itself.
class FoodBootstrapper extends StatefulWidget {
  final Widget child;

  const FoodBootstrapper({super.key, required this.child});

  @override
  State<FoodBootstrapper> createState() => _FoodBootstrapperState();
}

class _FoodBootstrapperState extends State<FoodBootstrapper> {
  _Stage _stage = _Stage.checking;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final decided = await FoodRepository.instance.hasImportChoice();

    if (!mounted) return;

    setState(() => _stage = decided ? _Stage.ready : _Stage.choice);
  }

  Future<void> _skip() async {
    await FoodRepository.instance.setImportChoice(
      FoodRepository.choiceSkipped,
    );

    if (!mounted) return;

    setState(() => _stage = _Stage.ready);
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _Stage.ready:
        return widget.child;

      case _Stage.importing:
        return SwissImportView(
          onFinished: (imported) {
            setState(() => _stage = imported ? _Stage.ready : _Stage.choice);
          },
        );

      case _Stage.checking:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));

      case _Stage.choice:
        return _ChoiceScreen(
          onImport: () => setState(() => _stage = _Stage.importing),
          onSkip: _skip,
        );
    }
  }
}

class _ChoiceScreen extends StatelessWidget {
  final VoidCallback onImport;
  final VoidCallback onSkip;

  const _ChoiceScreen({required this.onImport, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppLogo(size: 96),
                  const SizedBox(height: 24),
                  Text(
                    'Set up your food database',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Food data is used to calculate calories and macros for '
                    'your recipes and meals.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _OptionCard(
                    icon: Icons.cloud_download_outlined,
                    title: 'Import Swiss database',
                    description:
                        'Download the Swiss Food Composition Database. '
                        'Requires an internet connection and runs once.',
                    primary: true,
                    onTap: onImport,
                  ),
                  const SizedBox(height: 12),
                  _OptionCard(
                    icon: Icons.edit_note,
                    title: 'Start without it',
                    description:
                        'Skip the download and create your own foods '
                        'with custom nutrition values.',
                    onTap: onSkip,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Either way, you can add your own foods at any time. '
                    'You can also import the Swiss database later from '
                    'the menu.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool primary;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = primary
        ? scheme.primaryContainer
        : scheme.surfaceContainerHigh;
    final foreground = primary
        ? scheme.onPrimaryContainer
        : scheme.onSurface;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 32, color: foreground),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: foreground),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}
