import 'package:flutter/material.dart';

class AppTheme {
  // main color
  static const Color primaryColor = Colors.black;
  static const Color backgroundColor = Colors.white;
  static const Color textDark = Colors.black87;
  static const Color textLight = Colors.black54;
  static const Color dangerColor = Colors.redAccent;
  
  // Card & surface colors
  static final Color cardBackground = Colors.white;
  static final Color iconBackground = const Color(0xFFF5F5F5);
  static final Color borderColor = Colors.black.withValues(alpha: 0.1);

  static const double defaultPadding = 24.0;
  static const double cardRadius = 16.0;
  static const double inputRadius = 12.0;

  // Global Input Decoration 
  static InputDecoration baseInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.black.withValues(alpha: 0.3)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: const BorderSide(color: Colors.black, width: 1.5),
      ),
    );
  }
} 