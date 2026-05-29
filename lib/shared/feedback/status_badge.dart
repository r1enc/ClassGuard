import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String text;
  final Color textColor;
  final Color backgroundColor;

  const StatusBadge({
    super.key,
    required this.text,
    required this.textColor,
    required this.backgroundColor,
  });

  // Factory constructor for green "ACTIVE NOW" badge
  factory StatusBadge.active() {
    return StatusBadge(
      text: 'ACTIVE NOW',
      textColor: Colors.greenAccent,
      backgroundColor: Colors.greenAccent.withValues(alpha: 0.2),
    );
  }

  // Factory constructor for transparent white info badge
  factory StatusBadge.info(String text) {
    return StatusBadge(
      text: text,
      textColor: Colors.white,
      backgroundColor: Colors.white.withValues(alpha: 0.15),
    );
  }

  // Factory constructor for red warning badge
  factory StatusBadge.lateAlert(int mins) {
    return StatusBadge(
      text: 'Late $mins mins',
      textColor: Colors.red,
      backgroundColor: Colors.red.withValues(alpha: 0.1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}