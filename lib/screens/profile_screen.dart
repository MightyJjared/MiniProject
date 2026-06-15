// lib/screens/profile_screen.dart
// Full profile management: edit name, days, reset days counter,
// set semester start/end, manage holidays.

import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/profile_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _db = DatabaseHelper.instance;
  final _formKey = GlobalKey<FormState>();

  // Controllers pre-filled from DB
  late TextEditingController _nameCtrl;
  late TextEditingController _totalDaysCtrl;
  late TextEditingController _daysCompletedCtrl;
  late TextEditingController _minAttCtrl;

  ProfileModel? _profile;
  DateTime? _semStart;
  DateTime? _semEnd;
  List<String> _holidays = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final p = await _db.getProfile();
    setState(() {
      _profile = p;
      _nameCtrl = TextEditingController(text: p?.name ?? '');
      _totalDaysCtrl = TextEditingController(text: p?.totalDays.toString() ?? '');
      _daysCompletedCtrl = TextEditingController(text: p?.daysCompleted.toString() ?? '0');
      _minAttCtrl = TextEditingController(text: p?.minAttendance.toString() ?? '75');
      _holidays = List<String>.from(p?.holidays ?? []);
      if (p?.semesterStart.isNotEmpty == true) {
        _semStart = DateTime.tryParse(p!.semesterStart);
      }
      if (p?.semesterEnd.isNotEmpty == true) {
        _semEnd = DateTime.tryParse(p!.semesterEnd);
      }
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _totalDaysCtrl.dispose();
    _daysCompletedCtrl.dispose();
    _minAttCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Not set';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _toDbDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_semStart ?? now) : (_semEnd ?? now),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: isStart ? 'Select Semester Start' : 'Select Semester End',
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _semStart = picked;
        } else {
          _semEnd = picked;
        }
      });
      // Auto-calculate working days if both dates set
      if (_semStart != null && _semEnd != null) {
        _autoCalcDays();
      }
    }
  }

  // Auto-fill total days based on semester dates minus holidays and weekends
  void _autoCalcDays() {
    if (_semStart == null || _semEnd == null) return;
    final predictor = _WorkingDayCalc();
    final days = predictor.workingDaysBetween(
      start: _semStart!,
      end: _semEnd!,
      holidays: _holidays,
    );
    setState(() {
      _totalDaysCtrl.text = days.toString();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Auto-calculated: $days working days (excl. weekends & holidays)'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _addHoliday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Select Holiday Date',
    );
    if (picked != null) {
      final dateStr = _toDbDate(picked);
      if (!_holidays.contains(dateStr)) {
        setState(() => _holidays.add(dateStr));
        // Recalculate days
        if (_semStart != null && _semEnd != null) _autoCalcDays();
      }
    }
  }

  void _removeHoliday(String date) {
    setState(() => _holidays.remove(date));
    if (_semStart != null && _semEnd != null) _autoCalcDays();
  }

  Future<void> _resetDays() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Days?'),
        content: const Text(
            'This will set days completed back to 0. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.resetDays();
      setState(() => _daysCompletedCtrl.text = '0');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Days reset to 0'), backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final updated = ProfileModel(
      id: _profile?.id,
      name: _nameCtrl.text.trim(),
      totalDays: int.parse(_totalDaysCtrl.text.trim()),
      daysCompleted: int.tryParse(_daysCompletedCtrl.text.trim()) ?? 0,
      minAttendance: double.tryParse(_minAttCtrl.text.trim()) ?? 75.0,
      semesterStart: _semStart != null ? _toDbDate(_semStart!) : '',
      semesterEnd: _semEnd != null ? _toDbDate(_semEnd!) : '',
      holidays: _holidays,
    );

    if (_profile == null) {
      await _db.insertProfile(updated);
    } else {
      await _db.updateProfile(updated);
    }

    setState(() => _isSaving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved ✅'), backgroundColor: Colors.green),
    );
    Navigator.pop(context, true); // Return true = reload dashboard
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          // Reset days button in app bar
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset Days Counter',
            onPressed: _resetDays,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ─── PROFILE INFO ───
            _SectionHeader(title: '👤 Profile Info'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _minAttCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minimum Attendance %',
                prefixIcon: Icon(Icons.percent),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n < 0 || n > 100) return 'Enter 0–100';
                return null;
              },
            ),

            const SizedBox(height: 20),

            // ─── SEMESTER DATES ───
            _SectionHeader(title: '📅 Semester Dates'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DateTile(
                    label: 'Start Date',
                    value: _formatDate(_semStart),
                    icon: Icons.play_circle,
                    color: Colors.green,
                    onTap: () => _pickDate(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateTile(
                    label: 'End Date',
                    value: _formatDate(_semEnd),
                    icon: Icons.stop_circle,
                    color: Colors.red,
                    onTap: () => _pickDate(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ─── DAYS FIELDS ───
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _totalDaysCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Total Days',
                      prefixIcon: Icon(Icons.calendar_month),
                      border: OutlineInputBorder(),
                      helperText: 'Auto-filled from dates',
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Required';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _daysCompletedCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Days Completed',
                      prefixIcon: Icon(Icons.today),
                      border: OutlineInputBorder(),
                      helperText: 'Edit manually',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Reset days button
            OutlinedButton.icon(
              onPressed: _resetDays,
              icon: const Icon(Icons.restart_alt, color: Colors.red),
              label: const Text('Reset Days to 0', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
            ),

            const SizedBox(height: 20),

            // ─── HOLIDAYS ───
            _SectionHeader(title: '🏖️ Holidays This Semester'),
            const SizedBox(height: 8),
            const Text(
              'Adding holidays auto-recalculates total working days.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 10),

            if (_holidays.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No holidays added yet.', style: TextStyle(color: Colors.grey)),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _holidays.map((date) {
                  final dt = DateTime.tryParse(date);
                  final label = dt != null
                      ? '${dt.day}/${dt.month}/${dt.year}'
                      : date;
                  return Chip(
                    label: Text(label, style: const TextStyle(fontSize: 12)),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _removeHoliday(date),
                    backgroundColor: Colors.orange.shade50,
                    side: BorderSide(color: Colors.orange.shade200),
                  );
                }).toList(),
              ),

            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addHoliday,
              icon: const Icon(Icons.add),
              label: const Text('Add Holiday'),
            ),

            const SizedBox(height: 28),

            // Save button
            _isSaving
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Helper widgets ───

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const Divider(),
      ],
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DateTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// Internal helper (avoids importing prediction_service just for day calc)
class _WorkingDayCalc {
  int workingDaysBetween({
    required DateTime start,
    required DateTime end,
    required List<String> holidays,
  }) {
    int count = 0;
    DateTime current = start;
    final holidaySet = Set<String>.from(holidays);
    while (!current.isAfter(end)) {
      if (current.weekday != DateTime.saturday &&
          current.weekday != DateTime.sunday) {
        final key =
            '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
        if (!holidaySet.contains(key)) count++;
      }
      current = current.add(const Duration(days: 1));
    }
    return count;
  }
}
