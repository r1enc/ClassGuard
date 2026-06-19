import 'package:classguard/models/course.dart';
import 'package:classguard/core/services/firestore_service.dart';

// UI KIT IMPORTS
import 'package:classguard/shared/feedback/empty_state.dart';
import 'package:classguard/shared/dialogs/confirm_dialog.dart';
import 'package:classguard/shared/widgets/classroom_card.dart';
import 'package:classguard/shared/widgets/primary_button.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

// Provides the instructor with a comprehensive dashboard to monitor active sessions, manage student access, and review attendance records.
class TeacherDashboardScreen extends StatelessWidget {
  final Course course;
  const TeacherDashboardScreen({super.key, required this.course});

  // CORE LOGIC: Formats raw Android package names into user-friendly application titles for the VIP access interface.
  String _getCleanAppName(String packageName) {
    if (packageName == "all") return "All Applications";
    List<String> parts = packageName.split('.');
    parts.removeWhere(
          (part) => ['com', 'org', 'net', 'co', 'id', 'www', 'android', 'app'].contains(part.toLowerCase()),
    );
    if (parts.isEmpty) parts = [packageName.split('.').last];
    return parts.map((word) => word.isEmpty ? "" : word[0].toUpperCase() + word.substring(1).toLowerCase()).join(' ');
  }

