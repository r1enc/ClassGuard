import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:classguard/models/exam.dart';
import 'package:classguard/features/exam/screens/exam_dashboard.dart';

// UI KIT IMPORTS
import 'package:classguard/shared/feedback/empty_state.dart';
import 'package:classguard/shared/dialogs/confirm_dialog.dart';
import 'package:classguard/shared/widgets/exam_card.dart';

class ExamHistoryScreen extends StatefulWidget {
  const ExamHistoryScreen({super.key});

  @override
  State<ExamHistoryScreen> createState() => _ExamHistoryScreenState();
}

class _ExamHistoryScreenState extends State<ExamHistoryScreen> {
  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? "";

  // STATE MANAGEMENT: Track which tab is active and which card is expanded
  bool _isShowingCreated = true;
  String? _expandedCreatedId = "FIRST_LOAD";
  String? _expandedJoinedId = "FIRST_LOAD";

  late Stream<QuerySnapshot> _createdStream;
  late Stream<QuerySnapshot> _joinedStream;

  @override
  void initState() {
    super.initState();
    // CORE LOGIC: Initialize streams for both created and joined exams
    _createdStream = FirebaseFirestore.instance.collection('exams').snapshots();
    _joinedStream = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUid)
        .collection('joined_exams')
        .snapshots();
  }

  String _formatExamType(String rawType) {
    if (rawType.toLowerCase().contains('multiple')) return 'Multiple Choice';
    if (rawType.toLowerCase().contains('essay')) return 'Essay';
    return rawType;
  }

  String _getBasicFormattedDate(DateTime time) {
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "${time.day} ${months[time.month - 1]} ${time.year}";
  }

  // STATE MANAGEMENT: Toggle between created and joined views
  Widget _buildTopToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isShowingCreated = true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _isShowingCreated ? Colors.black : Colors.white,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                  ),
                  child: Center(
                    child: Text('Created', style: TextStyle(color: _isShowingCreated ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isShowingCreated = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: !_isShowingCreated ? Colors.black : Colors.white,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
                  ),
                  child: Center(
                    child: Text('Joined', style: TextStyle(color: !_isShowingCreated ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatedCardCollapsed(Map<String, dynamic> data, String docId) {
    String title = data['title'] ?? 'Exam';
    DateTime start = (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05), width: 1.0),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Color(0xFFF5F5F5), shape: BoxShape.circle),
            child: const Icon(Icons.edit_document, color: Colors.black87),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                const SizedBox(height: 4),
                Text(_getBasicFormattedDate(start), style: const TextStyle(color: Colors.black54, fontSize: 14)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.black87),
            color: Colors.white,
            onSelected: (value) {
              if (value == 'delete') {
                ConfirmDialog.show(
                  context: context,
                  title: 'Delete History',
                  message: 'Are you sure you want to delete this exam history? This action cannot be undone.',
                  confirmText: 'Delete',
                  isDestructive: true,
                  onConfirm: () async {
                    await FirebaseFirestore.instance.collection('exams').doc(docId).delete();
                  },
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'delete', child: Text('Delete History', style: TextStyle(color: Colors.black))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJoinedCardExpanded(DocumentSnapshot submissionDoc, Map<String, dynamic> examData) {
    String title = examData['title'] ?? 'Exam';
    String lecturer = examData['lecturer'] ?? 'Lecturer';
    DateTime start = (examData['startTime'] as Timestamp?)?.toDate() ?? DateTime.now();
    int duration = examData['durationMinutes'] ?? 0;
    String rawExamType = examData['examType'] ?? examData['type'] ?? 'Exam';
    String formattedExamType = _formatExamType(rawExamType);

    final end = start.add(Duration(minutes: duration));
    final startTimeStr = "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}";
    final endTimeStr = "${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}";
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    final weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    final dateStr = "${weekdays[start.weekday - 1]}, ${months[start.month - 1]} ${start.day}, ${start.year}";

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                      child: const Text('EXAM SUCCESS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24)
                      ),
                      child: Text(formattedExamType.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white70),
                color: Colors.white,
                onSelected: (value) {
                  if (value == 'delete') {
                    ConfirmDialog.show(
                      context: context,
                      title: 'Delete History',
                      message: 'Are you sure you want to delete this exam history? This action cannot be undone.',
                      confirmText: 'Delete',
                      isDestructive: true,
                      onConfirm: () async {
                        await submissionDoc.reference.delete();
                      },
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'delete', child: Text('Delete History', style: TextStyle(color: Colors.black))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(lecturer, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text('$startTimeStr - $endTimeStr • $duration Mins', style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(dateStr, style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJoinedCardCollapsed(DocumentSnapshot submissionDoc, Map<String, dynamic> examData) {
    String title = examData['title'] ?? 'Exam';
    String lecturer = examData['lecturer'] ?? 'Lecturer';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05), width: 1.0),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Color(0xFFF5F5F5), shape: BoxShape.circle),
            child: const Icon(Icons.assignment_turned_in_outlined, color: Colors.black87),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                const SizedBox(height: 4),
                Text(lecturer, style: const TextStyle(color: Colors.black54, fontSize: 14)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.black87),
            color: Colors.white,
            onSelected: (value) {
              if (value == 'delete') {
                ConfirmDialog.show(
                  context: context,
                  title: 'Delete History',
                  message: 'Are you sure you want to delete this exam history? This action cannot be undone.',
                  confirmText: 'Delete',
                  isDestructive: true,
                  onConfirm: () async {
                    await submissionDoc.reference.delete();
                  },
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'delete', child: Text('Delete History', style: TextStyle(color: Colors.black))),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('Exam History', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildTopToggle(),
          Expanded(
            child: _isShowingCreated
                ? _buildCreatedList()
                : _buildJoinedList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatedList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _createdStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.black));
        }

        final allDocs = snapshot.data?.docs ?? [];
        final hostedDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['hostId'] != _currentUid) return false;

          bool isInactive = data['isActive'] == false;
          bool isExpired = false;

          Timestamp? startTimestamp = data['startTime'] as Timestamp?;
          int duration = data['durationMinutes'] ?? 0;
          if (startTimestamp != null) {
            DateTime endTime = startTimestamp.toDate().add(Duration(minutes: duration));
            if (DateTime.now().isAfter(endTime)) {
              isExpired = true;
            }
          }

          return isInactive || isExpired;
        }).toList();

        hostedDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          Timestamp aTime = aData['startTime'] as Timestamp? ?? Timestamp.now();
          Timestamp bTime = bData['startTime'] as Timestamp? ?? Timestamp.now();
          return bTime.compareTo(aTime);
        });

        return CustomScrollView(
          slivers: [
            if (hostedDocs.isEmpty)
              const SliverFillRemaining(
                child: EmptyState(message: 'No created exam history yet.'),
              ),
            if (hostedDocs.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final data = hostedDocs[index].data() as Map<String, dynamic>;
                    final docId = hostedDocs[index].id;
                    final exam = Exam.fromJson(data, docId);
                    final formattedExamType = _formatExamType(data['examType'] ?? data['type'] ?? 'Exam');

                    Widget expandedCard = ExamCard(
                      exam: exam,
                      formattedExamType: formattedExamType,
                      isActive: false, 
                      onOpenDashboard: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => ExamDashboardScreen(exam: exam)));
                      },
                      onDelete: () {
                        ConfirmDialog.show(
                          context: context,
                          title: 'Delete Exam',
                          message: 'Are you sure you want to delete this exam session? This action cannot be undone.',
                          confirmText: 'Delete',
                          isDestructive: true,
                          onConfirm: () async {
                            await FirebaseFirestore.instance.collection('exams').doc(exam.id).delete();
                          },
                        );
                      },
                    );

                    if (index == 0) {
                      bool isExpanded = _expandedCreatedId == null || _expandedCreatedId == docId;
                      return GestureDetector(
                        onTap: () => setState(() => _expandedCreatedId = isExpanded ? null : docId),
                        child: AnimatedCrossFade(
                          duration: const Duration(milliseconds: 300),
                          firstChild: expandedCard,
                          secondChild: _buildCreatedCardCollapsed(data, docId),
                          crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                        ),
                      );
                    } else {
                      bool isExpanded = _expandedCreatedId == docId;
                      return GestureDetector(
                        onTap: () => setState(() => _expandedCreatedId = isExpanded ? null : docId),
                        child: AnimatedCrossFade(
                          duration: const Duration(milliseconds: 300),
                          crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                          firstChild: _buildCreatedCardCollapsed(data, docId),
                          secondChild: expandedCard,
                        ),
                      );
                    }
                  }, childCount: hostedDocs.length),
                ),
              )
          ],
        );
      },
    );
  }

  Widget _buildJoinedList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _joinedStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.black));
        }

        final submissionDocs = snapshot.data?.docs.toList() ?? [];

        submissionDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          Timestamp aTime = aData['submittedAt'] as Timestamp? ?? Timestamp.now();
          Timestamp bTime = bData['submittedAt'] as Timestamp? ?? Timestamp.now();
          return bTime.compareTo(aTime);
        });

        if (submissionDocs.isEmpty) {
          return const EmptyState(message: 'No joined exam history yet.');
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          itemCount: submissionDocs.length,
          itemBuilder: (context, index) {
            final submissionDoc = submissionDocs[index];
            final docId = submissionDoc.id;
            final examData = submissionDoc.data() as Map<String, dynamic>;

            if (index == 0) {
              bool isExpanded = _expandedJoinedId == null || _expandedJoinedId == docId;
              return GestureDetector(
                onTap: () => setState(() => _expandedJoinedId = isExpanded ? null : docId),
                child: AnimatedCrossFade(
                  duration: const Duration(milliseconds: 400),
                  firstChild: _buildJoinedCardExpanded(submissionDoc, examData),
                  secondChild: _buildJoinedCardCollapsed(submissionDoc, examData),
                  crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                ),
              );
            } else {
              bool isExpanded = _expandedJoinedId == docId;
              return GestureDetector(
                onTap: () => setState(() => _expandedJoinedId = isExpanded ? null : docId),
                child: AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  firstChild: _buildJoinedCardCollapsed(submissionDoc, examData),
                  secondChild: _buildJoinedCardExpanded(submissionDoc, examData),
                ),
              );
            }
          },
        );
      },
    );
  }
}