import 'package:flutter/material.dart';

/// Envoltorio reutilizable para el estado "cargando" de cualquier pantalla:
/// un `CircularProgressIndicator` centrado. Existe como widget propio (en
/// lugar de repetir `Center(child: CircularProgressIndicator())` en cada
/// pantalla) para que el estilo de carga sea consistente en toda la app y
/// se pueda ajustar en un único lugar.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
