import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';
import 'package:sound_mode/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ==========================================
// UTILITY FUNCTIONS (Smart Sorting & Collision)
// ==========================================
int timeToMinutes(String time) {
  final parts = time.split(':');
  if (parts.length != 2) return 0;
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

DateTime getNextOccurrence(String dayStr, String timeStr) {
  final days = {"Mon": 1, "Tue": 2, "Wed": 3, "Thu": 4, "Fri": 5, "Sat": 6, "Sun": 7};
  int targetDay = days[dayStr] ?? 1;

  final timeParts = timeStr.split(':');
  if (timeParts.length != 2) return DateTime.now();
  int targetHour = int.parse(timeParts[0]);
  int targetMin = int.parse(timeParts[1]);

  DateTime now = DateTime.now();
  DateTime candidate = DateTime(now.year, now.month, now.day, targetHour, targetMin);

  while (candidate.weekday != targetDay || candidate.isBefore(now)) {
    candidate = candidate.add(const Duration(days: 1));
  }
  return candidate;
}

Future<String?> checkAndHandleCollision(String newDay, String newStart, String newEnd, String newRole, {String? excludeId}) async {
  final snapshot = await FirebaseFirestore.instance.collection('schedules').where('day', isEqualTo: newDay).get();
  int newStartMin = timeToMinutes(newStart);
  int newEndMin = timeToMinutes(newEnd);

  bool personalOverridden = false;

  for (var doc in snapshot.docs) {
    if (excludeId != null && doc.id == excludeId) continue;
    final data = doc.data();
    if (data['isActive'] == false) continue;

    int existStart = timeToMinutes(data['startTime'] ?? '00:00');
    int existEnd = timeToMinutes(data['endTime'] ?? '00:00');

    if (newStartMin < existEnd && newEndMin > existStart) {
      if (newRole == 'Teacher' || newRole == 'Student') {
        if (data['role'] == 'Personal') {
          await FirebaseFirestore.instance.collection('schedules').doc(doc.id).update({'isActive': false});
          personalOverridden = true;
        } else {
          return "Cannot proceed. Time overlaps with existing class: ${data['subject']}";
        }
      } else {
        return "Cannot save. Time overlaps with existing schedule: ${data['subject']}";
      }
    }
  }
  if (personalOverridden) return "OVERRIDDEN";
  return null;
}

// ==========================================
// BACKGROUND ALARM FUNCTION (START & STOP)
// ==========================================
@pragma('vm:entry-point')
void startClassGuard() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  SharedPreferences prefs = await SharedPreferences.getInstance();

  try {
    await SoundMode.setSoundMode(RingerModeStatus.silent);
    VolumeController().setVolume(0.0);
    try {
      const platform = MethodChannel('com.classguard/applock');

      bool accStatus = await platform.invokeMethod('checkAccessibilityPermission') ?? false;
      bool usageStatus = await platform.invokeMethod('checkUsagePermission') ?? false;
      bool ovrStatus = await platform.invokeMethod('checkOverlayPermission') ?? false;
      bool batStatus = await platform.invokeMethod('checkBatteryOptimization') ?? false;
      bool dndStatus = await PermissionHandler.permissionsGranted ?? false;

      if (!accStatus || !usageStatus || !ovrStatus || !batStatus || !dndStatus) {
        await platform.invokeMethod('triggerEmergencyPopup');
      }
    } catch (e) {
      debugPrint("Failed to check permission in background: $e");
    }

    final snapshot = await FirebaseFirestore.instance.collection('schedules').where('isActive', isEqualTo: true).get();
    final now = DateTime.now();
    final dayStr = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][now.weekday - 1];

    String currentBlockedApps = "";
    int currentAllowanceTime = 2;
    String currentPin = "1234";

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['day'] == dayStr) {
        int start = timeToMinutes(data['startTime'] ?? "00:00");
        int end = timeToMinutes(data['endTime'] ?? "00:00");
        int current = now.hour * 60 + now.minute;

        if (current >= start - 2 && current <= end) {
          List<dynamic> apps = data['blockedApps'] ?? [];
          currentBlockedApps = apps.join(',');

          currentAllowanceTime = data['allowanceTime'] ?? 2;
          currentPin = data['securityPIN'] ?? "1234";
          break;
        }
      }
    }

    await prefs.setString('blockedApps', currentBlockedApps);
    await prefs.setInt('allowanceTime', currentAllowanceTime);
    await prefs.setString('securityPIN', currentPin);
    await prefs.setBool('isAppLockActive', true);

    Fluttertoast.showToast(
      msg: "Class started: Device is Silent & Distracting Apps Locked",
      toastLength: Toast.LENGTH_LONG,
      backgroundColor: Colors.black,
      textColor: Colors.white,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);

    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'classguard_channel', 'ClassGuard Alerts', importance: Importance.max, priority: Priority.high, ticker: 'ticker');
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
        id: 0, title: 'ClassGuard Activated', body: 'Class session has started. Focus mode enabled.', notificationDetails: platformChannelSpecifics
    );

  } catch (e) {
    debugPrint("Failed to start ClassGuard: $e");
  }
}

