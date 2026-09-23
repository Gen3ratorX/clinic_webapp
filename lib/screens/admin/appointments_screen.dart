import 'package:clinic_web_dashboard/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> with SingleTickerProviderStateMixin {
  DateTime? _selectedDate;
  String? _selectedDoctor;
  String? _selectedStatus;
  Map<String, Map<String, dynamic>> _doctorsCache = {};
  List<Map<String, dynamic>> _doctors = [];
  bool _isLoading = true;
  bool _isFiltersExpanded = false;
  Map<String, Map<String, dynamic>> _usersCache = {};
  late AnimationController _filterAnimationController;
  late Animation<double> _filterAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _filterAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _filterAnimation = CurvedAnimation(
      parent: _filterAnimationController,
      curve: Curves.easeInOut,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0.5).animate(_filterAnimationController);

    _fetchDoctors();
    _setupDoctorsListener();
    _setupUsersListener();
  }

  @override
  void dispose() {
    _filterAnimationController.dispose();
    super.dispose();
  }

  void _toggleFilters() {
    setState(() => _isFiltersExpanded = !_isFiltersExpanded);
    if (_isFiltersExpanded) {
      _filterAnimationController.forward();
    } else {
      _filterAnimationController.reverse();
    }
  }

  void _fetchDoctors() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection(Collections.doctors).get();

      setState(() {
        _doctors = snapshot.docs.map((doc) => {
              'id': doc.id,
              'name': doc['name'],
              'specialization': doc['specialization'] ?? 'Not specified',
            }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error fetching doctors: $e');
    }
  }

  void _setupDoctorsListener() {
    FirebaseFirestore.instance.collection(Collections.doctors).snapshots().listen((snapshot) {
      setState(() {
        _doctorsCache = {for (var doc in snapshot.docs) doc.id: doc.data()};
      });
    }, onError: (e) {
      _showErrorSnackBar('Error listening to doctors: $e');
    });
  }

  void _setupUsersListener() {
    FirebaseFirestore.instance.collection(Collections.users).snapshots().listen((snapshot) {
      setState(() {
        _usersCache = {for (var doc in snapshot.docs) doc.id: doc.data()};
      });
    }, onError: (e) {
      _showErrorSnackBar('Error listening to users: $e');
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Stream<QuerySnapshot> _getAppointmentsStream() {
    Query query = FirebaseFirestore.instance.collection(Collections.appointments);

    if (_selectedDate != null) {
      final startOfDay = Timestamp.fromDate(DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day));
      final endOfDay = Timestamp.fromDate(_selectedDate!.add(const Duration(days: 1)));
      query = query.where('date', isGreaterThanOrEqualTo: startOfDay).where('date', isLessThan: endOfDay);
    }
    if (_selectedDoctor != null && _selectedDoctor!.isNotEmpty) {
      query = query.where('doctorId', isEqualTo: _selectedDoctor);
    }
    if (_selectedStatus != null && _selectedStatus!.isNotEmpty) {
      query = query.where('status', isEqualTo: _selectedStatus);
    }

    return query.orderBy('date', descending: true).snapshots();
  }

  void _clearFilters() {
    setState(() {
      _selectedDate = null;
      _selectedDoctor = null;
      _selectedStatus = null;
    });
    _showSuccessSnackBar('Filters cleared successfully');
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return AppColors.secondary;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Icons.schedule_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_selectedDate != null) count++;
    if (_selectedDoctor != null) count++;
    if (_selectedStatus != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Appointments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _fetchDoctors();
              _showSuccessSnackBar('Data refreshed');
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildFilterSection(),
                _buildStatsSection(),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.event_note_rounded, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Appointments list',
                          style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  _buildAppointmentsList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _toggleFilters,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filters',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        if (_activeFiltersCount > 0)
                          Text(
                            '$_activeFiltersCount active filter${_activeFiltersCount > 1 ? 's' : ''}',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                          ),
                      ],
                    ),
                  ),
                  if (_activeFiltersCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        '$_activeFiltersCount',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  const SizedBox(width: 12),
                  RotationTransition(
                    turns: _rotationAnimation,
                    child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 24),
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _filterAnimation,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 16),
                  _buildFilterControls(),
                  if (_activeFiltersCount > 0) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear_all_rounded, size: 18),
                        label: const Text('Clear all filters'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterControls() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildDateFilter()),
            const SizedBox(width: 12),
            Expanded(child: _buildStatusFilter()),
          ],
        ),
        const SizedBox(height: 12),
        _buildDoctorFilter(),
      ],
    );
  }

  Widget _buildStatsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(Collections.appointments).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final appointments = snapshot.data!.docs;
        final total = appointments.length;
        final scheduled = appointments.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'scheduled').length;
        final completed = appointments.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'completed').length;
        final cancelled = appointments.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'cancelled').length;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(child: _buildStatCard('Total', total, Icons.event_rounded, AppColors.primary)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard('Scheduled', scheduled, Icons.schedule_rounded, AppColors.secondary)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard('Completed', completed, Icons.check_circle_rounded, AppColors.success)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard('Cancelled', cancelled, Icons.cancel_rounded, AppColors.error)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilter() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (date != null) setState(() => _selectedDate = date);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: _selectedDate != null ? AppColors.primary : AppColors.border, width: _selectedDate != null ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
          color: _selectedDate != null ? AppColors.primary.withOpacity(0.05) : Colors.transparent,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 16, color: _selectedDate != null ? AppColors.primary : AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Date',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: _selectedDate != null ? AppColors.primary : AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _selectedDate == null ? 'Any date' : _formatDate(_selectedDate!),
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _selectedDoctor != null ? AppColors.primary : AppColors.border, width: _selectedDoctor != null ? 2 : 1),
        borderRadius: BorderRadius.circular(12),
        color: _selectedDoctor != null ? AppColors.primary.withOpacity(0.05) : Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_hospital_rounded, size: 16, color: _selectedDoctor != null ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Doctor',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: _selectedDoctor != null ? AppColors.primary : AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              hint: Text('Any doctor', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              value: _selectedDoctor,
              isExpanded: true,
              items: _doctors.map<DropdownMenuItem<String>>((doctor) {
                return DropdownMenuItem<String>(
                  value: doctor['id'] as String,
                  child: Text('${doctor['name']} (${doctor['specialization']})', style: GoogleFonts.inter(fontSize: 13)),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedDoctor = value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _selectedStatus != null ? AppColors.primary : AppColors.border, width: _selectedStatus != null ? 2 : 1),
        borderRadius: BorderRadius.circular(12),
        color: _selectedStatus != null ? AppColors.primary.withOpacity(0.05) : Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: _selectedStatus != null ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Status',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: _selectedStatus != null ? AppColors.primary : AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              hint: Text('Any status', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              value: _selectedStatus,
              isExpanded: true,
              items: ['scheduled', 'completed', 'cancelled'].map((status) {
                return DropdownMenuItem(value: status, child: Text(status.toUpperCase(), style: GoogleFonts.inter(fontSize: 13)));
              }).toList(),
              onChanged: (value) => setState(() => _selectedStatus = value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList() {
    return _isLoading
        ? const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        : StreamBuilder<QuerySnapshot>(
            stream: _getAppointmentsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                );
              }
              if (snapshot.hasError) {
                return _buildErrorState();
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState();
              }
              final appointments = snapshot.data!.docs;
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: appointments.length,
                itemBuilder: (context, index) => _buildAppointmentCard(appointments[index]),
              );
            },
          );
  }

  Widget _buildErrorState() {
    return SizedBox(
      height: 260,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Error loading appointments',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Please check your connection and try again',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 260,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.event_busy_rounded, size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'No appointments found',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Try adjusting your filters or check back later',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(QueryDocumentSnapshot appointmentDoc) {
    final appointment = appointmentDoc.data() as Map<String, dynamic>;
    final doctorId = appointment['doctorId'] as String? ?? '';
    final userId = appointment['userId'] as String? ?? '';
    final doctorName = appointment['doctorName'] as String? ?? (_doctorsCache[doctorId]?['name'] ?? 'Unknown Doctor');
    final firstName = _usersCache[userId]?['firstName'] ?? '';
    final lastName = _usersCache[userId]?['lastName'] ?? '';
    final patientName = '$firstName $lastName'.trim().isEmpty ? 'Unknown Patient' : '$firstName $lastName';
    final date = (appointment['date'] as Timestamp?)?.toDate() ?? DateTime.now();
    final timeSlot = appointment['timeSlot'] as String? ?? 'N/A';
    final status = appointment['status'] as String? ?? 'Unknown';
    final department = appointment['department'] as String? ?? 'Not specified';
    final type = appointment['type'] as String? ?? 'N/A';
    final statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getStatusIcon(status), size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        status.toUpperCase(),
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.4),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded, size: 15, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      '${_formatDate(date)} · $timeSlot',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildInfoSection('Doctor', doctorName, Icons.local_hospital_rounded)),
                    Container(height: 36, width: 1, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 16)),
                    Expanded(child: _buildInfoSection('Patient', patientName, Icons.person_rounded)),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildInfoSection('Department', department, Icons.business_rounded)),
                    Container(height: 36, width: 1, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 16)),
                    Expanded(child: _buildInfoSection('Type', type, Icons.category_rounded)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(
            value,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
