import 'dart:async';

import 'package:classguard/background/alarm_service.dart';
import 'package:classguard/models/course.dart';
import 'package:classguard/screens/dashboard/add_schedule_screen.dart';
import 'package:classguard/screens/dashboard/settings_screen.dart';
import 'package:classguard/screens/dashboard/teacher_dashboard_screen.dart';
import 'package:classguard/screens/onboarding/permission_onboarding_screen.dart';
import 'package:classguard/screens/room/create_room_screen.dart';
import 'package:classguard/screens/room/join_room_screen.dart';
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

// ===============
// 4. HOME SCREEN
// ===============
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

  @override
  void initState() {
    super.initState();
    _alarmService = AlarmService(platform: platform);
    _loadProfileName();
    FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    _schedulesStream = _firestoreService.schedulesStreamForCurrentUser();

    _scheduleSubscription = _schedulesStream.listen((snapshot) async {
      _alarmService.recalculateAlarms(snapshot.docs);
      _currentSchedules = snapshot.docs;
      _checkSchedulesState();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        //_checkAndShowPermissionWarning();
      }
    });

    _minuteTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {});
        _checkSchedulesState();
      }
    });
  }

  Future<void> _checkSchedulesState() async {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final now = DateTime.now();
    final dayStr = [
      "Mon",
      "Tue",
      "Wed",
      "Thu",
      "Fri",
      "Sat",
      "Sun",
    ][now.weekday - 1];
    int currentMins = now.hour * 60 + now.minute;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool foundActive = false;

    for (var doc in _currentSchedules) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['isActive'] == true && data['day'] == dayStr) {
        int start = timeToMinutes(data['startTime'] ?? "00:00");
        int end = timeToMinutes(data['endTime'] ?? "00:00");

        if (currentMins >= start && currentMins < end) {
          if (data['role'] == 'Teacher' && data['userId'] == uid) {
            continue;
          }

          bool wasActive = prefs.getBool('isAppLockActive') ?? false;
          if (!wasActive) {
            double currentVol = await VolumeController().getVolume();
            await prefs.setDouble('prevVolume', currentVol);

            if (data['isSilentModeEnabled'] == true) {
              try {
                await SoundMode.setSoundMode(RingerModeStatus.silent);
                await Future.delayed(const Duration(milliseconds: 500));
                VolumeController().setVolume(0.0);
              } catch (e) {}
            }
            Fluttertoast.showToast(
              msg: "Class started: Device is Silent & Distracting Apps Locked",
              toastLength: Toast.LENGTH_LONG,
            );
          }

          List<dynamic> apps = data['blockedApps'] ?? [];
          await prefs.setString('blockedApps', apps.join(','));
          await prefs.setInt('allowanceTime', data['allowanceTime'] ?? 2);
          await prefs.setString('securityPIN', data['securityPIN'] ?? "1234");
          await prefs.setBool(
            'isAppLockActive',
            data['isAppLockEnabled'] ?? true,
          );

          Map<String, dynamic> vipAccess = data['vipAccess'] ?? {};
          var myVip = vipAccess[uid];
          if (myVip != null) {
            await prefs.setString('allowedApp', myVip['app']);
            await prefs.setInt('allowedUntil', myVip['until']);
          } else {
            await prefs.setString('allowedApp', "");
            await prefs.setInt('allowedUntil', 0);
          }

          foundActive = true;
          break;
        }
      }
    }

    if (!foundActive) {
      bool wasActive = prefs.getBool('isAppLockActive') ?? false;
      if (wasActive) {
        double prevVol = prefs.getDouble('prevVolume') ?? 0.5;
        try {
          await SoundMode.setSoundMode(RingerModeStatus.normal);
          await Future.delayed(const Duration(milliseconds: 500));
          VolumeController().setVolume(prevVol);
        } catch (e) {}
        Fluttertoast.showToast(
          msg: "Class ended: Device is back to normal",
          toastLength: Toast.LENGTH_LONG,
        );
      }
      await prefs.setBool('isAppLockActive', false);
    }
  }

  Future<void> _loadProfileName() async {
    final profileName = await _authService.loadProfileName(
      fallbackName: widget.userName,
    );
    setState(() {
      _displayName = profileName;
    });
  }

  Future<void> _checkAndShowPermissionWarning() async {
    bool dndStatus = await PermissionHandler.permissionsGranted ?? false;
    bool accStatus = false;
    bool ovrStatus = false;
    bool batStatus = false;

    try {
      accStatus =
          await platform.invokeMethod('checkAccessibilityPermission') ?? false;
      ovrStatus =
          await platform.invokeMethod('checkOverlayPermission') ?? false;
      batStatus =
          await platform.invokeMethod('checkBatteryOptimization') ?? false;
    } catch (e) {
      debugPrint("Warning check failed: $e");
    }

    List<String> missingPermissions = [];
    if (!dndStatus) missingPermissions.add("Do Not Disturb (DND)");
    if (!accStatus) missingPermissions.add("Accessibility (AppLock Service)");
    if (!ovrStatus)
      missingPermissions.add("Display Over Other Apps (Lock Screen)");
    if (!batStatus)
      missingPermissions.add("Battery Optimization (Prevent App Kill)");

    if (missingPermissions.isNotEmpty && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: const [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 28,
                ),
                SizedBox(width: 8),
                Text(
                  'Action Required',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
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
                ...missingPermissions.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.close, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            p,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PermissionOnboardingScreen(
                          isFromSettings: true,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Enable Permissions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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
    final months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
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

    return currentMins >= startMins && currentMins < endMins;
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
        border: isRunning
            ? Border.all(color: Colors.greenAccent, width: 2)
            : null,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isRunning
                      ? Colors.greenAccent.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isRunning
                      ? 'ACTIVE NOW'
                      : '${course.day.toUpperCase()} • ${course.role.toUpperCase()}',
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
                        Fluttertoast.showToast(
                          msg: "Class is running. Cannot change settings now.",
                          backgroundColor: Colors.red,
                        );
                        return;
                      }
                      if (!course.isOwner) {
                        Fluttertoast.showToast(
                          msg: "Only the host can change this setting.",
                          backgroundColor: Colors.black87,
                        );
                        return;
                      }
                      setState(() {
                        course.isSilentModeEnabled =
                            !course.isSilentModeEnabled;
                      });
                      _firestoreService.updateScheduleSilentMode(
                        course.id,
                        course.isSilentModeEnabled,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        course.isSilentModeEnabled
                            ? Icons.volume_off
                            : Icons.volume_up,
                        color: course.isSilentModeEnabled
                            ? Colors.white
                            : Colors.white38,
                        size: 20,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (isRunning) {
                        Fluttertoast.showToast(
                          msg: "Class is running. Cannot change settings now.",
                          backgroundColor: Colors.red,
                        );
                        return;
                      }
                      if (!course.isOwner) {
                        Fluttertoast.showToast(
                          msg: "Only the host can change this setting.",
                          backgroundColor: Colors.black87,
                        );
                        return;
                      }
                      setState(() {
                        course.isAppLockEnabled = !course.isAppLockEnabled;
                      });
                      _firestoreService.updateScheduleAppLock(
                        course.id,
                        course.isAppLockEnabled,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        course.isAppLockEnabled
                            ? Icons.lock_outline
                            : Icons.lock_open_outlined,
                        color: course.isAppLockEnabled
                            ? Colors.white
                            : Colors.white38,
                        size: 20,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: (isRunning && !course.isOwner)
                          ? Colors.white24
                          : Colors.white70,
                    ),
                    onSelected: (value) async {
                      if (isRunning && !course.isOwner) {
                        Fluttertoast.showToast(
                          msg: "Class is running. Action blocked.",
                          backgroundColor: Colors.red,
                        );
                        return;
                      }
                      if (value == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AddScheduleScreen(courseToEdit: course),
                          ),
                        );
                      } else if (value == 'delete') {
                        if (isRunning) {
                          Fluttertoast.showToast(
                            msg: "Class is running. Cannot delete.",
                            backgroundColor: Colors.red,
                          );
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
                      if (course.isOwner &&
                          (!isRunning || course.role == 'Teacher'))
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (!isRunning)
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            course.isOwner ? 'Delete' : 'Leave Classroom',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      if (isRunning && !course.isOwner)
                        const PopupMenuItem(
                          value: 'locked',
                          child: Text(
                            'Locked during class',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            course.subject,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${course.lecturer} • ${course.room}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${course.startTime} - ${course.endTime}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Switch(
                value: course.isActive,
                activeColor: Colors.black,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                onChanged: (val) async {
                  if (isRunning && val == false) {
                    Fluttertoast.showToast(
                      msg: "Class is running. Cannot turn off.",
                      backgroundColor: Colors.red,
                    );
                    return;
                  }
                  if (!course.isOwner) {
                    Fluttertoast.showToast(
                      msg: "Only the teacher can toggle this room.",
                      backgroundColor: Colors.red,
                    );
                    return;
                  }
                  if (val == true) {
                    String? error = await _firestoreService
                        .checkAndHandleCollision(
                          course.day,
                          course.startTime,
                          course.endTime,
                          course.role,
                          excludeId: course.id,
                        );
                    if (error != null) {
                      if (error == "OVERRIDDEN") {
                        Fluttertoast.showToast(
                          msg:
                              "Notice: A conflicting personal schedule was auto-disabled.",
                        );
                      } else {
                        if (context.mounted)
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(error)));
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
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TeacherDashboardScreen(course: course),
                  ),
                ),
                icon: const Icon(Icons.admin_panel_settings, size: 20),
                label: const Text(
                  'Open Classroom Dashboard',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollapsedLightCard(Course course) {
    IconData roleIcon = course.role == 'Teacher'
        ? Icons.assignment_ind
        : (course.role == 'Student'
              ? Icons.class_outlined
              : Icons.calendar_today_outlined);
    bool isRunning = _isCourseCurrentlyRunning(course);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRunning
              ? Colors.greenAccent
              : Colors.black.withValues(alpha: 0.1),
          width: isRunning ? 2.0 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(roleIcon, color: Colors.black87),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.subject,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: course.isActive ? Colors.black87 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isRunning
                      ? 'RUNNING NOW'
                      : '${course.day} • ${course.startTime} - ${course.endTime}',
                  style: TextStyle(
                    color: isRunning
                        ? Colors.green
                        : (course.isActive ? Colors.black54 : Colors.black26),
                    fontSize: 14,
                    fontWeight: isRunning ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: course.isActive,
            activeColor: Colors.white,
            activeTrackColor: Colors.black87,
            onChanged: (val) async {
              if (isRunning && val == false) {
                Fluttertoast.showToast(
                  msg: "Class is running. Cannot turn off.",
                  backgroundColor: Colors.red,
                );
                return;
              }
              if (!course.isOwner) {
                Fluttertoast.showToast(
                  msg: "Only the teacher can toggle this.",
                  backgroundColor: Colors.black87,
                );
                return;
              }
              if (val == true) {
                String? error = await _firestoreService.checkAndHandleCollision(
                  course.day,
                  course.startTime,
                  course.endTime,
                  course.role,
                  excludeId: course.id,
                );
                if (error != null) {
                  if (error == "OVERRIDDEN") {
                    Fluttertoast.showToast(
                      msg:
                          "Notice: A conflicting personal schedule was auto-disabled.",
                    );
                  } else {
                    if (context.mounted)
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(error)));
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
            icon: Icon(
              Icons.more_vert,
              color: (isRunning && !course.isOwner)
                  ? Colors.black26
                  : Colors.black87,
            ),
            onSelected: (value) async {
              if (isRunning && !course.isOwner) {
                Fluttertoast.showToast(
                  msg: "Class is running. Action blocked.",
                  backgroundColor: Colors.red,
                );
                return;
              }
              if (value == 'edit') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AddScheduleScreen(courseToEdit: course),
                  ),
                );
              } else if (value == 'delete') {
                if (isRunning) {
                  Fluttertoast.showToast(
                    msg: "Class is running. Cannot delete.",
                    backgroundColor: Colors.red,
                  );
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
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
              if (!isRunning)
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    course.isOwner ? 'Delete' : 'Leave Classroom',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              if (isRunning && !course.isOwner)
                const PopupMenuItem(
                  value: 'locked',
                  child: Text(
                    'Locked during class',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
            ],
          ),
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
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData)
            return const Center(
              child: CircularProgressIndicator(color: Colors.black),
            );

          String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
          final docs = snapshot.data?.docs ?? [];

          List<Course> courseList = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            bool isOwner = data['userId'] == currentUid;
            String originalRole = data['role'] ?? 'Personal';

            String displayRole = (originalRole == 'Teacher' && !isOwner)
                ? 'Student'
                : originalRole;

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
              role: displayRole,
              roomCode: data['roomCode'],
              securityPIN: data['securityPIN'],
              allowanceTime: data['allowanceTime'] ?? 0,
              blockedApps: data['blockedApps'] ?? [],
              isOwner: isOwner,
            );
          }).toList();

          courseList.sort((a, b) {
            bool aRunning = _isCourseCurrentlyRunning(a);
            bool bRunning = _isCourseCurrentlyRunning(b);
            if (aRunning && !bRunning) return -1;
            if (!aRunning && bRunning) return 1;
            return getNextOccurrence(
              a.day,
              a.startTime,
            ).compareTo(getNextOccurrence(b.day, b.startTime));
          });

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.white.withValues(alpha: 0.95),
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
                        Text(
                          'Hello, ${_displayName.isNotEmpty ? _displayName : widget.userName}!',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getFormattedDate(),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        ).then((_) => _loadProfileName());
                      },
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.1),
                            width: 1.0,
                          ),
                        ),
                        child: const Icon(
                          Icons.settings,
                          color: Colors.black87,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (courseList.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 500),
                          builder: (context, val, child) =>
                              Opacity(opacity: val, child: child),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Text(
                                'No schedules yet. Tap + to add schedule or join a classroom.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: Duration(milliseconds: 300 + (index * 100)),
                      builder: (context, val, child) => Opacity(
                        opacity: val,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - val)),
                          child: child,
                        ),
                      ),
                      child: () {
                        if (index == 0) {
                          Course course = courseList[0];
                          bool isExpanded =
                              _expandedCourseId == null ||
                              _expandedCourseId == course.id;
                          return Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: GestureDetector(
                              onTap: () => setState(
                                () => _expandedCourseId = isExpanded
                                    ? null
                                    : course.id,
                              ),
                              child: AnimatedCrossFade(
                                duration: const Duration(milliseconds: 400),
                                firstChild: _buildExpandedCard(course),
                                secondChild: _buildCollapsedLightCard(course),
                                crossFadeState: isExpanded
                                    ? CrossFadeState.showFirst
                                    : CrossFadeState.showSecond,
                              ),
                            ),
                          );
                        }

                        if (index == 1) {
                          if (courseList.length == 1)
                            return Padding(
                              padding: const EdgeInsets.only(
                                top: 32,
                                bottom: 16,
                              ),
                              child: Center(
                                child: Text(
                                  'No other schedules',
                                  style: TextStyle(
                                    color: Colors.black.withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                            );
                          return const Padding(
                            padding: EdgeInsets.only(top: 16, bottom: 16),
                            child: Text(
                              'Other Schedules',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          );
                        }

                        Course course = courseList[index - 1];
                        bool isExpanded = _expandedCourseId == course.id;
                        return GestureDetector(
                          onTap: () => setState(
                            () => _expandedCourseId = isExpanded
                                ? null
                                : course.id,
                          ),
                          child: AnimatedCrossFade(
                            duration: const Duration(milliseconds: 300),
                            crossFadeState: isExpanded
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            firstChild: _buildCollapsedLightCard(course),
                            secondChild: _buildExpandedCard(course),
                          ),
                        );
                      }(),
                    );
                  }, childCount: courseList.isEmpty ? 1 : courseList.length + 1),
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
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (context) {
              return Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add Options',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.calendar_month,
                          color: Colors.black87,
                        ),
                      ),
                      title: const Text(
                        'Add Schedule',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Your personal routine',
                        style: TextStyle(fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddScheduleScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.add_box_outlined,
                          color: Colors.black87,
                        ),
                      ),
                      title: const Text(
                        'Create Classroom',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'As a Teacher',
                        style: TextStyle(fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CreateRoomScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.login, color: Colors.black87),
                      ),
                      title: const Text(
                        'Join Classroom',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'As a Student',
                        style: TextStyle(fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => JoinRoomScreen(
                              userName: _displayName.isNotEmpty
                                  ? _displayName
                                  : widget.userName,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
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