@pragma('vm:entry-point')
void stopClassGuard() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();

  try {
    await SoundMode.setSoundMode(RingerModeStatus.normal);
    VolumeController().setVolume(0.5);

    await prefs.setBool('isAppLockActive', false);

    Fluttertoast.showToast(
      msg: "Class ended: Device is back to normal",
      toastLength: Toast.LENGTH_LONG,
      backgroundColor: Colors.black,
      textColor: Colors.white,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);

    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'classguard_channel', 'ClassGuard Alerts', importance: Importance.max, priority: Priority.high, ticker: 'ticker');
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
        id: 1, title: 'Class Session Ended', body: 'Great job focusing! Devices unmuted.', notificationDetails: platformChannelSpecifics
    );

  } catch (e) {
    debugPrint("Failed to stop ClassGuard: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await AndroidAlarmManager.initialize();

  runApp(const ClassGuardApp());
}

// ==========================================
// 1. DATA STRUCTURE
// ==========================================
class Course {
  String? id;
  String subject;
  String lecturer;
  String room;
  String day;
  String startTime;
  String endTime;
  bool isAppLockEnabled;
  bool isSilentModeEnabled;
  bool isActive;
  String role;
  String? roomCode;
  String? securityPIN;
  int allowanceTime;
  List<dynamic> blockedApps;

  Course({
    this.id,
    required this.subject,
    required this.lecturer,
    required this.room,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.isAppLockEnabled,
    this.isSilentModeEnabled = true,
    this.isActive = true,
    required this.role,
    this.roomCode,
    this.securityPIN,
    this.allowanceTime = 0,
    this.blockedApps = const [],
  });
}

// ==========================================
// 2. APP THEME
// ==========================================
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
        colorScheme: const ColorScheme.light(primary: Colors.black, secondary: Colors.black87, surface: Colors.white),
        textTheme: GoogleFonts.montserratTextTheme(),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// ==========================================
// PAGE TRANSITION ANIMATION HELPER
// ==========================================
Route _createRoute(Widget page) {
  return CupertinoPageRoute(builder: (context) => page);
}

// ==========================================
// 2.1 PERMISSION ONBOARDING SCREEN
// ==========================================
class PermissionOnboardingScreen extends StatefulWidget {
  final bool isFromSettings;
  const PermissionOnboardingScreen({super.key, this.isFromSettings = false});

  @override
  State<PermissionOnboardingScreen> createState() => _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState extends State<PermissionOnboardingScreen> with WidgetsBindingObserver {
  bool isDndGranted = false;
  bool isAccessibilityGranted = false;
  bool isOverlayGranted = false;
  bool isBatteryGranted = false;
  bool isUsageGranted = false;
  bool isAutoStartClicked = false;

  final platform = const MethodChannel('com.classguard/applock');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    bool? dndStatus = await PermissionHandler.permissionsGranted;
    bool accStatus = false;
    bool ovrStatus = false;
    bool batStatus = false;
    bool usageStatus = false;
    try {
      accStatus = await platform.invokeMethod('checkAccessibilityPermission') ?? false;
      ovrStatus = await platform.invokeMethod('checkOverlayPermission') ?? false;
      batStatus = await platform.invokeMethod('checkBatteryOptimization') ?? false;
      usageStatus = await platform.invokeMethod('checkUsagePermission') ?? false;
    } catch (e) {}

    setState(() {
      isDndGranted = dndStatus ?? false;
      isAccessibilityGranted = accStatus;
      isOverlayGranted = ovrStatus;
      isBatteryGranted = batStatus;
      isUsageGranted = usageStatus;
    });
  }

  void _requestDND() async => await PermissionHandler.openDoNotDisturbSetting();
  void _requestUsage() async => await platform.invokeMethod('requestUsagePermission');
  void _requestAccessibility() async => await platform.invokeMethod('openAccessibilitySettings');
  void _requestOverlay() async => await platform.invokeMethod('requestOverlayPermission');
  void _requestBattery() async => await platform.invokeMethod('requestBatteryOptimization');
  void _requestAutoStart() async {
    await platform.invokeMethod('requestAutoStartPermission');
    Fluttertoast.showToast(msg: "Please turn ON Auto Start for ClassGuard!");
    setState(() {
      isAutoStartClicked = true;
    });
  }

  void _proceedToAuth(BuildContext context) async {
    if (!isDndGranted || !isAccessibilityGranted || !isOverlayGranted || !isBatteryGranted || !isUsageGranted || !isAutoStartClicked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please grant all 6 required permissions first.')));
      return;
    }
    if (widget.isFromSettings) {
      if (context.mounted) Navigator.pop(context);
    } else {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstTimeSetupDone', true);
      if (context.mounted) Navigator.pushReplacement(context, _createRoute(const AuthScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool allGranted = isDndGranted && isAccessibilityGranted && isOverlayGranted && isBatteryGranted && isUsageGranted && isAutoStartClicked;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: widget.isFromSettings ? AppBar(title: const Text('System Permissions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), centerTitle: true) : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.isFromSettings) ...[
                const SizedBox(height: 24),
                const Icon(Icons.settings_suggest, size: 64, color: Colors.black),
                const SizedBox(height: 32),
                const Text('Setup Permissions', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 16),
                const Text('To make ClassGuard work seamlessly, we need access to a few core system settings.', style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.5)),
                const SizedBox(height: 48),
              ],

              _buildPermissionItem(icon: Icons.do_not_disturb_on, title: 'Do Not Disturb', description: 'Automatically mute your phone during classes.', isGranted: isDndGranted, onRequest: _requestDND),
              const SizedBox(height: 16),
              _buildPermissionItem(icon: Icons.data_usage, title: 'Usage Access', description: 'Required to sort and find your most used apps.', isGranted: isUsageGranted, onRequest: _requestUsage),
              const SizedBox(height: 16),
              _buildPermissionItem(icon: Icons.accessibility_new, title: 'Accessibility', description: 'Detect & block distracting apps while active.', isGranted: isAccessibilityGranted, onRequest: _requestAccessibility),
              const SizedBox(height: 16),
              _buildPermissionItem(icon: Icons.layers, title: 'Display Over Apps', description: 'Show the Lock Screen when an app is blocked.', isGranted: isOverlayGranted, onRequest: _requestOverlay),
              const SizedBox(height: 16),
              _buildPermissionItem(icon: Icons.battery_charging_full, title: 'Battery Optimization', description: 'Prevent system kill.', isGranted: isBatteryGranted, onRequest: _requestBattery),
              const SizedBox(height: 16),

              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: isAutoStartClicked ? Colors.green.withOpacity(0.05) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isAutoStartClicked ? Colors.green.shade200 : Colors.orange.shade200)
                ),
                child: Row(
                  children: [
                    Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: isAutoStartClicked ? Colors.black.withOpacity(0.05) : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12)
                        ),
                        child: Icon(Icons.rocket_launch, size: 24, color: isAutoStartClicked ? Colors.green : Colors.orange)
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                      Text('Auto Start (Crucial)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Required to keep the protection active in the background. Please turn ON Auto Start.', style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4))
                    ])),
                    const SizedBox(width: 8),
                    if (isAutoStartClicked)
                      const Icon(Icons.check_circle, color: Colors.green, size: 28)
                    else
                      ElevatedButton(
                          onPressed: _requestAutoStart,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16)),
                          child: const Text('Configure', style: TextStyle(fontSize: 12))
                      )
                  ],
                ),
              ),

              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: () => _proceedToAuth(context),
                  style: ElevatedButton.styleFrom(backgroundColor: allGranted ? Colors.black : Colors.grey.shade300, foregroundColor: allGranted ? Colors.white : Colors.black38, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                  child: Text(widget.isFromSettings ? 'Done' : (allGranted ? 'Continue' : 'Permissions Required'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem({required IconData icon, required String title, required String description, required bool isGranted, required VoidCallback onRequest}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isGranted ? Colors.green.withOpacity(0.05) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: isGranted ? Colors.green.shade200 : Colors.black12)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 24, color: isGranted ? Colors.green : Colors.black87)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(description, style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.4))])),
          const SizedBox(width: 8),
          if (isGranted) const Icon(Icons.check_circle, color: Colors.green, size: 28)
          else ElevatedButton(onPressed: onRequest, style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16)), child: const Text('Grant', style: TextStyle(fontSize: 12)))
        ],
      ),
    );
  }
}

// ==========================================
// 3. AUTHENTICATION SCREEN (FIREBASE AUTH)
// ==========================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool isLoading = false;

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
      Fluttertoast.showToast(msg: "Email and Password are required", backgroundColor: Colors.red);
      return;
    }
    if (!isLogin && nameController.text.isEmpty) {
      Fluttertoast.showToast(msg: "Name is required for Sign Up", backgroundColor: Colors.red);
      return;
    }

    setState(() => isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String finalName = "Student";

      if (isLogin) {
        UserCredential user = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
        finalName = user.user?.displayName ?? prefs.getString('profileName') ?? "Student";
        await prefs.setString('profileName', finalName);
      } else {
        UserCredential user = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
        finalName = nameController.text.trim();
        await user.user?.updateDisplayName(finalName);
        await prefs.setString('profileName', finalName);
        await prefs.setString('profileEmail', emailController.text.trim());
      }

      await prefs.setBool('isLoggedIn', true);

      if (mounted) {
        Navigator.pushReplacement(context, _createRoute(HomeScreen(userName: finalName)));
      }
    } on FirebaseAuthException catch (e) {
      Fluttertoast.showToast(msg: e.message ?? "Authentication failed", backgroundColor: Colors.red);
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
                Text(isLogin ? 'Welcome Back' : 'Create Account', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text(isLogin ? 'Build your focus.' : 'Start building your focus.', style: TextStyle(fontSize: 16, color: Colors.black.withOpacity(0.6))),
                const SizedBox(height: 48),
                if (!isLogin) ...[
                  TextField(controller: nameController, decoration: _authInputStyle('Full Name', Icons.person_outline)),
                  const SizedBox(height: 20),
                ],
                // Input diubah pakai email dan password controller khusus
                TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: _authInputStyle('Email Address', Icons.alternate_email)),
                const SizedBox(height: 20),
                TextField(controller: passwordController, obscureText: true, decoration: _authInputStyle('Password', Icons.lock_outline)),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submitAuth,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                    child: isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(isLogin ? 'Log In' : 'Sign Up', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => isLogin = !isLogin),
                    style: TextButton.styleFrom(foregroundColor: Colors.black87),
                    child: Text(isLogin ? "Don't have an account? Sign Up" : "Already have an account? Log In", style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _authInputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label, labelStyle: TextStyle(color: Colors.black.withOpacity(0.6)), filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.black.withOpacity(0.1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.black.withOpacity(0.1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.black, width: 1.5)),
      prefixIcon: Icon(icon, color: Colors.black54),
    );
  }
}

