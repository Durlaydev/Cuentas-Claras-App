plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.cuentasclaras.cuentas_claras"
    // Se fija en 36 (en vez de usar flutter.compileSdkVersion) porque
    // androidx.core:core-ktx 1.18.0 -- una dependencia transitiva de los
    // plugins de Firebase -- exige compilar contra Android API 36 o superior.
    compileSdk = 36
    // Se fija en la versión más alta pedida por los plugins (Firebase,
    // sqflite, connectivity_plus, etc. la requieren) en vez de usar
    // flutter.ndkVersion, que puede quedar por debajo de lo que ellos piden.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Requerido por flutter_local_notifications: la librería usa APIs de
        // java.time que en Android < 26 solo existen si se activa el desugaring.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.cuentasclaras.cuentas_claras"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // minSdk 23 es requerido por flutter_local_notifications 20.x y por
        // Firebase Auth/Firestore recientes; se fija explícito en vez de usar
        // flutter.minSdkVersion para no depender del default del engine.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// A partir de Kotlin 2.3, la DSL `android.kotlinOptions { jvmTarget = ... }`
// (basada en un String) fue removida; el target de JVM del compilador de
// Kotlin ahora se configura con la DSL `compilerOptions`, fuera del bloque
// `android { ... }`.
kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
    }
}

dependencies {
    // Necesario para habilitar isCoreLibraryDesugaringEnabled en compileOptions.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
