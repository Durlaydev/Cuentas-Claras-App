import 'package:flutter/material.dart';

import '../utils/money_formatter.dart';

/// Widget reutilizable para mostrar un monto en centavos formateado como
/// moneda (vía [formatCents]), evitando repetir la conversión y el
/// formateo en cada pantalla que muestra un monto (listas de deudas,
/// detalle, dashboard, badges de saldo, etc).
///
/// Con [colorByValue] en `true`, el color del texto se decide según el
/// signo de [cents] (verde si es positivo, rojo si es negativo, color por
/// defecto si es cero), útil para representar saldos ("te deben" /
/// "debes"). Si se provee [style] explícito, [colorByValue] solo completa
/// el color cuando ese estilo no trae uno propio.
class MoneyText extends StatelessWidget {
  const MoneyText({
    super.key,
    required this.cents,
    this.style,
    this.colorByValue = false,
  });

  /// Monto a mostrar, en centavos.
  final int cents;

  /// Estilo base del texto. Si es `null`, se usa `bodyMedium` del tema.
  final TextStyle? style;

  /// Si es `true`, colorea el texto en verde/rojo/neutro según el signo de
  /// [cents].
  final bool colorByValue;

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? Theme.of(context).textTheme.bodyMedium;
    final effectiveStyle = colorByValue
        ? baseStyle?.copyWith(color: _colorForValue(context))
        : baseStyle;

    return Text(formatCents(cents), style: effectiveStyle);
  }

  Color? _colorForValue(BuildContext context) {
    if (cents > 0) return Colors.green.shade700;
    if (cents < 0) return Theme.of(context).colorScheme.error;
    return null;
  }
}
