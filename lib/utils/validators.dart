import 'money_formatter.dart';

/// Valida que un campo de texto obligatorio no sea nulo ni esté vacío
/// (ni compuesto solo de espacios). Sigue la firma habitual de
/// `FormFieldValidator<String>` de Flutter: devuelve `null` si es válido
/// o un mensaje de error en español si no lo es.
String? validateRequiredText(String? value, {String fieldName = 'Este campo'}) {
  if (value == null || value.trim().isEmpty) {
    return '$fieldName es obligatorio.';
  }
  return null;
}

/// Valida el texto ingresado en un campo de monto: debe poder parsearse
/// con [parseCentsFromInput] y el resultado debe ser mayor a cero.
String? validateAmountInput(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'El monto es obligatorio.';
  }

  final int cents;
  try {
    cents = parseCentsFromInput(value);
  } on FormatException catch (e) {
    return e.message;
  }

  if (cents <= 0) {
    return 'El monto debe ser mayor a cero.';
  }

  return null;
}

/// Valida el nombre de una persona: obligatorio, con una longitud
/// razonable (entre 2 y 60 caracteres).
String? validatePersonName(String? value) {
  final requiredError = validateRequiredText(value, fieldName: 'El nombre');
  if (requiredError != null) {
    return requiredError;
  }

  final trimmed = value!.trim();
  if (trimmed.length < 2) {
    return 'El nombre debe tener al menos 2 caracteres.';
  }
  if (trimmed.length > 60) {
    return 'El nombre no puede superar los 60 caracteres.';
  }

  return null;
}

final RegExp _phonePattern = RegExp(r'^[0-9+\-() ]+$');

/// Valida un teléfono opcional: si está vacío o es nulo, es válido (el
/// campo no es obligatorio). Si tiene contenido, debe parecer un número
/// de teléfono (dígitos, espacios, `+`, `-`, paréntesis) de entre 6 y 20
/// caracteres.
String? validateOptionalPhone(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  final trimmed = value.trim();
  final looksLikePhone = _phonePattern.hasMatch(trimmed);
  final hasValidLength = trimmed.length >= 6 && trimmed.length <= 20;

  if (!looksLikePhone || !hasValidLength) {
    return 'Ingresa un teléfono válido (6 a 20 caracteres: números, '
        'espacios, +, - o paréntesis).';
  }

  return null;
}
