import 'package:flutter/material.dart';

class InfoBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final Color textColor;

  const InfoBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    this.backgroundColor = const Color(0xFFF2F2F2),
    this.iconColor = Colors.black87,
    this.textColor = Colors.black87,
  });

  // Factory for warning/alert banner
  factory InfoBanner.warning({required String message}) {
    return InfoBanner(
      message: message,
      icon: Icons.warning_amber_rounded,
      backgroundColor: Colors.orange.withValues(alpha: 0.1),
      iconColor: Colors.orange,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: textColor, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}