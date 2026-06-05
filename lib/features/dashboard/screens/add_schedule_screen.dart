import 'package:classguard/models/course.dart';
import 'package:classguard/core/routes/app_routes.dart';
import 'package:classguard/features/classroom/screens/select_apps_screen.dart';
import 'package:classguard/core/services/firestore_service.dart';
import 'package:classguard/core/theme/app_theme.dart';

// UI KIT IMPORTS
import 'package:classguard/shared/widgets/day_selector.dart';
import 'package:classguard/shared/widgets/primary_button.dart';
import 'package:classguard/shared/widgets/setting_card.dart';

import 'package:flutter/material.dart';

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
  bool isLoading = false; 
  List<String> blockedPackages = [];

  @override
  void initState() {
    super.initState();
    // STATE MANAGEMENT: Pre-fill fields if we are editing an existing schedule
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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
        title: Text(
          widget.courseToEdit != null ? 'Edit Schedule' : 'Add Schedule',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Day', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DaySelector(
              selectedDay: selectedDay,
              onDaySelected: (day) => setState(() => selectedDay = day),
            ),
            const SizedBox(height: 24),

            const Text('Course', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: subjectController,
              decoration: AppTheme.baseInputDecoration("e.g., Web Programming"),
            ),
            const SizedBox(height: 20),

            const Text('Lecturer', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: lecturerController,
              decoration: AppTheme.baseInputDecoration("e.g., John Doe"),
            ),
            const SizedBox(height: 20),

            const Text('Room', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: roomController,
              decoration: AppTheme.baseInputDecoration("e.g., Computer Lab"),
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
                        decoration: AppTheme.baseInputDecoration("e.g., 08:00"),
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
                        decoration: AppTheme.baseInputDecoration("e.g., 10:30"),
                      ),
                    ],
                  ),
                ),
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
              decoration: AppTheme.baseInputDecoration(
                "Create 4-digit unlock PIN",
              ).copyWith(counterText: ""),
            ),
            const SizedBox(height: 24),

            // Controls the activation of the background application monitoring service.
            SettingCard(
              icon: Icons.block,
              title: 'App Lock',
              subtitle: 'Block distracting apps during schedule',
              trailing: Switch(
                value: isAppLockEnabled,
                activeColor: Colors.white,
                activeTrackColor: AppTheme.primaryColor,
                onChanged: (val) => setState(() => isAppLockEnabled = val),
              ),
            ),
            
            if (isAppLockEnabled) ...[
              const SizedBox(height: 12),
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
                    const Icon(Icons.apps, color: AppTheme.textLight),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "${blockedPackages.length} Apps Selected",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Launches the package selection interface to define restricted applications.
                    ElevatedButton(
                      onPressed: () async {
                        FocusScope.of(context).unfocus();
                        final result = await Navigator.push(
                          context,
                          createRoute(SelectAppsScreen(initialSelectedApps: blockedPackages)),
                        );
                        if (result != null) {
                          setState(() {
                            blockedPackages = List<String>.from(result);
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
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
            const SizedBox(height: 16),

            SettingCard(
              icon: Icons.volume_off,
              title: 'Auto-Silent',
              subtitle: 'Mute phone ringtone during schedule',
              trailing: Switch(
                value: isSilentModeEnabled,
                activeColor: Colors.white,
                activeTrackColor: AppTheme.primaryColor,
                onChanged: (val) => setState(() => isSilentModeEnabled = val),
              ),
            ),
            const SizedBox(height: 48),

            // CORE LOGIC: Verify inputs and save the personal routine to Firestore
            PrimaryButton(
              text: widget.courseToEdit != null ? 'Update Schedule' : 'Save Schedule',
              isLoading: isLoading,
              onPressed: () async {
                if (subjectController.text.isEmpty ||
                    startTimeController.text.isEmpty ||
                    endTimeController.text.isEmpty ||
                    pinController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Required fields are missing.')),
                  );
                  return;
                }

                if (pinController.text.length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN must be 4 digits.')),
                  );
                  return;
                }

                setState(() => isLoading = true);
                
                // Validates the provided time slots against existing schedules to prevent overlaps.
                String? collisionError = await _firestoreService
                    .checkAndHandleCollision(
                  selectedDay,
                  startTimeController.text,
                  endTimeController.text,
                  'Personal',
                  excludeId: widget.courseToEdit?.id,
                );
                if (collisionError != null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(collisionError)),
                    );
                  }
                  setState(() => isLoading = false);
                  return;
                }

                try {
                  // Persists the newly created or modified schedule configuration to Cloud Firestore.
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
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error saving to Cloud: $e')),
                    );
                  }
                } finally {
                  if (mounted) setState(() => isLoading = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
