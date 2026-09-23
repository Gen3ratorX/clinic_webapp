import 'package:clinic_web_dashboard/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isSaving = false;
  bool _showPasswordChange = false;
  bool _showCurrentPassword = true;
  bool _showNewPassword = true;
  bool _showConfirmPassword = true;
  String? _originalName;
  String? _originalEmail;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection(Collections.doctors)
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          _nameController.text = data['name'] ?? '';
          _emailController.text = data['email'] ?? '';
          _originalName = data['name'] ?? '';
          _originalEmail = data['email'] ?? '';
        }
      }
    } catch (e) {
      _showSnackBar('Unable to load profile. Please check your connection and try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection(Collections.doctors)
              .doc(user.uid)
              .update({
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
          });
          _originalName = _nameController.text.trim();
          _originalEmail = _emailController.text.trim();
          _showSnackBar('Profile updated successfully!');
        }
      } catch (e) {
        _showSnackBar('Failed to update profile. Please try again later.', isError: true);
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _changePassword() async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showSnackBar('Please fill in all password fields.', isError: true);
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnackBar('New password and confirmation do not match.', isError: true);
      return;
    }
    if (_newPasswordController.text.length < 8) {
      _showSnackBar('New password must be at least 8 characters long.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final credential = EmailAuthProvider.credential(
            email: user.email!, password: _currentPasswordController.text);
        try {
          await user.reauthenticateWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          debugPrint('Reauthentication error: ${e.code} - ${e.message}');
          if (e.code == 'wrong-password' || e.code == 'invalid-credential' || e.code == 'user-mismatch') {
            _showSnackBar('Current password is incorrect.', isError: true);
            if (mounted) setState(() => _isSaving = false);
            return;
          } else if (e.code == 'user-not-found' || e.code == 'invalid-email') {
            _showSnackBar('Authentication error. Please sign out and sign in again.', isError: true);
            if (mounted) setState(() => _isSaving = false);
            return;
          } else if (e.code == 'too-many-requests') {
            _showSnackBar('Too many attempts. Please try again later.', isError: true);
            if (mounted) setState(() => _isSaving = false);
            return;
          }
          rethrow;
        }

        try {
          await user.updatePassword(_newPasswordController.text);
          _showSnackBar('Password updated successfully!');
          setState(() => _showPasswordChange = false);
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        } on FirebaseAuthException catch (e) {
          String errorMessage;
          switch (e.code) {
            case 'weak-password':
              errorMessage = 'New password is too weak. Please use a stronger password.';
              break;
            case 'too-many-requests':
              errorMessage = 'Too many attempts. Please try again later.';
              break;
            default:
              errorMessage = 'Failed to update password. Please try again.';
          }
          _showSnackBar(errorMessage, isError: true);
        }
      } else {
        _showSnackBar('No user is signed in. Please sign in again.', isError: true);
      }
    } catch (e) {
      debugPrint('Unexpected error: $e');
      _showSnackBar('An unexpected error occurred. Please check your connection and try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetForm() {
    setState(() {
      _nameController.text = _originalName ?? '';
      _emailController.text = _originalEmail ?? '';
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_rounded : Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.local_hospital_rounded, color: AppColors.primary, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Doctor profile',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                'Manage your medical profile',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AppColors.textSecondary,
            size: 20,
          ),
          onPressed: onToggleVisibility,
        ),
      ),
    );
  }

  Widget _buildPasswordChangeSection() {
    if (!_showPasswordChange) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 20),
        _buildPasswordField(
          controller: _currentPasswordController,
          label: 'Current password',
          obscureText: _showCurrentPassword,
          onToggleVisibility: () => setState(() => _showCurrentPassword = !_showCurrentPassword),
          validator: (value) => value!.isEmpty ? 'Please enter your current password' : null,
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          controller: _newPasswordController,
          label: 'New password',
          obscureText: _showNewPassword,
          onToggleVisibility: () => setState(() => _showNewPassword = !_showNewPassword),
          validator: (value) {
            if (value!.isEmpty) return 'Please enter a new password';
            if (value.length < 8) return 'Password must be at least 8 characters';
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          controller: _confirmPasswordController,
          label: 'Confirm new password',
          obscureText: _showConfirmPassword,
          onToggleVisibility: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
          validator: (value) {
            if (value!.isEmpty) return 'Please confirm your new password';
            if (value != _newPasswordController.text) return 'Passwords do not match';
            return null;
          },
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _changePassword,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.shield_outlined, size: 18),
            label: Text(_isSaving ? 'Updating...' : 'Update password'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Doctor Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileHeader(),
                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 24),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Doctor name',
                                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                                ),
                                validator: (value) => (value?.isEmpty ?? true) ? 'Please enter your name' : null,
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
                                  if (value!.isEmpty) return 'Please enter your email';
                                  if (!value.contains('@')) return 'Please enter a valid email';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isSaving ? null : _saveProfile,
                                      icon: _isSaving
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : const Icon(Icons.save_rounded, size: 18),
                                      label: Text(_isSaving ? 'Saving...' : 'Save changes'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _resetForm,
                                      child: const Text('Cancel'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => setState(() => _showPasswordChange = !_showPasswordChange),
                            icon: Icon(_showPasswordChange ? Icons.expand_less_rounded : Icons.lock_reset_rounded, size: 18),
                            label: Text(_showPasswordChange ? 'Hide password change' : 'Change password'),
                          ),
                        ),
                        _buildPasswordChangeSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
