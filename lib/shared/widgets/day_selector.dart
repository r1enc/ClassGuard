import 'package:flutter/material.dart';

class DaySelector extends StatelessWidget {
  final String selectedDay;
  final ValueChanged<String> onDaySelected;

  const DaySelector({
    super.key,
    required this.selectedDay,
    required this.onDaySelected,
  });

  static const List<String> _days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _days.map((day) {
        bool isSelected = selectedDay == day;
        return GestureDetector(
          onTap: () => onDaySelected(day),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected ? Colors.black : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black26),
            ),
            child: Center(
              child: Text(
                day,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}