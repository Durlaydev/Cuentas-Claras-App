import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../utils/notification_id.dart';

/// Servicio de infraestructura responsable de programar y cancelar
/// notificaciones locales de recordatorio de vencimiento de deudas.
///
/// Es una clase Dart simple (no un `ChangeNotifier`): no mantiene estado de
/// UI ni notifica a widgets, solo coordina el plugin
/// `flutter_local_notifications` y el paquete `timezone`.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Id del canal de notificaciones usado para los recordatorios de
  /// vencimiento. Un único canal basta para el alcance de esta app.
  static const String _channelId = 'debt_reminders';
  static const String _channelName = 'Recordatorios de vencimiento';
  static const String _channelDescription =
      'Avisos de recordatorio para el vencimiento de una deuda registrada '
      'en la app.';

  /// Hora fija (24hs) en la que se muestra el recordatorio del día de
  /// vencimiento. Se elige un horario fijo (9:00) en lugar de intentar
  /// adivinar un "buen" horario a partir de la hora de creación de la deuda:
  /// es una regla simple y predecible, más fácil de razonar para quien está
  /// aprendiendo que una heurística de horario variable.
  static const int _reminderHour = 9;

  bool _initialized = false;

  /// Inicializa el soporte de timezone y el plugin de notificaciones
  /// locales. Debe llamarse una única vez, típicamente al arrancar la app,
  /// antes de programar cualquier recordatorio.
  Future<void> init() async {
    if (_initialized) {
      return;
    }

    tz_data.initializeTimeZones();

    // Simplificación deliberada: en una app de producción se debería
    // detectar la zona horaria real del dispositivo (por ejemplo, con el
    // paquete `flutter_timezone`) en lugar de asumir una zona horaria fija.
    // Acá se usa 'America/Argentina/Buenos_Aires' como valor por defecto
    // pragmático porque es la audiencia principal de esta app.
    tz.setLocalLocation(tz.getLocation('America/Argentina/Buenos_Aires'));

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings: initializationSettings);

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );

      // Requeridos a partir de Android 13 (API 33) y Android 14
      // respectivamente. En versiones anteriores estas llamadas son un
      // no-op seguro.
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }

    _initialized = true;
  }

  /// Programa un recordatorio único para el vencimiento de una deuda.
  ///
  /// El recordatorio se muestra a las 9:00 AM (hora local) del día indicado
  /// por [dueDate]. Si esa fecha/hora ya pasó, no se programa nada (no tiene
  /// sentido recordar un vencimiento que ya ocurrió).
  ///
  /// El [id] de la notificación se deriva de forma determinística a partir
  /// de [debtId] mediante [deriveNotificationId], de modo que programar el
  /// mismo `debtId` dos veces reemplaza el recordatorio anterior, y
  /// [cancelReminder] puede cancelarlo usando el mismo id.
  Future<void> scheduleDebtDueReminder({
    required String debtId,
    required String title,
    required String body,
    required DateTime dueDate,
  }) async {
    final tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      dueDate.year,
      dueDate.month,
      dueDate.day,
      _reminderHour,
    );

    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      // La fecha de vencimiento ya pasó: se omite la programación en
      // silencio en lugar de lanzar una excepción, ya que el plugin
      // rechazaría igualmente una fecha pasada.
      return;
    }

    final int notificationId = deriveNotificationId(debtId);

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        );
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      // Requiere el permiso SCHEDULE_EXACT_ALARM/USE_EXACT_ALARM. Se
      // elige la variante "AllowWhileIdle" para que el recordatorio se
      // dispare a la hora exacta incluso si el dispositivo entra en modo
      // Doze (ahorro de energía).
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Cancela el recordatorio de vencimiento asociado a [debtId], si existe.
  ///
  /// Debe llamarse cuando la deuda correspondiente se marca como pagada,
  /// se elimina, o se edita (en cuyo caso normalmente se cancela y se
  /// vuelve a programar con la nueva fecha).
  Future<void> cancelReminder(String debtId) async {
    final int notificationId = deriveNotificationId(debtId);
    await _plugin.cancel(id: notificationId);
  }

  /// Muestra una notificación local de forma inmediata, sin programarla.
  ///
  /// A diferencia de [scheduleDebtDueReminder], no usa el paquete
  /// `timezone` ni calcula ninguna fecha futura: sirve para mostrar en el
  /// momento una notificación ya recibida, por ejemplo un mensaje push de
  /// Firebase Cloud Messaging llegado con la app en primer plano (caso en
  /// el que FCM no muestra nada por sí solo).
  Future<void> showNow({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        );
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }
}
