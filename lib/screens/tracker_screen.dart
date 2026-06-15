// lib/screens/tracker_screen.dart
// Shows today's subjects from the timetable and lets users mark present/absent.
// Updates subject attendance counts automatically in the database.

import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/timetable_model.dart';
import '../models/subject_model.dart';
import '../models/attendance_model.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  final _db = DatabaseHelper.instance;

  List<TimetableModel> _todayPeriods = [];
  List<SubjectModel> _allSubjects = [];
  bool _isLoading = true;

  // Format today's date as YYYY-MM-DD for DB storage
  final String _today = DateTime.now().toIso8601String().split('T').first;

  // Get today's weekday name (e.g., 'Monday')
  String get _todayName {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[DateTime.now().weekday - 1];
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final subjects = await _db.getAllSubjects();
    final periods = await _db.getTimetableForDay(_todayName);

    // Attach subject names to timetable entries
    for (final period in periods) {
      final match = subjects.where((s) => s.id == period.subjectId);
      period.subjectName = match.isNotEmpty ? match.first.name : 'Unknown';
    }

    setState(() {
      _allSubjects = subjects;
      _todayPeriods = periods;
      _isLoading = false;
    });
  }

  /// Marks attendance for a subject — updates the count and logs the record
  Future<void> _markAttendance(TimetableModel period, String status) async {
    // Check if already marked for today
    final alreadyMarked =
        await _db.isAttendanceMarked(period.subjectId, _today);
    if (alreadyMarked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already marked for today!')),
      );
      return;
    }

    // Log the attendance record
    await _db.insertAttendanceLog(AttendanceModel(
      subjectId: period.subjectId,
      date: _today,
      status: status,
    ));

    // Find the subject and update its count
    final subject = _allSubjects.firstWhere((s) => s.id == period.subjectId);

    subject.conducted++; // Total classes increases regardless of presence
    if (status == 'present') subject.attended++; // Attended only if present

    await _db.updateSubject(subject);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Marked ${status.toUpperCase()} for ${period.subjectName}'),
        backgroundColor: status == 'present' ? Colors.green : Colors.red,
      ),
    );

    _loadData(); // Refresh UI
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today: $_todayName'),
            Text(_today,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _todayPeriods.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.event_busy,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        'No classes scheduled for $_todayName',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text('Go to Timetable to add periods.',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _todayPeriods.length,
                  itemBuilder: (ctx, i) {
                    final period = _todayPeriods[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: const Color(0xFF1565C0),
                                  foregroundColor: Colors.white,
                                  child: Text('P${period.periodNumber}'),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  period.subjectName ?? 'Unknown',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Present / Absent buttons
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        _markAttendance(period, 'present'),
                                    icon: const Icon(Icons.check),
                                    label: const Text('Present'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Color.fromARGB(255, 8, 70, 10),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        _markAttendance(period, 'absent'),
                                    icon: const Icon(Icons.close),
                                    label: const Text('Absent'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Color.fromARGB(255, 58, 18, 15),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
