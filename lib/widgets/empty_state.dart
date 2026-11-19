import 'package:flutter/material.dart';

/// Widget reutilizable para representar "no hay nada que mostrar todavía".
///
/// Se usa en cualquier pantalla que liste algo que puede estar vacío (sin
/// personas, sin deudas, sin pagos, sin datos para el dashboard), evitando
/// repetir el mismo layout de ícono + mensaje + acción opcional en cada
/// pantalla. El ícono, el mensaje y la acción son parámetros para que cada
/// lugar de uso pueda adaptarlos a su contexto sin duplicar código.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  /// Ícono que ilustra el estado vacío.
  final IconData icon;

  /// Mensaje principal mostrado debajo del ícono.
  final String message;

  /// Etiqueta del botón de acción opcional (por ejemplo, "Agregar persona").
  /// Si es `null`, no se muestra ningún botón.
  final String? actionLabel;

  /// Callback invocado al presionar el botón de acción. Se ignora si
  /// [actionLabel] es `null`.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
