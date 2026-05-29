import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
// IMPORT FILE PICKER TO HANDLE SCOPED STORAGE SAFELY
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../../models/exam.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/feedback/empty_state.dart';

class ExamDashboardScreen extends StatefulWidget {
  final Exam exam;
  const ExamDashboardScreen({super.key, required this.exam});

  @override
  State<ExamDashboardScreen> createState() => _ExamDashboardScreenState();
}

class _ExamDashboardScreenState extends State<ExamDashboardScreen> {
  bool _isLoading = false;
  String _examType = 'multiple_choice';

  @override
  void initState() {
    super.initState();
    _fetchExamType();
  }

  Future<void> _fetchExamType() async {
    try {
      DocumentSnapshot examDoc = await FirebaseFirestore.instance.collection('exams').doc(widget.exam.id).get();
      if (examDoc.exists && mounted) {
        setState(() {
          _examType = (examDoc.data() as Map<String, dynamic>)['examType'] ?? 'multiple_choice';
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch examType: $e");
    }
  }

  Future<void> _endExamSession() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('exams').doc(widget.exam.id).update({'isActive': false});
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exam session ended.'), backgroundColor: Colors.black));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // EXPORT FEATURE: Generate CSV and use FilePicker to save safely on modern Android
  Future<void> _exportGradingToCSV(List<QueryDocumentSnapshot> studentDocs) async {
    List<List<dynamic>> rows = [];
    rows.add(["Student Name", "Score", "Status", "Joined At", "Submitted At"]);

    for (var doc in studentDocs) {
      var data = doc.data() as Map<String, dynamic>;
      rows.add([
        data['studentName'] ?? 'Unknown',
        data['score'] ?? 0.0,
        data['status'] ?? 'Unknown',
        data['joinedAt'] != null ? (data['joinedAt'] as Timestamp).toDate().toString() : '-',
        data['submittedAt'] != null ? (data['submittedAt'] as Timestamp).toDate().toString() : '-',
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);

    try {
      // Convert string to bytes — required for Android & iOS file operations
      final Uint8List bytes = Uint8List.fromList(csvData.codeUnits);

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Exam Scores',
        fileName: 'Exam_Scores_${widget.exam.examCode}.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        // Required parameter for saving files on modern Android via FilePicker
        bytes: bytes,
      );

      if (outputFile == null) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Scores Exported Successfully!'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to export: $e'), backgroundColor: Colors.red)
        );
      }
    }
  }

  String _calculateLateness(dynamic joinedAtData) {
    if (joinedAtData == null) return 'On Time';
    if (joinedAtData is Timestamp) {
      DateTime joinedTime = joinedAtData.toDate();
      if (joinedTime.isAfter(widget.exam.startTime)) {
        int minutes = joinedTime.difference(widget.exam.startTime).inMinutes;
        return minutes > 0 ? 'Late ${minutes}m' : 'On Time';
      }
    }
    return 'On Time';
  }

