# 📅 Smart Attendance Planner

A Flutter Android app for students to track, manage, and predict attendance across subjects.

---

## 🏗️ Project Structure

```
lib/
├── main.dart                      # App entry point & routing
├── models/
│   ├── profile_model.dart         # User profile data
│   ├── subject_model.dart         # Subject with attendance counts
│   ├── timetable_model.dart       # Timetable entry (weekday + period)
│   └── attendance_model.dart      # Attendance log (present/absent)
├── database/
│   └── database_helper.dart       # SQLite setup & all CRUD operations
├── services/
│   ├── prediction_service.dart    # Attendance math & risk logic
│   └── chatbot_service.dart       # Rule-based chatbot responses
├── screens/
│   ├── home_screen.dart           # BottomNavigationBar shell
│   ├── profile_setup_screen.dart  # First-time profile setup
│   ├── dashboard_screen.dart      # Overview + stats
│   ├── subject_screen.dart        # Add/Edit/Delete subjects
│   ├── timetable_screen.dart      # Weekly timetable builder
│   ├── tracker_screen.dart        # Mark present/absent for today
│   └── chatbot_screen.dart        # Chat UI
└── widgets/
    ├── risk_badge.dart            # Green/Yellow/Red indicator badge
    └── stat_card.dart             # Dashboard stat tile
```

---

## ⚙️ Tech Stack

| Layer        | Technology               |
|-------------|--------------------------|
| Framework   | Flutter (Dart)           |
| Database    | SQLite via `sqflite`     |
| UI          | Material Design 3        |
| Architecture| Clean Architecture (MVC-like layers) |

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK ≥ 3.0.0 installed
- Android Studio or VS Code with Dart/Flutter extensions
- Connected Android device or emulator

### Setup Steps

```bash
# 1. Open the project folder in VS Code
code smart_attendance_planner

# 2. Install dependencies
flutter pub get

# 3. Run on connected device (or press F5 in VS Code)
flutter run
```

### First Launch
- The app checks if a profile exists in SQLite.
- If not → **Profile Setup screen** appears.
- Fill in your name, total semester days (e.g. 90), and minimum attendance %.
- After saving → you reach the **Dashboard**.

---

## 📱 Feature Walkthrough

### 1. Profile Setup
- Enter your name, semester days, and minimum attendance (default 75%)
- Stored in SQLite `profile` table

### 2. Subjects (Tab 2)
- Tap `+` to add a subject
- Fill name, attended classes, conducted classes, priority (LOW/MID/HIGH)
- Edit or delete existing subjects

### 3. Timetable (Tab 3)
- Select a weekday tab (Mon–Sat)
- Tap `+` to add a period — choose subject and period number
- Data saved to SQLite `timetable` table

### 4. Attendance Tracker (Tab 4)
- Shows today's periods from the timetable automatically
- Tap **Present** or **Absent** for each class
- Updates subject attendance counts in real time
- Won't let you mark twice on the same day

### 5. Dashboard (Tab 1)
- Overall attendance % with color-coded progress bar
- Days completed / days left
- Per-subject breakdown with skip budget
- Tap "Mark Today as Done" to increment completed days

### 6. Chatbot (Tab 5)
- Type or tap quick chips to ask:
  - "Can I skip today?"
  - "Which subject is risky?"
  - "How many classes should I attend?"
  - "What is my attendance status?"

---

## 🧮 Prediction Formula

```
To reach minimum attendance:
  (A + x) / (T + x) >= min%
  x = ceil( (min% * T - A) / (100 - min%) )

To find safe skips:
  A / (T + x) >= min%
  x = floor( A / min% - T )

Where:
  A = classes attended
  T = classes conducted
  x = future classes (attended or skipped)
```

---

## 🗄️ Database Schema

```sql
profile      (id, name, total_days, days_completed, min_attendance)
subjects     (id, name, attended, conducted, priority)
timetable    (id, weekday, period_number, subject_id)
attendance_log (id, subject_id, date, status)
```

---

## 🎓 Viva Tips

- **Why SQLite?** Lightweight, offline, no server needed — perfect for mobile apps.
- **Why sqflite?** It's the official Flutter plugin for SQLite with async support.
- **Clean Architecture:** Models (data) → Services (logic) → Screens (UI) — each layer has one job.
- **Prediction Formula:** Derived algebraically from the attendance fraction inequality.
- **Singleton DB:** `DatabaseHelper.instance` ensures only one DB connection exists, preventing conflicts.