// ==========================================
// 4. HOME SCREEN
// ==========================================
class HomeScreen extends StatefulWidget {
  final String userName;
  const HomeScreen({super.key, required this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription? _scheduleSubscription;
  late Stream<QuerySnapshot> _schedulesStream;
  String? _expandedCourseId;
  String _displayName = "";
  final platform = const MethodChannel('com.classguard/applock');

  Timer? _minuteTimer;

  @override
  void initState() {
    super.initState();
    _loadProfileName();
    FlutterLocalNotificationsPlugin().resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();

    _schedulesStream = FirebaseFirestore.instance.collection('schedules').snapshots();

    _scheduleSubscription = _schedulesStream.listen((snapshot) async {
      _recalculateAlarms(snapshot.docs);

      final now = DateTime.now();
      final dayStr = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][now.weekday - 1];
      int currentMins = now.hour * 60 + now.minute;

      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool foundActive = false;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['isActive'] == true && data['day'] == dayStr) {
          int start = timeToMinutes(data['startTime'] ?? "00:00");
          int end = timeToMinutes(data['endTime'] ?? "00:00");

          if (currentMins >= start && currentMins <= end) {
            bool wasActive = prefs.getBool('isAppLockActive') ?? false;
            if (!wasActive) {
              Fluttertoast.showToast(msg: "Class started: Device is Silent & Distracting Apps Locked", toastLength: Toast.LENGTH_LONG);
            }

            List<dynamic> apps = data['blockedApps'] ?? [];
            await prefs.setString('blockedApps', apps.join(','));
            await prefs.setInt('allowanceTime', data['allowanceTime'] ?? 2);
            await prefs.setString('securityPIN', data['securityPIN'] ?? "1234");
            await prefs.setString('allowedApp', data['allowedApp'] ?? "");
            await prefs.setInt('allowedUntil', data['allowedUntil'] ?? 0);
            await prefs.setBool('isAppLockActive', data['isAppLockEnabled'] ?? true);

            foundActive = true;
            break;
          }
        }
      }

      if (!foundActive) {
        bool wasActive = prefs.getBool('isAppLockActive') ?? false;
        if (wasActive) {
          Fluttertoast.showToast(msg: "Class ended: Device is back to normal", toastLength: Toast.LENGTH_LONG);
        }
        await prefs.setBool('isAppLockActive', false);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowPermissionWarning();
    });

    _minuteTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadProfileName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _displayName = prefs.getString('profileName') ?? widget.userName;
    });
  }

  Future<void> _checkAndShowPermissionWarning() async {
    bool dndStatus = await PermissionHandler.permissionsGranted ?? false;
    bool accStatus = false;
    bool ovrStatus = false;
    bool batStatus = false;

    try {
      accStatus = await platform.invokeMethod('checkAccessibilityPermission') ?? false;
      ovrStatus = await platform.invokeMethod('checkOverlayPermission') ?? false;
      batStatus = await platform.invokeMethod('checkBatteryOptimization') ?? false;
    } catch (e) {
      debugPrint("Warning check failed: $e");
    }

    List<String> missingPermissions = [];
    if (!dndStatus) missingPermissions.add("Do Not Disturb (DND)");
    if (!accStatus) missingPermissions.add("Accessibility (AppLock Service)");
    if (!ovrStatus) missingPermissions.add("Display Over Other Apps (Lock Screen)");
    if (!batStatus) missingPermissions.add("Battery Optimization (Prevent App Kill)");

    if (missingPermissions.isNotEmpty && mounted) {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => PopScope(
              canPop: false,
              child: AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                    SizedBox(width: 8),
                    Text('Action Required', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ClassGuard detected that some core system permissions are disabled. Please re-enable the following permissions to keep the protection active:', style: TextStyle(fontSize: 14, color: Colors.black87)),
                    const SizedBox(height: 16),
                    ...missingPermissions.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.close, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(p, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        ],
                      ),
                    )),
                  ],
                ),
                actions: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context, _createRoute(const PermissionOnboardingScreen(isFromSettings: true)));
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: const Text('Enable Permissions', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              )
          )
      );
    }
  }

  @override
  void dispose() {
    _scheduleSubscription?.cancel();
    _minuteTimer?.cancel();
    super.dispose();
  }

  void _recalculateAlarms(List<QueryDocumentSnapshot> docs) {
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['isActive'] == true && data['isSilentModeEnabled'] == true) {
        String startTime = data['startTime'] ?? "00:00";
        String endTime = data['endTime'] ?? "00:00";

        _setAutomaticAlarm(startTime, doc.id.hashCode, startClassGuard, "Focus Mode Active", "Class session has started. Your phone is muted and distracting apps are locked.");
        _setAutomaticAlarm(endTime, doc.id.hashCode + 1, stopClassGuard, "Focus Mode Ended", "Great job! Class session has ended. Your phone is back to normal.");
      } else {
        AndroidAlarmManager.cancel(doc.id.hashCode);
        AndroidAlarmManager.cancel(doc.id.hashCode + 1);

        platform.invokeMethod('cancelNativePopupAlarm', {'alarmId': doc.id.hashCode});
        platform.invokeMethod('cancelNativePopupAlarm', {'alarmId': doc.id.hashCode + 1});
      }
    }
  }

  void _setAutomaticAlarm(String timeStr, int alarmId, Function callback, String title, String message) async {
    final now = DateTime.now();
    final parts = timeStr.split(':');
    if (parts.length != 2) return;
    var scheduleTime = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
    if (scheduleTime.isBefore(now)) scheduleTime = scheduleTime.add(const Duration(days: 1));

    await AndroidAlarmManager.oneShot(scheduleTime.difference(now), alarmId, callback, exact: true, wakeup: true);

    try {
      await platform.invokeMethod('setNativePopupAlarm', {
        'alarmId': alarmId,
        'timeInMillis': scheduleTime.millisecondsSinceEpoch,
        'title': title,
        'message': message
      });
    } catch (e) {
      debugPrint("Failed to set native alarm: $e");
    }
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    final weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return "${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}";
  }

  bool _isCourseCurrentlyRunning(Course course) {
    if (!course.isActive) return false;
    final now = DateTime.now();
    final days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    if (course.day != days[now.weekday - 1]) return false;

    int currentMins = now.hour * 60 + now.minute;
    int startMins = timeToMinutes(course.startTime);
    int endMins = timeToMinutes(course.endTime);

    return currentMins >= startMins && currentMins <= endMins;
  }

  Widget _buildExpandedCard(Course course) {
    bool isOwner = course.role == 'Personal' || course.role == 'Teacher';
    bool isRunning = _isCourseCurrentlyRunning(course);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(24),
          border: isRunning ? Border.all(color: Colors.greenAccent, width: 2) : null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: isRunning ? Colors.greenAccent.withOpacity(0.2) : Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: Text(isRunning ? 'ACTIVE NOW' : '${course.day.toUpperCase()} • ${course.role.toUpperCase()}', style: TextStyle(color: isRunning ? Colors.greenAccent : Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1))
              ),
              const Spacer(),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (isRunning) {
                        Fluttertoast.showToast(msg: "Class is running. Cannot change settings now.", backgroundColor: Colors.red);
                        return;
                      }
                      if (!isOwner) {
                        Fluttertoast.showToast(msg: "Only the host can change this setting.", backgroundColor: Colors.black87);
                        return;
                      }
                      FirebaseFirestore.instance.collection('schedules').doc(course.id).update({'isSilentModeEnabled': !course.isSilentModeEnabled});
                    },
                    child: Padding(padding: const EdgeInsets.all(8.0), child: Icon(course.isSilentModeEnabled ? Icons.volume_off : Icons.volume_up, color: course.isSilentModeEnabled ? Colors.white : Colors.white38, size: 20)),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (isRunning) {
                        Fluttertoast.showToast(msg: "Class is running. Cannot change settings now.", backgroundColor: Colors.red);
                        return;
                      }
                      if (!isOwner) {
                        Fluttertoast.showToast(msg: "Only the host can change this setting.", backgroundColor: Colors.black87);
                        return;
                      }
                      FirebaseFirestore.instance.collection('schedules').doc(course.id).update({'isAppLockEnabled': !course.isAppLockEnabled});
                    },
                    child: Padding(padding: const EdgeInsets.all(8.0), child: Icon(course.isAppLockEnabled ? Icons.lock_outline : Icons.lock_open_outlined, color: course.isAppLockEnabled ? Colors.white : Colors.white38, size: 20)),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: (isRunning && course.role != 'Teacher') ? Colors.white24 : Colors.white70),
                    onSelected: (value) {
                      if (isRunning && course.role != 'Teacher') {
                        Fluttertoast.showToast(msg: "Class is running. Action blocked.", backgroundColor: Colors.red);
                        return;
                      }
                      if (value == 'edit') {
                        Navigator.push(context, _createRoute(AddScheduleScreen(courseToEdit: course)));
                      } else if (value == 'delete') {
                        AndroidAlarmManager.cancel(course.id.hashCode);
                        AndroidAlarmManager.cancel(course.id.hashCode + 1);
                        platform.invokeMethod('cancelNativePopupAlarm', {'alarmId': course.id.hashCode});
                        platform.invokeMethod('cancelNativePopupAlarm', {'alarmId': course.id.hashCode + 1});
                        FirebaseFirestore.instance.collection('schedules').doc(course.id).delete();
                      }
                    },
                    itemBuilder: (context) => [
                      if (isOwner && (!isRunning || course.role == 'Teacher')) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (!isRunning) const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                      if (isRunning && course.role != 'Teacher') const PopupMenuItem(value: 'locked', child: Text('Locked during class', style: TextStyle(color: Colors.grey))),
                    ],
                  )
                ],
              )
            ],
          ),
          const SizedBox(height: 20),
          Text(course.subject, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('${course.lecturer} • ${course.room}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [const Icon(Icons.access_time, color: Colors.white70, size: 16), const SizedBox(width: 8), Text('${course.startTime} - ${course.endTime}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))]),
              Switch(
                value: course.isActive,
                activeColor: Colors.black,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                onChanged: (val) async {
                  if (isRunning) {
                    Fluttertoast.showToast(msg: "Cannot turn off an active running class.", backgroundColor: Colors.red);
                    return;
                  }
                  if (val == true) {
                    String? error = await checkAndHandleCollision(course.day, course.startTime, course.endTime, course.role, excludeId: course.id);
                    if (error != null && error != "OVERRIDDEN") {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                      return;
                    }
                  }
                  await FirebaseFirestore.instance.collection('schedules').doc(course.id).update({'isActive': val});
                },
              )
            ],
          ),
          if (course.role == 'Teacher') ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(context, _createRoute(TeacherDashboardScreen(course: course))),
                icon: const Icon(Icons.admin_panel_settings, size: 20),
                label: const Text('Open Teacher Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            )
          ],
        ],
      ),
    );
  }

  Widget _buildCollapsedLightCard(Course course) {
    IconData roleIcon = course.role == 'Teacher' ? Icons.assignment_ind : (course.role == 'Student' ? Icons.class_outlined : Icons.calendar_today_outlined);
    bool isRunning = _isCourseCurrentlyRunning(course);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isRunning ? Colors.greenAccent : Colors.black.withOpacity(0.1), width: isRunning ? 2.0 : 1.0),
      ),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)), child: Icon(roleIcon, color: Colors.black87)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.subject, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: course.isActive ? Colors.black87 : Colors.black38)),
                const SizedBox(height: 4),
                Text(isRunning ? 'RUNNING NOW' : '${course.day} • ${course.startTime} - ${course.endTime}', style: TextStyle(color: isRunning ? Colors.green : (course.isActive ? Colors.black54 : Colors.black26), fontSize: 14, fontWeight: isRunning ? FontWeight.bold : FontWeight.normal)),
              ],
            ),
          ),
          Switch(
            value: course.isActive,
            activeColor: Colors.white,
            activeTrackColor: Colors.black87,
            onChanged: (val) async {
              if (isRunning) {
                Fluttertoast.showToast(msg: "Cannot turn off an active running class.", backgroundColor: Colors.red);
                return;
              }
              if (val == true) {
                String? error = await checkAndHandleCollision(course.day, course.startTime, course.endTime, course.role, excludeId: course.id);
                if (error != null && error != "OVERRIDDEN") {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                  return;
                }
              }
              await FirebaseFirestore.instance.collection('schedules').doc(course.id).update({'isActive': val});
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: (isRunning && course.role != 'Teacher') ? Colors.black26 : Colors.black87),
            onSelected: (value) {
              if (isRunning && course.role != 'Teacher') {
                Fluttertoast.showToast(msg: "Class is running. Action blocked.", backgroundColor: Colors.red);
                return;
              }
              if (value == 'edit') {
                Navigator.push(context, _createRoute(AddScheduleScreen(courseToEdit: course)));
              } else if (value == 'delete') {
                AndroidAlarmManager.cancel(course.id.hashCode);
                AndroidAlarmManager.cancel(course.id.hashCode + 1);
                platform.invokeMethod('cancelNativePopupAlarm', {'alarmId': course.id.hashCode});
                platform.invokeMethod('cancelNativePopupAlarm', {'alarmId': course.id.hashCode + 1});
                FirebaseFirestore.instance.collection('schedules').doc(course.id).delete();
              }
            },
            itemBuilder: (context) => [
              if (course.role != 'Student' && (!isRunning || course.role == 'Teacher')) const PopupMenuItem(value: 'edit', child: Text('Edit')),
              if (!isRunning) const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
              if (isRunning && course.role != 'Teacher') const PopupMenuItem(value: 'locked', child: Text('Locked during class', style: TextStyle(color: Colors.grey))),
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: _schedulesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.black));

          final docs = snapshot.data?.docs ?? [];
          List<Course> courseList = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Course(
              id: doc.id,
              subject: data['subject'] ?? '-',
              lecturer: data['lecturer'] ?? '-',
              room: data['room'] ?? '-',
              day: data['day'] ?? 'Mon',
              startTime: data['startTime'] ?? '00:00',
              endTime: data['endTime'] ?? '00:00',
              isAppLockEnabled: data['isAppLockEnabled'] ?? false,
              isSilentModeEnabled: data['isSilentModeEnabled'] ?? false,
              isActive: data['isActive'] ?? true,
              role: data['role'] ?? 'Personal',
              roomCode: data['roomCode'],
              securityPIN: data['securityPIN'],
              allowanceTime: data['allowanceTime'] ?? 0,
              blockedApps: data['blockedApps'] ?? [],
            );
          }).toList();

          courseList.sort((a, b) {
            bool aRunning = _isCourseCurrentlyRunning(a);
            bool bRunning = _isCourseCurrentlyRunning(b);
            if (aRunning && !bRunning) return -1;
            if (!aRunning && bRunning) return 1;
            return getNextOccurrence(a.day, a.startTime).compareTo(getNextOccurrence(b.day, b.startTime));
          });

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.white.withOpacity(0.95),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                toolbarHeight: 90,
                titleSpacing: 24,
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Hello, ${_displayName.isNotEmpty ? _displayName : widget.userName}!', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: -0.5)),
                        const SizedBox(height: 4),
                        Text(_getFormattedDate(), style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.5), fontWeight: FontWeight.w600)),
                      ],
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.push(context, _createRoute(const SettingsScreen())).then((_) => _loadProfileName());
                      },
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black.withOpacity(0.1), width: 1.0),
                        ),
                        child: const Icon(Icons.settings, color: Colors.black87, size: 24),
                      ),
                    )
                  ],
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      if (courseList.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: TweenAnimationBuilder(
                            tween: Tween<double>(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 500),
                            builder: (context, val, child) => Opacity(opacity: val, child: child),
                            child: Container(
                              width: double.infinity, padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))]),
                              child: const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('No schedules yet. Tap + to add schedule or join a room.', style: TextStyle(color: Colors.white70, height: 1.5), textAlign: TextAlign.center)),
                            ),
                          ),
                        );
                      }

                      return TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: Duration(milliseconds: 300 + (index * 100)),
                        builder: (context, val, child) => Opacity(opacity: val, child: Transform.translate(offset: Offset(0, 20 * (1 - val)), child: child)),
                        child: () {
                          if (index == 0) {
                            Course course = courseList[0];
                            bool isExpanded = _expandedCourseId == null || _expandedCourseId == course.id;
                            return Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: GestureDetector(
                                onTap: () => setState(() => _expandedCourseId = isExpanded ? null : course.id),
                                child: AnimatedCrossFade(
                                  duration: const Duration(milliseconds: 400),
                                  firstChild: _buildExpandedCard(course),
                                  secondChild: _buildCollapsedLightCard(course),
                                  crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                                ),
                              ),
                            );
                          }

                          if (index == 1) {
                            if (courseList.length == 1) return Padding(padding: const EdgeInsets.only(top: 32, bottom: 16), child: Center(child: Text('No other schedules', style: TextStyle(color: Colors.black.withOpacity(0.3)))));
                            return const Padding(padding: EdgeInsets.only(top: 16, bottom: 16), child: Text('Other Schedules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)));
                          }

                          Course course = courseList[index - 1];
                          bool isExpanded = _expandedCourseId == course.id;
                          return GestureDetector(
                            onTap: () => setState(() => _expandedCourseId = isExpanded ? null : course.id),
                            child: AnimatedCrossFade(
                              duration: const Duration(milliseconds: 300),
                              crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                              firstChild: _buildCollapsedLightCard(course),
                              secondChild: _buildExpandedCard(course),
                            ),
                          );
                        }(),
                      );
                    },
                    childCount: courseList.isEmpty ? 1 : courseList.length + 1,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 88)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
              context: context,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              builder: (context) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Add Options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.calendar_month, color: Colors.black87)),
                        title: const Text('Add Schedule', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text('Your personal routine', style: TextStyle(fontSize: 12)),
                        onTap: () { Navigator.pop(context); Navigator.push(context, _createRoute(const AddScheduleScreen())); },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add_box_outlined, color: Colors.black87)),
                        title: const Text('Create Room', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text('As a Teacher', style: TextStyle(fontSize: 12)),
                        onTap: () { Navigator.pop(context); Navigator.push(context, _createRoute(const CreateRoomScreen())); },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.login, color: Colors.black87)),
                        title: const Text('Join Room', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text('As a Student', style: TextStyle(fontSize: 12)),
                        onTap: () { Navigator.pop(context); Navigator.push(context, _createRoute(JoinRoomScreen(userName: _displayName.isNotEmpty ? _displayName : widget.userName))); },
                      ),
                    ],
                  ),
                );
              }
          );
        },
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ==========================================
// 4.1 TEACHER DASHBOARD (VIP PERMISSION SYSTEM)
// ==========================================
class TeacherDashboardScreen extends StatelessWidget {
  final Course course;
  const TeacherDashboardScreen({super.key, required this.course});

