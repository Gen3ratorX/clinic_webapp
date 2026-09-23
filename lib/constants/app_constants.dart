import 'package:flutter/material.dart';

// Firestore collection names
class Collections {
  static const String users = 'users';
  static const String doctors = 'doctors';
  static const String appointments = 'appointments';
  static const String prescriptions = 'prescriptions';
  static const String reports = 'reports';
  static const String chats = 'chats';
  static const String messages = 'messages';
  static const String notifications = 'notifications';
  static const String tokens = 'tokens';
  static const String presence = 'presence';
}

// App-wide colors — clean/clinical palette
class AppColors {
  static const Color primary = Color(0xFF0F766E);
  static const Color primaryLight = Color(0xFF14B8A6);
  static const Color primaryDark = Color(0xFF115E59);
  static const Color secondary = Color(0xFF2563EB);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color onPrimary = Colors.white;
}
