import 'package:flutter_test/flutter_test.dart';
import 'package:shori_book/core/utils/timezone_offsets.dart';

void main() {
  group('businessLocalToUtc', () {
    test('Barbados (UTC-4): 9:00 AM local -> 13:00 UTC', () {
      final utc = businessLocalToUtc(
        date: '2026-07-09',
        time: '09:00',
        timezone: 'America/Barbados',
      );
      expect(utc, DateTime.utc(2026, 7, 9, 13, 0));
    });

    test('Jamaica (UTC-5): 9:00 AM local -> 14:00 UTC', () {
      final utc = businessLocalToUtc(
        date: '2026-07-09',
        time: '09:00',
        timezone: 'America/Jamaica',
      );
      expect(utc, DateTime.utc(2026, 7, 9, 14, 0));
    });

    test('unknown timezone falls back to the default (Barbados)', () {
      final withUnknown = businessLocalToUtc(
        date: '2026-07-09',
        time: '09:00',
        timezone: 'Not/A_Real_Zone',
      );
      final withDefault = businessLocalToUtc(
        date: '2026-07-09',
        time: '09:00',
        timezone: 'America/Barbados',
      );
      expect(withUnknown, withDefault);
    });

    test('crossing midnight rolls over to the next UTC day', () {
      final utc = businessLocalToUtc(
        date: '2026-07-09',
        time: '23:00',
        timezone: 'America/Barbados',
      );
      expect(utc, DateTime.utc(2026, 7, 10, 3, 0));
    });
  });

  group('utcToBusinessLocal / businessLocalDateString round-trip', () {
    test('converting to UTC and back yields the same local wall time', () {
      final utc = businessLocalToUtc(
        date: '2026-07-09',
        time: '14:30',
        timezone: 'America/Barbados',
      );
      final local = utcToBusinessLocal(utc, 'America/Barbados');
      expect(local.hour, 14);
      expect(local.minute, 30);
      expect(businessLocalDateString(utc, 'America/Barbados'), '2026-07-09');
    });
  });
}
