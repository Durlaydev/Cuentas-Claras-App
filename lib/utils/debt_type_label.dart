import '../models/debt.dart';

/// Traduce el enum de dominio [DebtType] a una etiqueta legible en
/// español para mostrarla en la interfaz de usuario.
///
/// Se mantiene fuera de `lib/models/debt.dart` a propósito: el modelo de
/// dominio no debe conocer textos de UI ni idioma, para poder
/// reutilizarse tal cual en otra pantalla, otro idioma o incluso otra
/// capa de presentación.
extension DebtTypeLabel on DebtType {
  String get label {
    switch (this) {
      case DebtType.owedToMe:
        return 'Me deben';
      case DebtType.iOwe:
        return 'Debo';
    }
  }
}