  void _showGrantAccessDialog(BuildContext context, String studentDocId, String studentName) {
    if (course.blockedApps.isEmpty) {
      Fluttertoast.showToast(msg: "No apps are blocked in this room.");
      return;
    }

    String selectedApp = course.blockedApps.first.toString();
    int selectedMins = 5;

    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Grant VIP Access', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Allow $studentName to access a specific blocked app.', style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 24),
                  const Text('Select App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedApp,
                        items: course.blockedApps.map((app) {
                          String cleanName = app.toString();
                          if (cleanName.contains("whatsapp")) cleanName = "WhatsApp";
                          else if (cleanName.contains("instagram")) cleanName = "Instagram";
                          else if (cleanName.contains("tiktok") || cleanName.contains("musically")) cleanName = "TikTok";
                          else if (cleanName.contains("mobile.legends")) cleanName = "Mobile Legends";
                          else if (cleanName.contains("facebook")) cleanName = "Facebook";

                          return DropdownMenuItem<String>(
                            value: app.toString(),
                            child: Text(cleanName),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => selectedApp = val!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Duration (Minutes)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [1, 5, 10, 15].map((min) => GestureDetector(
                      onTap: () => setState(() => selectedMins = min),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                            color: selectedMins == min ? Colors.black : Colors.white,
                            border: Border.all(color: selectedMins == min ? Colors.black : Colors.black12),
                            borderRadius: BorderRadius.circular(10)
                        ),
                        child: Text('$min', style: TextStyle(color: selectedMins == min ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                      ),
                    )).toList(),
                  )
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.black54))),
                ElevatedButton(
                  onPressed: () async {
                    int unlockMillis = DateTime.now().millisecondsSinceEpoch + (selectedMins * 60 * 1000);
                    await FirebaseFirestore.instance.collection('schedules').doc(studentDocId).update({
                      'allowedApp': selectedApp,
                      'allowedUntil': unlockMillis
                    });
                    if (context.mounted) {
                      Navigator.pop(context);
                      Fluttertoast.showToast(msg: "Access granted for $selectedMins minutes!");
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('Grant Access', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              ],
            )
        )
    );
  }

  void _showStudentsList(BuildContext context) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(24), height: 500,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Students in Room', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('schedules').where('roomCode', isEqualTo: course.roomCode).where('role', isEqualTo: 'Student').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.black));
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) return Center(child: Text('No students have joined yet.', style: TextStyle(color: Colors.black.withOpacity(0.5))));

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          var docData = docs[index].data() as Map<String, dynamic>;
                          String studentName = docData.containsKey('studentName') ? docData['studentName'] : 'Student ${index + 1}';

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(backgroundColor: Color(0xFFF5F5F5), child: Icon(Icons.person_outline, color: Colors.black87)),
                            title: Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: const Text('Joined successfully', style: TextStyle(fontSize: 12, color: Colors.black54)),
                            trailing: IconButton(
                              icon: const Icon(Icons.key, color: Colors.orange),
                              tooltip: 'Grant VIP Access',
                              onPressed: () => _showGrantAccessDialog(context, docs[index].id, studentName),
                            ),
                          );
                        },
                      );
                    },
                  ),
                )
              ],
            ),
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0, title: const Text('Teacher Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.subject, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(children: [const Icon(Icons.location_on_outlined, size: 16, color: Colors.white70), const SizedBox(width: 4), Text(course.room, style: const TextStyle(color: Colors.white70))]),
                  const Divider(color: Colors.white24, height: 32),
                  const Text('SECURITY CREDENTIALS', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Room Code', style: TextStyle(color: Colors.white70, fontSize: 12)), const SizedBox(height: 4), Text(course.roomCode ?? '-', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2))]),
                      IconButton(onPressed: () { Clipboard.setData(ClipboardData(text: course.roomCode ?? '')); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code Copied!'))); }, icon: const Icon(Icons.copy, color: Colors.white70))
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Emergency PIN', style: TextStyle(color: Colors.white70, fontSize: 12)), const SizedBox(height: 4), Text(course.securityPIN ?? '----', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 4))]),
                      const Icon(Icons.vpn_key_outlined, color: Colors.white70),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('SESSION INFO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showStudentsList(context),
              child: Container(
                padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withOpacity(0.1))),
                child: Row(
                  children: [
                    const Icon(Icons.groups_outlined, color: Colors.black87), const SizedBox(width: 16),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Students Joined', style: TextStyle(fontWeight: FontWeight.bold)), Text('Tap to grant app access / view list', style: TextStyle(fontSize: 12, color: Colors.black54))])),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('schedules').where('roomCode', isEqualTo: course.roomCode).where('role', isEqualTo: 'Student').snapshots(),
                      builder: (context, snapshot) {
                        int count = snapshot.data?.docs.length ?? 0;
                        return Row(children: [Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(width: 8), const Icon(Icons.chevron_right, color: Colors.black26)]);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: () async {
                  await FirebaseFirestore.instance.collection('schedules').doc(course.id).update({'isActive': false});
                  final snapshot = await FirebaseFirestore.instance.collection('schedules').where('roomCode', isEqualTo: course.roomCode).get();
                  for(var doc in snapshot.docs) {
                    await FirebaseFirestore.instance.collection('schedules').doc(doc.id).update({'isActive': false});
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Class Session Ended. All student devices unlocked.')));
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.redAccent, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), side: const BorderSide(color: Colors.redAccent, width: 1)),
                child: const Text('End Class Session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 5. SETTINGS SCREEN
// ==========================================
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0, title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 12),
          _buildSettingItem(Icons.person_outline, 'Edit Profile', 'Name, Student ID, Email', onTap: () => Navigator.push(context, _createRoute(const EditProfileScreen()))),
          const SizedBox(height: 32),
          const Text('System', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 12),
          _buildSettingItem(Icons.security_outlined, 'System Permissions', 'Accessibility, DND, Overlay', onTap: () => Navigator.push(context, _createRoute(const PermissionOnboardingScreen(isFromSettings: true)))),
          _buildSettingItem(Icons.help_outline, 'How to Use ClassGuard', 'Learn how to setup focus schedules', onTap: () {
            showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: Colors.white, title: const Text('How to Use', style: TextStyle(fontWeight: FontWeight.bold)), content: const Text('1. Create a Personal schedule or Teacher Room.\n2. Select apps you want to block during that time.\n3. Set allowance time (in minutes) for emergencies.\n4. ClassGuard will automatically mute media and lock apps based on your schedule.', style: TextStyle(height: 1.5)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Understood', style: TextStyle(color: Colors.black)))]));
          }),

          _buildSettingItem(Icons.info_outline, 'About ClassGuard', 'Version 1.2.0'),
          const SizedBox(height: 8),
          ListTile(
            onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
            contentPadding: EdgeInsets.zero,
            leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.logout, color: Colors.redAccent)),
            title: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(IconData icon, String title, String sub, {VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap, contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Colors.black87)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: Colors.black54)), trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.black26),
    );
  }
}

// ==========================================
// 5.1 EDIT PROFILE SCREEN
// ==========================================
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final nameController = TextEditingController();
  final idController = TextEditingController();
  final emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      nameController.text = prefs.getString('profileName') ?? 'Wildan Ariel';
      idController.text = prefs.getString('profileId') ?? '123456789';
      emailController.text = prefs.getString('profileEmail') ?? 'student@university.edu';
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    idController.dispose();
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0, title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), centerTitle: true),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(width: 100, height: 100, decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))]), child: const Icon(Icons.person, size: 50, color: Colors.white)),
                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: const Icon(Icons.camera_alt, size: 16, color: Colors.white))
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), TextField(controller: nameController, decoration: _inputStyle("Enter your full name")), const SizedBox(height: 24),
                  const Text('Student ID', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), TextField(controller: idController, keyboardType: TextInputType.number, decoration: _inputStyle("Enter your student ID")), const SizedBox(height: 24),
                  const Text('Email Address', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: _inputStyle("Enter your email address")), const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        SharedPreferences prefs = await SharedPreferences.getInstance();
                        await prefs.setString('profileName', nameController.text);
                        await prefs.setString('profileId', idController.text);
                        await prefs.setString('profileEmail', emailController.text);

                        if (context.mounted) {
                          FocusScope.of(context).unfocus();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                      child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ]
            )
        )
    );
  }

  InputDecoration _inputStyle(String hint) {
    return InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.black.withOpacity(0.3)), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withOpacity(0.2))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withOpacity(0.2))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black, width: 1.5)));
  }
}

