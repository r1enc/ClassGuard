import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:classguard/screens/onboarding/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await AndroidAlarmManager.initialize();

  runApp(const ClassGuardApp());
}

class ClassGuardApp extends StatelessWidget {
  const ClassGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClassGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        primaryColor: Colors.black,
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          secondary: Colors.black87,
          surface: Colors.white,
        ),
        textTheme: GoogleFonts.montserratTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// BACKGROUND WAKE UP (KEEP THIS IN MAIN.DART)
// Must remain top-level for Android background isolate execution.
@pragma('vm:entry-point')
void wakeUpClassGuard() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  
  await prefs.setBool('isWarmupActive', true);
  
  debugPrint("ClassGuard Warmup: Background Isolate Awakened & Satpam Siaga!");
}