import 'package:intl/intl.dart';

/// Formatea un valor en centavos como moneda usando [NumberFormat] de `intl`.
///
/// Todos los montos de la aplicación se almacenan como `int` en centavos
/// (nunca como `double`) para evitar errores de redondeo de punto flotante.
/// Un ejemplo clásico: en binario, `0.1 + 0.2` no da exactamente `0.3`
/// (da `0.30000000000000004`), porque 0.1 y 0.2 no tienen representación
/// exacta en base 2. Si guardáramos "$1500.50" como `double`, sumas y
/// restas repetidas podrían ir acumulando centavos de diferencia. Al
/// trabajar siempre con enteros (centavos), las operaciones aritméticas
/// son exactas; la división por 100.0 se hace únicamente aquí, en el
/// límite de presentación, para mostrarlo al usuario.
String formatCents(int cents, {String locale = 'es_AR'}) {
  // Se fuerza un patrón explícito (símbolo pegado adelante, sin espacio)
  // porque el patrón por defecto de es_AR ubica el símbolo al final
  // (ej: "1.500,50 $"), y en Argentina la convención habitual para
  // mostrar montos es con el símbolo adelante (ej: "$1.500,50").
  final format = NumberFormat.currency(
    locale: locale,
    symbol: r'$',
    decimalDigits: 2,
    customPattern: '¤#,##0.00',
  );
  return format.format(cents / 100.0);
}

/// Parsea un string ingresado por el usuario (que puede usar `,` o `.`
/// como separador decimal, separadores de miles, espacios o símbolo de
/// moneda) y devuelve el valor equivalente en centavos.
///
/// Esta función solo rechaza entradas basura (vacías o no numéricas).
/// La negatividad NO es una responsabilidad del parser: es una regla de
/// dominio (por ejemplo, [validateAmountInput] es quien exige que el
/// monto sea mayor a cero). Por eso un valor negativo válido se parsea
/// sin lanzar excepción.
int parseCentsFromInput(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('El monto no puede estar vacío.');
  }

  // Elimina cualquier carácter que no sea dígito, separador decimal,
  // separador de miles o signo negativo (por ejemplo, símbolos de moneda
  // o espacios).
  final cleaned = trimmed.replaceAll(RegExp(r'[^0-9.,-]'), '');
  if (cleaned.isEmpty || !RegExp(r'[0-9]').hasMatch(cleaned)) {
    throw FormatException('"$trimmed" no es un monto válido.');
  }

  final isNegative = cleaned.startsWith('-');
  final unsigned = cleaned.replaceAll('-', '');

  final normalized = _normalizeDecimalSeparator(unsigned);
  final parts = normalized.split('.');

  final integerPart = parts[0].isEmpty ? '0' : parts[0];
  var fractionalPart = parts.length > 1 ? parts[1] : '';

  if (!RegExp(r'^[0-9]*$').hasMatch(integerPart) ||
      !RegExp(r'^[0-9]*$').hasMatch(fractionalPart)) {
    throw FormatException('"$trimmed" no es un monto válido.');
  }

  fractionalPart = fractionalPart.padRight(2, '0');
  if (fractionalPart.length > 2) {
    fractionalPart = fractionalPart.substring(0, 2);
  }

  final integerCents = int.parse(integerPart) * 100;
  final fractionalCents = int.parse(fractionalPart);
  final totalCents = integerCents + fractionalCents;

  return isNegative ? -totalCents : totalCents;
}

/// Normaliza un string numérico (sin signo) a un formato con `.` como
/// separador decimal, para poder parsearlo con [int.parse] sobre sus
/// partes entera y fraccionaria.
///
/// Heurística: si aparecen tanto `,` como `.`, el que aparece más a la
/// derecha es el separador decimal y el otro es separador de miles. Si
/// aparece un solo tipo de separador, se asume separador de miles cuando
/// se repite o cuando le siguen exactamente 3 dígitos (por ejemplo
/// "1.500"); en caso contrario se asume separador decimal.
String _normalizeDecimalSeparator(String value) {
  final lastComma = value.lastIndexOf(',');
  final lastDot = value.lastIndexOf('.');

  if (lastComma == -1 && lastDot == -1) {
    return value;
  }

  if (lastComma != -1 && lastDot != -1) {
    if (lastComma > lastDot) {
      return value.replaceAll('.', '').replaceAll(',', '.');
    } else {
      return value.replaceAll(',', '');
    }
  }

  final sep = lastComma != -1 ? ',' : '.';
  final sepIndex = lastComma != -1 ? lastComma : lastDot;
  final digitsAfter = value.length - sepIndex - 1;
  final occurrences = sep.allMatches(value).length;

  if (occurrences > 1 || digitsAfter == 3) {
    // Múltiples ocurrencias o exactamente 3 dígitos después: separador de miles.
    return value.replaceAll(sep, '');
  }

  return value.replaceAll(sep, '.');
}