// ==========================================
// 6. ADD SCHEDULE SCREEN
// ==========================================
class AddScheduleScreen extends StatefulWidget {
  final Course? courseToEdit;
  const AddScheduleScreen({super.key, this.courseToEdit});

  @override
  State<AddScheduleScreen> createState() => _AddScheduleScreenState();
}

class _AddScheduleScreenState extends State<AddScheduleScreen> {
  final subjectController = TextEditingController();
  final lecturerController = TextEditingController();
  final roomController = TextEditingController();
  final startTimeController = TextEditingController();
  final endTimeController = TextEditingController();
  final pinController = TextEditingController();

  String selectedDay = "Mon";
  bool isAppLockEnabled = true;
  bool isSilentModeEnabled = true;
  final List<String> days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

  List<String> blockedPackages = [];

  @override
  void initState() {
    super.initState();
    if (widget.courseToEdit != null) {
      subjectController.text = widget.courseToEdit!.subject;
      lecturerController.text = widget.courseToEdit!.lecturer;
      roomController.text = widget.courseToEdit!.room;
      selectedDay = widget.courseToEdit!.day;
      startTimeController.text = widget.courseToEdit!.startTime;
      endTimeController.text = widget.courseToEdit!.endTime;
      isAppLockEnabled = widget.courseToEdit!.isAppLockEnabled;
      isSilentModeEnabled = widget.courseToEdit!.isSilentModeEnabled;
      pinController.text = widget.courseToEdit!.securityPIN ?? "";
      blockedPackages = List<String>.from(widget.courseToEdit!.blockedApps);
    }
  }

