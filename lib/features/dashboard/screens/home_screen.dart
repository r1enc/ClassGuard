import 'dart:async';

import 'package:classguard/background/alarm_service.dart';
import 'package:classguard/models/course.dart';
import 'package:classguard/models/exam.dart';
import 'package:classguard/screens/dashboard/add_schedule_screen.dart';
import 'package:classguard/screens/dashboard/settings_screen.dart';
import 'package:classguard/screens/dashboard/teacher_dashboard_screen.dart';
import 'package:classguard/screens/onboarding/permission_onboarding_screen.dart';
import 'package:classguard/screens/room/create_room_screen.dart';
import 'package:classguard/screens/room/join_room_screen.dart';
import 'package:classguard/screens/exam/create_exam.dart';
import 'package:classguard/screens/exam/exam_session.dart';
import 'package:classguard/screens/exam/exam_dashboard.dart';
import 'package:classguard/screens/exam/exam_history.dart';
import 'package:classguard/services/auth_service.dart';
import 'package:classguard/services/firestore_service.dart';
import 'package:classguard/utils/time_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_mode/permission_handler.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';
import 'package:volume_controller/volume_controller.dart';

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
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final platform = const MethodChannel('com.classguard/applock');

  Timer? _minuteTimer;
  late final AlarmService _alarmService;
  List<QueryDocumentSnapshot> _currentSchedules = [];
  List<QueryDocumentSnapshot> _currentExams = [];

  bool _hasShownPermissionWarning = false;

  @override
  void initState() {
    super.initState();
    _alarmService = AlarmService(platform: platform);
    _loadProfileName();

    // Request notification permissions for Android 13+ devices
    FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
    >()
        ?.requestNotificationsPermission();

    // Initialize the stream for current user's schedules
    _schedulesStream = _firestoreService.schedulesStreamForCurrentUser();

    // Listen to schedule changes to automatically recalculate background alarms
    _scheduleSubscription = _schedulesStream.listen((snapshot) async {
      _alarmService.recalculateAlarms(snapshot.docs);
      _currentSchedules = snapshot.docs;
      _checkSchedulesState();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Trigger the one-time tutorial popup check after the UI is built
      _checkAndShowTutorialPopup();

      await Future.delayed(const Duration(seconds: 5));
      // Display permission warning dialog if critical system permissions are missing
      if (mounted && !_hasShownPermissionWarning) {
        _hasShownPermissionWarning = true;
        _checkAndShowPermissionWarning();
      }
    });

    // Background timer to constantly check schedule and exam statuses without relying solely on streams
    _minuteTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
        // Execute heavy checking logic every 5 seconds to optimize performance and prevent UI lag
        if (timer.tick % 5 == 0) {
          _checkSchedulesState();
          _checkExpiredExams();
        }
      }
    });
  }

  // HELPER METHODS
  // Evaluates if a given course is currently active based on system time
  bool _isCourseCurrentlyRunning(Course course) {
    if (!course.isActive) return false;
    final now = DateTime.now();
    final days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    if (course.day != days[now.weekday - 1]) return false;

    int currentMins = now.hour * 60 + now.minute;
    int startMins = timeToMinutes(course.startTime);
    int endMins = timeToMinutes(course.endTime);

    return currentMins >= startMins && currentMins < endMins;
  }

  // ONE-TIME TUTORIAL POPUP LOGIC
  // Checks local storage to ensure the tutorial is only shown once per app installation
  Future<void> _checkAndShowTutorialPopup() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasSeenTutorial = prefs.getBool('hasSeenTutorial') ?? false;

    if (!hasSeenTutorial && mounted) {
      _showTutorialDialog(prefs);
    }
  }

  void _showTutorialDialog(SharedPreferences prefs) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          int currentIndex = 0;
          final PageController pageController = PageController();

          return StatefulBuilder(builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                width: double.infinity,
                height: 460,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  // Soft black shadow to create depth and separate the popup from the monochrome home screen
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                      offset: const Offset(0, 15),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: PageView(
                        controller: pageController,
                        onPageChanged: (index) => setState(() => currentIndex = index),
                        children: [
                          _buildTutorialSlide(
                            icon: Icons.calendar_month_outlined,
                            title: 'Personal Schedule',
                            description: 'Manage your daily routines. Set specific study hours to automatically silence your phone and block distracting apps.',
                          ),
                          _buildTutorialSlide(
                            icon: Icons.domain_outlined,
                            title: 'Classroom',
                            description: 'Host or join virtual classes. When a class is active, it enforces focus mode and app restrictions synchronously for all students.',
                          ),
                          _buildTutorialSlide(
                            icon: Icons.shield_outlined,
                            title: 'Exam Mode',
                            description: 'Enter a secure testing environment. The app locks your screen to prevent cheating during the exam session.',
                          ),
                        ],
                      ),
                    ),
                    // Dynamic pagination dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: currentIndex == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: currentIndex == index ? Colors.black : Colors.black26,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            if (currentIndex < 2) {
                              // Proceed to the next tutorial slide
                              pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
                            } else {
                              // Finalize tutorial and save state to prevent it from appearing again
                              prefs.setBool('hasSeenTutorial', true);
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                              currentIndex < 2 ? 'Next' : 'Get Started',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          });
        }
    );
  }

  // Generates individual slides for the tutorial popup
  Widget _buildTutorialSlide({required IconData icon, required String title, required String description}) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F5F5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: Colors.black87),
          ),
          const SizedBox(height: 32),
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 16),
          Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.5)
          ),
        ],
      ),
    );
  }

  // Automatically deactivates exam sessions when their allotted time has expired
  void _checkExpiredExams() {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final now = DateTime.now();

    for (var doc in _currentExams) {
      final data = doc.data() as Map<String, dynamic>;
      // Only process exams owned by the current user that are still marked as active
      if (data['hostId'] == uid && data['isActive'] == true) {
        Timestamp? startTimestamp = data['startTime'] as Timestamp?;
        int duration = data['durationMinutes'] ?? 0;
        if (startTimestamp != null) {
          DateTime endTime = startTimestamp.toDate().add(Duration(minutes: duration));
          if (now.isAfter(endTime)) {
            // Update Firestore to flag the exam as inactive, removing it from active dashboards
            FirebaseFirestore.instance.collection('exams').doc(doc.id).update({'isActive': false}).catchError((_) {});
          }
        }
      }
    }
  }

  // Evaluates schedules to trigger hardware locks (silent mode, app blocking) based on the current time
  Future<void> _checkSchedulesState() async {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final now = DateTime.now();
    final dayStr = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][now.weekday - 1];
    int currentMins = now.hour * 60 + now.minute;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool foundActive = false;

    for (var doc in _currentSchedules) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['isActive'] == true && data['day'] == dayStr) {
        int start = timeToMinutes(data['startTime'] ?? "00:00");
        int end = timeToMinutes(data['endTime'] ?? "00:00");

        if (currentMins >= start && currentMins < end) {
          // Teachers are exempt from restrictions in their own classrooms
          if (data['role'] == 'Teacher' && data['userId'] == uid) continue;

          bool wasActive = prefs.getBool('isAppLockActive') ?? false;
          if (!wasActive) {
            double currentVol = await VolumeController().getVolume();
            await prefs.setDouble('prevVolume', currentVol);

            // Execute hardware silent mode protocol
            if (data['isSilentModeEnabled'] == true) {
              try {
                await SoundMode.setSoundMode(RingerModeStatus.silent);
                await Future.delayed(const Duration(milliseconds: 500));
                VolumeController().setVolume(0.0);
              } catch (e) {
                // Catch block filled to prevent unused variable warning
                debugPrint("Silent mode error: $e");
              }
            }
            Fluttertoast.showToast(msg: "Class started: Device is Silent & Distracting Apps Locked", toastLength: Toast.LENGTH_LONG);
          }

          // Inject class rules into local preferences for the Kotlin Background Service
          List<dynamic> apps = data['blockedApps'] ?? [];
          await prefs.setString('blockedApps', apps.join(','));
          await prefs.setInt('allowanceTime', data['allowanceTime'] ?? 2);
          await prefs.setString('securityPIN', data['securityPIN'] ?? "1234");
          await prefs.setBool('isAppLockActive', data['isAppLockEnabled'] ?? true);

          foundActive = true;
          break; // Stop evaluating after finding the first active schedule
        }
      }
    }

    // Revert hardware settings to normal if no schedules are currently active
    if (!foundActive) {
      bool wasActive = prefs.getBool('isAppLockActive') ?? false;
      if (wasActive) {
        double prevVol = prefs.getDouble('prevVolume') ?? 0.5;
        try {
          await SoundMode.setSoundMode(RingerModeStatus.normal);
          await Future.delayed(const Duration(milliseconds: 500));
          VolumeController().setVolume(prevVol);
        } catch (e) {
          // Catch block filled to prevent unused variable warning
          debugPrint("Normal mode error: $e");
        }
        Fluttertoast.showToast(msg: "Class ended: Device is back to normal", toastLength: Toast.LENGTH_LONG);
      }
      await prefs.setBool('isAppLockActive', false);
    }
  }

  Future<void> _loadProfileName() async {
    final profileName = await _authService.loadProfileName(fallbackName: widget.userName);
    setState(() {
      _displayName = profileName;
    });
  }

  // Scans for required device permissions and displays an alert if any are disabled
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

    if (missingPermissions.isEmpty) {
      _hasShownPermissionWarning = false;
      return;
    }

    if (missingPermissions.isNotEmpty && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                SizedBox(width: 8),
                Text('Action Required', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ClassGuard detected that some core system permissions are disabled. Please re-enable the following permissions to keep the protection active:',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
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
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const PermissionOnboardingScreen(isFromSettings: true)));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Enable Permissions', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _scheduleSubscription?.cancel();
    _minuteTimer?.cancel();
    super.dispose();
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    final weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return "${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}";
  }

  // Translates raw database strings into a cleaner format for the UI badges
  String _formatExamType(String rawType) {
    if (rawType.toLowerCase().contains('multiple')) return 'Multiple Choice';
    if (rawType.toLowerCase().contains('essay')) return 'Essay';
    return rawType;
  }

  // REDESIGNED ACTIVE EXAM CARD
  // Builds a highly visible, distinct card for active exams hosted by the current user
  Widget _buildActiveExamCard(Exam exam, String examType) {
    final days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];
    final String dayStr = days[exam.startTime.weekday - 1];

    final String startStr = "${exam.startTime.hour.toString().padLeft(2, '0')}:${exam.startTime.minute.toString().padLeft(2, '0')}";
    final String endStr = "${exam.endTime.hour.toString().padLeft(2, '0')}:${exam.endTime.minute.toString().padLeft(2, '0')}";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.redAccent, width: 2),
        // Aggressive drop shadow to ensure the card grabs attention
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$dayStr • EXAM',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      examType.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white70),
                color: Colors.black,
                onSelected: (value) async {
                  if (value == 'delete') {
                    await FirebaseFirestore.instance.collection('exams').doc(exam.id).delete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            exam.title,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            exam.creatorName,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                '$startStr - $endStr',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Code: ${exam.examCode}',
            style: const TextStyle(color: Colors.white54, fontSize: 13, letterSpacing: 1),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ExamDashboardScreen(exam: exam))),
              icon: const Icon(Icons.monitor, size: 20, color: Colors.black),
              label: const Text('Open Exam Dashboard', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedCard(Course course) {
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isRunning ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isRunning ? 'ACTIVE NOW' : '${course.day.toUpperCase()} • ${course.role.toUpperCase()}',
                  style: TextStyle(
                    color: isRunning ? Colors.greenAccent : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
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
                      if (!course.isOwner) {
                        Fluttertoast.showToast(msg: "Only the host can change this setting.", backgroundColor: Colors.black87);
                        return;
                      }
                      setState(() {
                        course.isSilentModeEnabled = !course.isSilentModeEnabled;
                      });
                      _firestoreService.updateScheduleSilentMode(course.id, course.isSilentModeEnabled);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        course.isSilentModeEnabled ? Icons.volume_off : Icons.volume_up,
                        color: course.isSilentModeEnabled ? Colors.white : Colors.white38,
                        size: 20,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (isRunning) {
                        Fluttertoast.showToast(msg: "Class is running. Cannot change settings now.", backgroundColor: Colors.red);
                        return;
                      }
                      if (!course.isOwner) {
                        Fluttertoast.showToast(msg: "Only the host can change this setting.", backgroundColor: Colors.black87);
                        return;
                      }
                      setState(() {
                        course.isAppLockEnabled = !course.isAppLockEnabled;
                      });
                      _firestoreService.updateScheduleAppLock(course.id, course.isAppLockEnabled);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        course.isAppLockEnabled ? Icons.lock_outline : Icons.lock_open_outlined,
                        color: course.isAppLockEnabled ? Colors.white : Colors.white38,
                        size: 20,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: (isRunning && !course.isOwner) ? Colors.white24 : Colors.white70,
                    ),
                    color: Colors.black,
                    itemBuilder: (context) => [
                      if (course.isOwner && (!isRunning || course.role == 'Teacher'))
                        const PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Colors.white))),
                      if (!isRunning)
                        PopupMenuItem(value: 'delete', child: Text(course.isOwner ? 'Delete' : 'Leave Classroom', style: const TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                ],
              ),
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
              Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text('${course.startTime} - ${course.endTime}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                ],
              ),
              Switch(
                value: course.isActive,
                activeThumbColor: Colors.black,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                onChanged: (val) async {
                  if (isRunning && val == false) {
                    Fluttertoast.showToast(msg: "Class is running. Cannot turn off.", backgroundColor: Colors.red);
                    return;
                  }
                  if (!course.isOwner) {
                    Fluttertoast.showToast(msg: "Only the teacher can toggle this room.", backgroundColor: Colors.red);
                    return;
                  }
                  if (val == true) {
                    String? error = await _firestoreService.checkAndHandleCollision(course.day, course.startTime, course.endTime, course.role, excludeId: course.id);
                    if (error != null) {
                      if (error == "OVERRIDDEN") {
                        Fluttertoast.showToast(msg: "Notice: A conflicting personal schedule was auto-disabled.");
                      } else {
                        // Prevent UI updates across async gaps if the widget was disposed
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                        return;
                      }
                    }
                  }
                  setState(() {
                    course.isActive = val;
                  });
                  _firestoreService.updateScheduleActive(course.id, val);
                },
              ),
            ],
          ),
          if (course.role == 'Teacher' && course.isOwner) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TeacherDashboardScreen(course: course))),
                icon: const Icon(Icons.admin_panel_settings, size: 20, color: Colors.black),
                label: const Text('Open Classroom Dashboard', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollapsedLightCard(Course course) {
    IconData roleIcon = course.role == 'Teacher' ? Icons.assignment_ind_outlined : (course.role == 'Student' ? Icons.school_outlined : Icons.calendar_today_outlined);
    bool isRunning = _isCourseCurrentlyRunning(course);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isRunning ? Colors.greenAccent : Colors.black.withValues(alpha: 0.05), width: isRunning ? 2.0 : 1.0),
        boxShadow: isRunning ? [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))] : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Color(0xFFF5F5F5), shape: BoxShape.circle),
            child: Icon(roleIcon, color: Colors.black87),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.subject,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: course.isActive ? Colors.black87 : Colors.black38),
                ),
                const SizedBox(height: 4),
                Text(
                  isRunning ? 'ACTIVE NOW' : '${course.day} • ${course.startTime} - ${course.endTime}',
                  style: TextStyle(
                    color: isRunning ? Colors.green : (course.isActive ? Colors.black54 : Colors.black26),
                    fontSize: 14,
                    fontWeight: isRunning ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: course.isActive,
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.black87,
            onChanged: (val) async {
              if (isRunning && val == false) {
                Fluttertoast.showToast(msg: "Class is running. Cannot turn off.", backgroundColor: Colors.red);
                return;
              }
              if (!course.isOwner) {
                Fluttertoast.showToast(msg: "Only the teacher can toggle this.", backgroundColor: Colors.black87);
                return;
              }
              if (val == true) {
                String? error = await _firestoreService.checkAndHandleCollision(course.day, course.startTime, course.endTime, course.role, excludeId: course.id);
                if (error != null) {
                  if (error == "OVERRIDDEN") {
                    Fluttertoast.showToast(msg: "Notice: A conflicting personal schedule was auto-disabled.");
                  } else {
                    // Prevent UI updates across async gaps if the widget was disposed
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                    return;
                  }
                }
              }
              setState(() {
                course.isActive = val;
              });
              _firestoreService.updateScheduleActive(course.id, val);
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: (isRunning && !course.isOwner) ? Colors.black26 : Colors.black87),
            color: Colors.white,
            onSelected: (value) async {
              if (isRunning && !course.isOwner) {
                Fluttertoast.showToast(msg: "Class is running. Action blocked.", backgroundColor: Colors.red);
                return;
              }
              if (value == 'edit') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => AddScheduleScreen(courseToEdit: course)));
              } else if (value == 'delete') {
                if (isRunning) {
                  Fluttertoast.showToast(msg: "Class is running. Cannot delete.", backgroundColor: Colors.red);
                  return;
                }
                if (course.isOwner) {
                  _firestoreService.deleteSchedule(course.id);
                } else {
                  _firestoreService.leaveSchedule(course.id);
                }
              }
            },
            itemBuilder: (context) => [
              if (course.isOwner && (!isRunning || course.role == 'Teacher'))
                const PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Colors.black))),
              if (!isRunning)
                PopupMenuItem(value: 'delete', child: Text(course.isOwner ? 'Delete' : 'Leave Classroom', style: const TextStyle(color: Colors.redAccent))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheetItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: Color(0xFFF5F5F5), shape: BoxShape.circle),
              child: Icon(icon, color: Colors.black87, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.black.withValues(alpha: 0.5))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('exams').snapshots(),
        builder: (context, examSnapshot) {
          _currentExams = examSnapshot.data?.docs ?? [];

          final activeExams = _currentExams.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['hostId'] != currentUid || data['isActive'] != true) return false;

            Timestamp? startTimestamp = data['startTime'] as Timestamp?;
            int duration = data['durationMinutes'] ?? 0;
            if (startTimestamp != null) {
              DateTime endTime = startTimestamp.toDate().add(Duration(minutes: duration));
              if (DateTime.now().isAfter(endTime)) return false;
            }
            return true;
          }).toList();

          bool isAnyExamActive = activeExams.isNotEmpty;

          return StreamBuilder<QuerySnapshot>(
            stream: _schedulesStream,
            builder: (context, scheduleSnapshot) {
              if (scheduleSnapshot.connectionState == ConnectionState.waiting && !scheduleSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Colors.black));
              }

              final docs = scheduleSnapshot.data?.docs ?? [];

              List<Course> courseList = docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                bool isOwner = data['userId'] == currentUid;
                String originalRole = data['role'] ?? 'Personal';
                String displayRole = (originalRole == 'Teacher' && !isOwner) ? 'Student' : originalRole;

                return Course(
                  id: doc.id, subject: data['subject'] ?? '-', lecturer: data['lecturer'] ?? '-',
                  room: data['room'] ?? '-', day: data['day'] ?? 'Mon',
                  startTime: data['startTime'] ?? '00:00', endTime: data['endTime'] ?? '00:00',
                  isAppLockEnabled: data['isAppLockEnabled'] ?? false,
                  isSilentModeEnabled: data['isSilentModeEnabled'] ?? false,
                  isActive: data['isActive'] ?? true, role: displayRole,
                  roomCode: data['roomCode'], securityPIN: data['securityPIN'],
                  allowanceTime: data['allowanceTime'] ?? 0, blockedApps: data['blockedApps'] ?? [],
                  isOwner: isOwner,
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
                    backgroundColor: const Color(0xFFF8F9FA).withValues(alpha: 0.95),
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    toolbarHeight: 90,
                    titleSpacing: 24,
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hello, ${_displayName.isNotEmpty ? _displayName : widget.userName}!', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: -0.5)),
                            const SizedBox(height: 4),
                            Text(_getFormattedDate(), style: TextStyle(fontSize: 14, color: Colors.black.withValues(alpha: 0.5), fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Row(
                          children: [
                            InkWell(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const ExamHistoryScreen()));
                              },
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black.withValues(alpha: 0.05), width: 1.0)),
                                child: const Icon(Icons.history, color: Colors.black87, size: 24),
                              ),
                            ),
                            const SizedBox(width: 12),
                            InkWell(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())).then((_) => _loadProfileName());
                              },
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black.withValues(alpha: 0.05), width: 1.0)),
                                child: const Icon(Icons.settings_outlined, color: Colors.black87, size: 24),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),

                  if (isAnyExamActive)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            final data = activeExams[index].data() as Map<String, dynamic>;
                            final exam = Exam.fromJson(data, activeExams[index].id);

                            // Fetch raw type and format it cleanly for the badge
                            final rawExamType = data['examType'] ?? data['type'] ?? 'Exam';
                            final formattedExamType = _formatExamType(rawExamType.toString());

                            return Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: _buildActiveExamCard(exam, formattedExamType),
                            );
                          },
                          childCount: activeExams.length,
                        ),
                      ),
                    ),

                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        if (courseList.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(24)),
                              child: const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('No schedules yet. Tap + to add schedule or join a classroom.', style: TextStyle(color: Colors.white70, height: 1.5), textAlign: TextAlign.center)),
                            ),
                          );
                        }

                        if (isAnyExamActive) {
                          if (index == 0) {
                            return const Padding(
                                padding: EdgeInsets.only(top: 16, bottom: 16),
                                child: Text('Other Schedules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))
                            );
                          }
                          Course course = courseList[index - 1];
                          bool isExpanded = _expandedCourseId == course.id;
                          return GestureDetector(
                            onTap: () => setState(() => _expandedCourseId = isExpanded ? null : course.id),
                            child: AnimatedCrossFade(
                                duration: const Duration(milliseconds: 300),
                                crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                                firstChild: _buildCollapsedLightCard(course),
                                secondChild: _buildExpandedCard(course)
                            ),
                          );
                        } else {
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
                                    crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond
                                ),
                              ),
                            );
                          }

                          if (index == 1) {
                            if (courseList.length == 1) return Padding(padding: const EdgeInsets.only(top: 32, bottom: 16), child: Center(child: Text('No other schedules', style: TextStyle(color: Colors.black.withValues(alpha: 0.3)))));
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
                                secondChild: _buildExpandedCard(course)
                            ),
                          );
                        }
                      }, childCount: courseList.isEmpty ? 1 : courseList.length + 1),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 88)),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            builder: (context) {
              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, MediaQuery.of(context).padding.bottom + 24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildBottomSheetItem(
                          icon: Icons.date_range_outlined,
                          title: 'Add Schedule', subtitle: 'Your personal routine',
                          onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const AddScheduleScreen())); },
                        ),
                        const SizedBox(height: 8),
                        _buildBottomSheetItem(
                          icon: Icons.domain_add_outlined,
                          title: 'Create Classroom', subtitle: 'As a Teacher',
                          onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateRoomScreen())); },
                        ),
                        const SizedBox(height: 8),
                        _buildBottomSheetItem(
                          icon: Icons.login_outlined,
                          title: 'Join Classroom', subtitle: 'As a Student',
                          onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => JoinRoomScreen(userName: _displayName.isNotEmpty ? _displayName : widget.userName))); },
                        ),
                        const SizedBox(height: 8),
                        _buildBottomSheetItem(
                          icon: Icons.edit_document,
                          title: 'Create Exam Room', subtitle: 'Host a strict exam session',
                          onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateExamScreen())); },
                        ),
                        const SizedBox(height: 8),
                        _buildBottomSheetItem(
                          icon: Icons.login_outlined,
                          title: 'Join Exam Room', subtitle: 'Enter an active exam session',
                          onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const ExamSessionScreen())); },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}