import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import 'nav_items.dart';

/// Hosts a tab bar via StatefulShellRoute.indexedStack, which (unlike a
/// plain ShellRoute) preserves each tab's own navigation stack and scroll
/// position independently when switching tabs. Reused for both the
/// Owner/Staff shell (bottomNavItems) and the customer shell
/// (customerBottomNavItems) — the item list is a parameter, not baked in.
class BottomNavShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final List<NavItem> items;

  const BottomNavShell({
    super.key,
    required this.navigationShell,
    this.items = bottomNavItems,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: [
          for (final item in items)
            BottomNavigationBarItem(
              icon: Text(
                item.icon,
                style: const TextStyle(fontSize: 18, color: AppColors.muted),
              ),
              activeIcon: Text(
                item.icon,
                style: const TextStyle(fontSize: 18, color: AppColors.sage),
              ),
              label: item.label,
            ),
        ],
      ),
    );
  }
}
