// lib/models/attendance_model.dart
// Represents a single attendance record: was a student present or absent on a given date?

class AttendanceModel {
  final int? id;
  final int subjectId;
  final String date;   // Format: 'YYYY-MM-DD'
  final String status; // 'present' or 'absent'

  AttendanceModel({
    this.id,
    required this.subjectId,
    required this.date,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject_id': subjectId,
      'date': date,
      'status': status,
    };
  }

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      id: map['id'],
      subjectId: map['subject_id'],
      date: map['date'],
      status: map['status'],
    );
  }
}
