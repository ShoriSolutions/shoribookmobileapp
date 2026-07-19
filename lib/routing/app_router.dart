import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/app_mode/application/app_mode_provider.dart';
import '../features/app_mode/presentation/unsupported_role_screen.dart';
import '../features/appointments/presentation/appointment_detail_screen.dart';
import '../features/availability/presentation/availability_screen.dart';
import '../features/profile_marketplace/presentation/business_profile_edit_screen.dart';
import '../features/profile_marketplace/presentation/profile_marketplace_screen.dart';
import '../features/auth/application/auth_providers.dart';
import '../features/auth/presentation/business_register_screen.dart';
import '../features/auth/presentation/customer_register_screen.dart';
import '../features/auth/presentation/delete_account_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_choose_screen.dart';
import '../features/auth/presentation/set_password_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/booking/presentation/booking_flow_screen.dart';
import '../features/booking_link/presentation/booking_link_screen.dart';
import '../features/business_context/application/active_business_provider.dart';
import '../features/business_context/presentation/create_business_screen.dart';
import '../features/business_context/presentation/no_business_screen.dart';
import '../features/calendar/presentation/calendar_screen.dart';
import '../features/clients/presentation/client_detail_screen.dart';
import '../features/clients/presentation/client_form_screen.dart';
import '../features/clients/presentation/clients_list_screen.dart';
import '../features/customer_booking/presentation/booking_wizard_screen.dart';
import '../features/customer_profile/presentation/customer_profile_edit_screen.dart';
import '../features/subscription/presentation/subscription_required_screen.dart';
import '../features/subscription/presentation/trial_started_screen.dart';
import '../features/customer_profile/presentation/customer_profile_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/deposits/presentation/deposits_list_screen.dart';
import '../features/favorites/presentation/favorites_screen.dart';
import '../features/marketplace/presentation/business_profile_screen.dart';
import '../features/marketplace/presentation/categories_screen.dart';
import '../features/marketplace/presentation/discover_screen.dart';
import '../features/marketplace/presentation/search_map_screen.dart';
import '../features/more/presentation/more_screen.dart';
import '../features/notifications/presentation/notification_preferences_screen.dart';
import '../features/notifications/presentation/notification_settings_screen.dart';
import '../features/notifications/presentation/notifications_feed_screen.dart';
import '../features/onboarding/application/onboarding_providers.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/my_bookings/presentation/booking_detail_screen.dart';
import '../features/my_bookings/presentation/my_bookings_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/services/presentation/service_form_screen.dart';
import '../features/services/presentation/services_list_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/staff/presentation/invite_staff_screen.dart';
import '../features/staff/presentation/staff_detail_screen.dart';
import '../features/staff/presentation/staff_list_screen.dart';
import '../features/support/presentation/support_screen.dart';
import 'route_paths.dart';
import 'shell/bottom_nav_shell.dart';
import 'shell/nav_items.dart';

const _preAuthRoutes = {
  RoutePaths.login,
  RoutePaths.forgotPassword,
  RoutePaths.setPassword,
  RoutePaths.register,
  RoutePaths.customerRegister,
  RoutePaths.businessRegister,
};

/// True for any route that belongs to the customer/marketplace shell,
/// including its public (no-login-required) browsing surface.
bool _isCustomerModePath(String path) {
  return path == RoutePaths.discover ||
      path.startsWith('${RoutePaths.discover}/') ||
      path == RoutePaths.search ||
      path == RoutePaths.categories ||
      path == RoutePaths.bookings ||
      path.startsWith('${RoutePaths.bookings}/') ||
      path == RoutePaths.favorites ||
      path.startsWith('${RoutePaths.favorites}/') ||
      path == RoutePaths.notificationsFeed ||
      path == RoutePaths.account ||
      path.startsWith('${RoutePaths.account}/') ||
      path.startsWith('/business/') ||
      path.startsWith('/book/');
}

/// True for any route that belongs to the Business Owner/Staff shell.
bool _isOwnerModePath(String path) {
  return path == RoutePaths.home ||
      path == RoutePaths.calendar ||
      path.startsWith(RoutePaths.clients) ||
      path.startsWith(RoutePaths.services) ||
      path == RoutePaths.more ||
      path.startsWith('/appointments/') ||
      path == RoutePaths.bookingNew ||
      path.startsWith(RoutePaths.staff) ||
      path == RoutePaths.deposits ||
      path == RoutePaths.bookingLink ||
      path == RoutePaths.reports ||
      path == RoutePaths.availability ||
      path == RoutePaths.profileMarketplace ||
      path == RoutePaths.editBusinessProfile ||
      path == RoutePaths.notificationSettings ||
      path.startsWith('/preview-business/') ||
      path == RoutePaths.settings ||
      path == RoutePaths.noBusiness ||
      path == RoutePaths.trialStarted ||
      path == RoutePaths.createBusiness;
}

