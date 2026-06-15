// lib/screens/home_screen.dart
// Main app shell with a BottomNavigationBar linking all major screens.

import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'subject_screen.dart';
import 'timetable_screen.dart';
import 'tracker_screen.dart';
import 'chatbot_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // List of screens corresponding to each tab
  final List<Widget> _screens = const [
    DashboardScreen(),
    SubjectScreen(),
    TimetableScreen(),
    TrackerScreen(),
    ChatbotScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Required for 5+ items
        selectedItemColor: const Color(0xFF1565C0),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Subjects'),
          BottomNavigationBarItem(icon: Icon(Icons.table_chart), label: 'Timetable'),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle), label: 'Tracker'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chatbot'),
        ],
      ),
    );
  }
}
