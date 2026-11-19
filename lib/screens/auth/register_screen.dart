import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';

/// Pantalla de registro de una cuenta nueva con email y contraseña.
///
/// Misma idea que `LoginScreen`: widgets de Material estándar, sin
/// pretensión visual, pensada para mostrar con claridad cómo conectar un
/// `Form` con [AuthProvider]. No importa `login_screen.dart` a propósito
/// (para evitar un import circular entre ambas pantallas); por eso define
/// sus propias validaciones locales en lugar de reutilizar las de
/// `LoginScreen`.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await context.read<AuthProvider>().register(
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                    ),
                    validator: validateEmail,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                    ),
                    validator: validatePassword,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contraseña',
                    ),
                    validator: (value) => validateConfirmPassword(
                      value,
                      _passwordController.text,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (authProvider.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        authProvider.errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (authProvider.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Registrarme'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('¿Ya tienes una cuenta? Iniciar sesión'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Validación local de email: ver la nota equivalente en `login_screen.dart`.
String? validateEmail(String? value) {
  final requiredError = validateRequiredText(
    value,
    fieldName: 'El correo electrónico',
  );
  if (requiredError != null) {
    return requiredError;
  }

  final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!emailPattern.hasMatch(value!.trim())) {
    return 'Ingresa un correo electrónico válido.';
  }
  return null;
}

/// Validación local de contraseña: obligatoria y con un mínimo de 6
/// caracteres (el mínimo que exige Firebase Authentication).
String? validatePassword(String? value) {
  final requiredError = validateRequiredText(
    value,
    fieldName: 'La contraseña',
  );
  if (requiredError != null) {
    return requiredError;
  }

  if (value!.length < 6) {
    return 'La contraseña debe tener al menos 6 caracteres.';
  }
  return null;
}

/// Valida que la confirmación de contraseña sea obligatoria y coincida
/// exactamente con [password].
String? validateConfirmPassword(String? value, String password) {
  final requiredError = validateRequiredText(
    value,
    fieldName: 'La confirmación de contraseña',
  );
  if (requiredError != null) {
    return requiredError;
  }

  if (value != password) {
    return 'Las contraseñas no coinciden.';
  }
  return null;
}
