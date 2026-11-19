import 'package:cuentas_claras/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // No se puede levantar Firebase real en un test unitario, así que estos
  // tests se concentran exclusivamente en la lógica de mapeo de errores de
  // `mapAuthErrorCode`, que es pura y no depende de Firebase para nada.
  group('mapAuthErrorCode', () {
    test('email-already-in-use', () {
      expect(
        mapAuthErrorCode('email-already-in-use'),
        'Ya existe una cuenta registrada con este correo electrónico.',
      );
    });

    test('invalid-email', () {
      expect(
        mapAuthErrorCode('invalid-email'),
        'El correo electrónico ingresado no es válido.',
      );
    });

    test('weak-password', () {
      expect(
        mapAuthErrorCode('weak-password'),
        'La contraseña es muy débil. Usa al menos 6 caracteres.',
      );
    });

    test('user-not-found', () {
      expect(
        mapAuthErrorCode('user-not-found'),
        'No existe ninguna cuenta con este correo electrónico.',
      );
    });

    test('wrong-password', () {
      expect(
        mapAuthErrorCode('wrong-password'),
        'La contraseña ingresada es incorrecta.',
      );
    });

    test('invalid-credential', () {
      expect(
        mapAuthErrorCode('invalid-credential'),
        'El correo electrónico o la contraseña son incorrectos.',
      );
    });

    test('network-request-failed', () {
      expect(
        mapAuthErrorCode('network-request-failed'),
        'No se pudo conectar. Revisa tu conexión a internet e intenta de '
            'nuevo.',
      );
    });

    test('código desconocido usa el mensaje genérico de fallback', () {
      expect(
        mapAuthErrorCode('algun-codigo-que-firebase-no-documenta'),
        'Ocurrió un error inesperado. Intenta de nuevo en unos minutos.',
      );
    });

    test('funciona a partir del código real de un FirebaseAuthException', () {
      // FirebaseAuthException se puede construir directamente sin
      // necesidad de red ni de un emulador (no es const: su constructor
      // real recibe además otros parámetros opcionales de contexto).
      final exception = FirebaseAuthException(code: 'user-not-found');

      expect(
        mapAuthErrorCode(exception.code),
        'No existe ninguna cuenta con este correo electrónico.',
      );
    });
  });

  group('AuthFailure', () {
    test('expone el mensaje recibido', () {
      const failure = AuthFailure('mensaje de prueba');

      expect(failure.message, 'mensaje de prueba');
    });

    test('toString incluye el mensaje', () {
      const failure = AuthFailure('mensaje de prueba');

      expect(failure.toString(), contains('mensaje de prueba'));
    });
  });
}
