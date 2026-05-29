import 'package:classguard/core/routes/app_routes.dart';
import 'package:classguard/features/classroom/screens/select_apps_screen.dart';
import 'package:classguard/core/services/firestore_service.dart';
import 'package:classguard/core/theme/app_theme.dart';
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
  final List<String> days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.black87, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "You are creating a classroom as a Teacher. A code will be generated for students.",
                      style: TextStyle(color: Colors.black87, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
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
                          ? AppTheme.primaryColor
                          : AppTheme.backgroundColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black26),
                    ),
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          color: selectedDay == day
                              ? Colors.white
                              : AppTheme.textDark,
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

            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                border: Border.all(color: AppTheme.borderColor, width: 1.0),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.iconBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.block, color: AppTheme.textDark),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enforce App Lock',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'Lock students apps during this session',
                              style: TextStyle(fontSize: 12, color: AppTheme.textLight),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isAppLockEnabled,
                        activeColor: Colors.white,
                        activeTrackColor: AppTheme.primaryColor,
                        onChanged: (val) => setState(() => isAppLockEnabled = val),
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
                ],
              ),
            ),
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

            PrimaryButton(
              text: 'Create Classroom',
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
                // Prevent overlapping schedules before creating synchronized classroom sessions.
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
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
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