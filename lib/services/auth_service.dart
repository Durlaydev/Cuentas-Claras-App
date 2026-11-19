import 'package:firebase_auth/firebase_auth.dart';

/// Puerto (en el sentido de arquitectura hexagonal) que expone la
/// autenticación a providers/pantallas. La UI depende únicamente de esta
/// interfaz, nunca de `FirebaseAuth` directamente: así se puede inyectar
/// una implementación falsa en tests sin necesidad de tocar Firebase, del
/// mismo modo que `PersonRepository`/`LocalPersonRepository` desacoplan la
/// UI de sqflite.
abstract class AuthService {
  /// Emite el usuario autenticado actual cada vez que cambia: al iniciar
  /// sesión, cerrar sesión, o al restaurar una sesión previa cuando arranca
  /// la app.
  Stream<User?> get authStateChanges;

  /// Usuario autenticado en este momento, o `null` si no hay sesión activa.
  User? get currentUser;

  /// Registra una cuenta nueva con email y contraseña.
  ///
  /// Lanza [AuthFailure] (nunca [FirebaseAuthException]) si Firebase
  /// rechaza el registro.
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  });

  /// Inicia sesión con email y contraseña.
  ///
  /// Lanza [AuthFailure] (nunca [FirebaseAuthException]) si Firebase
  /// rechaza el inicio de sesión.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  });

  /// Cierra la sesión activa.
  Future<void> signOut();
}

/// Implementación de [AuthService] respaldada por Firebase Authentication.
///
/// Es un envoltorio delgado (thin wrapper) alrededor de [FirebaseAuth]: no
/// agrega lógica de negocio propia, solo traduce las excepciones de
/// Firebase a [AuthFailure] para que la capa de presentación nunca necesite
/// conocer los detalles de `firebase_auth`.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  @override
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  @override
  User? get currentUser => _firebaseAuth.currentUser;

  @override
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(mapAuthErrorCode(e.code));
    }
  }

  @override
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(mapAuthErrorCode(e.code));
    }
  }

  @override
  Future<void> signOut() => _firebaseAuth.signOut();
}

/// Error propio de la capa de autenticación: envuelve los errores de
/// Firebase Auth con un mensaje en español entendible por una persona no
/// técnica. La capa de presentación siempre atrapa [AuthFailure], nunca
/// [FirebaseAuthException].
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  /// Mensaje en español, listo para mostrarse directamente en la UI.
  final String message;

  @override
  String toString() => 'AuthFailure: $message';
}

/// Traduce un código de error de [FirebaseAuthException] a un mensaje en
/// español apto para mostrarse en la UI.
///
/// Se extrae como función de nivel superior (en lugar de quedar como un
/// método privado de [FirebaseAuthService]) para poder testear el mapeo
/// completo sin necesidad de disparar ninguna llamada real a Firebase.
String mapAuthErrorCode(String code) {
  switch (code) {
    case 'email-already-in-use':
      return 'Ya existe una cuenta registrada con este correo electrónico.';
    case 'invalid-email':
      return 'El correo electrónico ingresado no es válido.';
    case 'weak-password':
      return 'La contraseña es muy débil. Usa al menos 6 caracteres.';
    case 'user-not-found':
      return 'No existe ninguna cuenta con este correo electrónico.';
    case 'wrong-password':
      return 'La contraseña ingresada es incorrecta.';
    case 'invalid-credential':
      return 'El correo electrónico o la contraseña son incorrectos.';
    case 'network-request-failed':
      return 'No se pudo conectar. Revisa tu conexión a internet e '
          'intenta de nuevo.';
    default:
      return 'Ocurrió un error inesperado. Intenta de nuevo en unos '
          'minutos.';
  }
}
