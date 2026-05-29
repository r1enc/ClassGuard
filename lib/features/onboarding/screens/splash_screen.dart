import 'package:classguard/core/routes/app_routes.dart';
import 'package:classguard/features/auth/screens/auth_screen.dart';
import 'package:classguard/features/dashboard/screens/home_screen.dart';
import 'package:classguard/features/onboarding/screens/permission_onboarding_screen.dart';
import 'package:classguard/features/auth/services/auth_service.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2500), () {
      _navigateToNextScreen();
    });
  }
// Restore onboarding and authentication state before entering the app.
  Future<void> _navigateToNextScreen() async {
    final splashState = await _authService.loadSplashUserState();

    if (mounted) {
      if (!splashState.isSetupDone) {
        Navigator.pushReplacement(
          context,
          createRoute(const PermissionOnboardingScreen()),
        );
      } else if (splashState.isLoggedIn) {
        Navigator.pushReplacement(
          context,
          createRoute(HomeScreen(userName: splashState.userName)),
        );
      } else {
        Navigator.pushReplacement(context, createRoute(const AuthScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Image.asset(
                'assets/images/logo.png',
                width: 180,
                fit: BoxFit.contain,
              ),
            ),

            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: Image.asset(
                  'assets/images/r1enc.png',
                  height: 30,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}