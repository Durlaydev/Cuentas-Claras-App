import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import 'register_screen.dart';

/// Pantalla de inicio de sesión con email y contraseña.
///
/// Es una pantalla simple con widgets de Material estándar: el proyecto
/// todavía no tiene un sistema de diseño propio, y el objetivo pedagógico
/// de este capítulo es mostrar cómo conectar un `Form` con [AuthProvider],
/// no construir pantallas visualmente pulidas.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await context.read<AuthProvider>().login(
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
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
                      child: const Text('Ingresar'),
                    ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: const Text('¿No tienes una cuenta? Regístrate'),
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

/// Validación local de email: solo verifica una forma básica
/// (`algo@algo.algo`). No pretende ser una validación exhaustiva del
/// estándar RFC 5322, basta para detectar los errores de tipeo más
/// comunes en un formulario de la UI.
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
