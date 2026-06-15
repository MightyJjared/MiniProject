// lib/database/database_helper.dart
// Central SQLite manager. Handles all DB operations.

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/profile_model.dart';
import '../models/subject_model.dart';
import '../models/timetable_model.dart';
import '../models/attendance_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('attendance.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(path, version: 2, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  // Called when DB is created fresh
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        total_days INTEGER NOT NULL,
        days_completed INTEGER NOT NULL DEFAULT 0,
        min_attendance REAL NOT NULL DEFAULT 75.0,
        semester_start TEXT NOT NULL DEFAULT '',
        semester_end TEXT NOT NULL DEFAULT '',
        holidays TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        attended INTEGER NOT NULL DEFAULT 0,
        conducted INTEGER NOT NULL DEFAULT 0,
        total_sem_classes INTEGER NOT NULL DEFAULT 0,
        priority TEXT NOT NULL DEFAULT 'LOW'
      )
    ''');

    await db.execute('''
      CREATE TABLE timetable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        weekday TEXT NOT NULL,
        period_number INTEGER NOT NULL,
        subject_id INTEGER NOT NULL,
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
      )
    ''');
  }

  // Called when DB version upgrades (existing installs)
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns to existing tables safely
      try {
        await db.execute('ALTER TABLE profile ADD COLUMN semester_start TEXT NOT NULL DEFAULT ""');
        await db.execute('ALTER TABLE profile ADD COLUMN semester_end TEXT NOT NULL DEFAULT ""');
        await db.execute('ALTER TABLE profile ADD COLUMN holidays TEXT NOT NULL DEFAULT ""');
        await db.execute('ALTER TABLE subjects ADD COLUMN total_sem_classes INTEGER NOT NULL DEFAULT 0');
      } catch (_) {
        // Columns may already exist — safe to ignore
      }
    }
  }

  // ───────── PROFILE ─────────

  Future<int> insertProfile(ProfileModel p) async {
    final db = await database;
    return await db.insert('profile', p.toMap());
  }

  Future<ProfileModel?> getProfile() async {
    final db = await database;
    final result = await db.query('profile', limit: 1);
    if (result.isEmpty) return null;
    return ProfileModel.fromMap(result.first);
  }

  Future<int> updateProfile(ProfileModel p) async {
    final db = await database;
    return await db.update('profile', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  // Reset days completed back to 0
  Future resetDays() async {
    final db = await database;
    await db.rawUpdate('UPDATE profile SET days_completed = 0');
  }

  // ───────── SUBJECTS ─────────

  Future<int> insertSubject(SubjectModel s) async {
    final db = await database;
    return await db.insert('subjects', s.toMap());
  }

  Future<List<SubjectModel>> getAllSubjects() async {
    final db = await database;
    final result = await db.query('subjects', orderBy: 'name ASC');
    return result.map((m) => SubjectModel.fromMap(m)).toList();
  }

  Future<int> updateSubject(SubjectModel s) async {
    final db = await database;
    return await db.update('subjects', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
  }

  Future<int> deleteSubject(int id) async {
    final db = await database;
    return await db.delete('subjects', where: 'id = ?', whereArgs: [id]);
  }

  // ───────── TIMETABLE ─────────

  Future<int> insertTimetableEntry(TimetableModel e) async {
    final db = await database;
    return await db.insert('timetable', e.toMap());
  }

  Future<List<TimetableModel>> getTimetableForDay(String weekday) async {
    final db = await database;
    final result = await db.query('timetable',
        where: 'weekday = ?', whereArgs: [weekday], orderBy: 'period_number ASC');
    return result.map((m) => TimetableModel.fromMap(m)).toList();
  }

  Future<int> deleteTimetableEntry(int id) async {
    final db = await database;
    return await db.delete('timetable', where: 'id = ?', whereArgs: [id]);
  }

  // Delete all timetable entries for a specific weekday (used during import)
  Future deleteTimetableForDay(String weekday) async {
    final db = await database;
    await db.delete('timetable', where: 'weekday = ?', whereArgs: [weekday]);
  }

  // Get ALL timetable entries (used for export)
  Future<List<TimetableModel>> getAllTimetableEntries() async {
    final db = await database;
    final result = await db.query('timetable', orderBy: 'weekday, period_number ASC');
    return result.map((m) => TimetableModel.fromMap(m)).toList();
  }

  // ───────── ATTENDANCE LOG ─────────

  Future<int> insertAttendanceLog(AttendanceModel log) async {
    final db = await database;
    return await db.insert('attendance_log', log.toMap());
  }

  Future<bool> isAttendanceMarked(int subjectId, String date) async {
    final db = await database;
    final result = await db.query('attendance_log',
        where: 'subject_id = ? AND date = ?', whereArgs: [subjectId, date]);
    return result.isNotEmpty;
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}
