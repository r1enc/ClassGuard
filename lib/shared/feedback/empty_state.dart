import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final String message;
  final bool isCard;

  const EmptyState({
    super.key,
    required this.message,
    // Determines whether to show a black card or just plain text
    this.isCard = false, 
  });

  @override
  Widget build(BuildContext context) {
    if (isCard) {
      // Black card UI, usually used in main screens
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white70, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Plain text UI, typically used inside bottom sheets or dialogs
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: Colors.black.withValues(alpha: 0.4)),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}