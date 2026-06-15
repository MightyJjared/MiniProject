// lib/models/profile_model.dart
// Stores user profile + semester start/end dates + holidays list

class ProfileModel {
  final int? id;
  String name;
  int totalDays;          // Total working days in semester
  int daysCompleted;      // Days completed so far (manually editable)
  double minAttendance;   // Minimum required % (default 75)
  String semesterStart;   // Format: 'YYYY-MM-DD'
  String semesterEnd;     // Format: 'YYYY-MM-DD'
  List<String> holidays;  // List of holiday dates 'YYYY-MM-DD'

  ProfileModel({
    this.id,
    required this.name,
    required this.totalDays,
    this.daysCompleted = 0,
    this.minAttendance = 75.0,
    this.semesterStart = '',
    this.semesterEnd = '',
    this.holidays = const [],
  });

  // Days left after excluding holidays from remaining semester days
  int get daysLeft {
    final raw = totalDays - daysCompleted;
    return raw < 0 ? 0 : raw;
  }

  // Convert holidays list to comma-separated string for SQLite storage
  String get holidaysString => holidays.join(',');

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'total_days': totalDays,
      'days_completed': daysCompleted,
      'min_attendance': minAttendance,
      'semester_start': semesterStart,
      'semester_end': semesterEnd,
      'holidays': holidaysString,
    };
  }

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    final holidayStr = map['holidays'] as String? ?? '';
    return ProfileModel(
      id: map['id'],
      name: map['name'],
      totalDays: map['total_days'],
      daysCompleted: map['days_completed'],
      minAttendance: (map['min_attendance'] as num).toDouble(),
      semesterStart: map['semester_start'] ?? '',
      semesterEnd: map['semester_end'] ?? '',
      holidays: holidayStr.isEmpty ? [] : holidayStr.split(','),
    );
  }
}
