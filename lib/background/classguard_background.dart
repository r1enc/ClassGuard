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

Future<void> showClassGuardNotification({
  required int id,
  required String title,
  required String body,
}) async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
  );

  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'classguard_channel',
        'ClassGuard Alerts',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
      );
  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );

  await flutterLocalNotificationsPlugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: platformChannelSpecifics,
  );
}

@pragma('vm:entry-point')
void startClassGuard() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  SharedPreferences prefs = await SharedPreferences.getInstance();

  try {
    double currentVol = await VolumeController().getVolume();
    await prefs.setDouble('prevVolume', currentVol);

    await SoundMode.setSoundMode(RingerModeStatus.silent);
    await Future.delayed(const Duration(milliseconds: 500));
    VolumeController().setVolume(0.0);

    try {
      const platform = MethodChannel('com.classguard/applock');

      bool accStatus =
          await platform.invokeMethod('checkAccessibilityPermission') ?? false;
      bool usageStatus =
          await platform.invokeMethod('checkUsagePermission') ?? false;
      bool ovrStatus =
          await platform.invokeMethod('checkOverlayPermission') ?? false;
      bool batStatus =
          await platform.invokeMethod('checkBatteryOptimization') ?? false;
      bool dndStatus = await PermissionHandler.permissionsGranted ?? false;

      if (!accStatus ||
          !usageStatus ||
          !ovrStatus ||
          !batStatus ||
          !dndStatus) {
        await platform.invokeMethod('triggerEmergencyPopup');
      }
    } catch (e) {
      debugPrint("Permission check failed: $e");
    }

    String uid =
        FirebaseAuth.instance.currentUser?.uid ??
        prefs.getString('userUid') ??
        "";
    final snapshot = await FirebaseFirestore.instance
        .collection('schedules')
        .where('joinedStudents', arrayContains: uid)
        .where('isActive', isEqualTo: true)
        .get();

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

    String currentBlockedApps = "";
    int currentAllowanceTime = 2;
    String currentPin = "1234";

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['day'] == dayStr) {
        int start = timeToMinutes(data['startTime'] ?? "00:00");
        int end = timeToMinutes(data['endTime'] ?? "00:00");
        int current = now.hour * 60 + now.minute;

        if (current >= start - 2 && current < end) {
          if (data['role'] == 'Teacher' && data['userId'] == uid) {
            continue;
          }

          List<dynamic> apps = data['blockedApps'] ?? [];
          currentBlockedApps = apps.join(',');

          currentAllowanceTime = data['allowanceTime'] ?? 2;
          currentPin = data['securityPIN'] ?? "1234";

          Map<String, dynamic> vipAccess = data['vipAccess'] ?? {};
          var myVip = vipAccess[uid];
          if (myVip != null) {
            await prefs.setString('allowedApp', myVip['app']);
            await prefs.setInt('allowedUntil', myVip['until']);
          } else {
            await prefs.setString('allowedApp', "");
            await prefs.setInt('allowedUntil', 0);
          }
          break;
        }
      }
    }

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
void stopClassGuard() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();

  try {
    double prevVol = prefs.getDouble('prevVolume') ?? 0.5;
    await SoundMode.setSoundMode(RingerModeStatus.normal);
    await Future.delayed(const Duration(milliseconds: 500));
    VolumeController().setVolume(prevVol);

    await prefs.setBool('isAppLockActive', false);

    Fluttertoast.showToast(
      msg: "Class ended: Device is back to normal",
      toastLength: Toast.LENGTH_LONG,
      backgroundColor: Colors.black,
      textColor: Colors.white,
    );

    await showClassGuardNotification(
      id: 1,
      title: 'Class Session Ended',
      body: 'Great job focusing! Devices unmuted.',
    );
  } catch (e) {
    debugPrint("Failed to stop ClassGuard: $e");
  }
}
