import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:classguard/core/background/classguard_background.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Import main.dart to access wakeUpClassGuard function
import 'package:classguard/main.dart';

class AlarmService {
  AlarmService({required this.platform});

  final MethodChannel platform;
  final List<int> activeAlarmIds = [];

  // Rebuild all scheduled alarms whenever classroom schedules change in realtime.
  void recalculateAlarms(List<QueryDocumentSnapshot> docs) {
    for (var id in activeAlarmIds) {
      AndroidAlarmManager.cancel(id);
      platform.invokeMethod('cancelNativePopupAlarm', {'alarmId': id});
      // Also cancel the warmup alarm
      AndroidAlarmManager.cancel(id + 10000);
    }
    activeAlarmIds.clear();

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['isActive'] == true && data['isSilentModeEnabled'] == true) {
        String startTime = data['startTime'] ?? "00:00";
        String endTime = data['endTime'] ?? "00:00";

        int startId = doc.id.hashCode;
        int endId = doc.id.hashCode + 1;

        setAutomaticAlarm(
          startTime,
          startId,
          startClassGuard,
          "Focus Mode Active",
          "Class session has started. Your phone is muted and distracting apps are locked.",
        );
        setAutomaticAlarm(
          endTime,
          endId,
          stopClassGuard,
          "Focus Mode Ended",
          "Great job! Class session has ended. Your phone is back to normal.",
        );

        activeAlarmIds.addAll([startId, endId]);
      }
    }
  }

  // Schedule both Android alarms and native popup notifications.
  void setAutomaticAlarm(
      String timeStr,
      int alarmId,
      Function callback,
      String title,
      String message,
      ) async {
    final now = DateTime.now();
    final parts = timeStr.split(':');
    if (parts.length != 2) return;
    
    var scheduleTime = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );

    // CORE LOGIC UPDATE: Prevent pushing immediately upcoming alarms to tomorrow.
    // Gives a 5-minute grace period so the warmup system can still trigger 
    // when creating schedules near the exact start time.
    if (scheduleTime.isBefore(now) && now.difference(scheduleTime).inMinutes > 5) {
      scheduleTime = scheduleTime.add(const Duration(days: 1));
    }

    // WARMUP ALARM LOGIC (5 MINUTES BEFORE)
    DateTime warmupTime = scheduleTime.subtract(const Duration(minutes: 5));
    if (warmupTime.isAfter(now)) {
      await AndroidAlarmManager.oneShot(
        warmupTime.difference(now),
        alarmId + 10000, // Unique ID for warmup
        wakeUpClassGuard,
        exact: true,
        wakeup: true,
      );
    }

    // MAIN ALARM
    if (scheduleTime.isAfter(now)) {
      await AndroidAlarmManager.oneShot(
        scheduleTime.difference(now),
        alarmId,
        callback,
        exact: true,
        wakeup: true,
      );
    }

    try {
      await platform.invokeMethod('setNativePopupAlarm', {
        'alarmId': alarmId,
        'timeInMillis': scheduleTime.millisecondsSinceEpoch,
        'title': title,
        'message': message,
      });
    } catch (e) {
      debugPrint("Failed to set native alarm: $e");
    }
  }
}