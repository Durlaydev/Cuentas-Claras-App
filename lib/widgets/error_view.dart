import 'package:flutter/material.dart';

/// Widget reutilizable para el estado de error de cualquier pantalla que
/// dependa de un provider con `errorMessage`: muestra el mensaje de error y
/// un botón "Reintentar" que delega en [onRetry] la lógica de recarga
/// (por ejemplo, volver a llamar a `loadPeople()` o `loadAll()`), para no
/// acoplar este widget a ningún provider concreto.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  /// Mensaje de error a mostrar.
  final String message;

  /// Callback invocado al presionar "Reintentar".
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
