// lib/models/subject_model.dart
// Subject with current attendance + total classes planned for full semester

class SubjectModel {
  final int? id;
  String name;
  int attended;        // Classes attended so far
  int conducted;       // Classes conducted so far
  int totalSemClasses; // Total classes planned for entire semester (e.g. 90)
  String priority;     // 'LOW', 'MID', 'HIGH'

  SubjectModel({
    this.id,
    required this.name,
    this.attended = 0,
    this.conducted = 0,
    this.totalSemClasses = 0, // 0 means not set
    this.priority = 'LOW',
  });

  // Current attendance %
  double get attendancePercent {
    if (conducted == 0) return 0.0;
    return (attended / conducted) * 100;
  }

  // Classes remaining in semester (not yet conducted)
  int get classesRemaining {
    final rem = totalSemClasses - conducted;
    return rem < 0 ? 0 : rem;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'attended': attended,
      'conducted': conducted,
      'total_sem_classes': totalSemClasses,
      'priority': priority,
    };
  }

  factory SubjectModel.fromMap(Map<String, dynamic> map) {
    return SubjectModel(
      id: map['id'],
      name: map['name'],
      attended: map['attended'],
      conducted: map['conducted'],
      totalSemClasses: map['total_sem_classes'] ?? 0,
      priority: map['priority'],
    );
  }
}
