import 'package:flutter/material.dart';
import 'package:preplist/app/about_screen.dart';
import 'package:preplist/core/ui/responsive.dart';
import 'package:preplist/features/foods/screens/foods_screen.dart';

import 'package:preplist/features/meal_planning/screens/week_plan_tab.dart';
import 'package:preplist/features/recipes/screens/recipes_tab.dart';
import 'package:preplist/features/groceries/screens/groceries_tab.dart';
import 'package:preplist/features/inventory/screens/inventory_tab.dart';

class _Destination {
  final String title;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _Destination({
    required this.title,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _tabs = [
    WeekPlanTab(),
    RecipesTab(),
    GroceriesTab(),
    InventoryTab(),
  ];

  static const List<_Destination> _destinations = [
    _Destination(
      title: 'Week Plan',
      label: 'Plan',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
    ),
    _Destination(
      title: 'Recipes',
      label: 'Recipes',
      icon: Icons.restaurant_menu_outlined,
      selectedIcon: Icons.restaurant_menu,
    ),
    _Destination(
      title: 'Groceries',
      label: 'Groceries',
      icon: Icons.shopping_cart_outlined,
      selectedIcon: Icons.shopping_cart,
    ),
    _Destination(
      title: 'Inventory',
      label: 'Inventory',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
    ),
  ];

  void _select(int index) {
    setState(() => _selectedIndex = index);
  }

  void _onMenuSelected(String value) {
    final Widget? screen = switch (value) {
      'foods' => const FoodsScreen(),
      'about' => const AboutScreen(),
      _ => null,
    };

    if (screen != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    // Phones use a bottom bar; tablets, foldables and landscape use a rail.
    final useRail = width >= Breakpoints.medium;
    final extendRail = width >= Breakpoints.large;

    final body = ContentWidth(
      maxWidth: 900,
      child: IndexedStack(index: _selectedIndex, children: _tabs),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_destinations[_selectedIndex].title),
        actions: [
          PopupMenuButton<String>(
            onSelected: _onMenuSelected,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'foods',
                child: ListTile(
                  leading: Icon(Icons.fastfood_outlined),
                  title: Text('My foods'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'about',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('About PrepList'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: useRail
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _select,
                  extended: extendRail,
                  labelType: extendRail
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  destinations: [
                    for (final item in _destinations)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: Text(item.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: useRail
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _select,
              destinations: [
                for (final item in _destinations)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: item.label,
                  ),
              ],
            ),
    );
  }
}
