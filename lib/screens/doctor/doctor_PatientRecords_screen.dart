import 'package:clinic_web_dashboard/constants/app_constants.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class DoctorPatientRecordsScreen extends StatefulWidget {
  final String doctorId;
  const DoctorPatientRecordsScreen({super.key, required this.doctorId});

  @override
  State<DoctorPatientRecordsScreen> createState() => _DoctorPatientRecordsScreenState();
}

class _DoctorPatientRecordsScreenState extends State<DoctorPatientRecordsScreen> {
  List<Map<String, String>> _allPatients = [];
  List<Map<String, String>> _filteredPatients = [];
  String? _selectedPatientId;
  String? _selectedPatientName;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _debounce;

  bool _showPrescriptionForm = false;
  bool _isSubmittingPrescription = false;
  String _selectedFrequencyType = 'times per day';
  String _selectedDurationType = 'days';
  final GlobalKey<FormState> _prescriptionFormKey = GlobalKey<FormState>();
  final TextEditingController _medicationController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _frequencyController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPatients();
    _searchController.addListener(_debouncedSearch);
  }

  void _debouncedSearch() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _filterPatients);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _medicationController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _durationController.dispose();
    _instructionsController.dispose();
    _notesController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchPatients() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance.collection(Collections.users).get();
      List<Map<String, String>> patients = snapshot.docs.map((doc) {
        final data = doc.data();
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
      _showPrescriptionForm = false;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _selectedPatientId = null;
      _selectedPatientName = null;
      _showPrescriptionForm = false;
    });
  }

  void _togglePrescriptionForm() {
    setState(() {
      _showPrescriptionForm = !_showPrescriptionForm;
    });

    if (!_showPrescriptionForm) {
      _clearPrescriptionForm();
    }
  }

  void _clearPrescriptionForm() {
    _medicationController.clear();
    _dosageController.clear();
    _frequencyController.clear();
    _durationController.clear();
    _instructionsController.clear();
    _notesController.clear();
    setState(() {
      _selectedFrequencyType = 'times per day';
      _selectedDurationType = 'days';
    });
  }

  Future<void> _submitPrescription() async {
    if (!_prescriptionFormKey.currentState!.validate()) return;
    if (_selectedPatientId == null) return;

    setState(() {
      _isSubmittingPrescription = true;
    });

    try {
      final now = DateTime.now();
      final prescriptionData = {
        'patientId': _selectedPatientId,
        'patientName': _selectedPatientName,
        'doctorId': widget.doctorId,
        'medication': _medicationController.text.trim(),
        'dosage': _dosageController.text.trim(),
        'frequency': '${_frequencyController.text.trim()} $_selectedFrequencyType',
        'duration': '${_durationController.text.trim()} $_selectedDurationType',
        'instructions': _instructionsController.text.trim(),
        'notes': _notesController.text.trim(),
        'prescribedAt': now,
        'status': 'active',
        'createdAt': now,
        'updatedAt': now,
      };

      final docRef = await FirebaseFirestore.instance.collection(Collections.prescriptions).add(prescriptionData);
      final prescriptionId = docRef.id;

      final prescriptionDataWithId = {
        ...prescriptionData,
        'id': prescriptionId,
      };

      await FirebaseFirestore.instance
          .collection(Collections.users)
          .doc(_selectedPatientId)
          .collection(Collections.prescriptions)
          .doc(prescriptionId)
          .set(prescriptionDataWithId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 12),
                Text('Prescription added successfully!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }

      _clearPrescriptionForm();
      _togglePrescriptionForm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to add prescription: $e')),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingPrescription = false;
        });
      }
    }
  }

  Stream<QuerySnapshot> _getPrescriptionHistory() {
    if (_selectedPatientId == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection(Collections.users)
        .doc(_selectedPatientId)
        .collection(Collections.prescriptions)
        .orderBy('prescribedAt', descending: true)
        .snapshots();
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
              Text('Find patient', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by patient name...',
              prefixIcon: const Icon(Icons.person_search_rounded, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: _clearSearch)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          if (_filteredPatients.isNotEmpty)
            _buildPatientDropdown()
          else if (_searchController.text.isNotEmpty)
            _buildNoResultsWidget(),
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
        color: AppColors.secondary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.secondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No patients found matching "${_searchController.text}"',
              style: GoogleFonts.inter(color: AppColors.secondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientRecord(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPatientHeader(),
          const SizedBox(height: 4),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildMedicalRecordsForm(data),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _togglePrescriptionForm,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text('Add prescription'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
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
      ),
    );
  }

  Widget _buildMedicalRecordsForm(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Patient information',
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildRecordCard(
                label: 'Blood group',
                value: data['bloodGroup']?.toString() ?? 'N/A',
                icon: Icons.bloodtype_rounded,
                color: AppColors.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildRecordCard(
                label: 'Height',
                value: data['height']?.toString() ?? 'N/A',
                unit: 'cm',
                icon: Icons.height_rounded,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildRecordCard(
          label: 'Weight',
          value: data['weight']?.toString() ?? 'N/A',
          unit: 'kg',
          icon: Icons.monitor_weight_rounded,
          color: AppColors.success,
        ),
        const SizedBox(height: 12),
        _buildRecordCard(
          label: 'Allergies',
          value: data['allergies']?.toString() ?? 'None reported',
          icon: Icons.warning_amber_rounded,
          color: AppColors.warning,
        ),
        const SizedBox(height: 12),
        _buildRecordCard(
          label: 'Medical conditions',
          value: data['conditions']?.toString() ?? 'None reported',
          icon: Icons.medical_information_rounded,
          color: const Color(0xFF7C3AED),
        ),
      ],
    );
  }

  Widget _buildRecordCard({
    required String label,
    required String value,
    String? unit,
    required IconData icon,
    required Color color,
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
          RichText(
            text: TextSpan(
              text: value,
              style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
              children: unit != null
                  ? [
                      TextSpan(
                        text: ' $unit',
                        style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ]
                  : [],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Form(
        key: _prescriptionFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.receipt_long_rounded, color: AppColors.success, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('New prescription', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        Text('for $_selectedPatientName', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _togglePrescriptionForm,
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextFormField(
                    controller: _medicationController,
                    decoration: const InputDecoration(labelText: 'Medication name', prefixIcon: Icon(Icons.medication_outlined, size: 20)),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Please enter medication name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _dosageController,
                    decoration: const InputDecoration(labelText: 'Dosage (e.g., 500mg, 1 tablet)', prefixIcon: Icon(Icons.science_outlined, size: 20)),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Please enter dosage' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _frequencyController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Frequency', prefixIcon: Icon(Icons.schedule_rounded, size: 20)),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Enter frequency' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedFrequencyType,
                          decoration: const InputDecoration(labelText: 'Unit'),
                          items: ['times per day', 'times per week', 'times per month', 'as needed']
                              .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                              .toList(),
                          onChanged: (value) => setState(() => _selectedFrequencyType = value!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _durationController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Duration', prefixIcon: Icon(Icons.calendar_today_rounded, size: 20)),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Enter duration' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedDurationType,
                          decoration: const InputDecoration(labelText: 'Unit'),
                          items: ['days', 'weeks', 'months', 'until finished']
                              .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                              .toList(),
                          onChanged: (value) => setState(() => _selectedDurationType = value!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _instructionsController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Instructions (e.g., Take with food)', prefixIcon: Icon(Icons.info_outline_rounded, size: 20)),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Please enter instructions' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Additional notes (optional)', prefixIcon: Icon(Icons.note_add_outlined, size: 20)),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmittingPrescription ? null : _submitPrescription,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                      child: _isSubmittingPrescription
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                                SizedBox(width: 12),
                                Text('Adding prescription...'),
                              ],
                            )
                          : const Text('Add prescription'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionHistory() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.history_rounded, color: AppColors.success, size: 20),
                ),
                const SizedBox(width: 14),
                Text('Prescription history', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: _getPrescriptionHistory(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator(color: AppColors.success)),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Error loading prescriptions: ${snapshot.error}', style: GoogleFonts.inter(color: AppColors.error)),
                      ),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.medication_outlined, size: 40, color: AppColors.textSecondary),
                        const SizedBox(height: 12),
                        Text('No prescriptions yet', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text('No prescriptions have been added for this patient.', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                );
              }
              final prescriptions = snapshot.data!.docs;
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: prescriptions.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final prescription = prescriptions[index].data() as Map<String, dynamic>;
                  return _buildPrescriptionCard(prescription);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionCard(Map<String, dynamic> prescription) {
    final prescribedAt = (prescription['prescribedAt'] as Timestamp?)?.toDate();
    final status = prescription['status'] ?? 'active';
    final isActive = status == 'active';
    final formattedDate = prescribedAt != null ? '${prescribedAt.day}/${prescribedAt.month}/${prescribedAt.year}' : 'Unknown Date';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? AppColors.success.withOpacity(0.05) : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isActive ? AppColors.success.withOpacity(0.3) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.medication_rounded, color: isActive ? AppColors.success : AppColors.textSecondary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  prescription['medication'] ?? 'Unknown Medication',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.success.withOpacity(0.15) : AppColors.border,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: isActive ? AppColors.success : AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text('Prescribed on: $formattedDate', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Dosage: ${prescription['dosage'] ?? 'N/A'}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Frequency: ${prescription['frequency'] ?? 'N/A'}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Duration: ${prescription['duration'] ?? 'N/A'}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(
            'Instructions: ${prescription['instructions'] ?? 'None'}',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (prescription['notes'] != null && prescription['notes'].isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Notes: ${prescription['notes']}',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), shape: BoxShape.circle),
              child: const Icon(Icons.people_outline_rounded, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text('No patients found', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'No patient records are available for you at the moment.',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Patient Records'),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetchPatients)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage != null
              ? Center(
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text('Something went wrong', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        Text(_errorMessage!, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _fetchPatients,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildSearchSection(),
                      if (_selectedPatientId != null) ...[
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection(Collections.users).doc(_selectedPatientId).snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Container(
                                margin: const EdgeInsets.all(16),
                                height: 160,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                              );
                            }
                            if (snapshot.hasError) {
                              return Container(
                                margin: const EdgeInsets.all(16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                                ),
                                child: Text('Error loading patient data: ${snapshot.error}', style: GoogleFonts.inter(color: AppColors.error)),
                              );
                            }
                            if (!snapshot.hasData || !snapshot.data!.exists) {
                              return Container(
                                margin: const EdgeInsets.all(16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                                ),
                                child: Text('Patient not found', style: GoogleFonts.inter(color: AppColors.warning)),
                              );
                            }
                            final data = snapshot.data!.data() as Map<String, dynamic>;
                            return Column(
                              children: [
                                _buildPatientRecord(data),
                                if (_showPrescriptionForm) _buildPrescriptionForm(),
                                _buildPrescriptionHistory(),
                              ],
                            );
                          },
                        ),
                      ] else if (_allPatients.isEmpty && !_isLoading)
                        _buildEmptyState(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}
