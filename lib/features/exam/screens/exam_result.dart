import 'package:flutter/material.dart';

import 'package:classguard/core/theme/app_theme.dart';
import 'package:classguard/shared/widgets/primary_button.dart';

class ExamResultScreen extends StatelessWidget {
  const ExamResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // SECURITY: PopScope prevents user from going back via hardware button
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.defaultPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 80,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Exam Submitted!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Answers submitted successfully.\nPlease wait for the host to announce the results.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppTheme.textLight, height: 1.5),
                ),
                const Spacer(),

                // REUSABLE WIDGET
                PrimaryButton(
                  text: 'Back to Home',
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}