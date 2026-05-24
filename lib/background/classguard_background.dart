import 'package:classguard/utils/time_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_mode/permission_handler.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';
import 'package:volume_controller/volume_controller.dart';
// Display native Android notifications for focus session state changes.
Future<void> showClassGuardNotification({
  required int id,
  required String title,
  required String body,
}) async {
  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

  final AndroidInitializationSettings androidInit =
  AndroidInitializationSettings('@mipmap/launcher_icon');

  final InitializationSettings initSettings = InitializationSettings(
    android: androidInit,
  );

  await plugin.initialize(
    settings: initSettings,
  );

  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'classguard_channel',
    'ClassGuard Alerts',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );

  final NotificationDetails platformDetails = NotificationDetails(
    android: androidDetails,
  );

  await plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: platformDetails,
  );
}
// Must remain top-level for Android background isolate execution.
@pragma('vm:entry-point')
// Activate silent mode and app lock when scheduled classroom session starts.
void startClassGuard() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  SharedPreferences prefs = await SharedPreferences.getInstance();

  String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
  if (uid.isEmpty) return;

  final now = DateTime.now();
  final days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  String dayStr = days[now.weekday % 7];
  int currentMins = now.hour * 60 + now.minute;

  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('schedules')
        .where('joinedStudents', arrayContains: uid)
        .where('isActive', isEqualTo: true)
        .get();

    String currentBlockedApps = "";
    int currentAllowanceTime = 0;
    String currentPin = "1234";
    bool matched = false;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['day'] == dayStr) {
        int start = timeToMinutes(data['startTime'] ?? "00:00");
        int end = timeToMinutes(data['endTime'] ?? "00:00");

        if (currentMins >= start && currentMins < end) {
          if (data['role'] == 'Teacher' && data['userId'] == uid) {
            continue;
          }
          List blocked = data['blockedApps'] ?? [];
          currentBlockedApps = blocked.join(",");
          currentAllowanceTime = data['allowanceTime'] ?? 0;
          currentPin = data['securityPIN'] ?? "1234";
          matched = true;
          break;
        }
      }
    }

    if (!matched) return;

    try {
      double vol = await VolumeController().getVolume();
      await prefs.setDouble('prevVolume', vol);
    } catch (_) {}

    await SoundMode.setSoundMode(RingerModeStatus.silent);

    await prefs.setString('blockedApps', currentBlockedApps);
    await prefs.setInt('allowanceTime', currentAllowanceTime);
    await prefs.setString('securityPIN', currentPin);
    await prefs.setBool('isAppLockActive', true);

    Fluttertoast.showToast(
      msg: "Class started: Device is Silent & Apps Locked",
      toastLength: Toast.LENGTH_LONG,
      backgroundColor: Colors.black,
      textColor: Colors.white,
    );

    await showClassGuardNotification(
      id: 0,
      title: 'ClassGuard Activated',
      body: 'Class session has started. Focus mode enabled.',
    );
  } catch (e) {
    debugPrint("Failed to start ClassGuard: $e");
  }
}

@pragma('vm:entry-point')
// Restore normal device state after focus session has ended.
void stopClassGuard() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();

  try {
    double prevVol = prefs.getDouble('prevVolume') ?? 0.5;
    await SoundMode.setSoundMode(RingerModeStatus.normal);
    await Future.delayed(const Duration(milliseconds: 500));
    VolumeController().setVolume(prevVol);

    await prefs.setBool('isAppLockActive', false);
    await prefs.setBool('isWarmupActive', false);

    Fluttertoast.showToast(
      msg: "Class ended: Device is back to normal",
      toastLength: Toast.LENGTH_LONG,
      backgroundColor: Colors.black,
      textColor: Colors.white,
    );

    await showClassGuardNotification(
      id: 1,
      title: 'ClassGuard Deactivated',
      body: 'Class session has ended. Device unlocked.',
    );
  } catch (e) {
    debugPrint("Failed to stop ClassGuard: $e");
  }
}