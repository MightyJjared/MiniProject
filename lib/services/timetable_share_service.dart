// lib/services/timetable_share_service.dart
//
// Handles exporting and importing timetable + subjects as a shareable JSON file.
// The file format is human-readable and can be shared via WhatsApp, email, etc.
//
// EXPORT: Creates a .attendx file (JSON inside) with all subjects + timetable.
// IMPORT: Reads .attendx file, inserts subjects and timetable into DB.
//         If a subject with the same name already exists it skips insertion.

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../database/database_helper.dart';
import '../models/subject_model.dart';
import '../models/timetable_model.dart';

class TimetableShareService {
  final _db = DatabaseHelper.instance;

  // ─── EXPORT ───────────────────────────────────────────────────────────────

  /// Builds a JSON payload from current subjects + full timetable.
  /// Saves as   <appDocDir>/AttendX_Timetable.attendx
  /// Returns the file path so the caller can share it.
  Future<String> exportTimetable() async {
    final subjects = await _db.getAllSubjects();
    final weekdays = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];

    // Build subject list (no attendance data — just name, priority, total classes)
    final subjectList = subjects.map((s) => {
      'name': s.name,
      'priority': s.priority,
      'total_sem_classes': s.totalSemClasses,
    }).toList();

    // Build timetable — one entry per day
    final timetableMap = <String, List<Map<String, dynamic>>>{};
    for (final day in weekdays) {
      final entries = await _db.getTimetableForDay(day);
      timetableMap[day] = entries.map((e) {
        // Find subject name for this entry
        final sub = subjects.firstWhere(
          (s) => s.id == e.subjectId,
          orElse: () => SubjectModel(name: 'Unknown'),
        );
        return {
          'subject_name': sub.name,
          'period_number': e.periodNumber,
        };
      }).toList();
    }

    // Final payload
    final payload = {
      'format': 'attendx_timetable',
      'version': '1',
      'exported_at': DateTime.now().toIso8601String(),
      'subjects': subjectList,
      'timetable': timetableMap,
    };

    // Save to app documents directory
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/AttendX_Timetable.attendx');
    await file.writeAsString(jsonEncode(payload), flush: true);

