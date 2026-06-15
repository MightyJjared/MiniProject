// lib/screens/subject_screen.dart
// Add/Edit/Delete subjects. Includes "Total Semester Classes" for end-of-semester prediction.

import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/subject_model.dart';
import '../models/profile_model.dart';
import '../services/prediction_service.dart';

class SubjectScreen extends StatefulWidget {
  const SubjectScreen({super.key});

  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  final _db = DatabaseHelper.instance;
  final _predictor = PredictionService();
  List<SubjectModel> _subjects = [];
  ProfileModel? _profile;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final subjects = await _db.getAllSubjects();
    final profile = await _db.getProfile();
    setState(() {
      _subjects = subjects;
      _profile = profile;
    });
  }

  Future<void> _deleteSubject(int id) async {
    await _db.deleteSubject(id);
    _loadData();
  }

  void _showSubjectDialog({SubjectModel? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final attendedCtrl = TextEditingController(text: existing?.attended.toString() ?? '0');
    final conductedCtrl = TextEditingController(text: existing?.conducted.toString() ?? '0');
    final totalSemCtrl = TextEditingController(
        text: existing?.totalSemClasses != 0 ? existing?.totalSemClasses.toString() : '');
    String priority = existing?.priority ?? 'LOW';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? '➕ Add Subject' : '✏️ Edit Subject'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Subject Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: attendedCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Attended',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: conductedCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Conducted',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Total semester classes ──
                TextField(
                  controller: totalSemCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total Classes This Semester',
                    hintText: 'e.g. 90',
                    border: OutlineInputBorder(),
                    helperText: 'Used to predict classes needed for 75%',
                    prefixIcon: Icon(Icons.school),
                  ),
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  value: priority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(),
                  ),
                  items: ['LOW', 'MID', 'HIGH']
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => priority = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final sub = SubjectModel(
                  id: existing?.id,
                  name: name,
                  attended: int.tryParse(attendedCtrl.text) ?? 0,
                  conducted: int.tryParse(conductedCtrl.text) ?? 0,
                  totalSemClasses: int.tryParse(totalSemCtrl.text) ?? 0,
                  priority: priority,
                );
                if (existing == null) {
                  await _db.insertSubject(sub);
                } else {
                  await _db.updateSubject(sub);
                }
                if (!mounted) return;
                Navigator.pop(ctx);
                _loadData();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'HIGH': return Colors.red.shade50;
      case 'MID':  return Colors.orange.shade50;
      default:     return Colors.green.shade50;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subjects')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSubjectDialog(),
        child: const Icon(Icons.add),
      ),
      body: _subjects.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.book_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No subjects yet. Tap + to add.',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _subjects.length,
              itemBuilder: (ctx, i) {
                final sub = _subjects[i];
                final minPct = _profile?.minAttendance ?? 75.0;
                final risk = _predictor.riskLevel(sub.attendancePercent, minPct);

                // Semester prediction if total sem classes is set
                SemesterPrediction? semPred;
                if (sub.totalSemClasses > 0) {
                  semPred = _predictor.semesterPrediction(
                    attended: sub.attended,
                    totalSemClasses: sub.totalSemClasses,
                    classesRemaining: sub.classesRemaining,
                    minPercent: minPct,
                  );
                }

                return Card(
                  color: _priorityColor(sub.priority),
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          children: [
                            Expanded(
                              child: Text(sub.name,
                                  style: const TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.bold)),
                            ),
                            Chip(
                              label: Text(sub.priority,
                                  style: const TextStyle(fontSize: 11)),
                              padding: EdgeInsets.zero,
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                              onPressed: () => _showSubjectDialog(existing: sub),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: () => _deleteSubject(sub.id!),
                            ),
                          ],
                        ),

                        // Current stats
                        Row(
                          children: [
                            _StatPill(
                                label: 'Attended',
                                value: '${sub.attended}',
                                color: Colors.blue),
                            const SizedBox(width: 6),
                            _StatPill(
                                label: 'Conducted',
                                value: '${sub.conducted}',
                                color: Colors.grey),
                            const SizedBox(width: 6),
                            _StatPill(
                                label: 'Current',
                                value: '${sub.attendancePercent.toStringAsFixed(1)}%',
                                color: risk == 'GREEN'
                                    ? Colors.green
                                    : (risk == 'YELLOW' ? Colors.orange : Colors.red)),
                          ],
                        ),

                        // Semester prediction section
                        if (semPred != null) ...[
                          const Divider(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.analytics, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                'Semester: ${sub.conducted}/${sub.totalSemClasses} done · '
                                '${sub.classesRemaining} remaining',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (semPred.willAchieveMin)
                            _PredictionBanner(
                              icon: '🎯',
                              text: 'Must attend ${semPred.mustAttendRemaining} more '
                                  '(can skip ${semPred.canSkipRemaining}) '
                                  'to reach ${minPct.toInt()}%',
                              color: Colors.blue.shade50,
                              borderColor: Colors.blue,
                            )
                          else
                            _PredictionBanner(
                              icon: '🚨',
                              text: 'Cannot reach ${minPct.toInt()}% — '
                                  'only ${sub.classesRemaining} classes left but need '
                                  '${semPred.mustAttendRemaining}. Attend ALL remaining!',
                              color: Colors.red.shade50,
                              borderColor: Colors.red,
                            ),
                        ] else ...[
                          const SizedBox(height: 4),
                          const Text(
                            '💡 Set "Total Classes This Semester" to see prediction',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _PredictionBanner extends StatelessWidget {
  final String icon;
  final String text;
  final Color color;
  final Color borderColor;
  const _PredictionBanner(
      {required this.icon, required this.text, required this.color, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
