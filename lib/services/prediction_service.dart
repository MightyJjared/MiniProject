// lib/services/prediction_service.dart
// All attendance math logic — current % + semester-end predictions

class PredictionService {

  /// Classes needed to reach minPercent from NOW
  /// Formula: (A + x) / (T + x) >= min/100
  /// Solving: x >= (min*T/100 - A) / (1 - min/100)
  int classesNeededToReach({
    required int attended,
    required int conducted,
    required double minPercent,
  }) {
    final minFraction = minPercent / 100.0;
    if (conducted > 0 && (attended / conducted) >= minFraction) return 0;
    final denominator = 1.0 - minFraction;
    if (denominator <= 0) return -1;
    final x = ((minFraction * conducted) - attended) / denominator;
    return x.ceil() < 0 ? 0 : x.ceil();
  }

  /// Safe classes to skip while staying above minPercent
  /// Formula: A / (T + x) >= min/100
  /// Solving: x <= A/minFraction - T
  int safeClassesToSkip({
    required int attended,
    required int conducted,
    required double minPercent,
  }) {
    final minFraction = minPercent / 100.0;
    if (minFraction <= 0) return 999;
    final canSkip = (attended / minFraction) - conducted;
    return canSkip.floor() < 0 ? 0 : canSkip.floor();
  }

  /// ── SEMESTER PREDICTION ──
  /// Given total classes in semester and classes remaining,
  /// how many of the REMAINING classes must the student attend
  /// to finish semester at >= minPercent?
  ///
  /// At end of semester:
  ///   (attended + x) / totalSemClasses >= minPercent/100
  ///   x >= (minPercent/100 * totalSemClasses) - attended
  ///
  /// Returns:
  ///   mustAttendRemaining: classes needed from remaining
  ///   canSkipRemaining: classes that can be skipped from remaining
  ///   willAchieveMin: true if it's still possible
  SemesterPrediction semesterPrediction({
    required int attended,           // attended so far
    required int totalSemClasses,    // total in full semester
    required int classesRemaining,   // not yet conducted
    required double minPercent,
  }) {
    if (totalSemClasses == 0 || classesRemaining == 0) {
      return SemesterPrediction(
        mustAttendRemaining: 0,
        canSkipRemaining: 0,
        projectedPercent: attended > 0 ? (attended / totalSemClasses * 100) : 0,
        willAchieveMin: false,
      );
    }

    final minFraction = minPercent / 100.0;
    final needed = (minFraction * totalSemClasses) - attended;
    final mustAttend = needed.ceil() < 0 ? 0 : needed.ceil();
    final canSkip = classesRemaining - mustAttend;

    // Projected % if student attends ALL remaining
    final projectedIfAllAttended =
        ((attended + classesRemaining) / totalSemClasses) * 100;

    return SemesterPrediction(
      mustAttendRemaining: mustAttend > classesRemaining ? classesRemaining : mustAttend,
      canSkipRemaining: canSkip < 0 ? 0 : canSkip,
      projectedPercent: projectedIfAllAttended,
      willAchieveMin: mustAttend <= classesRemaining,
    );
  }

  double overallAttendancePercent({
    required int totalAttended,
    required int totalConducted,
  }) {
    if (totalConducted == 0) return 0.0;
    return (totalAttended / totalConducted) * 100;
  }

  String riskLevel(double currentPercent, double minPercent) {
    if (currentPercent >= minPercent) return 'GREEN';
    if (currentPercent >= minPercent - 5) return 'YELLOW';
    return 'RED';
  }

  /// Count working days between two dates, excluding holidays and weekends
  int workingDaysBetween({
    required DateTime start,
    required DateTime end,
    required List<String> holidays, // 'YYYY-MM-DD'
  }) {
    int count = 0;
    DateTime current = start;
    final holidaySet = Set<String>.from(holidays);

    while (!current.isAfter(end)) {
      // Skip weekends (Saturday=6, Sunday=7)
      if (current.weekday != DateTime.saturday &&
          current.weekday != DateTime.sunday) {
        final key =
            '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
        if (!holidaySet.contains(key)) {
          count++;
        }
      }
      current = current.add(const Duration(days: 1));
    }
    return count;
  }
}

/// Result of semester-end prediction for a subject
class SemesterPrediction {
  final int mustAttendRemaining;   // Must attend this many from remaining classes
  final int canSkipRemaining;      // Can skip this many from remaining classes
  final double projectedPercent;   // % if all remaining attended
  final bool willAchieveMin;       // Is 75% still achievable?

  SemesterPrediction({
    required this.mustAttendRemaining,
    required this.canSkipRemaining,
    required this.projectedPercent,
    required this.willAchieveMin,
  });
}
