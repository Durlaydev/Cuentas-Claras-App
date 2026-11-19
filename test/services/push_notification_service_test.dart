import 'package:cuentas_claras/services/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractNotificationContent', () {
    test('usa el título y el cuerpo de la notificación cuando existen', () {
      const RemoteMessage message = RemoteMessage(
        notification: RemoteNotification(
          title: 'Nuevo pago registrado',
          body: 'Juan te pagó \$500',
        ),
      );

      final ({String title, String body}) content =
          extractNotificationContent(message);

      expect(content.title, equals('Nuevo pago registrado'));
      expect(content.body, equals('Juan te pagó \$500'));
    });

    test('usa textos de reemplazo cuando no hay notification', () {
      const RemoteMessage message = RemoteMessage();

      final ({String title, String body}) content =
          extractNotificationContent(message);

      expect(content.title, isNotEmpty);
      expect(content.body, isNotEmpty);
    });

    test(
      'usa textos de reemplazo cuando title y body son null',
      () {
        const RemoteMessage message = RemoteMessage(
          notification: RemoteNotification(),
        );

        final ({String title, String body}) content =
            extractNotificationContent(message);

        expect(content.title, isNotEmpty);
        expect(content.body, isNotEmpty);
      },
    );

    test('conserva el título cuando solo falta el body', () {
      const RemoteMessage message = RemoteMessage(
        notification: RemoteNotification(title: 'Recordatorio'),
      );

      final ({String title, String body}) content =
          extractNotificationContent(message);

      expect(content.title, equals('Recordatorio'));
      expect(content.body, isNotEmpty);
    });
  });
}
