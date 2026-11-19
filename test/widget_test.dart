// Smoke test de arranque de la app: verifica que, sin sesión iniciada,
// `AuthGate` (conectado a un `AuthProvider` real respaldado por un
// `AuthService` falso) muestra la pantalla de login.
//
// No se construye `CuentasClarasApp` completo aquí: esa raíz depende de
// instancias reales de plugins de Firebase (`FirebaseMessaging.instance`,
// `FirebaseFirestore.instance`) que solo pueden resolverse con
// `Firebase.initializeApp` ya ejecutado contra un proyecto real, algo que
// este proyecto todavía no tiene (ver `lib/firebase_options.dart`). El
// mismo criterio ya se aplicó en el resto de la suite: la integración con
// Firebase se deja fuera de los tests automatizados y se verifica
// manualmente una vez configurado un proyecto real (capítulo de Firebase
// de la guía).
import 'dart:async';

import 'package:cuentas_claras/providers/auth_provider.dart';
import 'package:cuentas_claras/screens/auth/auth_gate.dart';
import 'package:cuentas_claras/screens/auth/login_screen.dart';
import 'package:cuentas_claras/services/auth_service.dart';
// Se oculta el `AuthProvider` que expone `firebase_auth` (relacionado con
// proveedores de OAuth) porque choca de nombre con el `AuthProvider`
// (`ChangeNotifier`) de la app.
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeAuthService implements AuthService {
  final _authStateController = StreamController<User?>.broadcast();

  @override
  Stream<User?> get authStateChanges => _authStateController.stream;

  @override
  User? get currentUser => null;

  @override
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) {
    throw UnimplementedError('No se usa en este test.');
  }

  @override
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    throw UnimplementedError('No se usa en este test.');
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('AuthGate muestra LoginScreen cuando no hay sesión activa', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(_FakeAuthService()),
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
