import 'package:classguard/routes/app_routes.dart';
import 'package:classguard/screens/auth/auth_screen.dart';
import 'package:classguard/screens/dashboard/home_screen.dart';
import 'package:classguard/screens/onboarding/permission_onboarding_screen.dart';
import 'package:classguard/services/auth_service.dart';
import 'package:flutter/material.dart';

// ==================
// 8. SPLASH SCREEN
// ==================
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
