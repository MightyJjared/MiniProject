// lib/screens/timetable_screen.dart
// Weekly timetable builder with:
//  • Export timetable → .attendx file (share via WhatsApp, email etc.)
//  • Import timetable ← from .attendx file
//  • Auto-calculate total semester classes per subject

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../database/database_helper.dart';
import '../models/timetable_model.dart';
import '../models/subject_model.dart';
import '../services/timetable_share_service.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper.instance;
  final _shareService = TimetableShareService();

  List<SubjectModel> _subjects = [];
  late TabController _tabController;
  bool _isExporting = false;
  bool _isCalculating = false;

  final List<String> _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _weekdays.length, vsync: this);
    _loadSubjects();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    final subjects = await _db.getAllSubjects();
    setState(() => _subjects = subjects);
  }

  // ─── EXPORT ──────────────────────────────────────────────────────────────

  Future<void> _exportTimetable() async {
    if (_subjects.isEmpty) {
      _showSnack('Add subjects first before exporting.', Colors.orange);
      return;
    }
    setState(() => _isExporting = true);

    try {
      final filePath = await _shareService.exportTimetable();

      setState(() => _isExporting = false);

      if (!mounted) return;

      // Show dialog with file path and instructions
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.share, color: Color(0xFF1565C0)),
            SizedBox(width: 8),
            Text('Timetable Exported!'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('File saved at:', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child:
                    Text(filePath, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              ),
              const SizedBox(height: 12),
              const Text(
                '📤 How to share:\n'
                '1. Open your file manager\n'
                '2. Navigate to the path above\n'
                '3. Share via WhatsApp, Email, Telegram etc.\n\n'
                '📥 Your classmate opens AttendX →\n'
                'Timetable tab → Import → select the file',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _isExporting = false);
      _showSnack('Export failed: $e', Colors.red);
    }
  }

  // ─── IMPORT ──────────────────────────────────────────────────────────────

  Future<void> _importTimetable() async {
    // Ask user to enter the file path (simplest cross-platform approach)
    // In a real app you'd use file_picker package — but we keep zero extra deps
    final pathCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.download, color: Color(0xFF1565C0)),
          SizedBox(width: 8),
          Text('Import Timetable'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1. Your classmate shares the .attendx file\n'
              '2. Save it to your Downloads folder\n'
              '3. Enter the full file path below:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pathCtrl,
              decoration: const InputDecoration(
                labelText: 'File path',
                hintText: '/storage/emulated/0/Download/AttendX_Timetable.attendx',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.folder_open),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '⚠️ Existing subjects with the same name won\'t be duplicated.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Import')),
        ],
      ),
    );

    if (confirmed != true || pathCtrl.text.trim().isEmpty) return;

    final result = await _shareService.importTimetable(pathCtrl.text.trim());
    _loadSubjects();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(result.success ? '✅ Import Complete' : '❌ Import Failed'),
        content: Text(result.message),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  // ─── AUTO-CALCULATE TOTAL CLASSES ────────────────────────────────────────

  Future<void> _autoCalculate() async {
    final profile = await _db.getProfile();
    if (profile == null || profile.semesterStart.isEmpty || profile.semesterEnd.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Semester Dates Missing'),
          content: const Text('Please set Semester Start and End dates in your Profile first.\n\n'
              'Go to Dashboard → Profile icon (top right) → set dates.'),
          actions: [
            ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    setState(() => _isCalculating = true);

    final start = DateTime.parse(profile.semesterStart);
    final end = DateTime.parse(profile.semesterEnd);

    final totals = await _shareService.autoCalculateTotalClasses(
      semStart: start,
      semEnd: end,
      holidays: profile.holidays,
    );

    // Show preview before applying
    setState(() => _isCalculating = false);
    if (!mounted) return;

    // Build preview list
    final preview = totals.entries
        .where((e) => e.value > 0)
        .map((e) => '• ${e.key}: ${e.value} classes')
        .join('\n');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.calculate, color: Color(0xFF1565C0)),
          SizedBox(width: 8),
          Text('Auto-Calculated Classes'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Based on your timetable × ${profile.semesterStart} to ${profile.semesterEnd}'
              '\n(excluding ${profile.holidays.length} holiday(s) & weekends)\n',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              preview.isEmpty ? 'No subjects found in timetable.' : preview,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'Apply these values to all subjects?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply ✅')),
        ],
      ),
    );

    if (confirm == true) {
      await _shareService.applyAutoCalculatedTotals(totals);
      _showSnack(
        '✅ Total semester classes updated for ${totals.length} subjects!',
        Colors.green,
      );
    }
  }

  void _showAddEntryDialog(String weekday) {
    int? selectedSubjectId;
    final periodCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Add Period — $weekday'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: periodCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Period Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(),
                ),
                items: _subjects
                    .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedSubjectId = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final period = int.tryParse(periodCtrl.text);
                if (period == null || selectedSubjectId == null) return;
                await _db.insertTimetableEntry(TimetableModel(
                  weekday: weekday,
                  periodNumber: period,
                  subjectId: selectedSubjectId!,
                ));
                if (!mounted) return;
                Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: _weekdays.map((d) => Tab(text: d.substring(0, 3))).toList(),
        ),
        actions: [
          // Auto-calculate button
          _isCalculating
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.calculate),
                  tooltip: 'Auto-calculate total semester classes',
                  onPressed: _autoCalculate,
                ),

          // Export button
          _isExporting
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Export & Share Timetable',
                  onPressed: _exportTimetable,
                ),

          // Import button
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Import Timetable from file',
            onPressed: _importTimetable,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: _weekdays
            .map((day) => _DayTimetable(
                  weekday: day,
                  subjects: _subjects,
                  onAdd: () {
                    _showAddEntryDialog(day);
                  },
                ))
            .toList(),
      ),
    );
  }
}

// ─── Single day timetable view ────────────────────────────────────────────────

class _DayTimetable extends StatefulWidget {
  final String weekday;
  final List<SubjectModel> subjects;
  final VoidCallback onAdd;

  const _DayTimetable({
    required this.weekday,
    required this.subjects,
    required this.onAdd,
  });

  @override
  State<_DayTimetable> createState() => _DayTimetableState();
}

class _DayTimetableState extends State<_DayTimetable> with AutomaticKeepAliveClientMixin {
  final _db = DatabaseHelper.instance;
  List<TimetableModel> _entries = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await _db.getTimetableForDay(widget.weekday);
    for (final e in entries) {
      final match = widget.subjects.where((s) => s.id == e.subjectId);
      e.subjectName = match.isNotEmpty ? match.first.name : 'Unknown';
    }
    setState(() => _entries = entries);
  }

  Future<void> _delete(int id) async {
    await _db.deleteTimetableEntry(id);
    _loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: _entries.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.table_chart_outlined, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text('No periods for ${widget.weekday}',
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 4),
                  const Text('Tap + to add', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _entries.length,
              itemBuilder: (ctx, i) {
                final e = _entries[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      child: Text('P${e.periodNumber}', style: const TextStyle(fontSize: 12)),
                    ),
                    title: Text(e.subjectName ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Period ${e.periodNumber}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _delete(e.id!),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_${widget.weekday}',
        onPressed: () {
          widget.onAdd();
          Future.delayed(const Duration(milliseconds: 600), _loadEntries);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
