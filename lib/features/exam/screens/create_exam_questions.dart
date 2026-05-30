import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:firebase_auth/firebase_auth.dart';

// REFACTORED IMPORTS
import 'package:classguard/core/theme/app_theme.dart';
import 'package:classguard/models/exam.dart';
import 'package:classguard/features/exam/services/exam_service.dart';
import 'package:classguard/shared/widgets/primary_button.dart';

class CreateExamQuestionsScreen extends StatefulWidget {
  final String examTitle;
  final String creatorName;
  final int duration;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String securityPIN;
  final String examType;

  const CreateExamQuestionsScreen({
    super.key,
    required this.examTitle,
    required this.creatorName,
    required this.duration,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.securityPIN,
    required this.examType,
  });

  @override
  State<CreateExamQuestionsScreen> createState() => _CreateExamQuestionsScreenState();
}

class _CreateExamQuestionsScreenState extends State<CreateExamQuestionsScreen> {
  final ExamService _examService = ExamService();
  final List<Question> _questions = [];
  bool _isLoading = false;

  String _generateExamCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    String randomPart = String.fromCharCodes(Iterable.generate(4, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    return 'EXM-$randomPart';
  }

  Future<void> _importFromCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);

      if (result != null && result.files.single.path != null) {
        setState(() => _isLoading = true);

        final file = File(result.files.single.path!);
        final csvString = await file.readAsString();

        var rowsAsListOfValues = const CsvToListConverter().convert(csvString);

        if (rowsAsListOfValues.isEmpty) throw Exception("The selected CSV file is empty.");

        int startIndex = 0;
        if (rowsAsListOfValues[0][0].toString().toLowerCase().contains('question') || rowsAsListOfValues[0][0].toString().toLowerCase().contains('soal')) {
          startIndex = 1;
        }

        int addedCount = 0;
        for (int i = startIndex; i < rowsAsListOfValues.length; i++) {
          var row = rowsAsListOfValues[i];
          if (widget.examType == 'essay') {
            if (row.isNotEmpty) {
              _questions.add(Question(id: '', questionText: row[0].toString().trim(), options: [], correctIndex: 0, order: _questions.length + 1));
              addedCount++;
            }
          } else {
            if (row.length >= 6) {
              _questions.add(Question(id: '', questionText: row[0].toString().trim(), options: [row[1].toString().trim(), row[2].toString().trim(), row[3].toString().trim(), row[4].toString().trim()], correctIndex: int.tryParse(row[5].toString()) ?? 0, order: _questions.length + 1));
              addedCount++;
            }
          }
        }

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully imported $addedCount questions from CSV.'), backgroundColor: Colors.black));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to import CSV: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAndPublishExam() async {
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one question.')));
      return;
    }
    setState(() => _isLoading = true);

