import 'package:flutter_test/flutter_test.dart';
import 'package:shorivo/models/appointment.dart';
import 'package:shorivo/models/business.dart';
import 'package:shorivo/models/business_member.dart';
import 'package:shorivo/models/business_role.dart';
import 'package:shorivo/models/customer.dart';
import 'package:shorivo/models/service.dart';

void main() {
  group('Business.fromJson', () {
    test('parses a full row and applies defaults for missing optional fields', () {
      final business = Business.fromJson({
        'id': 'b1',
        'owner_id': 'u1',
        'name': 'Cuts by Marcus',
        'slug': 'cuts-by-marcus',
        'timezone': 'America/Barbados',
        'currency': 'BBD',
        'badges': ['verified'],
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      });

      expect(business.name, 'Cuts by Marcus');
      expect(business.bookingEnabled, isTrue);
      expect(business.status, 'accepting_bookings');
      expect(business.badges, ['verified']);
    });
  });

  group('BusinessMember.fromJson', () {
    test('defaults status to ACTIVE when the column is absent (pre-migration project)', () {
      final member = BusinessMember.fromJson({
        'id': 'm1',
        'business_id': 'b1',
        'user_id': 'u1',
        'role': 'STAFF',
        'created_at': '2026-01-01T00:00:00Z',
      });

      expect(member.role, BusinessRole.staff);
      expect(member.status, 'ACTIVE');
    });
  });

  group('Service.effectiveDepositAmount', () {
    test('FIXED deposit uses deposit_amount directly', () {
      final service = Service.fromJson({
        'id': 's1',
        'business_id': 'b1',
        'name': 'Haircut',
        'price': 50,
        'deposit_required': true,
        'deposit_type': 'FIXED',
        'deposit_amount': 15,
      });
      expect(service.effectiveDepositAmount, 15);
    });

    test('PERCENTAGE deposit is derived from price, rounded to cents', () {
      final service = Service.fromJson({
        'id': 's2',
        'business_id': 'b1',
        'name': 'Color treatment',
        'price': 33.33,
        'deposit_required': true,
        'deposit_type': 'PERCENTAGE',
        'deposit_percentage': 25,
      });
      // 33.33 * 0.25 = 8.3325 -> rounds to 8.33
      expect(service.effectiveDepositAmount, 8.33);
    });

    test('no deposit required returns null regardless of stored fields', () {
      final service = Service.fromJson({
        'id': 's3',
        'business_id': 'b1',
        'name': 'Consultation',
        'price': 0,
        'deposit_required': false,
        'deposit_amount': 20,
      });
      expect(service.effectiveDepositAmount, isNull);
    });
  });

  group('Customer.fullName', () {
    test('joins first and last name, skipping a missing last name', () {
      final withLast = Customer.fromJson({
        'id': 'c1',
        'business_id': 'b1',
        'first_name': 'Alicia',
        'last_name': 'Browne',
        'phone': '+12460000000',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      });
      expect(withLast.fullName, 'Alicia Browne');

      final withoutLast = Customer.fromJson({
        'id': 'c2',
        'business_id': 'b1',
        'first_name': 'Alicia',
        'phone': '+12460000000',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      });
      expect(withoutLast.fullName, 'Alicia');
    });
  });

  group('Appointment.fromJson', () {
    test('prefers denormalized customer_name but falls back to the joined customer row', () {
      final withDenormalized = Appointment.fromJson({
        'id': 'a1',
        'business_id': 'b1',
        'start_time': '2026-07-09T13:00:00Z',
        'end_time': '2026-07-09T14:00:00Z',
        'status': 'confirmed',
        'deposit_required': false,
        'deposit_paid': false,
        'deposit_status': 'NOT_REQUIRED',
        'cancellation_policy_accepted': false,
        'customer_name': 'Walk-in Override',
        'booking_source': 'WALK_IN',
        'created_at': '2026-07-01T00:00:00Z',
        'updated_at': '2026-07-01T00:00:00Z',
        'customers': {
          'first_name': 'Real',
          'last_name': 'Customer',
          'phone': '+12460000000',
        },
      });
      expect(withDenormalized.customerName, 'Walk-in Override');

      final withoutDenormalized = Appointment.fromJson({
        'id': 'a2',
        'business_id': 'b1',
        'start_time': '2026-07-09T13:00:00Z',
        'end_time': '2026-07-09T14:00:00Z',
        'status': 'confirmed',
        'deposit_required': false,
        'deposit_paid': false,
        'deposit_status': 'NOT_REQUIRED',
        'cancellation_policy_accepted': false,
        'booking_source': 'ONLINE',
        'created_at': '2026-07-01T00:00:00Z',
        'updated_at': '2026-07-01T00:00:00Z',
        'customers': {
          'first_name': 'Real',
          'last_name': 'Customer',
          'phone': '+12460000000',
        },
      });
      expect(withoutDenormalized.customerName, 'Real Customer');
    });

    test('isActive is false for cancelled and no_show, true otherwise', () {
      Appointment build(String status) => Appointment.fromJson({
        'id': 'a1',
        'business_id': 'b1',
        'start_time': '2026-07-09T13:00:00Z',
        'end_time': '2026-07-09T14:00:00Z',
        'status': status,
        'deposit_required': false,
        'deposit_paid': false,
        'deposit_status': 'NOT_REQUIRED',
        'cancellation_policy_accepted': false,
        'booking_source': 'ONLINE',
        'created_at': '2026-07-01T00:00:00Z',
        'updated_at': '2026-07-01T00:00:00Z',
      });

      expect(build(AppointmentStatus.confirmed).isActive, isTrue);
      expect(build(AppointmentStatus.pending).isActive, isTrue);
      expect(build(AppointmentStatus.completed).isActive, isTrue);
      expect(build(AppointmentStatus.cancelled).isActive, isFalse);
      expect(build(AppointmentStatus.noShow).isActive, isFalse);
    });
  });

  group('BookingSource', () {
    test('does not include QR — the DB constraint rejects it', () {
      expect(BookingSource.all, isNot(contains('QR')));
    });
  });
}