  @override
  void dispose() {
    subjectController.dispose();
    lecturerController.dispose();
    roomController.dispose();
    startTimeController.dispose();
    endTimeController.dispose();
    pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0, title: Text(widget.courseToEdit != null ? 'Edit Schedule' : 'Add Schedule', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Day', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: days.map((day) => GestureDetector(
                onTap: () => setState(() => selectedDay = day),
                child: Container(width: 40, height: 40, decoration: BoxDecoration(color: selectedDay == day ? Colors.black : Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black26)), child: Center(child: Text(day, style: TextStyle(color: selectedDay == day ? Colors.white : Colors.black, fontSize: 12, fontWeight: FontWeight.bold)))),
              )).toList(),
            ),
            const SizedBox(height: 24),
            const Text('Subject Name', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), TextField(controller: subjectController, decoration: _inputStyle("e.g., Web Programming")), const SizedBox(height: 20),
            const Text('Lecturer', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), TextField(controller: lecturerController, decoration: _inputStyle("e.g., John Doe")), const SizedBox(height: 20),
            const Text('Room', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), TextField(controller: roomController, decoration: _inputStyle("e.g., Computer Lab")), const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Start Time', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), TextField(controller: startTimeController, decoration: _inputStyle("e.g., 08:00"))])),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('End Time', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), TextField(controller: endTimeController, decoration: _inputStyle("e.g., 10:30"))])),
              ],
            ),
            const SizedBox(height: 32),

            const Text('Security PIN', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: _inputStyle("Create 4-digit unlock PIN (Max 1 Min Access)").copyWith(counterText: ""),
            ),
            const SizedBox(height: 24),

            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.1), width: 1.0),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.block, color: Colors.black87)), const SizedBox(width: 16),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('App Lock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text('Block distracting apps during schedule', style: TextStyle(fontSize: 12, color: Colors.black54))])),
                      Switch(value: isAppLockEnabled, activeColor: Colors.white, activeTrackColor: Colors.black, onChanged: (val) => setState(() => isAppLockEnabled = val)),
                    ],
                  ),
                  if (isAppLockEnabled) ...[
                    const Divider(height: 32),
                    const Align(alignment: Alignment.centerLeft, child: Text("Blocked Apps List:", style: TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.apps, color: Colors.black54),
                          const SizedBox(width: 12),
                          Expanded(child: Text("${blockedPackages.length} Apps Selected", style: const TextStyle(fontWeight: FontWeight.bold))),
                          ElevatedButton(
                            onPressed: () async {
                              final result = await Navigator.push(context, _createRoute(SelectAppsScreen(initialSelectedApps: blockedPackages)));
                              if (result != null) {
                                setState(() {
                                  blockedPackages = List<String>.from(result);
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            child: const Text("SELECT"),
                          )
                        ],
                      ),
                    ),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 16),

            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.1), width: 1.0),
              ),
              child: Row(
                children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.volume_off, color: Colors.black87)), const SizedBox(width: 16),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Auto-Silent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text('Mute phone ringtone during schedule', style: TextStyle(fontSize: 12, color: Colors.black54))])),
                  Switch(value: isSilentModeEnabled, activeColor: Colors.white, activeTrackColor: Colors.black, onChanged: (val) => setState(() => isSilentModeEnabled = val)),
                ],
              ),
            ),
            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: () async {
                  if(subjectController.text.isEmpty || startTimeController.text.isEmpty || endTimeController.text.isEmpty || pinController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Required fields are missing.')));
                    return;
                  }

                  if(pinController.text.length < 4) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN must be 4 digits.')));
                    return;
                  }

                  String? collisionError = await checkAndHandleCollision(selectedDay, startTimeController.text, endTimeController.text, 'Personal', excludeId: widget.courseToEdit?.id);
                  if (collisionError != null) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(collisionError))); return; }

                  try {
                    if (widget.courseToEdit != null) {
                      await FirebaseFirestore.instance.collection('schedules').doc(widget.courseToEdit!.id).update({
                        'subject': subjectController.text, 'lecturer': lecturerController.text.isNotEmpty ? lecturerController.text : '-',
                        'room': roomController.text.isNotEmpty ? roomController.text : '-', 'day': selectedDay,
                        'startTime': startTimeController.text, 'endTime': endTimeController.text,
                        'isAppLockEnabled': isAppLockEnabled, 'isSilentModeEnabled': isSilentModeEnabled,
                        'blockedApps': blockedPackages, 'securityPIN': pinController.text, 'allowanceTime': 1,
                      });
                    } else {
                      await FirebaseFirestore.instance.collection('schedules').add({
                        'subject': subjectController.text, 'lecturer': lecturerController.text.isNotEmpty ? lecturerController.text : '-',
                        'room': roomController.text.isNotEmpty ? roomController.text : '-', 'day': selectedDay,
                        'startTime': startTimeController.text, 'endTime': endTimeController.text,
                        'isAppLockEnabled': isAppLockEnabled, 'isSilentModeEnabled': isSilentModeEnabled,
                        'isActive': true, 'role': 'Personal', 'blockedApps': blockedPackages,
                        'securityPIN': pinController.text, 'allowanceTime': 1,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                    }

                    if (mounted) {
                      FocusScope.of(context).unfocus();
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving to Cloud: $e')));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                child: Text(widget.courseToEdit != null ? 'Update Schedule' : 'Save Schedule', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputStyle(String hint) {
    return InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.black.withOpacity(0.3)), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withOpacity(0.2))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withOpacity(0.2))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black, width: 1.5)));
  }
}

