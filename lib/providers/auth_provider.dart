import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

/// Estado de autenticación de la app, expuesto a la UI vía Provider.
///
/// Mantiene [user] sincronizado con el stream `authStateChanges` del
/// [AuthService] inyectado (única fuente de verdad para saber si hay una
/// sesión activa), y expone operaciones de alto nivel (registro, login,
/// logout) con manejo de estado de carga y error para que las pantallas
/// solo necesiten leer [isLoading] y [errorMessage].
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authService) {
    _authStateSubscription = _authService.authStateChanges.listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  final AuthService _authService;
  late final StreamSubscription<User?> _authStateSubscription;

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  /// Usuario autenticado actual, o `null` si no hay sesión activa. Se
  /// actualiza únicamente a través del stream `authStateChanges`.
  User? get user => _user;

  /// Indica si hay una operación de registro, login o logout en curso.
  bool get isLoading => _isLoading;

  /// Mensaje de error en español de la última operación fallida, o `null`
  /// si no hubo error (o ya fue limpiado por una operación posterior).
  String? get errorMessage => _errorMessage;

  /// Atajo para `user != null`.
  bool get isAuthenticated => _user != null;

  /// Registra una cuenta nueva. Devuelve `true` si el registro tuvo éxito.
  Future<bool> register(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.registerWithEmail(email: email, password: password);
      return true;
    } on AuthFailure catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Inicia sesión. Devuelve `true` si el login tuvo éxito.
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signInWithEmail(email: email, password: password);
      return true;
    } on AuthFailure catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cierra la sesión activa.
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _authService.signOut();

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }
}
