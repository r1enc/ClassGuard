import 'package:classguard/models/course.dart';
import 'package:classguard/routes/app_routes.dart';
import 'package:classguard/screens/room/select_apps_screen.dart';
import 'package:classguard/services/firestore_service.dart';
import 'package:flutter/material.dart';

// ======================
// 6. ADD SCHEDULE SCREEN
// ======================
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
  final FirestoreService _firestoreService = FirestoreService();

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
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(
          widget.courseToEdit != null ? 'Edit Schedule' : 'Add Schedule',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Day', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: days
                  .map(
                    (day) => GestureDetector(
                      onTap: () => setState(() => selectedDay = day),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: selectedDay == day
                              ? Colors.black
                              : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black26),
                        ),
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              color: selectedDay == day
                                  ? Colors.white
                                  : Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            const Text('Course', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: subjectController,
              decoration: _inputStyle("e.g., Web Programming"),
            ),
            const SizedBox(height: 20),
            const Text(
              'Lecturer',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: lecturerController,
              decoration: _inputStyle("e.g., John Doe"),
            ),
            const SizedBox(height: 20),
            const Text('Room', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: roomController,
              decoration: _inputStyle("e.g., Computer Lab"),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Start Time (24h)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: startTimeController,
                        decoration: _inputStyle("e.g., 08:00"),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'End Time (24h)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: endTimeController,
                        decoration: _inputStyle("e.g., 10:30"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            const Text(
              'Security PIN',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: _inputStyle(
                "Create 4-digit unlock PIN (Max 1 Min Access)",
              ).copyWith(counterText: ""),
            ),
            const SizedBox(height: 24),

            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.1),
                  width: 1.0,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.block, color: Colors.black87),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'App Lock',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Block distracting apps during schedule',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isAppLockEnabled,
                        activeColor: Colors.white,
                        activeTrackColor: Colors.black,
                        onChanged: (val) =>
                            setState(() => isAppLockEnabled = val),
                      ),
                    ],
                  ),
                  if (isAppLockEnabled) ...[
                    const Divider(height: 32),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Blocked Apps List:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.apps, color: Colors.black54),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "${blockedPackages.length} Apps Selected",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              FocusScope.of(context).unfocus();
                              final result = await Navigator.push(
                                context,
                                createRoute(
                                  SelectAppsScreen(
                                    initialSelectedApps: blockedPackages,
                                  ),
                                ),
                              );
                              if (result != null) {
                                setState(() {
                                  blockedPackages = List<String>.from(result);
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text("SELECT"),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.1),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.volume_off, color: Colors.black87),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auto-Silent',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Mute phone ringtone during schedule',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isSilentModeEnabled,
                    activeColor: Colors.white,
                    activeTrackColor: Colors.black,
                    onChanged: (val) =>
                        setState(() => isSilentModeEnabled = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () async {
                  if (subjectController.text.isEmpty ||
                      startTimeController.text.isEmpty ||
                      endTimeController.text.isEmpty ||
                      pinController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Required fields are missing.'),
                      ),
                    );
                    return;
                  }

                  if (pinController.text.length < 4) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PIN must be 4 digits.')),
                    );
                    return;
                  }

                  String? collisionError = await _firestoreService
                      .checkAndHandleCollision(
                        selectedDay,
                        startTimeController.text,
                        endTimeController.text,
                        'Personal',
                        excludeId: widget.courseToEdit?.id,
                      );
                  if (collisionError != null) {
                    if (mounted)
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(collisionError)));
                    return;
                  }

                  try {
                    await _firestoreService.savePersonalSchedule(
                      scheduleId: widget.courseToEdit?.id,
                      subject: subjectController.text,
                      lecturer: lecturerController.text,
                      room: roomController.text,
                      day: selectedDay,
                      startTime: startTimeController.text,
                      endTime: endTimeController.text,
                      isAppLockEnabled: isAppLockEnabled,
                      isSilentModeEnabled: isSilentModeEnabled,
                      blockedApps: blockedPackages,
                      securityPin: pinController.text,
                    );

                    if (mounted) {
                      FocusScope.of(context).unfocus();
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error saving to Cloud: $e')),
                      );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  widget.courseToEdit != null
                      ? 'Update Schedule'
                      : 'Save Schedule',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputStyle(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.black.withValues(alpha: 0.3)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black, width: 1.5),
      ),
    );
  }
}
