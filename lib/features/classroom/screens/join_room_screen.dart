import 'package:classguard/services/firestore_service.dart';
import 'package:classguard/theme/app_theme.dart';
import 'package:classguard/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class JoinRoomScreen extends StatefulWidget {
  final String userName;
  const JoinRoomScreen({super.key, required this.userName});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final codeController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  bool isLoading = false;

  @override
  void dispose() {
    codeController.dispose();
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
          'Join Classroom',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter Classroom Code',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask your teacher for the code, then enter it here to join the session.',
              style: TextStyle(color: AppTheme.textLight),
            ),
            const SizedBox(height: 32),

            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: AppTheme.baseInputDecoration("e.g. CG-8921"),
            ),
            
            const Spacer(),

            PrimaryButton(
              text: 'Join Classroom',
              isLoading: isLoading,
              onPressed: () async {
                if (codeController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid code.')),
                  );
                  return;
                }
                setState(() => isLoading = true);

                try {
                  final querySnapshot = await _firestoreService
                      .findClassroomByCode(codeController.text);
                  if (querySnapshot.docs.isEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Classroom not found. Please check the code and try again.',
                          ),
                        ),
                      );
                    }
                    setState(() => isLoading = false);
                    return;
                  }

                  final roomDoc = querySnapshot.docs.first;
                  final roomData = roomDoc.data();
                  String roomDay = roomData['day'] ?? 'Mon';
                  String roomStart = roomData['startTime'] ?? '00:00';
                  String roomEnd = roomData['endTime'] ?? '00:00';
                  // Prevent joining classrooms that overlap with existing active schedules.
                  String? collisionError = await _firestoreService
                      .checkAndHandleCollision(
                        roomDay,
                        roomStart,
                        roomEnd,
                        'Student',
                      );
                  if (collisionError != null) {
                    if (collisionError == "OVERRIDDEN") {
                      Fluttertoast.showToast(
                        msg: "Notice: A conflicting personal schedule was auto-disabled.",
                      );
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(collisionError)),
                        );
                      }
                      setState(() => isLoading = false);
                      return;
                    }
                  }

                  await _firestoreService.joinClassroom(
                    roomId: roomDoc.id,
                    userName: widget.userName,
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Successfully joined the classroom!')),
                    );
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Connection error: $e')),
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