  int _timeToMins(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length != 2) return 0;
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  // STATE MANAGEMENT: Controls the temporary bypass mechanism, allowing specific students to access restricted applications for a defined duration.
  void _showGrantAccessDialog(BuildContext context, String studentUid, String studentName, List<dynamic> blockedApps) {
    if (blockedApps.isEmpty) {
      Fluttertoast.showToast(msg: "No apps are blocked in this classroom.");
      return;
    }
    String selectedApp = "all";
    int selectedMins = 5;
    TextEditingController customMinController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Grant VIP Access', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Allow $studentName to access blocked app(s).', style: const TextStyle(fontSize: 14)),
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
                      items: [
                        const DropdownMenuItem<String>(value: "all", child: Text("All Applications", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
                        ...blockedApps.map((app) => DropdownMenuItem<String>(value: app.toString(), child: Text(_getCleanAppName(app.toString())))),
                      ],
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
                    onTap: () {
                      setState(() {
                        selectedMins = min;
                        customMinController.clear();
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: (selectedMins == min && customMinController.text.isEmpty) ? Colors.black : Colors.white,
                        border: Border.all(color: (selectedMins == min && customMinController.text.isEmpty) ? Colors.black : Colors.black12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$min', style: TextStyle(color: (selectedMins == min && customMinController.text.isEmpty) ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Or Custom Minute:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 8),
                TextField(
                  controller: customMinController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: "Enter custom minutes...",
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.black12)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.black)),
                  ),
                  onChanged: (val) {
                    setState(() {
                      if (val.isNotEmpty) selectedMins = int.tryParse(val) ?? 5;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.black54))),
            ElevatedButton(
              onPressed: () async {
                int finalMins = selectedMins;
                if (customMinController.text.isNotEmpty) finalMins = int.tryParse(customMinController.text) ?? selectedMins;
                int unlockMillis = DateTime.now().millisecondsSinceEpoch + (finalMins * 60 * 1000);
                await FirestoreService().grantVipAccess(scheduleId: course.id, studentUid: studentUid, selectedApp: selectedApp, unlockMillis: unlockMillis);
                if (context.mounted) {
                  Navigator.pop(context);
                  Fluttertoast.showToast(msg: "Access granted for $finalMins minutes!");
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Grant Access', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showViolationLogs(BuildContext context, String studentName, String studentUid, Map<String, dynamic> violationLogs) {
    List<dynamic> logs = violationLogs[studentUid] ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Activity Logs: $studentName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: logs.isEmpty
                    ? const EmptyState(message: 'No violations recorded.')
                    : ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    var log = logs[logs.length - 1 - index];
                    DateTime date = DateTime.parse(log['timestamp']).toLocal();
                    String timeStr = "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
                    String app = log['app'] ?? 'Unknown App';
                    return ListTile(
                      leading: const Icon(Icons.block, color: Colors.red),
                      title: Text("Tried to open ${_getCleanAppName(app)}"),
                      subtitle: Text("At $timeStr"),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showStudentsList(BuildContext context, Map<String, dynamic> studentNames, Map<String, dynamic> joinTimes, Map<String, dynamic> studentIds, String startTime, List<dynamic> blockedApps, Map<String, dynamic> violationLogs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Students in Classroom', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: studentNames.isEmpty
                    ? const EmptyState(message: 'No students have joined yet.')
                    : ListView.builder(
                        itemCount: studentNames.length,
                        itemBuilder: (context, index) {
                          String studentUid = studentNames.keys.elementAt(index);
                          String studentName = studentNames[studentUid] ?? 'Student';
                          String joinTime = joinTimes[studentUid] ?? '';
                          String idStr = studentIds[studentUid] ?? '-';
                          int startMins = _timeToMins(startTime);
                          int lateMins = 0;
                          
                          // CORE LOGIC: Calculates attendance punctuality by comparing the student's join timestamp against the scheduled session start time.
                          if (joinTime.isNotEmpty) {
                            int jMins = _timeToMins(joinTime);
                            if (jMins > startMins) lateMins = jMins - startMins;
                          }

                    // CORE LOGIC: Calculate if the student joined late
                    if (joinTime.isNotEmpty) {
                      int jMins = _timeToMins(joinTime);
                      if (jMins > startMins) lateMins = jMins - startMins;
                    }

                    Widget subtitleWidget = lateMins > 0
                        ? Row(children: [
                      const Text('Joined successfully', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      const SizedBox(width: 8),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text('Late $lateMins mins', style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold))),
                    ])
                        : const Text('Joined successfully', style: TextStyle(fontSize: 12, color: Colors.black54));

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(backgroundColor: Color(0xFFF5F5F5), child: Icon(Icons.person_outline, color: Colors.black87)),
                      title: Text('$studentName ($idStr)', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: subtitleWidget,
                      trailing: IconButton(icon: const Icon(Icons.key, color: Colors.orange), onPressed: () => _showGrantAccessDialog(context, studentUid, studentName, blockedApps)),
                      onTap: () => _showViolationLogs(context, studentName, studentUid, violationLogs),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHistory(BuildContext context, List<dynamic> history, String startTime) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            return Container(
              padding: const EdgeInsets.all(24),
              height: 500,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Attendance History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: history.isEmpty
                        ? const EmptyState(message: 'No history available.')
                        : ListView.builder(
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        var session = history[history.length - 1 - index];
                        DateTime date = DateTime.parse(session['date']);
                        String formattedDate = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
                        Map<String, dynamic> students = session['students'] ?? {};
                        Map<String, dynamic> joinTimes = session['joinTimes'] ?? {};
                        Map<String, dynamic> sessionIds = session['studentIds'] ?? {};

                        return ExpansionTile(
                          title: Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${students.length} students joined'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () {
                                  ConfirmDialog.show(
                                    context: context,
                                    title: 'Delete History',
                                    message: 'Are you sure you want to delete this attendance record? This action cannot be undone.',
                                    confirmText: 'Delete',
                                    isDestructive: true,
                                    onConfirm: () {
                                      List updatedHistory = List.from(history);
                                      updatedHistory.removeAt(history.length - 1 - index);
                                      FirestoreService().updateAttendanceHistory(scheduleId: course.id, updatedHistory: updatedHistory);
                                      Navigator.pop(context);
                                      Fluttertoast.showToast(msg: "History record deleted.");
                                    },
                                  );
                                },
                              ),
                              const Icon(Icons.expand_more),
                            ],
                          ),
                          children: students.keys.map((uid) {
                            String name = students[uid] ?? 'Student';
                            String jTime = joinTimes[uid] ?? '';
                            String idStr = sessionIds[uid] ?? '-';
                            int startMins = _timeToMins(startTime);
                            int lateMins = 0;
                            if (jTime.isNotEmpty) {
                              int jMins = _timeToMins(jTime);
                              if (jMins > startMins) lateMins = jMins - startMins;
                            }
                            return ListTile(
                              title: Text('$name ($idStr)', style: const TextStyle(fontSize: 14)),
                              trailing: lateMins > 0 ? Text('Late $lateMins mins', style: const TextStyle(color: Colors.red, fontSize: 12)) : const Text('On time', style: TextStyle(color: Colors.green, fontSize: 12)),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('Classroom Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirestoreService().scheduleStream(course.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }

          var docData = snapshot.data?.data() as Map<String, dynamic>?;
          if (docData == null) {
            return const Center(child: Text('Classroom data not found.'));
          }

          // CORE LOGIC: Evaluates the current system time against the defined schedule parameters to determine if the session is actively running.
          bool isActive = docData['isActive'] ?? false;
          final now = DateTime.now();
          final days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
          bool isDayMatch = docData['day'] == days[now.weekday - 1];
          int currentMins = now.hour * 60 + now.minute;
          int startMins = _timeToMins(docData['startTime'] ?? "00:00");
          int endMins = _timeToMins(docData['endTime'] ?? "00:00");
          bool isTimeRunning = isDayMatch && (currentMins >= startMins && currentMins < endMins);
          bool isCurrentlyActive = isActive && isTimeRunning;

          Map<String, dynamic> studentNames = docData['studentNames'] ?? {};
          Map<String, dynamic> joinTimes = docData['joinTimes'] ?? {};
          Map<String, dynamic> studentIds = docData['studentIds'] ?? {};
          List<dynamic> blockedApps = docData['blockedApps'] ?? [];
          List<dynamic> history = docData['history'] ?? [];
          Map<String, dynamic> violationLogs = docData['violationLogs'] ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClassroomCard(
                  subject: docData['subject'] ?? '-',
                  lecturer: docData['lecturer'] ?? '-',
                  room: docData['room'] ?? '-',
                  roomCode: docData['roomCode'] ?? '-',
                  securityPIN: docData['securityPIN'] ?? '----',
                ),

                const SizedBox(height: 32),
                const Text('SESSION INFO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _showStudentsList(context, studentNames, joinTimes, studentIds, docData['startTime'] ?? "00:00", blockedApps, violationLogs),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withValues(alpha: 0.1))),
                    child: Row(
                      children: [
                        const Icon(Icons.groups_outlined, color: Colors.black87),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Students Joined', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('Tap to grant app access / view list', style: TextStyle(fontSize: 12, color: Colors.black54)),
                            ],
                          ),
                        ),
                        Row(children: [Text('${studentNames.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(width: 8), const Icon(Icons.chevron_right, color: Colors.black26)]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _showHistory(context, history, docData['startTime'] ?? "00:00"),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withValues(alpha: 0.1))),
                    child: Row(
                      children: [
                        const Icon(Icons.history, color: Colors.black87),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Attendance History', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('View previous sessions', style: TextStyle(fontSize: 12, color: Colors.black54)),
                            ],
                          ),
                        ),
                        Row(children: [Text('${history.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(width: 8), const Icon(Icons.chevron_right, color: Colors.black26)]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                PrimaryButton(
                  text: 'End Session',
                  onPressed: isCurrentlyActive
                      ? () {
                    ConfirmDialog.show(
                      context: context,
                      title: 'End Session?',
                      message: 'Are you sure you want to end this session? All student devices will be unlocked.',
                      confirmText: 'End Session',
                      isDestructive: true,
                      onConfirm: () {
                        String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
                        FirestoreService().endClassSession(scheduleId: course.id, uid: uid, studentNames: studentNames, studentIds: studentIds, joinTimes: joinTimes);
                        Fluttertoast.showToast(msg: "Class Session Ended. All student devices unlocked.");
                        Navigator.pop(context);
                      },
                    );
                  }
                      : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

                  onPressed: isCurrentlyActive 
                    ? () {
                        ConfirmDialog.show(
                          context: context,
                          title: 'End Session?',
                          message: 'Are you sure you want to end this session? All student devices will be unlocked.',
                          confirmText: 'End Session',
                          isDestructive: true,
                          onConfirm: () {
                            // Initiates the session termination sequence, updating the database to release active locks on student devices.
                            String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
                            FirestoreService().endClassSession(scheduleId: course.id, uid: uid, studentNames: studentNames, studentIds: studentIds, joinTimes: joinTimes);
                            Fluttertoast.showToast(msg: "Class Session Ended. All student devices unlocked.");
                            Navigator.pop(context);
                          },
                        );
                      }
                    : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
