import 'package:clinic_web_dashboard/constants/app_constants.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_dashboard.dart';

class PatientRecordsScreen extends StatefulWidget {
  const PatientRecordsScreen({super.key});

  @override
  State<PatientRecordsScreen> createState() => _PatientRecordsScreenAdminState();
}

class _PatientRecordsScreenAdminState extends State<PatientRecordsScreen> {
  List<Map<String, String>> _allPatients = [];
  List<Map<String, String>> _filteredPatients = [];
  String? _selectedPatientId;
  String? _selectedPatientName;
  Map<String, TextEditingController> _controllers = {};
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchPatients();
    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), _filterPatients);
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _fetchPatients() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance.collection(Collections.users).get();
      List<Map<String, String>> patients = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, 'name': _constructDisplayName(data)};
      }).toList();

      patients.sort((a, b) => a['name']!.compareTo(b['name']!));

      setState(() {
        _allPatients = patients;
        _filteredPatients = List.from(_allPatients);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch patients: $e';
        _isLoading = false;
      });
    }
  }

  String _constructDisplayName(Map<String, dynamic> data) {
    String firstName = (data['firstName']?.toString() ?? '').trim();
    String lastName = (data['lastName']?.toString() ?? '').trim();
    String name = (data['name']?.toString() ?? '').trim();
    String displayName = (data['displayName']?.toString() ?? '').trim();

    if (firstName.isNotEmpty && lastName.isNotEmpty) return '$firstName $lastName';
    if (name.isNotEmpty) return name;
    if (displayName.isNotEmpty) return displayName;
    if (firstName.isNotEmpty) return firstName;
    if (lastName.isNotEmpty) return lastName;
    return 'Unknown Patient';
  }

  void _filterPatients() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredPatients = query.isEmpty
          ? List.from(_allPatients)
          : _allPatients.where((p) => p['name']!.toLowerCase().contains(query)).toList();
    });
  }

  void _selectPatient(String? id) {
    if (id == null) return;
    final selectedPatient = _allPatients.firstWhere((p) => p['id'] == id);
    setState(() {
      _selectedPatientId = id;
      _selectedPatientName = selectedPatient['name'];
      _controllers = {
        'allergies': TextEditingController(),
        'medicalConditions': TextEditingController(),
        'height': TextEditingController(),
        'weight': TextEditingController(),
        'bloodGroup': TextEditingController(),
      };
    });
    _loadPatientData(id);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _selectedPatientId = null;
      _selectedPatientName = null;
    });
  }

  Widget _buildSearchSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patient search',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    Text(
                      'Find and view patient records',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by patient name...',
              prefixIcon: const Icon(Icons.person_search_rounded, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: _clearSearch,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          if (_filteredPatients.isNotEmpty)
            _buildPatientDropdown()
          else if (_searchController.text.isNotEmpty)
            _buildNoResultsWidget(),
          if (_filteredPatients.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '${_filteredPatients.length} patient(s) found',
                style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPatientDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedPatientId,
      decoration: const InputDecoration(labelText: 'Patient'),
      hint: const Text('Select patient'),
      items: _filteredPatients.map((patient) {
        return DropdownMenuItem(value: patient['id'], child: Text(patient['name']!));
      }).toList(),
      onChanged: _selectPatient,
      isExpanded: true,
    );
  }

  Widget _buildNoResultsWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_off_rounded, color: AppColors.warning, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No results found', style: GoogleFonts.inter(color: AppColors.warning, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('No patients match "${_searchController.text}"', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientRecord() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPatientHeader(),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 20),
          _buildMedicalRecordsForm(),
        ],
      ),
    );
  }

  Widget _buildPatientHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedPatientName ?? 'Unknown Patient',
                style: GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Medical records',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMedicalRecordsForm() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildRecordCard(
                controller: _controllers['bloodGroup']!,
                label: 'Blood group',
                icon: Icons.bloodtype_rounded,
                color: AppColors.error,
                hint: 'A+, B-, O+, AB-',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildRecordCard(
                controller: _controllers['height']!,
                label: 'Height (cm)',
                icon: Icons.height_rounded,
                color: AppColors.secondary,
                hint: '175',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildRecordCard(
          controller: _controllers['weight']!,
          label: 'Weight (kg)',
          icon: Icons.monitor_weight_rounded,
          color: AppColors.success,
          hint: '70',
        ),
        const SizedBox(height: 16),
        _buildRecordCard(
          controller: _controllers['allergies']!,
          label: 'Allergies',
          icon: Icons.warning_amber_rounded,
          color: AppColors.warning,
          hint: 'List known allergies...',
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        _buildRecordCard(
          controller: _controllers['medicalConditions']!,
          label: 'Medical conditions',
          icon: Icons.medical_information_rounded,
          color: const Color(0xFF7C3AED),
          hint: 'List current medical conditions...',
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildRecordCard({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    String? hint,
    int maxLines = 1,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            readOnly: true,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _loadPatientData(String patientId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection(Collections.users).doc(patientId).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _controllers['allergies']!.text = data['allergies']?.toString() ?? '';
          _controllers['medicalConditions']!.text = data['conditions']?.toString() ?? '';
          _controllers['height']!.text = data['height']?.toString() ?? '';
          _controllers['weight']!.text = data['weight']?.toString() ?? '';
          _controllers['bloodGroup']!.text = data['bloodGroup']?.toString() ?? '';
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load patient data');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildErrorMessage() {
    if (_errorMessage == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Error', style: GoogleFonts.inter(color: AppColors.error, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(_errorMessage!, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.error, size: 20),
            onPressed: () => setState(() => _errorMessage = null),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Patient Records'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const AdminDashboard()),
            );
          },
        ),
        actions: [
          if (_selectedPatientId != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _loadPatientData(_selectedPatientId!),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildErrorMessage(),
                  _buildSearchSection(),
                  if (_selectedPatientId != null)
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection(Collections.users).doc(_selectedPatientId).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Container(
                            margin: const EdgeInsets.all(16),
                            child: Text('Error: ${snapshot.error}', style: GoogleFonts.inter(color: AppColors.error)),
                          );
                        }

                        if (!snapshot.hasData) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator(color: AppColors.primary),
                            ),
                          );
                        }

                        return _buildPatientRecord();
                      },
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
