// Convert HH:mm format into total minutes.
int timeToMinutes(String time) {
  final parts = time.split(':');
  if (parts.length != 2) return 0;
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}
// Find the next upcoming occurrence
// for a schedule based on day and time.
DateTime getNextOccurrence(String dayStr, String timeStr) {
  final days = {
    "Mon": 1,
    "Tue": 2,
    "Wed": 3,
    "Thu": 4,
    "Fri": 5,
    "Sat": 6,
    "Sun": 7,
  };
  int targetDay = days[dayStr] ?? 1;

  final timeParts = timeStr.split(':');
  if (timeParts.length != 2) return DateTime.now();
  int targetHour = int.parse(timeParts[0]);
  int targetMin = int.parse(timeParts[1]);

  DateTime now = DateTime.now();
  DateTime candidate = DateTime(
    now.year,
    now.month,
    now.day,
    targetHour,
    targetMin,
  );

  while (candidate.weekday != targetDay || candidate.isBefore(now)) {
    candidate = candidate.add(const Duration(days: 1));
  }
  return candidate;
}
