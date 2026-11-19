import 'package:cuentas_claras/utils/money_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatCents', () {
    test('formatea cero como \$0,00', () {
      expect(formatCents(0), '\$0,00');
    });

    test('formatea un valor simple sin miles', () {
      expect(formatCents(100), '\$1,00');
    });

    test('formatea un valor con separador de miles y decimales', () {
      expect(formatCents(150050), '\$1.500,50');
    });

    test('formatea un valor grande con varios separadores de miles', () {
      expect(formatCents(123456789), '\$1.234.567,89');
    });
  });

  group('parseCentsFromInput', () {
    test('parsea un entero simple', () {
      expect(parseCentsFromInput('1500'), 150000);
    });

    test('parsea decimal con punto', () {
      expect(parseCentsFromInput('1500.50'), 150050);
    });

    test('parsea decimal con coma', () {
      expect(parseCentsFromInput('1500,50'), 150050);
    });

    test('parsea miles con punto y decimal con coma', () {
      expect(parseCentsFromInput('1.500,50'), 150050);
    });

    test('parsea miles con coma y decimal con punto', () {
      expect(parseCentsFromInput('1,500.50'), 150050);
    });

    test('ignora el símbolo de moneda y espacios', () {
      expect(parseCentsFromInput(r'  $ 1.500,50  '), 150050);
    });

    test('interpreta un único punto seguido de 3 dígitos como miles', () {
      expect(parseCentsFromInput('1.500'), 150000);
    });

    test('permite números negativos (la negatividad no es responsabilidad del parser)', () {
      expect(parseCentsFromInput('-150'), -15000);
    });

    test('lanza FormatException con string vacío', () {
      expect(() => parseCentsFromInput(''), throwsFormatException);
    });

    test('lanza FormatException con solo espacios', () {
      expect(() => parseCentsFromInput('   '), throwsFormatException);
    });

    test('lanza FormatException con texto no numérico', () {
      expect(() => parseCentsFromInput('abc'), throwsFormatException);
    });
  });
}
