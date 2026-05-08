import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:classguard/background/classguard_background.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AlarmService {
  AlarmService({required this.platform});

  final MethodChannel platform;
  final List<int> activeAlarmIds = [];

  void recalculateAlarms(List<QueryDocumentSnapshot> docs) {
    for (var id in activeAlarmIds) {
      AndroidAlarmManager.cancel(id);
      platform.invokeMethod('cancelNativePopupAlarm', {'alarmId': id});
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
    if (scheduleTime.isBefore(now)) {
      scheduleTime = scheduleTime.add(const Duration(days: 1));
    }

    await AndroidAlarmManager.oneShot(
      scheduleTime.difference(now),
      alarmId,
      callback,
      exact: true,
      wakeup: true,
    );

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
