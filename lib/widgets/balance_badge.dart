import 'package:flutter/material.dart';

import 'money_text.dart';

/// Chip reutilizable para mostrar un saldo neto (de una persona o global)
/// con color de fondo según el signo: verde si te deben (positivo), rojo
/// si debes (negativo), neutro si es cero. Reutiliza [MoneyText] para el
/// formateo del monto, de modo que el criterio de "cómo se ve un monto"
/// vive en un único lugar.
class BalanceBadge extends StatelessWidget {
  const BalanceBadge({super.key, required this.cents});

  /// Saldo neto a representar, en centavos.
  final int cents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color background;
    final Color foreground;
    if (cents > 0) {
      background = Colors.green.shade50;
      foreground = Colors.green.shade700;
    } else if (cents < 0) {
      background = theme.colorScheme.errorContainer;
      foreground = theme.colorScheme.error;
    } else {
      background = theme.colorScheme.surfaceContainerHighest;
      foreground = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: MoneyText(
        cents: cents,
        style: theme.textTheme.labelLarge?.copyWith(color: foreground),
      ),
    );
  }
}