    return file.path;
  }

  // ─── IMPORT ───────────────────────────────────────────────────────────────

  /// Reads a .attendx file, imports subjects and timetable into DB.
  /// Returns an ImportResult describing what was added / skipped.
  Future<ImportResult> importTimetable(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return ImportResult(success: false, message: 'File not found: $filePath');
    }

    final raw = await file.readAsString();
    final Map<String, dynamic> payload;

    try {
      payload = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      return ImportResult(success: false, message: 'Invalid file format.');
    }

    if (payload['format'] != 'attendx_timetable') {
      return ImportResult(success: false, message: 'Not a valid AttendX timetable file.');
    }

    int subjectsAdded = 0;
    int subjectsSkipped = 0;
    int periodsAdded = 0;

    // ── Step 1: Import subjects ──
    final subjectList = payload['subjects'] as List<dynamic>;
    // Map from subject name → new DB id (for timetable insertion)
    final nameToId = <String, int>{};

    // Get existing subjects to avoid duplicates
    final existing = await _db.getAllSubjects();
    for (final ex in existing) {
      nameToId[ex.name] = ex.id!;
    }

    for (final s in subjectList) {
      final name = s['name'] as String;
      if (nameToId.containsKey(name)) {
        // Already exists — skip
        subjectsSkipped++;
        continue;
      }
      final newId = await _db.insertSubject(SubjectModel(
        name: name,
        priority: s['priority'] ?? 'LOW',
        totalSemClasses: s['total_sem_classes'] ?? 0,
      ));
      nameToId[name] = newId;
      subjectsAdded++;
    }

    // ── Step 2: Import timetable ──
    final timetableMap = payload['timetable'] as Map<String, dynamic>;

    for (final day in timetableMap.keys) {
      final entries = timetableMap[day] as List<dynamic>;

      // Clear existing timetable for this day to avoid duplicates
      await _db.deleteTimetableForDay(day);

      for (final entry in entries) {
        final subjectName = entry['subject_name'] as String;
        final periodNumber = entry['period_number'] as int;
        final subjectId = nameToId[subjectName];

        if (subjectId == null) continue; // Should not happen

        await _db.insertTimetableEntry(TimetableModel(
          weekday: day,
          periodNumber: periodNumber,
          subjectId: subjectId,
        ));
        periodsAdded++;
      }
    }

    return ImportResult(
      success: true,
      message: '✅ Import complete!\n'
          '• $subjectsAdded subjects added\n'
          '• $subjectsSkipped subjects already existed\n'
          '• $periodsAdded timetable periods imported',
      subjectsAdded: subjectsAdded,
      periodsAdded: periodsAdded,
    );
  }

  // ─── AUTO-CALCULATE total semester classes per subject ────────────────────
  //
  // Logic:
  //   1. Count how many times each subject appears per week in the timetable.
  //   2. Count total working weeks between semester start and end
  //      (excluding holidays and weekends).
  //   3. total_sem_classes = classes_per_week × working_weeks
  //      (more precisely: sum across each week separately to handle holidays correctly)
  //
  Future<Map<String, int>> autoCalculateTotalClasses({
    required DateTime semStart,
    required DateTime semEnd,
    required List<String> holidays,
  }) async {
    final subjects = await _db.getAllSubjects();
    final weekdays = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
    final holidaySet = Set<String>.from(holidays);

    // Build: subjectId → classes per weekday (e.g. {1: {Monday: 2, Wednesday: 1}})
    final Map<int, Map<String, int>> subjectDayCount = {};
    for (final day in weekdays) {
      final entries = await _db.getTimetableForDay(day);
      for (final e in entries) {
        subjectDayCount.putIfAbsent(e.subjectId, () => {});
        subjectDayCount[e.subjectId]![day] =
            (subjectDayCount[e.subjectId]![day] ?? 0) + 1;
      }
    }

    // Count actual occurrences of each weekday between sem start and end
    // excluding holidays
    final Map<String, int> dayOccurrences = {
      'Monday': 0, 'Tuesday': 0, 'Wednesday': 0,
      'Thursday': 0, 'Friday': 0, 'Saturday': 0,
    };

    DateTime current = semStart;
    while (!current.isAfter(semEnd)) {
      // Skip Sundays
      if (current.weekday != DateTime.sunday) {
        final dateStr = _fmt(current);
        if (!holidaySet.contains(dateStr)) {
          final dayName = _weekdayName(current.weekday);
          if (dayOccurrences.containsKey(dayName)) {
            dayOccurrences[dayName] = dayOccurrences[dayName]! + 1;
          }
        }
      }
      current = current.add(const Duration(days: 1));
    }

    // Calculate total classes per subject
    final Map<String, int> result = {}; // subject name → total classes

    for (final subject in subjects) {
      final dayMap = subjectDayCount[subject.id] ?? {};
      int total = 0;
      for (final day in dayMap.keys) {
        final occurrences = dayOccurrences[day] ?? 0;
        final classesPerDay = dayMap[day] ?? 0;
        total += occurrences * classesPerDay;
      }
      result[subject.name] = total;
    }

    return result;
  }

  // ─── Apply auto-calculated totals back to DB ──────────────────────────────
  Future<void> applyAutoCalculatedTotals(Map<String, int> totals) async {
    final subjects = await _db.getAllSubjects();
    for (final subject in subjects) {
      final calculated = totals[subject.name];
      if (calculated != null && calculated > 0) {
        final updated = SubjectModel(
          id: subject.id,
          name: subject.name,
          attended: subject.attended,
          conducted: subject.conducted,
          totalSemClasses: calculated,
          priority: subject.priority,
        );
        await _db.updateSubject(updated);
      }
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _weekdayName(int weekday) {
    const names = {
      1: 'Monday', 2: 'Tuesday', 3: 'Wednesday',
      4: 'Thursday', 5: 'Friday', 6: 'Saturday', 7: 'Sunday',
    };
    return names[weekday] ?? '';
  }
}

/// Result returned after an import attempt
class ImportResult {
  final bool success;
  final String message;
  final int subjectsAdded;
  final int periodsAdded;

  ImportResult({
    required this.success,
    required this.message,
    this.subjectsAdded = 0,
    this.periodsAdded = 0,
  });
}
