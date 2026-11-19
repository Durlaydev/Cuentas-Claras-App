// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: public_member_api_docs, sort_constructors_first
// Archivo generado automáticamente por la CLI de FlutterFire.
//
// ESTE ES UN PLACEHOLDER: en este proyecto no existe un proyecto real de
// Firebase todavía. Cuando sigas el capítulo de Firebase de la guía, deberás
// ejecutar `flutterfire configure` desde la raíz del proyecto: ese comando
// SOBRESCRIBE este archivo con las credenciales reales de tu propio proyecto
// de Firebase (apiKey, appId, projectId, etc. para cada plataforma).
//
// No subas a un repositorio público la versión real de este archivo con
// credenciales de producción sensibles sin evaluar tu política de secretos;
// para la mayoría de apps cliente de Firebase estas claves son públicas por
// diseño (se restringen del lado del servidor con reglas de seguridad), pero
// igual es buena práctica no versionarlas a la ligera en proyectos de
// aprendizaje.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Opciones de Firebase por plataforma, seleccionadas automáticamente según
/// el sistema operativo en el que corre la app.
///
/// Uso típico en `main.dart`:
/// ```dart
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions no ha sido configurado para macOS - '
          'ejecuta `flutterfire configure` para generar la configuración real.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions no ha sido configurado para Windows - '
          'ejecuta `flutterfire configure` para generar la configuración real.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions no ha sido configurado para Linux - '
          'ejecuta `flutterfire configure` para generar la configuración real.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions no está soportado para esta plataforma.',
        );
    }
  }

  // Valores de relleno con el formato exacto que produce `flutterfire configure`.
  // No corresponden a ningún proyecto real: reemplázalos siguiendo el capítulo
  // de Firebase de la guía.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'PLACEHOLDER_API_KEY',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'cuentas-claras-placeholder',
    authDomain: 'cuentas-claras-placeholder.firebaseapp.com',
    storageBucket: 'cuentas-claras-placeholder.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'PLACEHOLDER_API_KEY',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'cuentas-claras-placeholder',
    storageBucket: 'cuentas-claras-placeholder.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'PLACEHOLDER_API_KEY',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'cuentas-claras-placeholder',
    storageBucket: 'cuentas-claras-placeholder.appspot.com',
    iosBundleId: 'com.cuentasclaras.cuentasClaras',
  );
}
