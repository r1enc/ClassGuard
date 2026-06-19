import 'dart:math';

import 'package:classguard/core/utils/time_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> schedulesStreamForCurrentUser() {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    return _firestore
        .collection('schedules')
        .where('joinedStudents', arrayContains: uid)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> scheduleStream(
      String? scheduleId,
      ) {
    return _firestore.collection('schedules').doc(scheduleId).snapshots();
  }

  // Prevent overlapping schedules and prioritize classroom sessions over personal schedules.
  Future<String?> checkAndHandleCollision(
      String newDay,
      String newStart,
      String newEnd,
      String newRole, {
        String? excludeId,
      }) async {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? "";

    final snapshot = await _firestore
        .collection('schedules')
        .where('joinedStudents', arrayContains: uid)
        .where('day', isEqualTo: newDay)
        .get();

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
        String existRole = data['role'] ?? 'Personal';
        if (existRole == 'Teacher' && data['userId'] != uid) {
          existRole = 'Student';
        }

        if (newRole == 'Teacher' || newRole == 'Student') {
          if (existRole == 'Personal') {
            await _firestore.collection('schedules').doc(doc.id).update({
              'isActive': false,
            });
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

  Future<void> updateScheduleSilentMode(String? scheduleId, bool value) {
    return _firestore.collection('schedules').doc(scheduleId).update({
      'isSilentModeEnabled': value,
    });
  }

  Future<void> updateScheduleAppLock(String? scheduleId, bool value) {
    return _firestore.collection('schedules').doc(scheduleId).update({
      'isAppLockEnabled': value,
    });
  }

  Future<void> updateScheduleActive(String? scheduleId, bool value) {
    return _firestore.collection('schedules').doc(scheduleId).update({
      'isActive': value,
    });
  }

  Future<void> deleteSchedule(String? scheduleId) {
    return _firestore.collection('schedules').doc(scheduleId).delete();
  }

  Future<void> leaveSchedule(String? scheduleId) async {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    await _firestore.collection('schedules').doc(scheduleId).update({
      'joinedStudents': FieldValue.arrayRemove([uid]),
      'studentNames.$uid': FieldValue.delete(),
      'joinTimes.$uid': FieldValue.delete(),
      'vipAccess.$uid': FieldValue.delete(),
    });
  }

  // Log unauthorized app access attempt by student during an active session
  Future<void> logViolation({
    required String scheduleId,
    required String packageName,
  }) async {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    String timestamp = DateTime.now().toIso8601String();
    await _firestore.collection('schedules').doc(scheduleId).update({
      'violationLogs.$uid': FieldValue.arrayUnion([
        {
          'app': packageName,
          'timestamp': timestamp,
        }
      ])
    });
  }

  Future<void> savePersonalSchedule({
    required String? scheduleId,
    required String subject,
    required String lecturer,
    required String room,
    required String day,
    required String startTime,
    required String endTime,
    required bool isAppLockEnabled,
    required bool isSilentModeEnabled,
    required List<String> blockedApps,
    required String securityPin,
  }) async {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? "";

    if (scheduleId != null) {
      await _firestore.collection('schedules').doc(scheduleId).update({
        'subject': subject,
        'lecturer': lecturer.isNotEmpty ? lecturer : '-',
        'room': room.isNotEmpty ? room : '-',
        'day': day,
        'startTime': startTime,
        'endTime': endTime,
        'isAppLockEnabled': isAppLockEnabled,
        'isSilentModeEnabled': isSilentModeEnabled,
        'blockedApps': blockedApps,
        'securityPIN': securityPin,
        'allowanceTime': 1,
      });
    } else {
      await _firestore.collection('schedules').add({
        'userId': uid,
        'createdBy': uid,
        'joinedStudents': [uid],
        'subject': subject,
        'lecturer': lecturer.isNotEmpty ? lecturer : '-',
        'room': room.isNotEmpty ? room : '-',
        'day': day,
        'startTime': startTime,
        'endTime': endTime,
        'isAppLockEnabled': isAppLockEnabled,
        'isSilentModeEnabled': isSilentModeEnabled,
        'isActive': true,
        'role': 'Personal',
        'blockedApps': blockedApps,
        'securityPIN': securityPin,
        'allowanceTime': 1,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Create synchronized classroom session with shared focus settings.
  Future<String> createClassroom({
    required String subject,
    required String lecturer,
    required String room,
    required String day,
    required String startTime,
    required String endTime,
    required bool isAppLockEnabled,
    required bool isSilentModeEnabled,
    required String securityPin,
    required String allowanceText,
    required List<String> blockedApps,
  }) async {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    String generatedCode = 'CG-${Random().nextInt(9000) + 1000}';

    await _firestore.collection('schedules').add({
      'userId': uid,
      'createdBy': uid,
      'joinedStudents': [uid],
      'studentNames': {},
      'studentIds': {},
      'vipAccess': {},
      'violationLogs': {},
      'history': [],
      'subject': subject,
      'lecturer': lecturer.isNotEmpty ? lecturer : 'Teacher',
      'room': room.isNotEmpty ? room : '-',
      'day': day,
      'startTime': startTime,
      'endTime': endTime,
      'isAppLockEnabled': isAppLockEnabled,
      'isSilentModeEnabled': isSilentModeEnabled,
      'isActive': true,
      'role': 'Teacher',
      'roomCode': generatedCode,
      'securityPIN': securityPin,
      'allowanceTime': int.tryParse(allowanceText) ?? 0,
      'blockedApps': blockedApps,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return generatedCode;
  }

  Future<QuerySnapshot<Map<String, dynamic>>> findClassroomByCode(String code) {
    return _firestore
        .collection('schedules')
        .where('roomCode', isEqualTo: code.trim())
        .where('role', isEqualTo: 'Teacher')
        .get();
  }

  Future<void> joinClassroom({
    required String roomId,
    required String userName,
  }) async {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    String joinTime =
        "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String studentId = prefs.getString('profileId') ?? "No ID";

    await _firestore.collection('schedules').doc(roomId).update({
      'joinedStudents': FieldValue.arrayUnion([uid]),
      'studentNames.$uid': userName,
      'studentIds.$uid': studentId,
      'joinTimes.$uid': joinTime,
    });
  }

  // Temporarily allow blocked app access for selected classroom members.
  Future<void> grantVipAccess({
    required String? scheduleId,
    required String studentUid,
    required String selectedApp,
    required int unlockMillis,
  }) {
    return _firestore.collection('schedules').doc(scheduleId).update({
      'vipAccess.$studentUid': {'app': selectedApp, 'until': unlockMillis},
    });
  }

  Future<void> updateAttendanceHistory({
    required String? scheduleId,
    required List updatedHistory,
  }) {
    return _firestore.collection('schedules').doc(scheduleId).update({
      'history': updatedHistory,
    });
  }

  // Save attendance history before resetting classroom session state.
  Future<void> endClassSession({
    required String? scheduleId,
    required String uid,
    required Map<String, dynamic> studentNames,
    required Map<String, dynamic> studentIds,
    required Map<String, dynamic> joinTimes,
  }) async {
    if (studentNames.isNotEmpty) {
      String formattedDate = DateTime.now().toIso8601String();
      await _firestore.collection('schedules').doc(scheduleId).update({
        'history': FieldValue.arrayUnion([
          {
            'date': formattedDate,
            'students': studentNames,
            'studentIds': studentIds,
            'joinTimes': joinTimes,
          },
        ]),
      });
    }

    await _firestore.collection('schedules').doc(scheduleId).update({
      'isActive': false,
      'joinedStudents': [uid],
      'studentNames': {},
      'studentIds': {},
      'joinTimes': {},
      'vipAccess': {},
      'violationLogs': {},
    });
  }

  Future<List<Map<String, dynamic>>> fetchMasterApps() async {
    final snapshot = await _firestore.collection('Master Apps').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        "name": data['name'] ?? 'Unknown App',
        "package": data['package'] ?? '',
        "iconUrl": data['iconUrl'] ?? '',
      };
    }).toList();
  }
}