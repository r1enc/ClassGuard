import 'package:classguard/routes/app_routes.dart';
import 'package:classguard/screens/dashboard/home_screen.dart';
import 'package:classguard/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

// ========================================
// 3. AUTHENTICATION SCREEN (FIREBASE AUTH)
// ========================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool isLoading = false;
  final AuthService _authService = AuthService();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitAuth() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: "Email and Password are required",
        backgroundColor: Colors.red,
      );
      return;
    }
    if (!isLogin && nameController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: "Name is required for Sign Up",
        backgroundColor: Colors.red,
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      final result = isLogin
          ? await _authService.login(
              email: emailController.text,
              password: passwordController.text,
            )
          : await _authService.signup(
              name: nameController.text,
              email: emailController.text,
              password: passwordController.text,
            );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          createRoute(HomeScreen(userName: result.name)),
        );
      }
    } on FirebaseAuthException catch (e) {
      Fluttertoast.showToast(
        msg: e.message ?? "Authentication failed",
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isLogin ? 'Welcome Back' : 'Create Account',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isLogin ? 'Build your focus.' : 'Start building your focus.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 48),
                if (!isLogin) ...[
                  TextField(
                    controller: nameController,
                    decoration: _authInputStyle(
                      'Full Name',
                      Icons.person_outline,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _authInputStyle(
                    'Email Address',
                    Icons.alternate_email,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: _authInputStyle('Password', Icons.lock_outline),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submitAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            isLogin ? 'Log In' : 'Sign Up',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => isLogin = !isLogin),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black87,
                    ),
                    child: Text(
                      isLogin
                          ? "Don't have an account? Sign Up"
                          : "Already have an account? Log In",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _authInputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.black.withValues(alpha: 0.6)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.black, width: 1.5),
      ),
      prefixIcon: Icon(icon, color: Colors.black54),
    );
  }
}
