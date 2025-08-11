import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:studybuddy/config/google_secrets.dart';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart' as AllPlatformsGoogleSignIn;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late AllPlatformsGoogleSignIn.GoogleSignIn _googleSignIn;

  @override
  void initState() {
    super.initState();
    _googleSignIn = AllPlatformsGoogleSignIn.GoogleSignIn(
      params: AllPlatformsGoogleSignIn.GoogleSignInParams(
        clientId: GoogleSecrets.clientId,
        clientSecret: GoogleSecrets.clientSecret,
        redirectPort: 3000, // Must match the redirect URI in Google Cloud Console
        // You can also add scopes if needed, e.g.:
        // scopes: [
        //   'https://www.googleapis.com/auth/userinfo.profile',
        //   'https://www.googleapis.com/auth/userinfo.email',
        // ],
      ),
    );
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn(); // This is GoogleSignInCredentials
      if (googleUser == null) {
        print('Google Sign-In aborted by user.');
        return null; // login aborted
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleUser.accessToken, // Assuming accessToken is directly on GoogleSignInCredentials
        idToken: googleUser.idToken,         // Assuming idToken is directly on GoogleSignInCredentials
      );

      return await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e, s) {
      print('Google Sign-In error: $e');
      print('Stack trace: $s');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login con Google')),
      body: Center(
        child: ElevatedButton.icon(
          icon: Image.asset('assets/google_logo.png', height: 24), // Ensure you have this asset
          label: const Text('Accedi con Google'),
          onPressed: () async {
            final userCredential = await signInWithGoogle();
            if (userCredential != null) {
              // Navigate to home page or show success message
              print('Signed in as: ${userCredential.user?.displayName}');
            } else {
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
