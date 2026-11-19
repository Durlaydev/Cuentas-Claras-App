import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import 'login_screen.dart';

/// Punto de entrada de la app en cuanto a autenticación: decide qué
/// pantalla mostrar según si hay una sesión activa o no.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, this.authenticatedHome});

  /// Pantalla a mostrar cuando hay una sesión iniciada.
  ///
  // TODO(integración): esto es intencionalmente un placeholder. Una fase
  // posterior de integración conectará aquí la pantalla principal real de
  // la app (por ejemplo, el dashboard), pasándola como `authenticatedHome`
  // desde `main.dart`. Mientras esa fase no ocurra, si no se provee este
  // parámetro se muestra un placeholder simple para poder probar el flujo
  // de autenticación de punta a punta.
  final Widget? authenticatedHome;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (!authProvider.isAuthenticated) {
      return const LoginScreen();
    }

    return authenticatedHome ??
        const Scaffold(body: Center(child: Text('Sesión iniciada')));
  }
}