/// Slow, smooth cross-fade page transition, used for the auth screens
/// (login ↔ register sections) so moving between them eases instead of
/// snapping. The incoming screen fades in while the outgoing one fades
/// out — for both push (via secondaryAnimation) and go/replace (the
/// outgoing page's own reverse animation).
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 600),
    reverseTransitionDuration: const Duration(milliseconds: 600),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Fade in on enter (and fade out on remove, when this animation runs
      // in reverse).
      final fadeIn = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
        reverseCurve: Curves.easeInOut,
      );
      // Fade out while being covered by the next screen (push case).
      final fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOut),
      );
      // A whisper of scale adds depth without a directional slide, which
      // keeps the animated header feeling continuous across screens.
      return FadeTransition(
        opacity: fadeIn,
        child: FadeTransition(
          opacity: fadeOut,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.99, end: 1.0).animate(fadeIn),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Plain fade-through page (fade in on enter, out on leave). Used for the
/// splash and the home shell so app-launch → home cross-fades smoothly
/// instead of hard-cutting. Ignores secondaryAnimation, so pushing a
/// detail screen over the shell doesn't fade the shell underneath.
CustomTransitionPage<dynamic> _fadeThroughPage(
    GoRouterState state, Widget child) {
  return CustomTransitionPage<dynamic>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 550),
    reverseTransitionDuration: const Duration(milliseconds: 450),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
      child: child,
    ),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = GoRouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authStatus = ref.read(authStatusProvider);
      final loc = state.matchedLocation;

      // Cold-start branded hold: stay on the splash for its minimum window
      // even if auth already resolved, so the fade-in isn't cut short.
      if (loc == RoutePaths.splash && refreshNotifier.splashHolding) {
        return null;
      }

      if (authStatus == AuthStatus.unknown) {
        return loc == RoutePaths.splash ? null : RoutePaths.splash;
      }

      if (authStatus == AuthStatus.unauthenticated) {
        // First-run intro: shown once before the marketplace. Allowed to
        // reach login/register from it (so returning users can sign in).
        final seenOnboarding = ref.read(onboardingSeenProvider);
        if (!seenOnboarding &&
            loc != RoutePaths.onboarding &&
            !_preAuthRoutes.contains(loc) &&
            loc != RoutePaths.support) {
          return RoutePaths.onboarding;
        }
        if (loc == RoutePaths.onboarding) {
          return seenOnboarding ? RoutePaths.discover : null;
        }
        if (_preAuthRoutes.contains(loc)) return null;
        if (_isCustomerModePath(loc)) return null;
        // Public help — reachable from the Guest Profile without an account.
        if (loc == RoutePaths.support) return null;
        // Browsing-first default: an unauthenticated session's home is the
        // marketplace, not a login wall — booking still requires login,
        // enforced inline by the wizard's "Confirm" step, not here.
        return RoutePaths.discover;
      }

      // Password recovery in progress — keep the user on the Set-password
      // screen until they've chosen a new one (otherwise the role-based
      // redirect below would bounce them to their home first).
      if (ref.read(passwordRecoveryProvider)) {
        return loc == RoutePaths.setPassword ? null : RoutePaths.setPassword;
      }

      // authenticated — resolve which mode this account uses before
      // deciding anything else.
      final profileAsync = ref.read(myProfileProvider);
      if (profileAsync.isLoading) {
        return (loc == RoutePaths.splash || loc == RoutePaths.setPassword)
            ? null
            : RoutePaths.splash;
      }

      final appMode = ref.read(appModeProvider);

      if (appMode == null || appMode == AppMode.unsupported) {
        return loc == RoutePaths.unsupportedRole
            ? null
            : RoutePaths.unsupportedRole;
      }

      if (appMode == AppMode.businessOwner) {
        if (loc == RoutePaths.login ||
            loc == RoutePaths.forgotPassword ||
            loc == RoutePaths.register ||
            loc == RoutePaths.customerRegister ||
            loc == RoutePaths.businessRegister) {
          return RoutePaths.home;
        }
        final membershipAsync = ref.read(activeMembershipProvider);
        if (membershipAsync.isLoading) {
          // The membership provider re-resolves whenever it's invalidated
          // (creating a business, saving profile changes, uploading a
          // logo/cover, toggling visibility…). Keep the user on whatever
          // business screen they're already on instead of bouncing to
          // splash — only fall back to splash from the entry points where
          // the destination genuinely isn't known yet.
          return (loc == RoutePaths.splash ||
                  loc == RoutePaths.setPassword ||
                  loc == RoutePaths.subscriptionRequired ||
                  _isOwnerModePath(loc))
              ? null
              : RoutePaths.splash;
        }
        final membership = membershipAsync.valueOrNull;
        if (membership == null) {
          return (loc == RoutePaths.noBusiness ||
                  loc == RoutePaths.createBusiness)
              ? null
              : RoutePaths.noBusiness;
        }
        // Access gate: no dashboard without an active trial or paid plan.
        // While locked, only the subscription-required screen (and a
        // password set from a deep link) are reachable.
        if (!membership.business.hasActiveAccess) {
          return (loc == RoutePaths.subscriptionRequired ||
                  loc == RoutePaths.setPassword)
              ? null
              : RoutePaths.subscriptionRequired;
        }
        if (loc == RoutePaths.splash ||
            loc == RoutePaths.noBusiness ||
            loc == RoutePaths.setPassword ||
            loc == RoutePaths.createBusiness ||
            loc == RoutePaths.subscriptionRequired) {
          return RoutePaths.home;
        }
        if (_isCustomerModePath(loc)) {
          return RoutePaths.home;
        }
        return null;
      }

      // appMode == AppMode.customer
      //
      // Deliberately NOT forcing a redirect away from login/register here
      // (unlike the businessOwner branch above): those routes can be
      // reached via a push from deep inside the booking wizard ("sign in
      // to book"), and a redirect-triggered `go()` replaces the whole
      // navigation stack, which would destroy the wizard screen — and its
      // in-progress state — sitting underneath. Those two screens instead
      // navigate themselves after a successful auth transition (pop back
      // to whatever pushed them, or go(splash) as a fallback when they
      // were the root route) — see login_screen.dart / customer_register_
      // screen.dart. splash/noBusiness/setPassword/unsupportedRole are
      // never reached via a mid-flow push, so forcing those is safe.
      if (loc == RoutePaths.splash ||
          loc == RoutePaths.noBusiness ||
          loc == RoutePaths.setPassword ||
          loc == RoutePaths.unsupportedRole) {
        return RoutePaths.discover;
      }
      if (_isOwnerModePath(loc)) {
        return RoutePaths.discover;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.onboarding,
        pageBuilder: (c, s) => _fadeThroughPage(s, const OnboardingScreen()),
      ),
      GoRoute(
        path: RoutePaths.splash,
        pageBuilder: (c, s) => _fadeThroughPage(s, const SplashScreen()),
      ),
      GoRoute(
        path: RoutePaths.login,
        pageBuilder: (c, s) => _fadePage(s, const LoginScreen()),
      ),
      GoRoute(
        path: RoutePaths.forgotPassword,
        pageBuilder: (c, s) => _fadePage(s, const ForgotPasswordScreen()),
      ),
      GoRoute(
        path: RoutePaths.setPassword,
        builder: (c, s) => const SetPasswordScreen(),
      ),
      GoRoute(
        path: RoutePaths.register,
        pageBuilder: (c, s) => _fadePage(s, const RegisterChooseScreen()),
      ),
      GoRoute(
        path: RoutePaths.customerRegister,
        pageBuilder: (c, s) => _fadePage(s, const CustomerRegisterScreen()),
      ),
      GoRoute(
        path: RoutePaths.businessRegister,
        pageBuilder: (c, s) => _fadePage(s, const BusinessRegisterScreen()),
      ),
      GoRoute(
        path: RoutePaths.noBusiness,
        builder: (c, s) => const NoBusinessScreen(),
      ),
      GoRoute(
        path: RoutePaths.createBusiness,
        builder: (c, s) => const CreateBusinessScreen(),
      ),
      GoRoute(
        path: RoutePaths.unsupportedRole,
        builder: (c, s) => const UnsupportedRoleScreen(),
      ),
      GoRoute(
        path: RoutePaths.subscriptionRequired,
        builder: (c, s) => const SubscriptionRequiredScreen(),
      ),
      GoRoute(
        path: RoutePaths.trialStarted,
        builder: (c, s) => const TrialStartedScreen(),
      ),

      // ── Business Owner/Staff shell ──────────────────────────────────────
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, navigationShell) => _fadeThroughPage(
          state,
          BottomNavShell(navigationShell: navigationShell),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.home,
                builder: (c, s) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.calendar,
                builder: (c, s) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.clients,
                builder: (c, s) => const ClientsListScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (c, s) => const ClientFormScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (c, s) =>
                        ClientDetailScreen(clientId: s.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: ':id/edit',
                    builder: (c, s) => ClientFormScreen(
                      clientId: s.pathParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.services,
                builder: (c, s) => const ServicesListScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (c, s) => const ServiceFormScreen(),
                  ),
                  GoRoute(
                    path: ':id/edit',
                    builder: (c, s) =>
                        ServiceFormScreen(serviceId: s.pathParameters['id']),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: RoutePaths.more, builder: (c, s) => const MoreScreen()),
            ],
          ),
        ],
      ),

      GoRoute(
        path: '/appointments/:id',
        builder: (c, s) =>
            AppointmentDetailScreen(appointmentId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: RoutePaths.bookingNew,
        builder: (c, s) => const BookingFlowScreen(),
      ),
      GoRoute(path: RoutePaths.staff, builder: (c, s) => const StaffListScreen()),
      GoRoute(
        path: RoutePaths.staffInvite,
        builder: (c, s) => const InviteStaffScreen(),
      ),
      GoRoute(
        path: '/staff/:id',
        builder: (c, s) => StaffDetailScreen(staffId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: RoutePaths.deposits,
        builder: (c, s) => const DepositsListScreen(),
      ),
      GoRoute(
        path: RoutePaths.bookingLink,
        builder: (c, s) => const BookingLinkScreen(),
      ),
      GoRoute(path: RoutePaths.reports, builder: (c, s) => const ReportsScreen()),
      GoRoute(
        path: RoutePaths.availability,
        builder: (c, s) => const AvailabilityScreen(),
      ),
      GoRoute(
        path: RoutePaths.profileMarketplace,
        builder: (c, s) => const ProfileMarketplaceScreen(),
      ),
      GoRoute(
        path: RoutePaths.editBusinessProfile,
        builder: (c, s) => const BusinessProfileEditScreen(),
      ),
      GoRoute(
        path: RoutePaths.settings,
        builder: (c, s) => const SettingsScreen(),
      ),
      // Neutral route — reachable from both the business "More" menu and
      // the customer profile, so it is intentionally not added to the
      // owner/customer mode-path lists.
      GoRoute(
        path: RoutePaths.notificationSettings,
        builder: (c, s) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.notificationPreferences,
        builder: (c, s) => const NotificationPreferencesScreen(),
      ),
      GoRoute(
        path: RoutePaths.editCustomerProfile,
        builder: (c, s) => const CustomerProfileEditScreen(),
      ),
      GoRoute(
        path: RoutePaths.support,
        builder: (c, s) => const SupportScreen(),
      ),
      GoRoute(
        path: RoutePaths.deleteAccount,
        builder: (c, s) => const DeleteAccountScreen(),
      ),

      // ── Customer/marketplace top-level routes ───────────────────────────
      GoRoute(
        path: '/business/:slug',
        builder: (c, s) =>
            BusinessProfileScreen(slug: s.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/preview-business/:slug',
        builder: (c, s) => BusinessProfileScreen(
          slug: s.pathParameters['slug']!,
          isPreview: true,
        ),
      ),
      GoRoute(
        path: '/book/:slug',
        builder: (c, s) => BookingWizardScreen(
          slug: s.pathParameters['slug']!,
          initialServiceId: s.uri.queryParameters['service'],
        ),
      ),

      // ── Customer/marketplace shell ───────────────────────────────────────
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, navigationShell) => _fadeThroughPage(
          state,
          BottomNavShell(
            navigationShell: navigationShell,
            items: customerBottomNavItems,
          ),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.discover,
                builder: (c, s) => const DiscoverScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.search,
                builder: (c, s) => const SearchMapScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.categories,
                builder: (c, s) => const CategoriesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.bookings,
                builder: (c, s) => const MyBookingsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (c, s) =>
                        BookingDetailScreen(bookingId: s.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.account,
                builder: (c, s) => const CustomerProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Favourites moved out of the tab bar (reached from Profile).
      GoRoute(
        path: RoutePaths.favorites,
        builder: (c, s) => const FavoritesScreen(),
      ),
      GoRoute(
        path: RoutePaths.notificationsFeed,
        builder: (c, s) => const NotificationsFeedScreen(),
      ),
    ],
  );
});

/// Bridges Riverpod state (auth status, profile/app-mode, and active
/// membership) to GoRouter's refreshListenable, so a redirect
/// re-evaluation fires whenever any of them change — no extra bridge
/// package needed.
class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(Ref ref) {
    ref.listen(authStatusProvider, (_, __) => notifyListeners());
    ref.listen(myProfileProvider, (_, __) => notifyListeners());
    ref.listen(activeMembershipProvider, (_, __) => notifyListeners());
    ref.listen(passwordRecoveryProvider, (_, __) => notifyListeners());
    ref.listen(onboardingSeenProvider, (_, __) => notifyListeners());
    // Hold the branded splash for a minimum moment on cold start so its
    // fade-in can play fully even when auth resolves instantly. Fires one
    // redirect re-evaluation when the window elapses.
    _splashTimer = Timer(_minSplash, () {
      _splashDone = true;
      notifyListeners();
    });
  }

  static const _minSplash = Duration(milliseconds: 2200);
  Timer? _splashTimer;
  bool _splashDone = false;

  /// True only during the initial minimum-splash window.
  bool get splashHolding => !_splashDone;

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }
}
