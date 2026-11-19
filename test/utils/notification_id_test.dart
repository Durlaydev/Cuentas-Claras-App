import 'package:cuentas_claras/utils/notification_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('deriveNotificationId', () {
    test('produces the same id for the same input', () {
      const String debtId = 'debt-abc-123';

      final int first = deriveNotificationId(debtId);
      final int second = deriveNotificationId(debtId);

      expect(first, equals(second));
    });

    test('produces distinct ids for a handful of distinct known inputs', () {
      const List<String> ids = <String>[
        'debt-1',
        'debt-2',
        'debt-3',
        'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        'another-debt-id',
      ];

      final Set<int> derivedIds = ids.map(deriveNotificationId).toSet();

      // No es una garantía matemática de ausencia de colisiones (el hashing
      // siempre puede colisionar), pero para este conjunto conocido de
      // strings distintas se espera que cada una produzca un id distinto.
      expect(derivedIds.length, equals(ids.length));
    });

    test('always returns a non-negative id', () {
      const List<String> ids = <String>[
        '',
        'x',
        'debt-negative-hash-candidate',
        '12345',
        'ÑOÑO-emoji-🚀-id',
      ];

      for (final String id in ids) {
        expect(deriveNotificationId(id), greaterThanOrEqualTo(0));
      }
    });
  });
}
