import 'package:classguard/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

// =====================
// 6.2 JOIN ROOM SCREEN
// =====================
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Join Classroom',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
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
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: "e.g. CG-8921",
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.black.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.black.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black, width: 1.5),
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (codeController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid code.'),
                            ),
                          );
                          return;
                        }
                        setState(() => isLoading = true);

                        try {
                          final querySnapshot = await _firestoreService
                              .findClassroomByCode(codeController.text);
                          if (querySnapshot.docs.isEmpty) {
                            if (context.mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Classroom not found. Please check the code and try again.',
                                  ),
                                ),
                              );
                            setState(() => isLoading = false);
                            return;
                          }

                          final roomDoc = querySnapshot.docs.first;
                          final roomData = roomDoc.data();
                          String roomDay = roomData['day'] ?? 'Mon';
                          String roomStart = roomData['startTime'] ?? '00:00';
                          String roomEnd = roomData['endTime'] ?? '00:00';

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
                                msg:
                                    "Notice: A conflicting personal schedule was auto-disabled.",
                              );
                            } else {
                              if (context.mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(collisionError)),
                                );
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
                              const SnackBar(
                                content: Text(
                                  'Successfully joined the classroom!',
                                ),
                              ),
                            );
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          if (context.mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Connection error: $e')),
                            );
                        } finally {
                          if (mounted) setState(() => isLoading = false);
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
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Join Classroom',
                        style: TextStyle(
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
}
