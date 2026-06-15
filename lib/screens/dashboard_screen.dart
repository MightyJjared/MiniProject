// lib/screens/dashboard_screen.dart
// AttendX main dashboard — donut chart, semester countdown, subject predictions, chatbot

import 'dart:math';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/profile_model.dart';
import '../models/subject_model.dart';
import '../services/prediction_service.dart';
import '../services/chatbot_service.dart';
import '../widgets/risk_badge.dart';
import '../widgets/stat_card.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = DatabaseHelper.instance;
  final _predictor = PredictionService();
  final _chatbot = ChatbotService();

  ProfileModel? _profile;
  List<SubjectModel> _subjects = [];
  bool _isLoading = true;

  // Chatbot
  final _chatCtrl = TextEditingController();
  String _botResponse = "👋 Ask me anything about your attendance!";
  bool _isBotTyping = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final profile = await _db.getProfile();
    final subjects = await _db.getAllSubjects();
    setState(() {
      _profile = profile;
      _subjects = subjects;
      _isLoading = false;
    });
  }

  Future<void> _openProfile() async {
    final reload = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    if (reload == true) _loadData();
  }

  Future<void> _incrementDay() async {
    if (_profile == null) return;
    _profile!.daysCompleted++;
    await _db.updateProfile(_profile!);
    _loadData();
  }

  Future<void> _askBot(String q) async {
    if (q.trim().isEmpty) return;
    setState(() { _isBotTyping = true; _botResponse = "🤖 thinking..."; });
    _chatCtrl.clear();
    final r = await _chatbot.getResponse(q);
    setState(() { _botResponse = r; _isBotTyping = false; });
  }

  Color _riskColor(String risk) {
    switch (risk) {
      case 'GREEN':  return Colors.green;
      case 'YELLOW': return Colors.orange;
      case 'RED':    return Colors.red;
      default:       return Colors.grey;
    }
  }

  // Days until semester ends
  String _semesterCountdown() {
    if (_profile == null || _profile!.semesterEnd.isEmpty) return '';
    final end = DateTime.tryParse(_profile!.semesterEnd);
    if (end == null) return '';
    final diff = end.difference(DateTime.now()).inDays;
    if (diff < 0) return 'Semester ended';
    if (diff == 0) return 'Last day today!';
    return '$diff days until semester ends';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_profile == null) return const Scaffold(body: Center(child: Text('No profile found.')));

    final totalAttended = _subjects.fold(0, (sum, s) => sum + s.attended);
    final totalConducted = _subjects.fold(0, (sum, s) => sum + s.conducted);
    final overallPercent = _predictor.overallAttendancePercent(
        totalAttended: totalAttended, totalConducted: totalConducted);
    final overallRisk = _predictor.riskLevel(overallPercent, _profile!.minAttendance);
    final countdown = _semesterCountdown();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AttendX'),
        actions: [
          // ── Profile icon (top right) ──
          IconButton(
            icon: const CircleAvatar(
              backgroundColor: Colors.white,
              radius: 14,
              child: Icon(Icons.person, color: Color(0xFF1565C0), size: 18),
            ),
            tooltip: 'Edit Profile',
            onPressed: _openProfile,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ─── Semester countdown banner ───
            if (countdown.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(countdown,
                        style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),

            // ─── MAIN DONUT CHART ───
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text('Hi, ${_profile!.name} 👋',
                        style: const TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 4),
                    const Text('Overall Attendance',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 185,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(185, 185),
                            painter: DonutChartPainter(
                                percent: overallPercent, risk: overallRisk),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${overallPercent.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                      color: _riskColor(overallRisk))),
                              RiskBadge(risk: overallRisk),
                              Text('Min: ${_profile!.minAttendance.toInt()}%',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _LegendDot(
                            color: _riskColor(overallRisk),
                            label: 'Attended ${overallPercent.toStringAsFixed(0)}%'),
                        const SizedBox(width: 16),
                        _LegendDot(
                            color: Colors.grey.shade300,
                            label: 'Absent ${(100 - overallPercent).toStringAsFixed(0)}%'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ─── MINI DONUT CHARTS PER SUBJECT ───
            if (_subjects.isNotEmpty) ...[
              const Text('Subject-wise',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 115,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _subjects.length,
                  itemBuilder: (ctx, i) {
                    final sub = _subjects[i];
                    final risk = _predictor.riskLevel(
                        sub.attendancePercent, _profile!.minAttendance);
                    return SizedBox(
                      width: 100,
                      child: Card(
                        margin: const EdgeInsets.only(right: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 58,
                                width: 58,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CustomPaint(
                                      size: const Size(58, 58),
                                      painter: DonutChartPainter(
                                          percent: sub.attendancePercent,
                                          risk: risk,
                                          strokeWidth: 7),
                                    ),
                                    Text(
                                      '${sub.attendancePercent.toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(sub.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ─── STATS ───
            Row(
              children: [
                Expanded(child: StatCard(
                    title: 'Days Done', value: '${_profile!.daysCompleted}',
                    subtitle: 'of ${_profile!.totalDays}',
                    icon: Icons.today, color: Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(
                    title: 'Days Left', value: '${_profile!.daysLeft}',
                    subtitle: 'remaining',
                    icon: Icons.calendar_today, color: Colors.orange)),
              ],
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _incrementDay,
              icon: const Icon(Icons.add_circle),
              label: const Text('Mark Today as Done (+1 Day)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),

            // ─── SUBJECT LIST ───
            const Text('Subject Breakdown',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_subjects.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('No subjects yet. Go to Subjects tab.')),
              )
            else
              ..._subjects.map((sub) {
                final risk = _predictor.riskLevel(
                    sub.attendancePercent, _profile!.minAttendance);
                final canSkip = _predictor.safeClassesToSkip(
                  attended: sub.attended,
                  conducted: sub.conducted,
                  minPercent: _profile!.minAttendance,
                );
                // Semester prediction
                SemesterPrediction? semPred;
                if (sub.totalSemClasses > 0) {
                  semPred = _predictor.semesterPrediction(
                    attended: sub.attended,
                    totalSemClasses: sub.totalSemClasses,
                    classesRemaining: sub.classesRemaining,
                    minPercent: _profile!.minAttendance,
                  );
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            RiskBadge(risk: risk, compact: true),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(sub.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ),
                            Text('Skip: $canSkip',
                                style: TextStyle(
                                    color: canSkip > 0
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${sub.attended}/${sub.conducted} conducted · ${sub.attendancePercent.toStringAsFixed(1)}%',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                        if (semPred != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: semPred.willAchieveMin
                                  ? Colors.blue.shade50
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: semPred.willAchieveMin
                                      ? Colors.blue
                                      : Colors.red),
                            ),
                            child: Text(
                              semPred.willAchieveMin
                                  ? '🎯 Need ${semPred.mustAttendRemaining} more of ${sub.classesRemaining} remaining classes'
                                  : '🚨 Cannot reach ${_profile!.minAttendance.toInt()}% — attend ALL ${sub.classesRemaining} remaining!',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 16),

            // ─── CHATBOT ───
            Card(
              elevation: 3,
              color: const Color(0xFFF0F4FF),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.smart_toy, color: Color(0xFF1565C0)),
                      SizedBox(width: 8),
                      Text('AttendX Bot',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                    ]),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _QuickChip(label: '🚫 Can I skip?',
                            onTap: () => _askBot('Can I skip today?')),
                        _QuickChip(label: '⚠️ Risky subjects?',
                            onTap: () => _askBot('Which subject is risky?')),
                        _QuickChip(label: '📊 My status',
                            onTap: () => _askBot('What is my attendance status?')),
                        _QuickChip(label: '📚 Classes needed?',
                            onTap: () => _askBot('How many classes should I attend?')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Text(_botResponse,
                          style: TextStyle(
                              fontSize: 13,
                              color: _isBotTyping
                                  ? Colors.grey
                                  : Colors.black87)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatCtrl,
                            decoration: InputDecoration(
                              hintText: 'Ask anything...',
                              hintStyle: const TextStyle(fontSize: 13),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            onSubmitted: _askBot,
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: const Color(0xFF1565C0),
                          child: IconButton(
                            icon: const Icon(Icons.send,
                                color: Colors.white, size: 18),
                            onPressed: () => _askBot(_chatCtrl.text),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// Donut chart painter
class DonutChartPainter extends CustomPainter {
  final double percent;
  final String risk;
  final double strokeWidth;

  DonutChartPainter({required this.percent, required this.risk, this.strokeWidth = 18});

  Color get _color {
    switch (risk) {
      case 'GREEN':  return Colors.green;
      case 'YELLOW': return Colors.orange;
      case 'RED':    return Colors.red;
      default:       return const Color(0xFF1565C0);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth / 2;
    canvas.drawCircle(center, radius,
        Paint()..color = Colors.grey.shade200
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * (percent.clamp(0, 100) / 100),
      false,
      Paint()..color = _color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(DonutChartPainter old) =>
      old.percent != percent || old.risk != risk;
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 12, height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ]);
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF1565C0)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF1565C0))),
      ),
    );
  }
}
