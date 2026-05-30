import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:classguard/models/exam.dart';
import 'package:classguard/shared/feedback/status_badge.dart';

class ExamCard extends StatelessWidget {
  final Exam exam;
  final String formattedExamType;
  final VoidCallback onOpenDashboard;
  final VoidCallback? onDelete; // Made optional to handle different screen needs
  
  // ADDED: Flag to control UI state (active vs history)
  final bool isActive; 

  const ExamCard({
    super.key,
    required this.exam,
    required this.formattedExamType,
    required this.onOpenDashboard,
    this.onDelete,
    // Default to true so HomeScreen remains unchanged and keeps the red shadow
    this.isActive = true, 
  });

  @override
  Widget build(BuildContext context) {
    final days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];
    final String dayStr = days[exam.startTime.weekday - 1];

    final String startStr =
        "${exam.startTime.hour.toString().padLeft(2, '0')}:${exam.startTime.minute.toString().padLeft(2, '0')}";
    final String endStr =
        "${exam.endTime.hour.toString().padLeft(2, '0')}:${exam.endTime.minute.toString().padLeft(2, '0')}";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        // MODIFIED: Dynamic border color based on active status
        border: isActive 
            ? Border.all(color: Colors.redAccent, width: 2) 
            : Border.all(color: Colors.white24, width: 1),
        // MODIFIED: Dynamic shadow based on active status
        boxShadow: isActive ? [
          BoxShadow(
            color: Colors.redAccent.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusBadge.info('$dayStr • EXAM'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      formattedExamType.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              if (onDelete != null)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  color: Colors.black,
                  onSelected: (value) {
                    if (value == 'delete') {
                      onDelete!();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            exam.title,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            exam.creatorName,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                '$startStr - $endStr',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Code: ${exam.examCode}',
            style: const TextStyle(color: Colors.white54, fontSize: 13, letterSpacing: 1),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onOpenDashboard,
              icon: const Icon(Icons.monitor, size: 20, color: Colors.black),
              // MODIFIED: Change button text if inactive to prevent confusion
              label: Text(
                isActive ? 'Open Exam Dashboard' : 'View Details',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}