import 'package:flutter/material.dart';

class TimeInfoRow extends StatelessWidget {
  final String startTime;
  final String endTime;
  final Color textColor;
  final Color iconColor;

  const TimeInfoRow({
    super.key,
    required this.startTime,
    required this.endTime,
    this.textColor = Colors.white,
    this.iconColor = Colors.white70,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.access_time, color: iconColor, size: 16),
        const SizedBox(width: 8),
        Text(
          '$startTime - $endTime',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}