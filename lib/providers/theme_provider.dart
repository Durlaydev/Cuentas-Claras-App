import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Responsable de leer y persistir la preferencia de tema oscuro/claro.
///
/// Recibe una instancia ya resuelta de [SharedPreferences] por constructor,
/// en lugar de un `Future<SharedPreferences> Function()` o de resolverla
/// internamente: `main.dart` ya necesita llamar a
/// `SharedPreferences.getInstance()` una única vez, antes de construir el
/// árbol de providers, entre otras cosas para poder elegir el `ThemeMode`
/// inicial de `MaterialApp` sin parpadeos (arrancar en claro y solo
/// después de un frame cambiar a oscuro se nota). Recibir la instancia ya
/// resuelta evita que este provider dependa de un `Future` propio y
/// simplifica los tests (con `SharedPreferences.setMockInitialValues`, la
/// instancia se resuelve de forma síncrona en la práctica).
///
/// El valor persistido se lee de forma eager en el constructor: es seguro
/// hacerlo de forma síncrona porque `SharedPreferences` ya cachea todos los
/// valores en memoria después de `getInstance()`.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider(this._preferences) : _isDarkMode = _preferences.getBool(_darkModeKey) ?? false;

  /// Clave usada para persistir la preferencia en `SharedPreferences`.
  static const String _darkModeKey = 'dark_mode_enabled';

  final SharedPreferences _preferences;
  bool _isDarkMode;

  bool get isDarkMode => _isDarkMode;

  /// Invierte el modo oscuro actual, lo persiste y notifica a los
  /// listeners.
  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    await _preferences.setBool(_darkModeKey, _isDarkMode);
    notifyListeners();
  }
}
