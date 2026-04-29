import 'package:flutter/material.dart';

/// Data model untuk satu item aktivitas terbaru.
class ActivityItem {
  final String title;
  final String subtitle;
  final String time;
  final IconData icon;
  final Color color;

  const ActivityItem({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    required this.color,
  });
}
