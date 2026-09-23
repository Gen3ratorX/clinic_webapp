import 'package:clinic_web_dashboard/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:html' as html;
import 'package:clinic_web_dashboard/screens/auth/auth_gate.dart';
import 'package:clinic_web_dashboard/screens/auth/login_screen.dart';
import 'package:clinic_web_dashboard/screens/auth/forgot_password_screen.dart';
import 'package:clinic_web_dashboard/screens/admin/admin_dashboard.dart';
import 'package:clinic_web_dashboard/screens/doctor/doctor_dashboard.dart';
import 'package:clinic_web_dashboard/screens/admin/register_user_screen.dart';
import 'package:clinic_web_dashboard/screens/admin/appointments_screen.dart';
import 'package:clinic_web_dashboard/screens/admin/patient_records_screen.dart';
import 'package:clinic_web_dashboard/screens/admin/admin_profile_screen.dart';
import 'package:clinic_web_dashboard/screens/doctor/doctor_profile_screen.dart';
import 'package:clinic_web_dashboard/screens/doctor/doctor_appointment_screen.dart';
import 'package:clinic_web_dashboard/screens/user_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDWj0DM8fBB00c5FvuTLCvDDiIQbRhnDOU",
      authDomain: "pentecost-clinic.firebaseapp.com",
      databaseURL: "https://pentecost-clinic-default-rtdb.firebaseio.com",
      projectId: "pentecost-clinic",
      storageBucket: "pentecost-clinic.appspot.com",
      messagingSenderId: "272709137362",
      appId: "1:272709137362:web:93b6bc3f76e5191827ce0b",
    ),
  );
  debugPrint('✅ Firebase initialized: ${Firebase.app().name}');

  // Register FCM service worker
  if (html.window.navigator.serviceWorker != null) {
    html.window.navigator.serviceWorker!
        .register('firebase-messaging-sw.js')
        .then((reg) => debugPrint('✅ Service Worker registered: ${reg.scope}'))
        .catchError((e) => debugPrint('❌ SW registration failed: $e'));
  }

  runApp(const ClinicWebDashboard());
}

class ClinicWebDashboard extends StatelessWidget {
  const ClinicWebDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deseret Hospital Dashboard',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
        textTheme: GoogleFonts.interTextTheme().apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border),
          ),
        ),
        dividerTheme: DividerThemeData(color: AppColors.border, thickness: 1),
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/admin': (context) => const AdminDashboard(),
        '/doctor': (context) => const DoctorDashboard(),
        '/register': (context) => const RegisterUserScreen(),
        '/appointments': (context) => const AppointmentsScreen(),
        '/patient-records': (context) => const PatientRecordsScreen(),
        '/admin-profile': (context) => const AdminProfileScreen(),
        '/doctor-profile': (context) => const DoctorProfileScreen(),
        '/doctor-appointments': (context) => const DoctorAppointmentScreen(),
        '/user-list': (context) => const UserListScreen(),
        '/forgotPassword': (context) => const ForgotPasswordScreen(),
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const UnknownRouteScreen(),
        );
      },
    );
  }
}

class UnknownRouteScreen extends StatelessWidget {
  const UnknownRouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Page Not Found'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text(
              'Page Not Found',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The page you are looking for does not exist.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}