import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class CustomTimePicker {
  static Future<String?> show({
    required BuildContext context,
    required String initialTime,
  }) async {
    int initialHour = 0;
    int initialMinute = 0;

    if (initialTime.isNotEmpty && initialTime.contains(':')) {
      final parts = initialTime.split(':');
      initialHour = int.tryParse(parts[0]) ?? 0;
      initialMinute = int.tryParse(parts[1]) ?? 0;
    }

    // Initializes DateTime instance for CupertinoDatePicker compatibility.
    DateTime initialDateTime = DateTime(2024, 1, 1, initialHour, initialMinute);
    DateTime selectedDateTime = initialDateTime;

    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Time',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 160,
                  child: CupertinoTheme(
                    data: const CupertinoThemeData(
                      textTheme: CupertinoTextThemeData(
                        // Enforces black text color to align with the monochrome UI theme.
                        dateTimePickerTextStyle: TextStyle(
                          color: Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // MODIFIED: Implemented CupertinoDatePicker with time mode to ensure proper 24-hour formatting.
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      use24hFormat: true,
                      initialDateTime: initialDateTime,
                      onDateTimeChanged: (DateTime newDateTime) {
                        selectedDateTime = newDateTime;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Formats hour and minute values to enforce a two-digit layout.
                        String formattedHour = selectedDateTime.hour.toString().padLeft(2, '0');
                        String formattedMinute = selectedDateTime.minute.toString().padLeft(2, '0');
                        Navigator.pop(context, "$formattedHour:$formattedMinute");
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

