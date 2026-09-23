import 'package:clinic_web_dashboard/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:clinic_web_dashboard/screens/auth/login_screen.dart';
import 'package:clinic_web_dashboard/screens/admin/admin_dashboard.dart';
import 'package:clinic_web_dashboard/screens/doctor/doctor_dashboard.dart';
import 'package:clinic_web_dashboard/services/presence_service.dart';
import 'dart:html' as html; // Added import for web-specific APIs

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  _AuthGateState createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final PresenceService _presenceService = PresenceService();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();
    _presenceService.setupPresence(); // Initialize presence
    _initializeFCM(); // Initialize FCM
  }

  Future<void> _initializeFCM() async {
    try {
      final user = await FirebaseAuth.instance.authStateChanges().firstWhere((user) => user != null, orElse: () => null);
      if (user == null) {
        debugPrint('⚠️ No authenticated user for FCM setup');
        return;
      }
      final role = await _getUserRole(user.uid);
      if (role != 'doctor') {
        debugPrint('⚠️ User is not a doctor, skipping FCM setup');
        return;
      }
      NotificationSettings settings = await _messaging.requestPermission();
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        debugPrint('⚠️ Notification permission denied');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable notifications to receive appointment alerts.')),
        );
        return;
      }
      String? token = await _messaging.getToken(
        vapidKey: 'BJfDqZ9BvTdODBMJu1UA3TWHshyBlKWCfbiW21nV7i2Q25HbHsNxSJUCV28yNftWe90ZWqO5DBwYHPb6UGqzKFI',
      );
      debugPrint('📲 FCM Token: $token');
      if (token != null) {
        await FirebaseFirestore.instance
            .collection(Collections.doctors)
            .doc(user.uid)
            .collection(Collections.tokens)
            .doc(token) // Use token as document ID to avoid duplicates
            .set({
          'fcmToken': token,
          'createdAt': FieldValue.serverTimestamp(),
          'device': html.window.navigator.userAgent, // Fixed: html is now imported
        });
        debugPrint('✅ FCM token saved for doctor UID: ${user.uid}');
      }
      _messaging.onTokenRefresh.listen((newToken) async {
        await FirebaseFirestore.instance
            .collection(Collections.doctors)
            .doc(user.uid)
            .collection(Collections.tokens)
            .doc(newToken)
            .set({
          'fcmToken': newToken,
          'createdAt': FieldValue.serverTimestamp(),
          'device': html.window.navigator.userAgent, // Fixed: html is now imported
        });
        debugPrint('✅ FCM token refreshed: $newToken');
      });

      // Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📩 Foreground Message: ${message.notification?.title} - ${message.notification?.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${message.notification?.title}: ${message.notification?.body}',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      });

      // Handle background notification taps
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('🔁 Opened from background: ${message.data}');
        if (message.data['route'] != null) {
          Navigator.of(context).pushNamed(message.data['route']);
        }
      });

      // Handle cold start from notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('🚀 Opened from cold start: ${initialMessage.data}');
        if (initialMessage.data['route'] != null) {
          Navigator.of(context).pushNamed(initialMessage.data['route']);
        }
      }
    } catch (e) {
      debugPrint('❌ FCM setup error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error setting up notifications: $e')),
      );
    }
  }

  Future<String> _getUserRole(String uid) async {
    try {
      DocumentSnapshot userDoc =
      await FirebaseFirestore.instance.collection(Collections.users).doc(uid).get();
      if (userDoc.exists) {
        return (userDoc.data() as Map<String, dynamic>?)?['role'] ?? 'unknown';
      }
      DocumentSnapshot doctorDoc =
      await FirebaseFirestore.instance.collection(Collections.doctors).doc(uid).get();
      if (doctorDoc.exists) {
        return (doctorDoc.data() as Map<String, dynamic>?)?['role'] ?? 'unknown';
      }
      return 'unknown';
    } catch (e) {
      debugPrint('Failed to fetch user role: $e');
      return 'unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const LoginScreen();
        }
        return FutureBuilder<String>(
          future: _getUserRole(snapshot.data!.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: AppColors.background,
                body: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }
            if (roleSnapshot.hasError || !roleSnapshot.hasData) {
              debugPrint('Error or no role data: ${roleSnapshot.error}');
              return Scaffold(
                backgroundColor: AppColors.background,
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Error loading user role. Please try again.',
                        style: TextStyle(color: AppColors.error),
                      ),
                      TextButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final role = roleSnapshot.data!;
            switch (role) {
              case 'admin':
                return const AdminDashboard();
              case 'doctor':
                return const DoctorDashboard();
              default:
                FirebaseAuth.instance.signOut();
                return const LoginScreen();
            }
          },
        );
      },
    );
  }
}