import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// REFACTORED IMPORTS
import 'package:classguard/models/exam.dart';
import 'package:classguard/features/exam/services/exam_service.dart';
import 'package:classguard/features/exam/screens/exam_result.dart';
import 'package:classguard/shared/widgets/primary_button.dart';
import 'package:classguard/shared/dialogs/confirm_dialog.dart';

class ExamViewScreen extends StatefulWidget {
  final String examId;
  final String submissionId;
  final Exam exam;

  const ExamViewScreen({
    super.key,
    required this.examId,
    required this.submissionId,
    required this.exam,
  });

  @override
  State<ExamViewScreen> createState() => _ExamViewScreenState();
}

class _ExamViewScreenState extends State<ExamViewScreen> {
  final ExamService _examService = ExamService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Question> _questions = [];
  final Map<String, dynamic> _studentAnswers = {};
  String _examType = 'multiple_choice';

  bool _isLoading = true;
  bool _isSubmitting = false;

  late int _timeLeftInSeconds;
  Timer? _timer;
  StreamSubscription<DocumentSnapshot>? _examStatusSubscription;

  @override
  void initState() {
    super.initState();
    _calculateRealTimeLeft();
    _lockDeviceAndMute();
    _fetchQuestions();
    _startTimer();
    _listenToExamStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _examStatusSubscription?.cancel();
    _unlockDeviceAndRestoreSound();
    super.dispose();
  }

  void _listenToExamStatus() {
    _examStatusSubscription = _firestore.collection('exams').doc(widget.examId).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        bool isActive = snapshot.data()?['isActive'] ?? false;
        if (!isActive && !_isSubmitting) {
          _autoSubmitExam();
        }
      }
    });
  }

  Future<void> _lockDeviceAndMute() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await Future.delayed(const Duration(seconds: 5));
      await prefs.setBool('isExamLockActive', true);
    } catch (e) {
      debugPrint("Failed to lock device: $e");
    }
  }

  Future<void> _unlockDeviceAndRestoreSound() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isExamLockActive', false);
    } catch (e) {
      debugPrint("Failed to unlock device: $e");
    }
  }

  void _calculateRealTimeLeft() {
    DateTime endTime = widget.exam.startTime.add(Duration(minutes: widget.exam.durationMinutes));
    int remaining = endTime.difference(DateTime.now()).inSeconds;
    _timeLeftInSeconds = remaining > 0 ? remaining : 0;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeftInSeconds > 0) {
        setState(() => _timeLeftInSeconds--);
      } else {
        _timer?.cancel();
        _autoSubmitExam();
      }
    });
  }

  String _getFormattedTime() {
    int minutes = _timeLeftInSeconds ~/ 60;
    int seconds = _timeLeftInSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchQuestions() async {
    try {
      DocumentSnapshot examDoc = await _firestore.collection('exams').doc(widget.examId).get();
      if (examDoc.exists) {
        _examType = (examDoc.data() as Map<String, dynamic>)['examType'] ?? 'multiple_choice';
      }

      final snapshot = await _firestore.collection('exams').doc(widget.examId).collection('questions').orderBy('order').get();

      setState(() {
        _questions = snapshot.docs.map((doc) {
          final data = doc.data();
          return Question(
            id: doc.id,
            questionText: data['questionText'] ?? '',
            options: List<String>.from(data['options'] ?? []),
            correctIndex: data['correctIndex'] ?? 0,
            order: data['order'] ?? 0,
          );
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading questions: $e'), backgroundColor: Colors.red));
    }
  }

  void _selectMultipleChoiceAnswer(String questionId, int optionIndex) {
    setState(() => _studentAnswers[questionId] = optionIndex);
  }

  Future<void> _autoSubmitExam() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      await _examService.submitExamAndGrade(
          widget.examId,
          widget.submissionId,
          _studentAnswers,
          _examType
      );

      final String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
      if (uid.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('joined_exams')
            .doc(widget.examId)
            .set({
          'examId': widget.examId,
          'title': widget.exam.title,
          'lecturer': widget.exam.creatorName,
          'startTime': widget.exam.startTime,
          'durationMinutes': widget.exam.durationMinutes,
          'examType': _examType,
          'submittedAt': FieldValue.serverTimestamp(),
        });
      }

      await _unlockDeviceAndRestoreSound();
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ExamResultScreen()));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission failed: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF8F9FA), foregroundColor: Colors.black, elevation: 0, automaticallyImplyLeading: false, title: Text(widget.exam.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), centerTitle: true,
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black.withValues(alpha: 0.05))), alignment: Alignment.center,
              child: Row(children: [const Icon(Icons.timer_outlined, size: 16, color: Colors.black87), const SizedBox(width: 6), Text(_getFormattedTime(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13))]),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.black))
            : Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: _questions.length,
                itemBuilder: (context, index) => _buildQuestionCard(_questions[index], index + 1),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.05)))),
              // REUSABLE WIDGET: PrimaryButton & ConfirmDialog
              child: PrimaryButton(
                  text: 'Finish & Submit',
                  isLoading: _isSubmitting,
                  onPressed: () {
                    ConfirmDialog.show(
                      context: context,
                      title: 'Submit Exam?',
                      message: 'Are you sure you want to finish and submit your answers?',
                      confirmText: 'Submit',
                      onConfirm: _autoSubmitExam,
                    );
                  }
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Question question, int displayIndex) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '$displayIndex. ${question.questionText}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.5, color: Colors.black)
          ),
          const SizedBox(height: 20),

          if (_examType != 'essay')
            ...List.generate(question.options.length, (optIndex) {
              final isSelected = _studentAnswers[question.id] == optIndex;
              return GestureDetector(
                onTap: () => _selectMultipleChoiceAnswer(question.id, optIndex),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: isSelected ? Colors.black : Colors.white,
                      border: Border.all(
                          color: isSelected ? Colors.black : Colors.black.withValues(alpha: 0.1),
                          width: 1.5
                      ),
                      borderRadius: BorderRadius.circular(16)
                  ),
                  child: Row(
                    children: [
                      Container(
                          width: 28, height: 28, alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: isSelected ? Colors.white : const Color(0xFFF5F5F5),
                              shape: BoxShape.circle
                          ),
                          child: Text(
                              String.fromCharCode(65 + optIndex),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.black : Colors.black87
                              )
                          )
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Text(
                              question.options[optIndex],
                              style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 15
                              )
                          )
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}