import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // login aborted

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e, s) { // Aggiungi lo stack trace 's'
      print('Google Sign-In error: $e');
      print('Stack trace: $s'); // Stampa lo stack trace per un debug più approfondito
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login con Google')),
      body: Center(
        child: ElevatedButton.icon(
          icon: Image.asset('assets/google_logo.png', height: 24), // metti un logo Google nella cartella assets
          label: const Text('Accedi con Google'),
          onPressed: () async {
            final userCredential = await signInWithGoogle();
            if (userCredential == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Login annullato o fallito')),
              );
            }
          },
        ),
      ),
    );
  }
}
