// lib/widgets/risk_badge.dart
// A colored badge that shows attendance risk level: GREEN / YELLOW / RED

import 'package:flutter/material.dart';

class RiskBadge extends StatelessWidget {
  final String risk;      // 'GREEN', 'YELLOW', or 'RED'
  final bool compact;     // If true, show only a colored dot

  const RiskBadge({super.key, required this.risk, this.compact = false});

  Color get _color {
    switch (risk) {
      case 'GREEN':  return Colors.green;
      case 'YELLOW': return Colors.orange;
      case 'RED':    return Colors.red;
      default:       return Colors.grey;
    }
  }

  String get _emoji {
    switch (risk) {
      case 'GREEN':  return '🟢';
      case 'YELLOW': return '🟡';
      case 'RED':    return '🔴';
      default:       return '⚪';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      // Just a colored circle icon
      return Icon(Icons.circle, color: _color, size: 20);
    }

    // Full badge with label
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        border: Border.all(color: _color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$_emoji $risk',
        style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }
}
