import 'package:classguard/core/routes/app_routes.dart';
import 'package:classguard/features/classroom/screens/select_apps_screen.dart';
import 'package:classguard/core/services/firestore_service.dart';
import 'package:classguard/core/theme/app_theme.dart';

// UI KIT IMPORTS
import 'package:classguard/shared/feedback/info_banner.dart';
import 'package:classguard/shared/widgets/custom_time_picker.dart';
import 'package:classguard/shared/widgets/day_selector.dart';
import 'package:classguard/shared/widgets/primary_button.dart';
import 'package:classguard/shared/widgets/setting_card.dart';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  // STATE MANAGEMENT: Controllers for text inputs and state tracking
  final subjectController = TextEditingController();
  final lecturerController = TextEditingController();
  final roomController = TextEditingController();
  final pinController = TextEditingController();
  final startTimeController = TextEditingController();
  final endTimeController = TextEditingController();
  final allowanceController = TextEditingController(text: "2");
  final FirestoreService _firestoreService = FirestoreService();

  String selectedDay = "Mon";
  bool isAppLockEnabled = true;
  bool isSilentModeEnabled = true;
  bool isLoading = false;

  List<String> blockedPackages = [];

  @override
  void dispose() {
    subjectController.dispose();
    lecturerController.dispose();
    roomController.dispose();
    pinController.dispose();
    startTimeController.dispose();
    endTimeController.dispose();
    allowanceController.dispose();
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
        title: const Text(
          'Create Classroom',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const InfoBanner(
              message: "You are creating a classroom as a Teacher. A code will be generated for students.",
            ),
            const SizedBox(height: 24),

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
              decoration: AppTheme.baseInputDecoration("e.g., Mr. John Doe"),
            ),
            const SizedBox(height: 20),

            const Text('Room', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: roomController,
              decoration: AppTheme.baseInputDecoration("e.g., Computer Lab 1"),
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
                        readOnly: true,
                        onTap: () async {
                          String? selected = await CustomTimePicker.show(
                            context: context,
                            initialTime: startTimeController.text,
                          );
                          if (selected != null) {
                            setState(() => startTimeController.text = selected);
                          }
                        },
                        decoration: AppTheme.baseInputDecoration("Tap to select time"),
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
                        readOnly: true,
                        onTap: () async {
                          String? selected = await CustomTimePicker.show(
                            context: context,
                            initialTime: endTimeController.text,
                          );
                          if (selected != null) {
                            setState(() => endTimeController.text = selected);
                          }
                        },
                        decoration: AppTheme.baseInputDecoration("Tap to select time"),
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
              decoration: AppTheme.baseInputDecoration("Create 4-digit unlock PIN").copyWith(counterText: ""),
            ),
            const SizedBox(height: 24),

            const Text('App Allowance Time (Minutes)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: allowanceController,
              keyboardType: TextInputType.number,
              decoration: AppTheme.baseInputDecoration("e.g. 2 for emergency unlock"),
            ),
            const SizedBox(height: 24),

            SettingCard(
              icon: Icons.block,
              title: 'Enforce App Lock',
              subtitle: 'Lock students apps during this session',
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
              title: 'Force Auto-Silent',
              subtitle: 'Mute students phone ringtone',
              trailing: Switch(
                value: isSilentModeEnabled,
                activeColor: Colors.white,
                activeTrackColor: AppTheme.primaryColor,
                onChanged: (val) => setState(() => isSilentModeEnabled = val),
              ),
            ),
            const SizedBox(height: 48),

            // CORE LOGIC: Input validation and conflict checking before writing to Firestore
            PrimaryButton(
              text: 'Create Classroom',
              isLoading: isLoading,
              onPressed: () async {
                // MODIFIED: Strict validation for all required fields
                if (subjectController.text.trim().isEmpty ||
                    lecturerController.text.trim().isEmpty ||
                    roomController.text.trim().isEmpty ||
                    startTimeController.text.trim().isEmpty ||
                    endTimeController.text.trim().isEmpty ||
                    allowanceController.text.trim().isEmpty ||
                    pinController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All fields are required.')),
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

                String? collisionError = await _firestoreService
                    .checkAndHandleCollision(
                  selectedDay,
                  startTimeController.text,
                  endTimeController.text,
                  'Teacher',
                );
                if (collisionError != null) {
                  if (collisionError == "OVERRIDDEN") {
                    Fluttertoast.showToast(msg: "Notice: A conflicting personal schedule was auto-disabled.");
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(collisionError)));
                    }
                    setState(() => isLoading = false);
                    return;
                  }
                }

                try {
                  String generatedCode = await _firestoreService
                      .createClassroom(
                    subject: subjectController.text,
                    lecturer: lecturerController.text,
                    room: roomController.text,
                    day: selectedDay,
                    startTime: startTimeController.text,
                    endTime: endTimeController.text,
                    isAppLockEnabled: isAppLockEnabled,
                    isSilentModeEnabled: isSilentModeEnabled,
                    securityPin: pinController.text,
                    allowanceText: allowanceController.text,
                    blockedApps: blockedPackages,
                  );

                  if (context.mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Text(
                            'Classroom Created!',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Share this code with your students to join the class:', textAlign: TextAlign.center),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                                decoration: BoxDecoration(
                                  color: AppTheme.iconBackground,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.black12, width: 2),
                                ),
                                child: Text(
                                  generatedCode,
                                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            PrimaryButton(
                              text: 'Done',
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        );
                      },
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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