    try {
      String generatedCode = _generateExamCode();
      String hostId = FirebaseAuth.instance.currentUser?.uid ?? "";
      final startParts = widget.startTime.split(':');
      final endParts = widget.endTime.split(':');

      DateTime finalStartTime = DateTime(widget.date.year, widget.date.month, widget.date.day, int.parse(startParts[0]), int.parse(startParts[1]));
      DateTime finalEndTime = DateTime(widget.date.year, widget.date.month, widget.date.day, int.parse(endParts[0]), int.parse(endParts[1]));

      Exam newExam = Exam(id: '', examCode: generatedCode, title: widget.examTitle, creatorName: widget.creatorName, date: widget.date, startTime: finalStartTime, endTime: finalEndTime, durationMinutes: widget.duration, securityPIN: widget.securityPIN, isActive: true, hostId: hostId);

      await _examService.createExamSession(newExam, _questions, widget.examType);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('host_exam_$generatedCode', hostId);

      if (mounted) {
        setState(() => _isLoading = false);
        _showPublishSuccessDialog(generatedCode);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error publishing exam: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showPublishSuccessDialog(String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Exam Published!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 12),
              const Text('Share this code with your students to\njoin the exam session.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 14, height: 1.4)),
              const SizedBox(height: 24),
              Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 24), decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(16)), child: Text(code, textAlign: TextAlign.center, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4, color: Colors.black))),
              const SizedBox(height: 24),
              // REUSABLE WIDGET: PrimaryButton
              PrimaryButton(text: 'Done', onPressed: () { Navigator.pop(context); Navigator.pop(context); Navigator.pop(context); }),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddQuestionDialog() {
    final qController = TextEditingController();
    final opt1Controller = TextEditingController();
    final opt2Controller = TextEditingController();
    final opt3Controller = TextEditingController();
    final opt4Controller = TextEditingController();
    int selectedCorrectIndex = 0;
    bool isEssay = widget.examType == 'essay';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Add New Question', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                      const SizedBox(height: 16),
                      TextField(controller: qController, maxLines: 3, style: const TextStyle(color: Colors.black), decoration: InputDecoration(hintText: "Enter question text here...", hintStyle: const TextStyle(color: Colors.black38), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)), borderRadius: BorderRadius.circular(12)), focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.black), borderRadius: BorderRadius.circular(12)))),

                      if (!isEssay) ...[
                        const SizedBox(height: 20),
                        const Text('Options:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                        const SizedBox(height: 12),
                        _buildOptionInputField("A", opt1Controller),
                        const SizedBox(height: 10),
                        _buildOptionInputField("B", opt2Controller),
                        const SizedBox(height: 10),
                        _buildOptionInputField("C", opt3Controller),
                        const SizedBox(height: 10),
                        _buildOptionInputField("D", opt4Controller),
                        const SizedBox(height: 20),
                        const Text('Correct Answer:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black.withValues(alpha: 0.2)), borderRadius: BorderRadius.circular(12)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: selectedCorrectIndex, isExpanded: true, dropdownColor: Colors.white, style: const TextStyle(color: Colors.black),
                              items: const [DropdownMenuItem(value: 0, child: Text("Option A")), DropdownMenuItem(value: 1, child: Text("Option B")), DropdownMenuItem(value: 2, child: Text("Option C")), DropdownMenuItem(value: 3, child: Text("Option D"))],
                              onChanged: (val) => setModalState(() => selectedCorrectIndex = val!),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),
                      // REUSABLE WIDGET: PrimaryButton
                      PrimaryButton(
                        text: 'Save Question',
                        onPressed: () {
                          if (qController.text.isEmpty || (!isEssay && (opt1Controller.text.isEmpty || opt2Controller.text.isEmpty))) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields.')));
                            return;
                          }
                          setState(() {
                            _questions.add(Question(
                              id: '', questionText: qController.text,
                              options: isEssay ? [] : [opt1Controller.text, opt2Controller.text, opt3Controller.text, opt4Controller.text],
                              correctIndex: isEssay ? 0 : selectedCorrectIndex,
                              order: _questions.length + 1,
                            ));
                          });
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            }
        );
      },
    );
  }

  Widget _buildOptionInputField(String prefixLabel, TextEditingController controller) {
    return Row(
      children: [
        Container(width: 40, height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFF5F5F5), border: Border.all(color: Colors.black.withValues(alpha: 0.15)), borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12))), child: Text(prefixLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
        Expanded(child: TextField(controller: controller, style: const TextStyle(color: Colors.black), decoration: InputDecoration(hintText: "Option content", hintStyle: const TextStyle(color: Colors.black38), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.15)), borderRadius: const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12))), focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.black), borderRadius: const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)))))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0, title: const Text('Add Questions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: _questions.isEmpty
                ? const Center(child: Text('No questions added yet.', style: TextStyle(color: Colors.black38, fontSize: 16)))
                : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                final q = _questions[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black.withValues(alpha: 0.1)), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text("${index + 1}. ${q.questionText}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.4, color: Colors.black))),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22), onPressed: () => setState(() => _questions.removeAt(index)))
                        ],
                      ),
                      if (widget.examType != 'essay') ...[
                        const SizedBox(height: 16),
                        ...List.generate(q.options.length, (optIndex) {
                          bool isCorrect = optIndex == q.correctIndex;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: isCorrect ? const Color(0xFFF5F5F5) : Colors.white, border: Border.all(color: isCorrect ? Colors.black : Colors.black.withValues(alpha: 0.05)), borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              children: [
                                Icon(isCorrect ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: isCorrect ? Colors.black : Colors.black38),
                                const SizedBox(width: 10),
                                Expanded(child: Text("${String.fromCharCode(65 + optIndex)}. ${q.options[optIndex]}", style: TextStyle(color: isCorrect ? Colors.black : Colors.black87, fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal))),
                              ],
                            ),
                          );
                        }),
                      ]
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.05)))),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.file_upload_outlined), label: const Text('Import CSV', style: TextStyle(fontWeight: FontWeight.bold)), style: OutlinedButton.styleFrom(foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: Colors.black), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _isLoading ? null : _importFromCSV)),
                    const SizedBox(width: 12),
                    Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.add), label: const Text('Add Manual', style: TextStyle(fontWeight: FontWeight.bold)), style: OutlinedButton.styleFrom(foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: Colors.black), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _isLoading ? null : _showAddQuestionDialog)),
                  ],
                ),
                const SizedBox(height: 12),
                // REUSABLE WIDGET: PrimaryButton
                PrimaryButton(text: 'Save & Publish Exam', isLoading: _isLoading, onPressed: _saveAndPublishExam),
              ],
            ),
          ),
        ],
      ),
    );
  }
}