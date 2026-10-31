import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String developerName = 'Oleksii Palamarchuk';
  static const String licenseName = 'MIT License';
  static const int releaseYear = 2026;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About PrepList')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),

          // App identity
          Center(
            child: Column(
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
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'PrepList',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Chip(
                  avatar: Icon(Icons.science_outlined, size: 16),
                  label: Text('ALPHA'),
                ),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox.shrink();
                    }

                    final info = snapshot.data!;

                    return Text(
                      'Version ${info.version} (${info.buildNumber})',
                      style: theme.textTheme.bodySmall,
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // About
          _sectionTitle(context, 'About'),

          const Text(
            'PrepList helps you plan meals, organize recipes, '
            'track nutrition, and manage groceries and food inventory.',
          ),

          const SizedBox(height: 24),

          // Features
          _sectionTitle(context, 'Features'),

          const _InfoTile(
            icon: Icons.calendar_month_outlined,
            title: 'Meal planning',
            subtitle: 'Organize your meals throughout the week.',
          ),
          const _InfoTile(
            icon: Icons.restaurant_menu,
            title: 'Recipes',
            subtitle: 'Create recipes and manage ingredients.',
          ),
          const _InfoTile(
            icon: Icons.monitor_weight_outlined,
            title: 'Nutrition tracking',
            subtitle: 'Track calories, protein, carbohydrates and fats.',
          ),
          const _InfoTile(
            icon: Icons.shopping_cart_outlined,
            title: 'Groceries',
            subtitle: 'Keep track of your shopping list.',
          ),
          const _InfoTile(
            icon: Icons.inventory_2_outlined,
            title: 'Inventory',
            subtitle: 'Manage your available food items.',
          ),

          const SizedBox(height: 24),

          // Developer
          _sectionTitle(context, 'Developer'),

          const _InfoTile(
            icon: Icons.person_outline,
            title: developerName,
            subtitle: 'Independent developer',
          ),

          const SizedBox(height: 24),

          // License
          _sectionTitle(context, 'License'),

          const _InfoTile(
            icon: Icons.description_outlined,
            title: licenseName,
            subtitle: 'Open-source software',
          ),

          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Copyright © 2026 Oleksii Palamarchuk\n\n'
              'Permission is hereby granted, free of charge, to any person '
              'obtaining a copy of this software and associated documentation '
              'files (the "Software"), to deal in the Software without '
              'restriction, including without limitation the rights to use, '
              'copy, modify, merge, publish, distribute, sublicense, and/or '
              'sell copies of the Software, and to permit persons to whom '
              'the Software is furnished to do so, subject to the following '
              'conditions:\n\n'
              'The above copyright notice and this permission notice shall '
              'be included in all copies or substantial portions of the '
              'Software.\n\n'
              'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY '
              'KIND, EXPRESS OR IMPLIED.',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
          ),

          const SizedBox(height: 24),

          // Privacy
          _sectionTitle(context, 'Privacy'),

          const Text(
            'Recipes, meal plans, and inventory are stored in the '
            'application database on your device. Importing food data '
            'may connect to external food data services.',
          ),

          const SizedBox(height: 24),

          // Alpha notice
          _sectionTitle(context, 'Alpha release'),

          const Text(
            'PrepList is currently in early development. Features may '
            'be incomplete, and unexpected issues may occur. Keep '
            'backups of important data during testing.',
          ),

          const SizedBox(height: 24),

          const Divider(),

          // Third-party licenses
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.article_outlined),
            title: const Text('Third-party licenses'),
            subtitle: const Text('Flutter and open-source dependencies'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'PrepList',
                applicationVersion: 'Alpha',
                applicationLegalese: 'Copyright © 2026 $developerName',
              );
            },
          ),

          const SizedBox(height: 24),

          Center(
            child: Text(
              'Made with Flutter',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}
