import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/primary_button.dart';
import 'create_exam_questions.dart';

class CreateExamScreen extends StatefulWidget {
  const CreateExamScreen({super.key});

  @override
  State<CreateExamScreen> createState() => _CreateExamScreenState();
}

class _CreateExamScreenState extends State<CreateExamScreen> {
  final titleController = TextEditingController();
  final creatorController = TextEditingController();
  final durationController = TextEditingController();
  final startTimeController = TextEditingController();
  final endTimeController = TextEditingController();

  String _selectedExamType = 'multiple_choice';
  DateTime? _selectedDate;
  final bool _isLoading = false;

  @override
  void dispose() {
    titleController.dispose();
    creatorController.dispose();
    durationController.dispose();
    startTimeController.dispose();
    endTimeController.dispose();
    super.dispose();
  }

  void _goToAddQuestions() {
    // Validate that all required fields are filled before proceeding
    if (titleController.text.isEmpty ||
        creatorController.text.isEmpty ||
        durationController.text.isEmpty ||
        startTimeController.text.isEmpty ||
        endTimeController.text.isEmpty ||
        _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All fields are required.')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateExamQuestionsScreen(
          examTitle: titleController.text,
          creatorName: creatorController.text,
          duration: int.parse(durationController.text),
          date: _selectedDate!,
          startTime: startTimeController.text,
          endTime: endTimeController.text,
          // Temporarily left empty as a string to prevent legacy code from crashing
          securityPIN: "",
          examType: _selectedExamType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
        title: const Text('Create Exam Room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.textDark, size: 20),
                  SizedBox(width: 12),
                  Expanded(child: Text("You are creating an exam session. A code will be generated for participants.", style: TextStyle(color: AppTheme.textDark, fontSize: 12))),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text('Exam Type', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(AppTheme.inputRadius),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedExamType,
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: AppTheme.textDark),
                  items: const [
                    DropdownMenuItem(value: 'multiple_choice', child: Text("Multiple Choice")),
                    DropdownMenuItem(value: 'essay', child: Text("Essay")),
                  ],
                  onChanged: (val) => setState(() => _selectedExamType = val!),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                DateTime? picked = await showDatePicker(
                  context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100),
                  builder: (context, child) => Theme(data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: AppTheme.primaryColor)), child: child!),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              borderRadius: BorderRadius.circular(AppTheme.inputRadius),
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black.withValues(alpha: 0.2)), borderRadius: BorderRadius.circular(AppTheme.inputRadius)),
                child: Text(_selectedDate != null ? "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}" : "Select Exam Date", style: TextStyle(color: _selectedDate != null ? AppTheme.textDark : Colors.black.withValues(alpha: 0.3))),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Exam Title', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(controller: titleController, decoration: AppTheme.baseInputDecoration("e.g., Final Algorithm Exam")),
            const SizedBox(height: 20),

            const Text('Lecturer', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(controller: creatorController, decoration: AppTheme.baseInputDecoration("e.g., Mr. John Doe")),
            const SizedBox(height: 20),

            const Text('Duration (Minutes)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(controller: durationController, keyboardType: TextInputType.number, decoration: AppTheme.baseInputDecoration("e.g., 120")),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Start Time (24h)', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(controller: startTimeController, decoration: AppTheme.baseInputDecoration("e.g., 08:00")),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('End Time (24h)', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(controller: endTimeController, decoration: AppTheme.baseInputDecoration("e.g., 10:30")),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            PrimaryButton(text: 'Next: Add Questions', isLoading: _isLoading, onPressed: _goToAddQuestions),
          ],
        ),
      ),
    );
  }
}