  void _showStudentsBottomSheet(List<QueryDocumentSnapshot> studentDocs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, 32, 24, MediaQuery.of(context).padding.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Students Joined', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 24),
                studentDocs.isEmpty 
                    ? const EmptyState(message: 'No students joined yet.')
                    : ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: studentDocs.length,
                    itemBuilder: (context, index) {
                      final data = studentDocs[index].data() as Map<String, dynamic>;
                      final name = data['studentName'] ?? 'Unknown';
                      final lateness = _calculateLateness(data['joinedAt']);
                      bool isLate = lateness.contains('Late');
                      bool isFinished = data['status'] == 'submitted';

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(backgroundColor: const Color(0xFFF5F5F5), foregroundColor: Colors.black87, child: Text(name.substring(0, 1).toUpperCase())),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(isFinished ? 'Finished' : 'Working...'),
                        trailing: Text(lateness, style: TextStyle(fontWeight: FontWeight.bold, color: isLate ? Colors.redAccent : Colors.green)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showGradingBottomSheet(List<QueryDocumentSnapshot> studentDocs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, 32, 24, MediaQuery.of(context).padding.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Grading Reports', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 24),
                studentDocs.isEmpty
                    ? const EmptyState(message: 'No grading reports available.')
                    : ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: studentDocs.length,
                    itemBuilder: (context, index) {
                      final data = studentDocs[index].data() as Map<String, dynamic>;
                      final name = data['studentName'] ?? 'Unknown';
                      final score = data['score'] ?? 0.0;
                      bool isFinished = data['status'] == 'submitted';

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(backgroundColor: const Color(0xFFF5F5F5), foregroundColor: Colors.black87, child: Text(name.substring(0, 1).toUpperCase())),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: Text(isFinished ? score.toStringAsFixed(1) : '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      );
                    },
                  ),
                ),

                if (studentDocs.isNotEmpty && _examType != 'essay') ...[
                  const SizedBox(height: 24),
                  PrimaryButton(
                      text: 'Export',
                      onPressed: () {
                        Navigator.pop(context);
                        _exportGradingToCSV(studentDocs);
                      }
                  ),
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(backgroundColor: const Color(0xFFF8F9FA), foregroundColor: Colors.black, elevation: 0, title: const Text('Exam Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('exams').doc(widget.exam.id).collection('submissions').snapshots(),
        builder: (context, snapshot) {
          final studentDocs = snapshot.data?.docs ?? [];
          int totalParticipants = studentDocs.length;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Container(
                    padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(24)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.exam.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.person_outline, color: Colors.white70, size: 16),
                            const SizedBox(width: 6),
                            Text(widget.exam.creatorName, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                            const SizedBox(width: 16),
                            const Icon(Icons.timer_outlined, color: Colors.white70, size: 16),
                            const SizedBox(width: 6),
                            Text('${widget.exam.durationMinutes} Min', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Divider(color: Colors.white24, thickness: 1),
                        const SizedBox(height: 20),
                        const Text('SECURITY CREDENTIALS', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Exam Code', style: TextStyle(color: Colors.white60, fontSize: 12)), const SizedBox(height: 4), Text(widget.exam.examCode, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5))]),
                            IconButton(onPressed: () { Clipboard.setData(ClipboardData(text: widget.exam.examCode)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exam Code copied to clipboard'))); }, icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 22))
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0), child: Text('SESSION INFO', style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)))),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 6.0),
                  child: InkWell(
                    onTap: () => _showStudentsBottomSheet(studentDocs),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withValues(alpha: 0.05))),
                      child: Row(
                        children: [
                          Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Color(0xFFF5F5F5), shape: BoxShape.circle), child: const Icon(Icons.groups_rounded, color: Colors.black87, size: 20)),
                          const SizedBox(width: 16),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Students Joined', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 2), Text('$totalParticipants registered inside this room', style: const TextStyle(color: Colors.black54, fontSize: 12))])),
                          const Icon(Icons.chevron_right_rounded, color: Colors.black38),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 6.0),
                  child: InkWell(
                    onTap: () => _showGradingBottomSheet(studentDocs),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withValues(alpha: 0.05))),
                      child: Row(
                        children: [
                          Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Color(0xFFF5F5F5), shape: BoxShape.circle), child: const Icon(Icons.analytics_outlined, color: Colors.black87, size: 20)),
                          const SizedBox(width: 16),
                          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Grading', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), SizedBox(height: 2), Text('View scores and export evaluation reports', style: TextStyle(color: Colors.black54, fontSize: 12))])),
                          const Icon(Icons.chevron_right_rounded, color: Colors.black38),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: widget.exam.isActive
                      ? PrimaryButton(text: 'End Session', isLoading: _isLoading, onPressed: _endExamSession)
                      : Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16), alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(12)), child: const Text('Session Ended', style: TextStyle(color: Colors.black38, fontWeight: FontWeight.bold, fontSize: 16))),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}