// ==========================================
// 6.1 CREATE ROOM SCREEN
// ==========================================
class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final subjectController = TextEditingController();
  final roomController = TextEditingController();
  final pinController = TextEditingController();
  final startTimeController = TextEditingController();
  final endTimeController = TextEditingController();
  final allowanceController = TextEditingController(text: "2");

  String selectedDay = "Mon";
  bool isAppLockEnabled = true;
  bool isSilentModeEnabled = true;
  final List<String> days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

  List<String> blockedPackages = [];

  @override
  void dispose() {
    subjectController.dispose();
    roomController.dispose();
    pinController.dispose();
    startTimeController.dispose();
    endTimeController.dispose();
    allowanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0, title: const Text('Create Room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(12)), child: const Row(children: [Icon(Icons.info_outline, color: Colors.black87, size: 20), SizedBox(width: 12), Expanded(child: Text("You are creating a room as a Teacher. A room code will be generated for students.", style: TextStyle(color: Colors.black87, fontSize: 12)))] )), const SizedBox(height: 24),
            const Text('Day', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: days.map((day) => GestureDetector(
                onTap: () => setState(() => selectedDay = day),
                child: Container(width: 40, height: 40, decoration: BoxDecoration(color: selectedDay == day ? Colors.black : Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black26)), child: Center(child: Text(day, style: TextStyle(color: selectedDay == day ? Colors.white : Colors.black, fontSize: 12, fontWeight: FontWeight.bold)))),
              )).toList(),
            ),
            const SizedBox(height: 24),
            const Text('Room/Course Name', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), TextField(controller: subjectController, decoration: _inputStyle("e.g., Web Programming")), const SizedBox(height: 20),
            const Text('Location', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), TextField(controller: roomController, decoration: _inputStyle("e.g., Computer Lab")), const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Start Time', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), TextField(controller: startTimeController, decoration: _inputStyle("e.g., 08:00"))])),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('End Time', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), TextField(controller: endTimeController, decoration: _inputStyle("e.g., 10:30"))])),
              ],
            ),
            const SizedBox(height: 32),
            const Text('Security PIN', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), TextField(controller: pinController, keyboardType: TextInputType.number, obscureText: true, maxLength: 4, decoration: _inputStyle("Create 4-digit unlock PIN").copyWith(counterText: "")), const SizedBox(height: 24),
            const Text('App Allowance Time (Minutes)', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), TextField(controller: allowanceController, keyboardType: TextInputType.number, decoration: _inputStyle("e.g. 2 for emergency unlock")), const SizedBox(height: 24),

            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.1), width: 1.0),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.block, color: Colors.black87)), const SizedBox(width: 16),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Enforce App Lock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text('Lock students apps during this room session', style: TextStyle(fontSize: 12, color: Colors.black54))])),
                      Switch(value: isAppLockEnabled, activeColor: Colors.white, activeTrackColor: Colors.black, onChanged: (val) => setState(() => isAppLockEnabled = val)),
                    ],
                  ),
                  if (isAppLockEnabled) ...[
                    const Divider(height: 32),
                    const Align(alignment: Alignment.centerLeft, child: Text("Blocked Apps List:", style: TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.apps, color: Colors.black54),
                          const SizedBox(width: 12),
                          Expanded(child: Text("${blockedPackages.length} Apps Selected", style: const TextStyle(fontWeight: FontWeight.bold))),
                          ElevatedButton(
                            onPressed: () async {
                              final result = await Navigator.push(context, _createRoute(SelectAppsScreen(initialSelectedApps: blockedPackages)));
                              if (result != null) {
                                setState(() {
                                  blockedPackages = List<String>.from(result);
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            child: const Text("SELECT"),
                          )
                        ],
                      ),
                    ),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 16),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.1), width: 1.0),
              ),
              child: Row(
                children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.volume_off, color: Colors.black87)), const SizedBox(width: 16),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Force Auto-Silent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text('Mute students phone ringtone', style: TextStyle(fontSize: 12, color: Colors.black54))])),
                  Switch(value: isSilentModeEnabled, activeColor: Colors.white, activeTrackColor: Colors.black, onChanged: (val) => setState(() => isSilentModeEnabled = val)),
                ],
              ),
            ),
            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: () async {
                  if(subjectController.text.isEmpty || startTimeController.text.isEmpty || endTimeController.text.isEmpty || pinController.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Required fields are missing.'))); return; }
                  if(pinController.text.length < 4) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN must be 4 digits.'))); return; }

                  String? collisionError = await checkAndHandleCollision(selectedDay, startTimeController.text, endTimeController.text, 'Teacher');
                  if (collisionError != null) {
                    if (collisionError == "OVERRIDDEN") Fluttertoast.showToast(msg: "Notice: A conflicting personal schedule was auto-disabled.");
                    else { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(collisionError))); return; }
                  }

                  String generatedCode = 'CG-${Random().nextInt(9000) + 1000}';

                  try {
                    await FirebaseFirestore.instance.collection('schedules').add({
                      'subject': subjectController.text, 'lecturer': 'Me (Teacher)', 'room': roomController.text.isNotEmpty ? roomController.text : '-',
                      'day': selectedDay, 'startTime': startTimeController.text, 'endTime': endTimeController.text,
                      'isAppLockEnabled': isAppLockEnabled, 'isSilentModeEnabled': isSilentModeEnabled,
                      'isActive': true, 'role': 'Teacher', 'roomCode': generatedCode,
                      'securityPIN': pinController.text, 'allowanceTime': int.tryParse(allowanceController.text) ?? 0,
                      'blockedApps': blockedPackages, 'createdAt': FieldValue.serverTimestamp(),
                    });

                    if (context.mounted) {
                      showDialog(
                          context: context, barrierDismissible: false,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: const Text('Room Created!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Share this code with your students to join the class:', textAlign: TextAlign.center), const SizedBox(height: 24),
                                  Container(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32), decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black12, width: 2)), child: Text(generatedCode, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4))),
                                ],
                              ),
                              actions: [SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold))))],
                            );
                          }
                      );
                    }
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                child: const Text('Create Room & Generate Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputStyle(String hint) {
    return InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.black.withOpacity(0.3)), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withOpacity(0.2))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withOpacity(0.2))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black, width: 1.5)));
  }
}

