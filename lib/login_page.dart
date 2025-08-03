import 'package:flutter/material.dart';
import 'package:studybuddy/auth_service.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton.icon(
          onPressed: () async {
            final user = await AuthService().signInWithGoogle(); // ✅ Con istanza, non statico
            if (user == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Login fallito')));
            }
          },
          icon: const Icon(Icons.login),
          label: const Text('Accedi con Google'),
        ),
      ),
    );
  }
}
