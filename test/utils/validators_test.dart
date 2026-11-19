import 'package:cuentas_claras/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateRequiredText', () {
    test('null es inválido', () {
      expect(validateRequiredText(null), isNotNull);
    });

    test('string vacío es inválido', () {
      expect(validateRequiredText(''), isNotNull);
    });

    test('string de solo espacios es inválido', () {
      expect(validateRequiredText('   '), isNotNull);
    });

    test('string con contenido es válido', () {
      expect(validateRequiredText('hola'), isNull);
    });

    test('usa el fieldName en el mensaje de error', () {
      final error = validateRequiredText(null, fieldName: 'La descripción');
      expect(error, contains('La descripción'));
    });
  });

  group('validateAmountInput', () {
    test('null es inválido', () {
      expect(validateAmountInput(null), isNotNull);
    });

    test('vacío es inválido', () {
      expect(validateAmountInput(''), isNotNull);
    });

    test('texto no numérico es inválido', () {
      expect(validateAmountInput('abc'), isNotNull);
    });

    test('cero es inválido', () {
      expect(validateAmountInput('0'), isNotNull);
    });

    test('negativo es inválido', () {
      expect(validateAmountInput('-100'), isNotNull);
    });

    test('monto positivo simple es válido', () {
      expect(validateAmountInput('1500'), isNull);
    });

    test('monto positivo con separadores es válido', () {
      expect(validateAmountInput('1.500,50'), isNull);
    });
  });

  group('validatePersonName', () {
    test('null es inválido', () {
      expect(validatePersonName(null), isNotNull);
    });

    test('vacío es inválido', () {
      expect(validatePersonName(''), isNotNull);
    });

    test('un solo caracter es inválido', () {
      expect(validatePersonName('A'), isNotNull);
    });

    test('nombre válido no da error', () {
      expect(validatePersonName('Ana Gomez'), isNull);
    });

    test('nombre demasiado largo es inválido', () {
      expect(validatePersonName('A' * 61), isNotNull);
    });
  });

  group('validateOptionalPhone', () {
    test('null es válido (campo opcional)', () {
      expect(validateOptionalPhone(null), isNull);
    });

    test('vacío es válido (campo opcional)', () {
      expect(validateOptionalPhone(''), isNull);
    });

    test('teléfono con formato típico es válido', () {
      expect(validateOptionalPhone('+54 9 11 1234-5678'), isNull);
    });

    test('teléfono demasiado corto es inválido', () {
      expect(validateOptionalPhone('123'), isNotNull);
    });

    test('teléfono con letras es inválido', () {
      expect(validateOptionalPhone('abc123456'), isNotNull);
    });

    test('teléfono demasiado largo es inválido', () {
      expect(validateOptionalPhone('1' * 21), isNotNull);
    });
  });
}
