// lib/models/timetable_model.dart
// Represents a single timetable slot: a subject on a specific weekday at a specific period.

class TimetableModel {
  final int? id;
  final String weekday;     // e.g., 'Monday', 'Tuesday'
  final int periodNumber;   // Period slot (1, 2, 3...)
  final int subjectId;      // Foreign key to subjects table

  // This is loaded separately from the subjects table (not stored in DB)
  String? subjectName;

  TimetableModel({
    this.id,
    required this.weekday,
    required this.periodNumber,
    required this.subjectId,
    this.subjectName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'weekday': weekday,
      'period_number': periodNumber,
      'subject_id': subjectId,
    };
  }

  factory TimetableModel.fromMap(Map<String, dynamic> map) {
    return TimetableModel(
      id: map['id'],
      weekday: map['weekday'],
      periodNumber: map['period_number'],
      subjectId: map['subject_id'],
    );
  }
}
