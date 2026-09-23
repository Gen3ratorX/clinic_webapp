import 'package:clinic_web_dashboard/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class RegisterUserScreen extends StatefulWidget {
  const RegisterUserScreen({super.key});

  @override
  State<RegisterUserScreen> createState() => _RegisterUserScreenState();
}

class _RegisterUserScreenState extends State<RegisterUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _licenseController = TextEditingController();
  String _role = 'doctor';
  String? _specialization;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _specializations = const [
    'Cardiology',
    'Dermatology',
    'General Medicine',
    'Neurology',
    'Orthopedics',
    'Pediatrics',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        // Save current admin credentials before registration (you must prompt for this securely)
        final currentAdminEmail = 'admin@deseret.com'; // Replace with actual admin email
        final currentAdminPassword = 'Admin1234'; // Replace with actual password

        // Register user
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // Set up user data in Firestore
        if (_role == 'doctor') {
          await FirebaseFirestore.instance
              .collection(Collections.doctors)
              .doc(credential.user!.uid)
              .set({
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'role': _role,
            'licenseNumber': _licenseController.text.trim(),
            'specialization': _specialization ?? 'Not specified',
            'createdAt': Timestamp.now(),
            'status': 'active',
          }, SetOptions(merge: true));
        } else if (_role == 'admin') {
          await FirebaseFirestore.instance
              .collection(Collections.users)
              .doc(credential.user!.uid)
              .set({
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'role': _role,
            'createdAt': Timestamp.now(),
          }, SetOptions(merge: true));
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'User registered successfully!',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        // Sign back in as admin
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: currentAdminEmail,
          password: currentAdminPassword,
        );

        _resetForm();
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = switch (e.code) {
            'email-already-in-use' => 'This email is already registered.',
            'invalid-email' => 'Please enter a valid email address.',
            'weak-password' => 'Password must be at least 6 characters long.',
            _ => 'Registration failed. Please try again.',
          };
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Unable to save user data. Please check your connection: $e';
        });
      } finally {
        if (!mounted) return;
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _passwordController.clear();
    _licenseController.clear();
    if (mounted) {
      setState(() {
        _role = 'doctor';
        _specialization = null;
        _obscurePassword = true;
        _errorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('User Registration'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withOpacity(0.08),
                        ),
                        child: const Icon(Icons.person_add_rounded, size: 36, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Create new account',
                        style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Fill in the details below to register a new user.',
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Personal information',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                      ),
                      validator: (value) => value!.isEmpty ? 'Full name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                      ),
                      validator: (value) {
                        if (value!.isEmpty) return 'Email address is required';
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
                      ),
                      validator: (value) {
                        if (value!.isEmpty) return 'Phone number is required';
                        if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(value)) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) {
                        if (value!.isEmpty) return 'Password is required';
                        if (value.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Professional information',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _role,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        prefixIcon: Icon(Icons.work_outline_rounded, size: 20),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                        DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _role = value!;
                          _licenseController.clear();
                          _specialization = null;
                        });
                      },
                    ),
                    if (_role == 'doctor') ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _specialization,
                        decoration: const InputDecoration(
                          labelText: 'Specialization',
                          hintText: 'Select medical specialization',
                          prefixIcon: Icon(Icons.medical_services_outlined, size: 20),
                        ),
                        validator: (value) => _role == 'doctor' && value == null ? 'Please select a specialization' : null,
                        items: _specializations
                            .map((specialization) => DropdownMenuItem<String>(
                                  value: specialization,
                                  child: Text(specialization),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _specialization = value),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _licenseController,
                      enabled: _role != 'admin',
                      decoration: InputDecoration(
                        labelText: 'License number',
                        hintText: _role == 'admin' ? 'Not required for administrators' : 'Enter professional license number',
                        prefixIcon: const Icon(Icons.card_membership_outlined, size: 20),
                      ),
                      validator: (value) {
                        if (_role != 'admin' && value!.isEmpty) return 'License number is required';
                        if (_role != 'admin' && !RegExp(r'^[A-Za-z0-9]{6,}$').hasMatch(value!)) {
                          return 'License must be at least 6 alphanumeric characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.inter(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Create account'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
