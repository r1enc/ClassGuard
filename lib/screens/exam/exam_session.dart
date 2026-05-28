import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/primary_button.dart';
import '../../services/exam_service.dart';
import '../../models/exam.dart';
import 'exam_view.dart'; // Next screen for taking the exam

class ExamSessionScreen extends StatefulWidget {
  const ExamSessionScreen({super.key});

  @override
  State<ExamSessionScreen> createState() => _ExamSessionScreenState();
}

class _ExamSessionScreenState extends State<ExamSessionScreen> {
  final _examService = ExamService();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _joinExam() async {
    final examCode = _codeController.text.trim().toUpperCase();
    final studentName = _nameController.text.trim();

    if (examCode.isEmpty || studentName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Fetch the exam details first to validate time constraints
      final examQuery = await FirebaseFirestore.instance
          .collection('exams')
          .where('examCode', isEqualTo: examCode)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (examQuery.docs.isEmpty) {
        throw Exception('Exam room not found or has been closed by the host.');
      }

      final examDoc = examQuery.docs.first;
      final examData = Exam.fromJson(examDoc.data(), examDoc.id);
      final now = DateTime.now();

      // 2. Time Validation Logic
      if (now.isBefore(examData.startTime)) {
        final startHour = examData.startTime.hour.toString().padLeft(2, '0');
        final startMin = examData.startTime.minute.toString().padLeft(2, '0');
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.cardBackground,
              title: const Text('Too Early ', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Text('The exam hasn\'t started yet. Please return at $startHour:$startMin.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(color: AppTheme.primaryColor)),
                ),
              ],
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      if (now.isAfter(examData.endTime)) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.cardBackground,
              title: const Text('Session Ended', style: TextStyle(fontWeight: FontWeight.bold)),
              content: const Text('The exam session has ended.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(color: AppTheme.primaryColor)),
                ),
              ],
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // 3. If time is valid, proceed to join and generate submission document
      final joinResult = await _examService.joinExamSession(examCode, studentName);

      if (mounted) {
        setState(() => _isLoading = false);

        // Navigate to the live exam view room
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ExamViewScreen(
              examId: joinResult['examId']!,
              submissionId: joinResult['submissionId']!,
              exam: examData,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
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
          'Join Exam Room',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.iconBackground,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_turned_in_outlined,
                  size: 48,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 32),

            const Text(
              'Exam Code',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _codeController,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              decoration: AppTheme.baseInputDecoration('e.g., EXM-A8X9'),
            ),
            const SizedBox(height: 24),

            const Text(
              'Full Name',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: AppTheme.baseInputDecoration('Enter your full name'),
            ),
            const SizedBox(height: 48),

            PrimaryButton(
              text: 'Enter Exam Room',
              isLoading: _isLoading,
              onPressed: _joinExam,
            ),
          ],
        ),
      ),
    );
  }
}