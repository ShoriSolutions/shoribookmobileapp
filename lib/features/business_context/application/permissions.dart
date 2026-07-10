import '../../../models/business_role.dart';

/// Business-wide permissions — deliberately identical to the web app's
/// src/lib/business.ts `can()` table (OWNER: everything, ADMIN:
/// everything but billing, STAFF: none of these). This is UI/repository
/// -layer gating, not a new security boundary — see the plan's "Known
/// Gaps" note: RLS itself is more permissive than this for STAFF, same
/// as on web.
enum Permission {
  manageServices,
  manageStaff,
  manageClients, // edit client profile/notes/tags, not just view contact
  viewReports,
  manageSettings,
  manageBilling,
  markDeposits,
}

const Map<BusinessRole, Set<Permission>> _rolePermissions = {
  BusinessRole.owner: {
    Permission.manageServices,
    Permission.manageStaff,
    Permission.manageClients,
    Permission.viewReports,
    Permission.manageSettings,
    Permission.manageBilling,
    Permission.markDeposits,
  },
  BusinessRole.admin: {
    Permission.manageServices,
    Permission.manageStaff,
    Permission.manageClients,
    Permission.viewReports,
    Permission.manageSettings,
    Permission.markDeposits,
  },
  BusinessRole.staff: {},
};

bool can(BusinessRole role, Permission permission) =>
    _rolePermissions[role]?.contains(permission) ?? false;

/// Appointment-status updates are the one area extended beyond the web
/// app's `can()` table for mobile, per product decision: OWNER/ADMIN can
/// update any appointment; STAFF can only update an appointment that is
/// assigned to them. Callers must always pass the true "is this
/// appointment assigned to the current staff member" check — this
/// function does not look that up itself.
bool canUpdateAppointmentStatus(
  BusinessRole role, {
  required bool isAssignedToViewer,
}) {
  if (role == BusinessRole.owner || role == BusinessRole.admin) return true;
  return isAssignedToViewer;
}

/// STAFF may view a client's contact info (name/phone/WhatsApp/email)
/// read-only when it's attached to one of their own appointments, but
/// may not edit the client's profile/notes/tags (that stays behind
/// Permission.manageClients). OWNER/ADMIN can always view.
bool canViewClientContact(BusinessRole role) => true;

/// Manual booking creation and full appointment edit/reschedule/cancel
/// stays OWNER/ADMIN only — STAFF's own-appointment allowance is status
/// updates only (confirm/complete/no-show/cancel-own), not editing time/
/// service/staff/price.
bool canCreateOrEditBooking(BusinessRole role) =>
    role == BusinessRole.owner || role == BusinessRole.admin;
