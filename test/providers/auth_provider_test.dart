import 'dart:async';

import 'package:cuentas_claras/providers/auth_provider.dart';
import 'package:cuentas_claras/services/auth_service.dart';
// `firebase_auth` expone su propia clase `AuthProvider` (relacionada con
// proveedores de OAuth, no con el estado de sesión de la app), que choca
// con nuestro `AuthProvider` (el `ChangeNotifier`). Se oculta la del
// paquete porque aquí no se usa.
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter_test/flutter_test.dart';

/// Doble de test de [AuthService]: no toca Firebase para nada, solo
/// permite simular éxito/fracaso de las operaciones y emitir manualmente
/// eventos de `authStateChanges` para probar cómo [AuthProvider] reacciona
/// a ellos.
class _FakeAuthService implements AuthService {
  final _authStateController = StreamController<User?>.broadcast();

  /// Si no es nulo, la próxima llamada a `registerWithEmail` o
  /// `signInWithEmail` lanza este error en lugar de "tener éxito".
  AuthFailure? failureToThrow;

  int registerCallCount = 0;
  int signInCallCount = 0;
  int signOutCallCount = 0;

  @override
  Stream<User?> get authStateChanges => _authStateController.stream;

  @override
  User? get currentUser => null;

  @override
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    registerCallCount++;
    final failure = failureToThrow;
    if (failure != null) {
      throw failure;
    }
    return _FakeUserCredential();
  }

  @override
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signInCallCount++;
    final failure = failureToThrow;
    if (failure != null) {
      throw failure;
    }
    return _FakeUserCredential();
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    // El signOut real de Firebase siempre termina emitiendo `null` por
    // authStateChanges; se simula el mismo comportamiento aquí.
    _authStateController.add(null);
  }

  /// Simula un cambio de sesión (login externo, restauración de sesión al
  /// arrancar la app, etc.) emitiendo manualmente un evento en el stream.
  void emitAuthState(User? user) => _authStateController.add(user);

  Future<void> dispose() => _authStateController.close();
}

/// [UserCredential] no se puede construir directamente (constructor
/// privado), pero como es una clase concreta común (no `sealed`/`base`),
/// se puede implementar su interfaz desde otra librería. Como
/// [AuthProvider] nunca lee nada de la credencial devuelta (confía
/// exclusivamente en el stream `authStateChanges` para saber quién es el
/// usuario actual), basta con este doble vacío: sobreescribir
/// `noSuchMethod` evita tener que implementar cada miembro uno por uno.
class _FakeUserCredential implements UserCredential {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mismo truco que [_FakeUserCredential], para simular un [User] sin
/// depender de Firebase.
class _FakeUser implements User {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _flushMicrotasks() => Future<void>.delayed(Duration.zero);

void main() {
  late _FakeAuthService fakeAuthService;
  late AuthProvider authProvider;

  setUp(() {
    fakeAuthService = _FakeAuthService();
    authProvider = AuthProvider(fakeAuthService);
  });

  tearDown(() async {
    authProvider.dispose();
    await fakeAuthService.dispose();
  });

  test('estado inicial: sin usuario, sin carga, sin error', () {
    expect(authProvider.user, isNull);
    expect(authProvider.isAuthenticated, isFalse);
    expect(authProvider.isLoading, isFalse);
    expect(authProvider.errorMessage, isNull);
  });

  group('login', () {
    test('éxito: devuelve true y no deja isLoading en true', () async {
      final result = await authProvider.login('a@a.com', 'password123');

      expect(result, isTrue);
      expect(fakeAuthService.signInCallCount, 1);
      expect(authProvider.isLoading, isFalse);
      expect(authProvider.errorMessage, isNull);
    });

    test('fracaso: devuelve false y expone errorMessage', () async {
      fakeAuthService.failureToThrow = const AuthFailure(
        'La contraseña ingresada es incorrecta.',
      );

      final result = await authProvider.login('a@a.com', 'password123');

      expect(result, isFalse);
      expect(
        authProvider.errorMessage,
        'La contraseña ingresada es incorrecta.',
      );
      expect(authProvider.isLoading, isFalse);
    });

    test('notifica a los listeners al iniciar y al terminar', () async {
      var notifyCount = 0;
      authProvider.addListener(() => notifyCount++);

      await authProvider.login('a@a.com', 'password123');

      expect(notifyCount, greaterThanOrEqualTo(2));
    });
  });

  group('register', () {
    test('éxito: devuelve true', () async {
      final result = await authProvider.register('a@a.com', 'password123');

      expect(result, isTrue);
      expect(fakeAuthService.registerCallCount, 1);
      expect(authProvider.errorMessage, isNull);
    });

    test('fracaso: devuelve false y expone errorMessage', () async {
      fakeAuthService.failureToThrow = const AuthFailure(
        'Ya existe una cuenta registrada con este correo electrónico.',
      );

      final result = await authProvider.register('a@a.com', 'password123');

      expect(result, isFalse);
      expect(
        authProvider.errorMessage,
        'Ya existe una cuenta registrada con este correo electrónico.',
      );
    });

    test('un intento fallido previo no deja errorMessage pegado tras uno exitoso', () async {
      fakeAuthService.failureToThrow = const AuthFailure('falló');
      await authProvider.register('a@a.com', 'password123');
      expect(authProvider.errorMessage, 'falló');

      fakeAuthService.failureToThrow = null;
      final result = await authProvider.register('a@a.com', 'password123');

      expect(result, isTrue);
      expect(authProvider.errorMessage, isNull);
    });
  });

  group('authStateChanges', () {
    test('sincroniza user/isAuthenticated cuando el stream emite', () async {
      final fakeUser = _FakeUser();

      fakeAuthService.emitAuthState(fakeUser);
      await _flushMicrotasks();

      expect(authProvider.user, same(fakeUser));
      expect(authProvider.isAuthenticated, isTrue);

      fakeAuthService.emitAuthState(null);
      await _flushMicrotasks();

      expect(authProvider.user, isNull);
      expect(authProvider.isAuthenticated, isFalse);
    });
  });

  group('logout', () {
    test('llama a signOut y termina sin isLoading en true', () async {
      final fakeUser = _FakeUser();
      fakeAuthService.emitAuthState(fakeUser);
      await _flushMicrotasks();
      expect(authProvider.isAuthenticated, isTrue);

      await authProvider.logout();
      await _flushMicrotasks();

      expect(fakeAuthService.signOutCallCount, 1);
      expect(authProvider.isLoading, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
    });
  });
}
