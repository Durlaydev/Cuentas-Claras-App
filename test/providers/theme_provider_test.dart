import 'package:cuentas_claras/providers/theme_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el valor por defecto es modo claro cuando no hay nada persistido', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    final provider = ThemeProvider(preferences);

    expect(provider.isDarkMode, isFalse);
  });

  test('toggleDarkMode invierte el flag y lo persiste', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final provider = ThemeProvider(preferences);

    await provider.toggleDarkMode();

    expect(provider.isDarkMode, isTrue);
    expect(preferences.getBool('dark_mode_enabled'), isTrue);

    await provider.toggleDarkMode();

    expect(provider.isDarkMode, isFalse);
    expect(preferences.getBool('dark_mode_enabled'), isFalse);
  });

  test('un ThemeProvider nuevo arranca en modo oscuro si ya estaba persistido en true', () async {
    SharedPreferences.setMockInitialValues({'dark_mode_enabled': true});
    final preferences = await SharedPreferences.getInstance();

    final provider = ThemeProvider(preferences);

    expect(provider.isDarkMode, isTrue);
  });
}
