/// String-path route constants — no codegen, easy to grep.
class RoutePaths {
  const RoutePaths._();

  static const splash = '/splash';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const setPassword = '/set-password';
  static const noBusiness = '/no-business';
  static const createBusiness = '/create-business';
  static const register = '/register'; // account-type chooser
  static const customerRegister = '/register/customer';
  static const businessRegister = '/register/business';
  static const unsupportedRole = '/unsupported-role';

  // Business Owner/Staff mode
  static const home = '/home';
  static const calendar = '/calendar';
  static const clients = '/clients';
  static const clientNew = '/clients/new';
  static const services = '/services';
  static const serviceNew = '/services/new';
  static const more = '/more';

  static const appointmentDetail = '/appointments/:id';
  static const bookingNew = '/booking/new';
  static const staff = '/staff';
  static const staffInvite = '/staff/invite';
  static const deposits = '/deposits';
  static const bookingLink = '/booking-link';
  static const reports = '/reports';
  static const availability = '/availability';
  static const profileMarketplace = '/profile-marketplace';
  static const editBusinessProfile = '/business-profile';
  static const notificationSettings = '/notification-settings';
  static const notificationPreferences = '/notification-preferences';
  static const editCustomerProfile = '/edit-profile';
  static const support = '/support';
  static const deleteAccount = '/delete-account';
  static const settings = '/settings';
  static const subscriptionRequired = '/subscription-required';

  static String clientDetail(String id) => '/clients/$id';
  static String clientEdit(String id) => '/clients/$id/edit';
  static String serviceEdit(String id) => '/services/$id/edit';
  static String staffDetail(String id) => '/staff/$id';
  static String appointmentDetailPath(String id) => '/appointments/$id';

  // Customer/marketplace mode
  static const discover = '/discover';
  static const bookings = '/bookings';
  static const favorites = '/favorites';
  static const account = '/account';

  static String businessProfile(String slug) => '/business/$slug';

  /// Owner-only preview of their own public marketplace profile.
  static String previewBusiness(String slug) => '/preview-business/$slug';
  static String bookingWizard(String slug) => '/book/$slug';

  /// Booking flow opened straight onto a chosen service (skips the
  /// service-picker step) — used by the tap-to-book service rows.
  static String bookingWizardService(String slug, String serviceId) =>
      '/book/$slug?service=$serviceId';
  static String bookingDetail(String id) => '/bookings/$id';
}
