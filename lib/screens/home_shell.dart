import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/debts_provider.dart';
import '../providers/theme_provider.dart';
import '../services/push_notification_service.dart';
import '../services/sync_service.dart';
import 'dashboard/dashboard_screen.dart';
import 'people/people_list_screen.dart';

/// Pantalla principal autenticada de la app: un `Scaffold` con navegación
/// inferior de 2 pestañas ("Personas" y "Resumen").
///
/// Usa `IndexedStack` (en lugar de reconstruir la pantalla activa con un
/// `switch`) para que cada pestaña conserve su estado (scroll, filtros,
/// etc.) al cambiar de pestaña y volver.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  static const List<Widget> _tabs = [PeopleListScreen(), DashboardScreen()];

  @override
  void initState() {
    super.initState();
    // Ver el comentario equivalente en PeopleListScreen/DashboardScreen: se
    // posterga la carga inicial al primer frame para no notificar listeners
    // durante la fase de build. `DebtsProvider` se hidrata aquí (una sola vez,
    // al montar el shell autenticado) porque `PersonDetailScreen` y
    // `DebtDetailScreen` lo consumen directamente sin pasar por una pantalla
    // que ya dispare su propia carga.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DebtsProvider>().loadAll();
      _syncAndRegisterPush();
    });
  }

  /// Dispara, en segundo plano y sin bloquear la UI, la sincronización con
  /// Firestore y el registro del token de FCM para el usuario ya
  /// autenticado (este widget solo se monta como `authenticatedHome` de
  /// [AuthGate], así que siempre hay una sesión activa aquí).
  ///
  /// Ambas operaciones dependen de un proyecto real de Firebase (ver
  /// `lib/firebase_options.dart`); mientras se use el placeholder, es
  /// esperable que fallen. Se atrapan los errores para que un backend no
  /// configurado nunca rompa la navegación de la app: la app debe seguir
  /// siendo utilizable en modo local-only.
  void _syncAndRegisterPush() {
    final String? uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;

    context.read<SyncService>().fullSync(uid).catchError((Object error, StackTrace stackTrace) {
      debugPrint('SyncService.fullSync falló: $error\n$stackTrace');
    });

    context.read<PushNotificationService>().init(uid: uid).catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      debugPrint('PushNotificationService.init falló: $error\n$stackTrace');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuentas Claras'),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: isDarkMode ? 'Modo claro' : 'Modo oscuro',
            onPressed: () => context.read<ThemeProvider>().toggleDarkMode(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Personas'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart_outline), label: 'Resumen'),
        ],
      ),
    );
  }
}
