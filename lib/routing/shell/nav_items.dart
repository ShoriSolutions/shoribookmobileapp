import '../../models/business_role.dart';

/// A destination in either the bottom nav or the "More" menu. Mirrors
/// the web's DashboardShell.tsx NAV_ITEMS + minRole pattern.
class NavItem {
  final String label;
  final String icon;
  final BusinessRole? minRole; // null = all roles

  const NavItem({required this.label, required this.icon, this.minRole});

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

/// Customer/marketplace mode's bottom tab bar — no role concept applies
/// here (customer authorization is identity-based, not role-based), so
/// every item is visible to every customer session.
const customerBottomNavItems = [
  NavItem(label: 'Discover', icon: '⊙'),
  NavItem(label: 'My Bookings', icon: '▤'),
  NavItem(label: 'Favorites', icon: '♡'),
  NavItem(label: 'Profile', icon: '◐'),
];
