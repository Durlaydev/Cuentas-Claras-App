import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'notification_service.dart';

/// Extrae el título y el cuerpo a mostrar a partir de un [RemoteMessage] de
/// Firebase Cloud Messaging.
///
/// Es una función pura, sin dependencias de Firebase inicializado ni de
/// I/O, para que pueda probarse de forma aislada. Si el mensaje no trae un
/// [RemoteMessage.notification], o este no trae título/cuerpo, se devuelven
/// textos de reemplazo en lugar de propagar `null` hacia la UI.
({String title, String body}) extractNotificationContent(
  RemoteMessage message,
) {
  final RemoteNotification? notification = message.notification;

  final String title = notification?.title ?? 'Cuentas Claras';
  final String body =
      notification?.body ?? 'Tienes una notificación nueva.';

  return (title: title, body: body);
}

/// Handler de mensajes de Firebase Cloud Messaging recibidos con la app en
/// segundo plano o terminada.
///
/// **Importante (fuente común de confusión):** cuando el mensaje incluye un
/// payload `notification`, Android lo muestra automáticamente en la bandeja
/// del sistema sin ejecutar ningún código de la app, tanto en segundo plano
/// como con la app terminada. Este handler NO es responsable de mostrar esa
/// notificación.
///
/// Este handler solo tiene sentido para mensajes "data-only" (sin
/// `notification`, solo con [RemoteMessage.data]), donde la app sí necesita
/// ejecutar código propio (por ejemplo, sincronizar datos) antes de que el
/// usuario interactúe con la notificación. Se mantiene deliberadamente vacío
/// porque esta fase no implementa ninguna sincronización en segundo plano.
///
/// Debe ser una función de nivel superior (no un método de clase ni una
/// función anónima): es un requisito de la API de `firebase_messaging` para
/// poder ejecutarse en un isolate separado en segundo plano.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Intencionalmente vacío: ver documentación de la función.
}

/// Servicio de infraestructura responsable de la integración con Firebase
/// Cloud Messaging (FCM): solicitar permiso de notificaciones, obtener y
/// mantener actualizado el token del dispositivo en Firestore, y reaccionar
/// a los mensajes push recibidos con la app en primer plano o al tocar una
/// notificación que reabre la app.
///
/// ## Wiring pendiente en `main.dart`
///
/// Esta clase no se conecta sola: una fase de integración posterior (no
/// implementada aquí) debe agregar, ANTES de `runApp`:
///
/// ```dart
/// WidgetsFlutterBinding.ensureInitialized();
/// FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
/// ```
///
/// y, luego de un login exitoso (una vez que se dispone de un `uid`):
///
/// ```dart
/// await PushNotificationService(
///   notificationService: notificationService,
/// ).init(uid: uid);
/// ```
class PushNotificationService {
  PushNotificationService({
    FirebaseMessaging? messaging,
    required NotificationService notificationService,
    this.onNotificationTapped,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _notificationService = notificationService;

  final FirebaseMessaging _messaging;
  final NotificationService _notificationService;

  /// Callback opcional invocado cuando el usuario toca una notificación push
  /// y eso reabre la app desde un estado en segundo plano (no terminada).
  ///
  /// La navegación real hacia una pantalla específica según el contenido del
  /// mensaje depende del sistema de rutas/pantallas de la app, implementado
  /// en otra fase; aquí solo se expone el punto de enganche.
  final void Function(RemoteMessage message)? onNotificationTapped;

  /// Solicita al usuario permiso para mostrar notificaciones.
  ///
  /// En Android 13 (API 33) en adelante, esto dispara el diálogo del sistema
  /// respaldado por el permiso `POST_NOTIFICATIONS` (ya declarado en el
  /// manifest de la app). En versiones anteriores de Android, la llamada es
  /// un no-op: ese permiso no existe ahí y las notificaciones están
  /// habilitadas por defecto.
  Future<void> requestPermission() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  /// Obtiene el token FCM actual del dispositivo, o `null` si todavía no
  /// pudo generarse (por ejemplo, sin conexión o sin Firebase configurado).
  Future<String?> getToken() async {
    return _messaging.getToken();
  }

  /// Persiste el token FCM actual del dispositivo en el documento del
  /// usuario en Firestore (`users/{uid}`), para que el backend pueda
  /// enviarle mensajes push a este dispositivo.
  ///
  /// Si todavía no hay token disponible, no escribe nada.
  Future<void> saveTokenToFirestore(String uid) async {
    final String? token = await getToken();
    if (token == null) {
      return;
    }

    await _writeToken(uid: uid, token: token);
  }

  Future<void> _writeToken({required String uid, required String token}) {
    return FirebaseFirestore.instance.collection('users').doc(uid).set(
      <String, Object?>{
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Orquesta la inicialización completa del servicio de push: pide
  /// permiso, guarda el token actual en Firestore, se suscribe a futuras
  /// renovaciones de token (para mantenerlo siempre actualizado), y registra
  /// los listeners de mensajes en primer plano y de apertura de la app desde
  /// una notificación tocada.
  ///
  /// Debe llamarse una única vez por sesión de usuario autenticado,
  /// típicamente inmediatamente después de un login exitoso, cuando ya se
  /// dispone del [uid] del usuario.
  Future<void> init({required String uid}) async {
    await requestPermission();
    await saveTokenToFirestore(uid);

    _messaging.onTokenRefresh.listen((String newToken) {
      _writeToken(uid: uid, token: newToken);
    });

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
  }

  /// Maneja un mensaje push recibido con la app en primer plano.
  ///
  /// A diferencia de segundo plano o app terminada, mientras la app está en
  /// primer plano FCM NO muestra ninguna notificación del sistema de forma
  /// automática: por eso aquí se la muestra explícitamente, reutilizando el
  /// mecanismo de notificaciones locales que ya usa la app para los
  /// recordatorios de vencimiento.
  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final ({String title, String body}) content = extractNotificationContent(
      message,
    );

    await _notificationService.showNow(
      title: content.title,
      body: content.body,
      payload: message.messageId,
    );
  }

  /// Maneja el toque de una notificación push que reabrió la app desde un
  /// estado en segundo plano (no terminada).
  ///
  /// Acá solo se invoca el punto de enganche [onNotificationTapped]: la
  /// navegación real hacia una pantalla específica depende del sistema de
  /// rutas de la app, que corresponde a otra fase.
  void _onMessageOpenedApp(RemoteMessage message) {
    onNotificationTapped?.call(message);
  }
}
