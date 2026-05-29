import 'package:flutter/material.dart';

class ExamTypeChip extends StatelessWidget {
  final String examType;
  final Color textColor;
  final Color borderColor;

  const ExamTypeChip({
    super.key,
    required this.examType,
    this.textColor = Colors.white,
    this.borderColor = Colors.white24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        examType.toUpperCase(),
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