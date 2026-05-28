// Core classroom and schedule model shared across personal and synced sessions.
class Course {
  String? id;
  String subject;
  String lecturer;
  String room;
  String day;
  String startTime;
  String endTime;
  bool isAppLockEnabled;
  bool isSilentModeEnabled;
  bool isActive;
  String role;
  String? roomCode;
  String? securityPIN;
  int allowanceTime;
  List<dynamic> blockedApps;
  bool isOwner;
  String? createdBy;

  Course({
    this.id,
    required this.subject,
    required this.lecturer,
    required this.room,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.isAppLockEnabled,
    this.isSilentModeEnabled = true,
    this.isActive = true,
    required this.role,
    this.roomCode,
    this.securityPIN,
    this.allowanceTime = 0,
    this.blockedApps = const [],
    this.isOwner = true,
    this.createdBy,
  });
}