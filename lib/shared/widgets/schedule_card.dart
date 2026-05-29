import 'package:flutter/material.dart';
import '../../models/course.dart';
import '../feedback/status_badge.dart';
import 'time_info_row.dart';

class ScheduleCard extends StatelessWidget {
  final Course course;
  final bool isRunning;
  final VoidCallback onToggleSilent;
  final VoidCallback onToggleAppLock;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;
  final VoidCallback? onOpenDashboard; // Optional

  const ScheduleCard({
    super.key,
    required this.course,
    required this.isRunning,
    required this.onToggleSilent,
    required this.onToggleAppLock,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
    this.onOpenDashboard,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        border: isRunning ? Border.all(color: Colors.greenAccent, width: 2) : null,
        boxShadow: [
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
            children: [
              isRunning
                  ? StatusBadge.active()
                  : StatusBadge.info('${course.day.toUpperCase()} • ${course.role.toUpperCase()}'),
              const Spacer(),
              Row(
                children: [
                  GestureDetector(
                    onTap: onToggleSilent,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        course.isSilentModeEnabled ? Icons.volume_off : Icons.volume_up,
                        color: course.isSilentModeEnabled ? Colors.white : Colors.white38,
                        size: 20,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onToggleAppLock,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        course.isAppLockEnabled ? Icons.lock_outline : Icons.lock_open_outlined,
                        color: course.isAppLockEnabled ? Colors.white : Colors.white38,
                        size: 20,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: (isRunning && !course.isOwner) ? Colors.white24 : Colors.white70,
                    ),
                    color: Colors.black,
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => [
                      if (course.isOwner && (!isRunning || course.role == 'Teacher'))
                        const PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Colors.white))),
                      if (!isRunning)
                        PopupMenuItem(value: 'delete', child: Text(course.isOwner ? 'Delete' : 'Leave Classroom', style: const TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(course.subject, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('${course.lecturer} • ${course.room}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TimeInfoRow(startTime: course.startTime, endTime: course.endTime),
              Switch(
                value: course.isActive,
                activeThumbColor: Colors.black,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                onChanged: (_) => onToggleActive(),
              ),
            ],
          ),
          if (course.role == 'Teacher' && course.isOwner && onOpenDashboard != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onOpenDashboard,
                icon: const Icon(Icons.admin_panel_settings, size: 20, color: Colors.black),
                label: const Text('Open Classroom Dashboard', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}