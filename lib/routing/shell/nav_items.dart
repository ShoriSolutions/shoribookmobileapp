import 'package:flutter/material.dart';
import '../../models/business_role.dart';

/// A destination in either the bottom nav or the "More" menu. Mirrors
/// the web's DashboardShell.tsx NAV_ITEMS + minRole pattern. [iconData]
/// is the Lucide-style line icon used by the customer tab bar; the older
/// [icon] glyph is kept for the vendor menu rows.
class NavItem {
  final String label;
  final String icon;
  final IconData? iconData;
  final IconData? activeIconData;
  final BusinessRole? minRole; // null = all roles

  const NavItem({
    required this.label,
    this.icon = '',
    this.iconData,
    this.activeIconData,
    this.minRole,
  });

  bool visibleFor(BusinessRole role) =>
      minRole == null || role.atLeast(minRole!);
}

/// Bottom tab bar — all 5 tabs are visible to every role; STAFF's data
/// within Calendar/Clients is filtered at the repository layer instead
/// of hiding the whole tab, since STAFF still needs their own calendar
/// and read-only client contact info.
const bottomNavItems = [
  NavItem(label: 'Home', icon: '◎'),
  NavItem(label: 'Calendar', icon: '⊞'),
  NavItem(label: 'Clients', icon: '○'),
  NavItem(label: 'Services', icon: '✦'),
  NavItem(label: 'More', icon: '☰'),
];

/// Secondary destinations shown inside the "More" tab.
const moreMenuItems = [
  NavItem(label: 'Staff', icon: '◈', minRole: BusinessRole.admin),
  NavItem(label: 'Deposits', icon: '◇', minRole: BusinessRole.admin),
  NavItem(label: 'Reports', icon: '↗', minRole: BusinessRole.admin),
  NavItem(label: 'Availability', icon: '◷', minRole: BusinessRole.admin),
  NavItem(label: 'Profile & Marketplace', icon: '❖', minRole: BusinessRole.admin),
  NavItem(label: 'Reminders', icon: '⏰', minRole: BusinessRole.admin),
  NavItem(label: 'Help & Support', icon: '☂'),
];

/// Customer/marketplace mode's bottom tab bar — Home · Search · Categories
/// · Bookings · Profile (per the marketplace-first handoff). No role
/// concept applies here (customer authorization is identity-based), so
/// every item is visible to every customer session. Favourites moved
/// under Profile.
const customerBottomNavItems = [
  NavItem(
      label: 'Home',
      iconData: Icons.home_outlined,
      activeIconData: Icons.home),
  NavItem(label: 'Search', iconData: Icons.search),
  NavItem(
      label: 'Categories',
      iconData: Icons.grid_view_outlined,
      activeIconData: Icons.grid_view),
  NavItem(
      label: 'Bookings',
      iconData: Icons.calendar_today_outlined,
      activeIconData: Icons.calendar_today),
  NavItem(
      label: 'Profile',
      iconData: Icons.person_outline,
      activeIconData: Icons.person),
];
