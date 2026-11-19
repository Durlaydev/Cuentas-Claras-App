import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/local/app_database.dart';
import 'data/local/debt_local_datasource.dart';
import 'data/local/payment_local_datasource.dart';
import 'data/local/person_local_datasource.dart';
import 'data/remote/debt_remote_datasource.dart';
import 'data/remote/payment_remote_datasource.dart';
import 'data/remote/person_remote_datasource.dart';
import 'data/repositories/debt_repository.dart';
import 'data/repositories/local_debt_repository.dart';
import 'data/repositories/local_payment_repository.dart';
import 'data/repositories/local_person_repository.dart';
import 'data/repositories/payment_repository.dart';
import 'data/repositories/person_repository.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/debts_provider.dart';
import 'providers/people_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/home_shell.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/push_notification_service.dart';
import 'services/sync_service.dart';

/// Punto de entrada de la app.
///
/// Todo el trabajo asíncrono de arranque (Firebase, `SharedPreferences`,
/// apertura de la base de datos local, inicialización de notificaciones)
/// se resuelve ACÁ, antes de `runApp`, en lugar de dentro de los widgets.
/// Esto evita pantallas de carga intermedias para la infraestructura básica
/// y permite construir el árbol de providers una única vez con todo ya
/// disponible.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Debe registrarse ANTES de `runApp` (y, en rigor, antes que cualquier
  // otro uso de `firebase_messaging`): es el requisito documentado por el
  // plugin para poder despachar mensajes en segundo plano a un isolate
  // separado.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // `Firebase.initializeApp` usa las credenciales de `firebase_options.dart`.
  // Mientras ese archivo sea el placeholder generado por esta guía (sin un
  // proyecto real detrás), esta llamada falla en tiempo de ejecución en un
  // dispositivo real -- eso es esperado hasta que se ejecute
  // `flutterfire configure` con un proyecto real (ver capítulo de Firebase).
  // Se envuelve en un try/catch para que la app pueda seguir arrancando
  // igual (por ejemplo, para poder navegar la UI sin backend) en lugar de
  // quedar en una pantalla blanca sin explicación.
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (error, stackTrace) {
    debugPrint('Firebase.initializeApp falló (¿todavía no hay proyecto real?): $error\n$stackTrace');
  }

  final SharedPreferences preferences = await SharedPreferences.getInstance();

  final AppDatabase appDatabase = AppDatabase();

  final PersonLocalDataSource personLocalDataSource = PersonLocalDataSource(appDatabase);
  final DebtLocalDataSource debtLocalDataSource = DebtLocalDataSource(appDatabase);
  final PaymentLocalDataSource paymentLocalDataSource = PaymentLocalDataSource(appDatabase);

  final PersonRepository personRepository = LocalPersonRepository(personLocalDataSource);
  final DebtRepository debtRepository = LocalDebtRepository(debtLocalDataSource);
  final PaymentRepository paymentRepository = LocalPaymentRepository(paymentLocalDataSource);

  final SyncService syncService = SyncService(
    personLocal: personLocalDataSource,
    debtLocal: debtLocalDataSource,
    paymentLocal: paymentLocalDataSource,
    personRemote: PersonRemoteDataSource(),
    debtRemote: DebtRemoteDataSource(),
    paymentRemote: PaymentRemoteDataSource(),
  );

  final NotificationService notificationService = NotificationService();
  // Igual que con Firebase: en un entorno sin permisos/plugins nativos
  // completos (por ejemplo, corriendo en un emulador recién creado) esta
  // inicialización puede fallar; se aísla para no tumbar el arranque de
  // toda la app por una funcionalidad secundaria (los recordatorios).
  try {
    await notificationService.init();
  } catch (error, stackTrace) {
    debugPrint('NotificationService.init falló: $error\n$stackTrace');
  }

  final AuthService authService = FirebaseAuthService();
  final PushNotificationService pushNotificationService = PushNotificationService(
    notificationService: notificationService,
  );

  runApp(
    CuentasClarasApp(
      personRepository: personRepository,
      debtRepository: debtRepository,
      paymentRepository: paymentRepository,
      authService: authService,
      notificationService: notificationService,
      pushNotificationService: pushNotificationService,
      syncService: syncService,
      preferences: preferences,
    ),
  );
}

/// Raíz de la app: arma el árbol de `Provider`/`ChangeNotifierProvider` con
/// todas las dependencias ya resueltas por [main], y define el
/// `MaterialApp` (tema claro/oscuro según [ThemeProvider], punto de entrada
/// [AuthGate]).
///
/// Recibe todas sus dependencias por constructor en lugar de construirlas
/// internamente para poder testear este widget con dependencias falsas si
/// hiciera falta más adelante (mismo principio de inyección de
/// dependencias que se usó en repositorios y providers).
class CuentasClarasApp extends StatelessWidget {
  const CuentasClarasApp({
    super.key,
    required this.personRepository,
    required this.debtRepository,
    required this.paymentRepository,
    required this.authService,
    required this.notificationService,
    required this.pushNotificationService,
    required this.syncService,
    required this.preferences,
  });

  final PersonRepository personRepository;
  final DebtRepository debtRepository;
  final PaymentRepository paymentRepository;
  final AuthService authService;
  final NotificationService notificationService;
  final PushNotificationService pushNotificationService;
  final SyncService syncService;
  final SharedPreferences preferences;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Servicios de infraestructura: se registran con `Provider.value`
        // (no son `ChangeNotifier`, no necesitan reconstruir la UI por sí
        // mismos) para que las pantallas puedan pedirlos con
        // `context.read<T>()` sin que cada pantalla tenga que recibirlos
        // por constructor.
        Provider<NotificationService>.value(value: notificationService),
        Provider<PushNotificationService>.value(value: pushNotificationService),
        Provider<SyncService>.value(value: syncService),

        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider(authService)),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider(preferences)),
        ChangeNotifierProvider<PeopleProvider>(
          create: (_) => PeopleProvider(personRepository, debtRepository, paymentRepository),
        ),
        ChangeNotifierProvider<DebtsProvider>(
          create: (_) => DebtsProvider(debtRepository, paymentRepository),
        ),
        ChangeNotifierProvider<DashboardProvider>(
          create: (_) => DashboardProvider(debtRepository, paymentRepository),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Cuentas Claras',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.indigo,
                brightness: Brightness.dark,
              ),
            ),
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const AuthGate(authenticatedHome: HomeShell()),
          );
        },
      ),
    );
  }
}