// ==========================================
// 6.2 JOIN ROOM SCREEN
// ==========================================
class JoinRoomScreen extends StatefulWidget {
  final String userName;
  const JoinRoomScreen({super.key, required this.userName});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final codeController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0, title: const Text('Join Room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter Room Code', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
            const Text('Ask your teacher for the room code, then enter it here to join the session.', style: TextStyle(color: Colors.black54)), const SizedBox(height: 32),
            TextField(
              controller: codeController, textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(hintText: "e.g. CG-8921", filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withOpacity(0.2))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withOpacity(0.2))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black, width: 1.5))),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: isLoading ? null : () async {
                  if(codeController.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid room code.'))); return; }
                  setState(() => isLoading = true);

                  try {
                    final querySnapshot = await FirebaseFirestore.instance.collection('schedules').where('roomCode', isEqualTo: codeController.text.trim()).where('role', isEqualTo: 'Teacher').get();
                    if (querySnapshot.docs.isEmpty) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room not found. Please check the code and try again.'))); setState(() => isLoading = false); return; }

                    final roomData = querySnapshot.docs.first.data();
                    String roomDay = roomData['day'] ?? 'Mon';
                    String roomStart = roomData['startTime'] ?? '00:00';
                    String roomEnd = roomData['endTime'] ?? '00:00';

                    String? collisionError = await checkAndHandleCollision(roomDay, roomStart, roomEnd, 'Student');
                    if (collisionError != null) {
                      if (collisionError == "OVERRIDDEN") Fluttertoast.showToast(msg: "Notice: A conflicting personal schedule was auto-disabled.");
                      else { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(collisionError))); setState(() => isLoading = false); return; }
                    }

                    await FirebaseFirestore.instance.collection('schedules').add({
                      'subject': roomData['subject'] ?? 'Unknown Subject', 'lecturer': roomData['lecturer'] ?? 'Unknown',
                      'room': roomData['room'] ?? '-', 'day': roomDay, 'startTime': roomStart, 'endTime': roomEnd,
                      'isAppLockEnabled': roomData['isAppLockEnabled'] ?? true, 'isSilentModeEnabled': roomData['isSilentModeEnabled'] ?? true,
                      'isActive': true, 'role': 'Student', 'roomCode': roomData['roomCode'],
                      'securityPIN': roomData['securityPIN'], 'allowanceTime': roomData['allowanceTime'] ?? 0,
                      'blockedApps': roomData['blockedApps'] ?? [], 'studentName': widget.userName,
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully joined the room!'))); Navigator.pop(context); }
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connection error: $e')));
                  } finally {
                    if (mounted) setState(() => isLoading = false);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                child: isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Join Room', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 7. SELECT APPS SCREEN
// ==========================================
class SelectAppsScreen extends StatefulWidget {
  final List<String> initialSelectedApps;
  const SelectAppsScreen({super.key, required this.initialSelectedApps});

  @override
  State<SelectAppsScreen> createState() => _SelectAppsScreenState();
}

class _SelectAppsScreenState extends State<SelectAppsScreen> {
  static const platformAppInfo = MethodChannel('com.classguard/app_info');

  List<Map<String, dynamic>> _installedApps = [];
  List<Map<String, dynamic>> _masterApps = [];

  bool _isLoadingInstalled = true;
  bool _isLoadingMaster = true;
  bool _showAll = false;

  List<String> _selectedPackages = [];

  @override
  void initState() {
    super.initState();
    _selectedPackages = List.from(widget.initialSelectedApps);
    _fetchMasterApps();
    _fetchInstalledApps();
  }

  Future<void> _fetchMasterApps() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('Master Apps').get();
      setState(() {
        _masterApps = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            "name": data['name'] ?? 'Unknown App',
            "package": data['package'] ?? '',
            "iconUrl": data['iconUrl'] ?? '',
          };
        }).toList();
        _isLoadingMaster = false;
      });
    } catch (e) {
      debugPrint("Failed to fetch master list from Firebase: $e");
      setState(() => _isLoadingMaster = false);
    }
  }

  Future<void> _fetchInstalledApps() async {
    try {
      final List<dynamic> apps = await platformAppInfo.invokeMethod('getInstalledApps');
      setState(() {
        _installedApps = apps.map((e) => Map<String, dynamic>.from(e)).toList();
        _isLoadingInstalled = false;
      });
    } catch (e) {
      debugPrint("Failed to fetch local apps: $e");
      setState(() => _isLoadingInstalled = false);
    }
  }

  void _toggleSelection(String packageName) {
    setState(() {
      if (_selectedPackages.contains(packageName)) {
        _selectedPackages.remove(packageName);
      } else {
        _selectedPackages.add(packageName);
      }
    });
  }

  void _saveSelection() {
    List<String> finalBlockedApps = _selectedPackages.toSet().toList();
    Navigator.pop(context, finalBlockedApps);
  }

  @override
  Widget build(BuildContext context) {
    bool isLoading = _isLoadingInstalled || _isLoadingMaster;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          "Select Apps",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMasterListFolder(),
            const Divider(color: Colors.black12, thickness: 1, height: 40),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text("Most Frequently Used", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
            ),
            const SizedBox(height: 10),
            ..._installedApps.take(9).map((app) => _buildAppTile(app)).toList(),
            if (!_showAll && _installedApps.length > 9)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showAll = true),
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black),
                    label: const Text("View All Apps", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      side: BorderSide(color: Colors.black.withOpacity(0.2), width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ),
              ),
            if (_showAll) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text("All Apps", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
              ),
              ..._installedApps.skip(9).map((app) => _buildAppTile(app)).toList(),
            ]
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.black,
        onPressed: _saveSelection,
        label: Text("Save (${_selectedPackages.length})", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.check, color: Colors.white),
      ),
    );
  }

  Widget _buildAppTile(Map<String, dynamic> app) {
    bool isSelected = _selectedPackages.contains(app['package']);
    String iconData = app['icon']?.toString() ?? "";

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: Container(
        width: 45, height: 45,
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
        child: iconData.isNotEmpty
            ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(base64Decode(iconData), gaplessPlayback: true, fit: BoxFit.cover))
            : const Icon(Icons.android, color: Colors.black45),
      ),
      title: Text(app['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      trailing: Checkbox(
        value: isSelected,
        activeColor: Colors.black,
        onChanged: (val) => _toggleSelection(app['package']),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      onTap: () => _toggleSelection(app['package']),
    );
  }

  Widget _buildMasterListFolder() {
    return GestureDetector(
      onTap: _openMasterFolderDialog,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.1), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.folder_special, color: Colors.black87),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Master List Apps", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 2),
                  Text("Contains ${_masterApps.length} popular distracting apps", style: TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  void _openMasterFolderDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Dialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                insetPadding: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Master List", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      _masterApps.isEmpty
                          ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text("No data available in Firebase.", style: TextStyle(color: Colors.black54)),
                      )
                          : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.8, crossAxisSpacing: 12, mainAxisSpacing: 16),
                        itemCount: _masterApps.length,
                        itemBuilder: (context, index) {
                          var app = _masterApps[index];
                          bool isSelected = _selectedPackages.contains(app['package']);

                          Widget iconWidget = app['iconUrl'].toString().isNotEmpty
                              ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(app['iconUrl'], fit: BoxFit.cover))
                              : const Icon(Icons.apps, color: Colors.black54, size: 28);

                          return GestureDetector(
                            onTap: () {
                              setStateDialog(() => _toggleSelection(app['package']));
                              setState(() {});
                            },
                            child: Column(
                              children: [
                                Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Container(
                                      height: 60, width: 60,
                                      decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(14), border: Border.all(color: isSelected ? Colors.black : Colors.transparent, width: 1.5)),
                                      child: Center(child: iconWidget),
                                    ),
                                    if (isSelected)
                                      Container(decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle), padding: const EdgeInsets.all(4), child: const Icon(Icons.check, color: Colors.white, size: 12))
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(app['name'], textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Done", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ==========================================
// 8. SPLASH SCREEN (STATIC LOGO)
// ==========================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2500), () {
      _navigateToNextScreen();
    });
  }

  Future<void> _navigateToNextScreen() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isSetupDone = prefs.getBool('isFirstTimeSetupDone') ?? false;
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    String userName = prefs.getString('profileName') ?? 'Student';

    if (mounted) {
      if (!isSetupDone) {
        Navigator.pushReplacement(context, _createRoute(const PermissionOnboardingScreen()));
      } else if (isLoggedIn) {
        Navigator.pushReplacement(context, _createRoute(HomeScreen(userName: userName)));
      } else {
        Navigator.pushReplacement(context, _createRoute(const AuthScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/images/logo.png',
          width: 250,
          height: 250,
        ),
      ),
    );
  }
}