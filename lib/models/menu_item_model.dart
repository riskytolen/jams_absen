import 'package:flutter/material.dart';

class MenuItemModel {
  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final String? badge;
  final VoidCallback? onTap;

  MenuItemModel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    this.badge,
    this.onTap,
  });
}
