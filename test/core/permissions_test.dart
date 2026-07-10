import 'package:flutter_test/flutter_test.dart';
import 'package:shori_book/features/business_context/application/permissions.dart';
import 'package:shori_book/models/business_role.dart';

void main() {
  group('can()', () {
    test('OWNER has every permission, including billing', () {
      for (final p in Permission.values) {
        expect(can(BusinessRole.owner, p), isTrue, reason: p.name);
      }
    });

    test('ADMIN has every permission except billing', () {
      for (final p in Permission.values) {
        final expected = p != Permission.manageBilling;
        expect(can(BusinessRole.admin, p), expected, reason: p.name);
      }
    });

    test('STAFF has no business-wide permissions (matches web app)', () {
      for (final p in Permission.values) {
        expect(can(BusinessRole.staff, p), isFalse, reason: p.name);
      }
    });
  });

  group('canUpdateAppointmentStatus()', () {
    test('OWNER and ADMIN can update any appointment', () {
      expect(
        canUpdateAppointmentStatus(
          BusinessRole.owner,
          isAssignedToViewer: false,
        ),
        isTrue,
      );
      expect(
        canUpdateAppointmentStatus(
          BusinessRole.admin,
          isAssignedToViewer: false,
        ),
        isTrue,
      );
    });

    test('STAFF can only update their own assigned appointment', () {
      expect(
        canUpdateAppointmentStatus(
          BusinessRole.staff,
          isAssignedToViewer: true,
        ),
        isTrue,
      );
      expect(
        canUpdateAppointmentStatus(
          BusinessRole.staff,
          isAssignedToViewer: false,
        ),
        isFalse,
      );
    });
  });

  group('canCreateOrEditBooking()', () {
    test('only OWNER/ADMIN can create or edit bookings', () {
      expect(canCreateOrEditBooking(BusinessRole.owner), isTrue);
      expect(canCreateOrEditBooking(BusinessRole.admin), isTrue);
      expect(canCreateOrEditBooking(BusinessRole.staff), isFalse);
    });
  });

  group('BusinessRole.atLeast()', () {
    test('rank ordering is OWNER > ADMIN > STAFF', () {
      expect(BusinessRole.owner.atLeast(BusinessRole.admin), isTrue);
      expect(BusinessRole.admin.atLeast(BusinessRole.owner), isFalse);
      expect(BusinessRole.staff.atLeast(BusinessRole.staff), isTrue);
    });
  });
}
