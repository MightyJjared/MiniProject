// lib/services/chatbot_service.dart
// A rule-based chatbot that reads from the database to answer
// attendance-related questions dynamically.

import '../database/database_helper.dart';
import '../services/prediction_service.dart';

class ChatbotService {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final PredictionService _predictor = PredictionService();

  /// Main method: takes user input and returns a bot response.
  /// Matches keywords to determine which rule to apply.
  Future<String> getResponse(String userInput) async {
    final input = userInput.toLowerCase().trim();

    // Rule 1: "Can I skip today?" / skip-related queries
    if (input.contains('skip')) {
      return await _handleSkipQuery();
    }

    // Rule 2: "How many classes should I attend?" / attend-related queries
    if (input.contains('attend') || input.contains('how many classes')) {
      return await _handleAttendQuery();
    }

    // Rule 3: "Which subject is risky?" / risk-related queries
    if (input.contains('risk') || input.contains('subject')) {
      return await _handleRiskQuery();
    }

    // Rule 4: General attendance status
    if (input.contains('attendance') || input.contains('status')) {
      return await _handleStatusQuery();
    }

    // Default fallback message
    return "🤖 I can help you with:\n"
        "• \"Can I skip today?\"\n"
        "• \"How many classes should I attend?\"\n"
        "• \"Which subject is risky?\"\n"
        "• \"What is my attendance?\"";
  }

  /// Tells the user how many classes they can safely skip overall.
  Future<String> _handleSkipQuery() async {
    final subjects = await _db.getAllSubjects();
    final profile = await _db.getProfile();
    if (profile == null || subjects.isEmpty) {
      return "⚠️ Please set up your profile and add subjects first.";
    }

    final buffer = StringBuffer();
    buffer.writeln("📊 Here's your skip budget:\n");

    for (final sub in subjects) {
      final canSkip = _predictor.safeClassesToSkip(
        attended: sub.attended,
        conducted: sub.conducted,
        minPercent: profile.minAttendance,
      );
      final emoji = canSkip > 2 ? '✅' : (canSkip > 0 ? '⚠️' : '🚫');
      buffer.writeln("$emoji ${sub.name}: Can skip $canSkip more class(es)");
    }

    buffer.writeln("\n💡 Tip: Don't skip HIGH priority subjects even if you can!");
    return buffer.toString();
  }

  /// Tells the user how many classes they need to attend per subject.
  Future<String> _handleAttendQuery() async {
    final subjects = await _db.getAllSubjects();
    final profile = await _db.getProfile();
    if (profile == null || subjects.isEmpty) {
      return "⚠️ Please set up your profile and add subjects first.";
    }

    final buffer = StringBuffer();
    buffer.writeln("📚 Classes needed to reach ${profile.minAttendance.toInt()}%:\n");

    for (final sub in subjects) {
      final needed = _predictor.classesNeededToReach(
        attended: sub.attended,
        conducted: sub.conducted,
        minPercent: profile.minAttendance,
      );
      if (needed == 0) {
        buffer.writeln("✅ ${sub.name}: You're on track! (${sub.attendancePercent.toStringAsFixed(1)}%)");
      } else {
        buffer.writeln("📌 ${sub.name}: Attend $needed more class(es) to be safe");
      }
    }

    return buffer.toString();
  }

  /// Identifies which subjects are in the danger zone.
  Future<String> _handleRiskQuery() async {
    final subjects = await _db.getAllSubjects();
    final profile = await _db.getProfile();
    if (profile == null || subjects.isEmpty) {
      return "⚠️ Please set up your profile and add subjects first.";
    }

    final buffer = StringBuffer();
    buffer.writeln("🔍 Subject Risk Report:\n");

    for (final sub in subjects) {
      final risk = _predictor.riskLevel(sub.attendancePercent, profile.minAttendance);
      final icon = risk == 'GREEN' ? '🟢' : (risk == 'YELLOW' ? '🟡' : '🔴');
      buffer.writeln("$icon ${sub.name} — ${sub.attendancePercent.toStringAsFixed(1)}% [$risk]");
    }

    final risky = subjects.where((s) {
      final r = _predictor.riskLevel(s.attendancePercent, profile.minAttendance);
      return r == 'RED';
    }).toList();

    if (risky.isNotEmpty) {
      buffer.writeln("\n⚠️ Focus on: ${risky.map((s) => s.name).join(', ')}");
    } else {
      buffer.writeln("\n🎉 All subjects look good! Keep it up.");
    }

    return buffer.toString();
  }

  /// Returns a quick overall attendance summary.
  Future<String> _handleStatusQuery() async {
    final subjects = await _db.getAllSubjects();
    final profile = await _db.getProfile();
    if (profile == null) {
      return "⚠️ Please set up your profile first.";
    }

    final totalAttended = subjects.fold(0, (sum, s) => sum + s.attended);
    final totalConducted = subjects.fold(0, (sum, s) => sum + s.conducted);
    final overall = _predictor.overallAttendancePercent(
      totalAttended: totalAttended,
      totalConducted: totalConducted,
    );

    return "📈 Overall Attendance: ${overall.toStringAsFixed(1)}%\n"
        "🗓️ Days Completed: ${profile.daysCompleted} / ${profile.totalDays}\n"
        "📅 Days Left: ${profile.daysLeft}\n"
        "🎯 Target: ${profile.minAttendance.toInt()}%";
  }
}
