import 'package:clinic_web_dashboard/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:async';

class DoctorAppointmentScreen extends StatefulWidget {
  const DoctorAppointmentScreen({super.key});

  @override
  State<DoctorAppointmentScreen> createState() => _DoctorAppointmentScreenState();
}

class _DoctorAppointmentScreenState extends State<DoctorAppointmentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime selectedDate = DateTime.now();
  DateTime? filterDate;
  User? _currentUser;
  String? _doctorId;
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';
  Map<String, dynamic>? _doctorInfo;
  Timer? _debounce;
  final Map<String, String> _patientNameCache = {};

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _initializeFirebase();
  }

  Future<void> _initializeFirebase() async {
    try {
      await Firebase.initializeApp();
      _currentUser = FirebaseAuth.instance.currentUser;
      if (_currentUser != null) {
        _doctorId = _currentUser!.uid;
        await _loadDoctorInfo();
      } else {
        _showSnackBar('Please sign in to view appointments.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error initializing app: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDoctorInfo() async {
    try {
      final doc = await _firestore.collection(Collections.doctors).doc(_doctorId).get();
      if (doc.exists) {
        setState(() => _doctorInfo = doc.data());
      } else {
        _showSnackBar('Doctor profile not found.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error loading profile: $e', isError: true);
    }
  }

  Future<String> _getPatientName(String userId) async {
    if (_patientNameCache.containsKey(userId)) {
      return _patientNameCache[userId]!;
    }

    try {
      final doc = await _firestore.collection(Collections.users).doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final firstName = data['firstName']?.toString() ?? '';
        final lastName = data['lastName']?.toString() ?? '';
        final fullName = '$firstName $lastName'.trim();
        _patientNameCache[userId] = fullName.isEmpty ? 'Unknown Patient' : fullName;
        return _patientNameCache[userId]!;
      }
      _patientNameCache[userId] = 'Unknown Patient';
      return 'Unknown Patient';
    } catch (e) {
      _showSnackBar('Error fetching patient name: $e', isError: true);
      _patientNameCache[userId] = 'Unknown Patient';
      return 'Unknown Patient';
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontSize: 14, color: Colors.white)),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search by patient name...',
                  hintStyle: GoogleFonts.inter(color: Colors.white70),
                  border: InputBorder.none,
                ),
              )
            : const Text('My Appointments'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
            tooltip: _isSearching ? 'Cancel search' : 'Search appointments',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Today'),
                Tab(text: 'Upcoming'),
                Tab(text: 'History'),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildDoctorInfoCard(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTodayTab(),
                _buildUpcomingTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorInfoCard() {
    if (_doctorInfo == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withOpacity(0.15),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dr. ${_doctorInfo!['name'] ?? 'Unknown'}',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                Text(
                  _doctorInfo!['specialization'] ?? 'Doctor',
                  style: GoogleFonts.inter(color: Colors.white.withOpacity(0.9), fontSize: 14),
                ),
                Text(
                  'License: ${_doctorInfo!['licenseNumber'] ?? 'N/A'}',
                  style: GoogleFonts.inter(color: Colors.white.withOpacity(0.75), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("Today's schedule"),
          const SizedBox(height: 14),
          _buildTodayStats(),
          const SizedBox(height: 22),
          _buildAppointmentsList(isToday: true),
        ],
      ),
    );
  }

  Widget _buildUpcomingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Filter by date'),
          const SizedBox(height: 14),
          _buildDateFilter(),
          const SizedBox(height: 22),
          _buildSectionTitle('Upcoming appointments'),
          const SizedBox(height: 14),
          _buildAppointmentsList(isUpcoming: true),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Filter by date'),
          const SizedBox(height: 14),
          _buildDateFilter(),
          const SizedBox(height: 22),
          _buildSectionTitle('Appointment history'),
          const SizedBox(height: 14),
          _buildAppointmentsList(isHistory: true),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
    );
  }

  Widget _buildTodayStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getTodayAppointmentsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final appointments = snapshot.data!.docs.where((doc) => _filterAppointment(doc)).toList();
        final total = appointments.length;
        final pending = appointments.where((doc) => doc['status'] == 'pending').length;
        final confirmed = appointments.where((doc) => doc['status'] == 'confirmed').length;
        final completed = appointments.where((doc) => doc['status'] == 'completed').length;

        return Row(
          children: [
            Expanded(child: _buildStatCard('Total', total.toString(), Icons.calendar_today_rounded, AppColors.primary)),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard('Pending', pending.toString(), Icons.pending_rounded, AppColors.warning)),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard('Confirmed', confirmed.toString(), Icons.check_circle_rounded, AppColors.success)),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard('Completed', completed.toString(), Icons.done_all_rounded, AppColors.secondary)),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          Text(title, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildDateFilter() {
    final isSelected = filterDate != null;

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: filterDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (date != null) {
                setState(() => filterDate = date);
                HapticFeedback.selectionClick();
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
                border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: isSelected ? 2 : 1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 16, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    filterDate == null ? 'Select date' : DateFormat('MMMM d, yyyy').format(filterDate!),
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: isSelected ? AppColors.primary : AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isSelected)
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: TextButton.icon(
              onPressed: () {
                setState(() => filterDate = null);
                HapticFeedback.selectionClick();
              },
              icon: const Icon(Icons.clear_rounded, size: 14, color: AppColors.error),
              label: Text('Clear', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.error)),
            ),
          ),
      ],
    );
  }

  Widget _buildAppointmentsList({bool isToday = false, bool isUpcoming = false, bool isHistory = false}) {
    Stream<QuerySnapshot> stream;

    if (isToday) {
      stream = _getTodayAppointmentsStream();
    } else if (isUpcoming) {
      stream = _getUpcomingAppointmentsStream();
    } else {
      stream = _getHistoryAppointmentsStream();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: GoogleFonts.inter(fontSize: 14)));
        }
        final appointments = snapshot.data!.docs.where((doc) => _filterAppointment(doc)).toList();

        if (appointments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today_rounded, size: 56, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                Text('No appointments found.', style: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final doc = appointments[index];
            final appointment = doc.data() as Map<String, dynamic>;
            final userId = appointment['userId']?.toString() ?? '';
            return FutureBuilder<String>(
              future: _getPatientName(userId),
              builder: (context, nameSnapshot) {
                final patientName = nameSnapshot.data ?? 'Loading...';
                return _buildAppointmentCard(doc.id, appointment, patientName, isHistory);
              },
            );
          },
        );
      },
    );
  }

  bool _filterAppointment(DocumentSnapshot doc) {
    if (_searchQuery.isEmpty) return true;
    final appointment = doc.data() as Map<String, dynamic>;
    final userId = appointment['userId']?.toString() ?? '';
    final patientName = _patientNameCache[userId]?.toLowerCase() ?? '';
    return patientName.contains(_searchQuery);
  }

  Widget _buildAppointmentCard(String appointmentId, Map<String, dynamic> appointment, String patientName, bool isHistory) {
    final date = (appointment['date'] as Timestamp?)?.toDate() ?? DateTime.now();
    final status = appointment['status'] as String? ?? 'unknown';
    final symptoms = appointment['symptoms']?.toString() ?? '';
    final statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: const Icon(Icons.person_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    Text(
                      appointment['type']?.toString() ?? 'Consultation',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 11, color: statusColor, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(DateFormat('MMMM d, yyyy').format(date), style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(width: 18),
              const Icon(Icons.access_time_rounded, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(appointment['timeSlot']?.toString() ?? 'N/A', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          if (symptoms.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.medical_services_outlined, size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Symptoms: $symptoms', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _buildReportsSection(appointmentId),
          if (!isHistory && status == 'pending') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateAppointmentStatus(appointmentId, 'confirmed'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                    child: const Text('Confirm'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateAppointmentStatus(appointmentId, 'canceled'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ],
          if (!isHistory && status == 'confirmed') ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _updateAppointmentStatus(appointmentId, 'completed'),
                child: const Text('Mark as completed'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'confirmed':
        return AppColors.success;
      case 'completed':
        return AppColors.secondary;
      case 'canceled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildReportsSection(String appointmentId) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_outlined, size: 17, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Medical reports',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showAddReportDialog(appointmentId),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add report'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildReportsList(appointmentId),
        ],
      ),
    );
  }

  Widget _buildReportsList(String appointmentId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection(Collections.appointments)
          .doc(appointmentId)
          .collection(Collections.reports)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(10),
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No reports available', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
            ),
          );
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            final report = doc.data() as Map<String, dynamic>;
            return _buildReportItem(appointmentId, doc.id, report);
          }).toList(),
        );
      },
    );
  }

  Widget _buildReportItem(String appointmentId, String reportId, Map<String, dynamic> report) {
    final createdAt = (report['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final hasAttachment = report['attachmentUrl'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  report['title']?.toString() ?? 'Medical Report',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ),
              if (hasAttachment) const Icon(Icons.attach_file_rounded, size: 16, color: AppColors.textSecondary),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _showEditReportDialog(appointmentId, reportId, report);
                      break;
                    case 'delete':
                      _deleteReport(appointmentId, reportId);
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
                icon: const Icon(Icons.more_vert_rounded, size: 16, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('MMM d, yyyy - h:mm a').format(createdAt),
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (report['content']?.toString().isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(
              report['content'],
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (hasAttachment) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _openAttachment(report['attachmentUrl']),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.file_present_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      report['attachmentName']?.toString() ?? 'Attachment',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddReportDialog(String appointmentId) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String? attachmentPath;
    String? attachmentName;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add medical report', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Report title',
                      errorText: titleController.text.trim().isEmpty && isUploading ? 'Title is required' : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: contentController,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Report content', alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: isUploading
                            ? null
                            : () async {
                                final result = await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['pdf'],
                                );
                                if (result != null) {
                                  setState(() {
                                    attachmentPath = result.files.single.path;
                                    attachmentName = result.files.single.name;
                                  });
                                  HapticFeedback.selectionClick();
                                }
                              },
                        icon: const Icon(Icons.attach_file_rounded, size: 16),
                        label: const Text('Attach PDF'),
                      ),
                      const SizedBox(width: 10),
                      if (attachmentName != null)
                        Expanded(
                          child: Text(attachmentName!, style: GoogleFonts.inter(fontSize: 12), overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUploading
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty) {
                        setState(() => isUploading = true);
                        _showSnackBar('Please enter a report title', isError: true);
                        return;
                      }

                      setState(() => isUploading = true);

                      try {
                        String? attachmentUrl;

                        if (attachmentPath != null) {
                          final file = File(attachmentPath!);
                          final fileName = '${DateTime.now().millisecondsSinceEpoch}_$attachmentName';
                          final ref = _storage.ref().child('reports/$appointmentId/$fileName');
                          await ref.putFile(file);
                          attachmentUrl = await ref.getDownloadURL();
                        }

                        await _firestore
                            .collection(Collections.appointments)
                            .doc(appointmentId)
                            .collection(Collections.reports)
                            .add({
                          'title': titleController.text.trim(),
                          'content': contentController.text.trim(),
                          'attachmentUrl': attachmentUrl,
                          'attachmentName': attachmentName,
                          'createdAt': Timestamp.now(),
                          'updatedAt': Timestamp.now(),
                          'doctorId': _doctorId,
                        });

                        if (context.mounted) Navigator.pop(context);
                        HapticFeedback.lightImpact();
                        _showSnackBar('Report added successfully');
                        await _sendReportNotification(appointmentId, titleController.text.trim());
                      } catch (e) {
                        _showSnackBar('Error adding report: $e', isError: true);
                      } finally {
                        setState(() => isUploading = false);
                      }
                    },
              child: isUploading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Add report'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditReportDialog(String appointmentId, String reportId, Map<String, dynamic> report) {
    final titleController = TextEditingController(text: report['title']);
    final contentController = TextEditingController(text: report['content']);
    String? attachmentPath;
    String? attachmentName = report['attachmentName'];
    String? currentAttachmentUrl = report['attachmentUrl'];
    bool isUploading = false;
    bool removeCurrentAttachment = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit medical report', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Report title',
                      errorText: titleController.text.trim().isEmpty && isUploading ? 'Title is required' : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: contentController,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Report content', alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 14),
                  if (currentAttachmentUrl != null && !removeCurrentAttachment) ...[
                    Row(
                      children: [
                        const Icon(Icons.attach_file_rounded, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Current: ${attachmentName ?? 'Attachment'}', style: GoogleFonts.inter(fontSize: 12)),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() => removeCurrentAttachment = true);
                            HapticFeedback.selectionClick();
                          },
                          icon: const Icon(Icons.close_rounded, size: 16),
                          tooltip: 'Remove attachment',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: isUploading
                            ? null
                            : () async {
                                final result = await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['pdf'],
                                );
                                if (result != null) {
                                  setState(() {
                                    attachmentPath = result.files.single.path;
                                    attachmentName = result.files.single.name;
                                    removeCurrentAttachment = true;
                                  });
                                  HapticFeedback.selectionClick();
                                }
                              },
                        icon: const Icon(Icons.attach_file_rounded, size: 16),
                        label: Text(currentAttachmentUrl != null ? 'Replace PDF' : 'Attach PDF'),
                      ),
                      const SizedBox(width: 10),
                      if (attachmentPath != null)
                        Expanded(
                          child: Text('New: $attachmentName', style: GoogleFonts.inter(fontSize: 12), overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUploading
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty) {
                        setState(() => isUploading = true);
                        _showSnackBar('Please enter a report title', isError: true);
                        return;
                      }

                      setState(() => isUploading = true);

                      try {
                        String? newAttachmentUrl = currentAttachmentUrl;
                        String? newAttachmentName = attachmentName;

                        if (removeCurrentAttachment) {
                          newAttachmentUrl = null;
                          newAttachmentName = null;
                        }

                        if (attachmentPath != null) {
                          final file = File(attachmentPath!);
                          final fileName = '${DateTime.now().millisecondsSinceEpoch}_$attachmentName';
                          final ref = _storage.ref().child('reports/$appointmentId/$fileName');
                          await ref.putFile(file);
                          newAttachmentUrl = await ref.getDownloadURL();
                          newAttachmentName = attachmentName;
                        }

                        await _firestore
                            .collection(Collections.appointments)
                            .doc(appointmentId)
                            .collection(Collections.reports)
                            .doc(reportId)
                            .update({
                          'title': titleController.text.trim(),
                          'content': contentController.text.trim(),
                          'attachmentUrl': newAttachmentUrl,
                          'attachmentName': newAttachmentName,
                          'updatedAt': Timestamp.now(),
                        });

                        if (context.mounted) Navigator.pop(context);
                        HapticFeedback.lightImpact();
                        _showSnackBar('Report updated successfully');
                      } catch (e) {
                        _showSnackBar('Error updating report: $e', isError: true);
                      } finally {
                        setState(() => isUploading = false);
                      }
                    },
              child: isUploading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Update report'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteReport(String appointmentId, String reportId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete report', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
        content: const Text('Are you sure you want to delete this report? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _firestore
                    .collection(Collections.appointments)
                    .doc(appointmentId)
                    .collection(Collections.reports)
                    .doc(reportId)
                    .delete();

                if (context.mounted) Navigator.pop(context);
                HapticFeedback.lightImpact();
                _showSnackBar('Report deleted successfully');
              } catch (e) {
                _showSnackBar('Error deleting report: $e', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openAttachment(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        HapticFeedback.selectionClick();
      } else {
        _showSnackBar('Could not open attachment', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error opening attachment: $e', isError: true);
    }
  }

  Stream<QuerySnapshot> _getTodayAppointmentsStream() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection(Collections.appointments)
        .where('doctorId', isEqualTo: _doctorId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('date')
        .orderBy('timeSlot')
        .snapshots();
  }

  Stream<QuerySnapshot> _getUpcomingAppointmentsStream() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final startOfTomorrow = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);

    Query query = _firestore
        .collection(Collections.appointments)
        .where('doctorId', isEqualTo: _doctorId)
        .where('status', whereIn: ['pending', 'confirmed'])
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfTomorrow))
        .orderBy('date');

    if (filterDate != null) {
      final startOfDay = DateTime(filterDate!.year, filterDate!.month, filterDate!.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay)).where('date', isLessThan: Timestamp.fromDate(endOfDay));
    }

    return query.snapshots();
  }

  Stream<QuerySnapshot> _getHistoryAppointmentsStream() {
    Query query = _firestore
        .collection(Collections.appointments)
        .where('doctorId', isEqualTo: _doctorId)
        .where('status', whereIn: ['completed', 'canceled'])
        .orderBy('date', descending: true);

    if (filterDate != null) {
      final startOfDay = DateTime(filterDate!.year, filterDate!.month, filterDate!.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay)).where('date', isLessThan: Timestamp.fromDate(endOfDay));
    }

    return query.snapshots();
  }

  void _updateAppointmentStatus(String appointmentId, String newStatus) async {
    try {
      final appointmentDoc = await _firestore.collection(Collections.appointments).doc(appointmentId).get();
      if (!appointmentDoc.exists) {
        _showSnackBar('Appointment not found', isError: true);
        return;
      }

      final appointmentData = appointmentDoc.data()!;
      final userId = appointmentData['userId'];
      await _getPatientName(userId);

      await _firestore.collection(Collections.appointments).doc(appointmentId).update({
        'status': newStatus,
        'updatedAt': Timestamp.now(),
      });

      String notificationTitle = 'Appointment Update';
      String notificationBody = '';

      switch (newStatus) {
        case 'confirmed':
          notificationBody = 'Your appointment with Dr. ${_doctorInfo?['name'] ?? 'Doctor'} has been confirmed.';
          break;
        case 'canceled':
          notificationBody = 'Your appointment with Dr. ${_doctorInfo?['name'] ?? 'Doctor'} has been canceled.';
          break;
        case 'completed':
          notificationBody = 'Your appointment with Dr. ${_doctorInfo?['name'] ?? 'Doctor'} has been completed.';
          break;
      }

      if (notificationBody.isNotEmpty) {
        await _sendNotification(userId, notificationTitle, notificationBody);
      }

      HapticFeedback.lightImpact();
      _showSnackBar('Appointment ${newStatus.toLowerCase()} successfully.');
    } catch (e) {
      _showSnackBar('Error updating appointment: $e', isError: true);
    }
  }

  Future<void> _sendNotification(String userId, String title, String body) async {
    try {
      final userDoc = await _firestore.collection(Collections.users).doc(userId).get();
      if (!userDoc.exists) {
        debugPrint('User document not found for ID: $userId');
        return;
      }

      final userData = userDoc.data()!;
      final fcmToken = userData['fcmToken'];

      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('No FCM token found for user: $userId');
        return;
      }

      await _firestore.collection(Collections.notifications).add({
        'to': fcmToken,
        'title': title,
        'body': body,
        'data': {
          'type': 'appointment_update',
          'userId': userId,
          'doctorId': _doctorId,
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        },
        'timestamp': FieldValue.serverTimestamp(),
        'processed': false,
        'retryCount': 0,
      });

      await _firestore.collection(Collections.users).doc(userId).collection(Collections.notifications).add({
        'title': title,
        'body': body,
        'type': 'appointment_update',
        'doctorId': _doctorId,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      debugPrint('Notification queued successfully for user: $userId');
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  Future<void> _sendReportNotification(String appointmentId, String reportTitle) async {
    try {
      final appointmentDoc = await _firestore.collection(Collections.appointments).doc(appointmentId).get();
      if (!appointmentDoc.exists) return;

      final appointmentData = appointmentDoc.data()!;
      final userId = appointmentData['userId'];

      await _sendNotification(
        userId,
        'New Medical Report',
        'Dr. ${_doctorInfo?['name'] ?? 'Your doctor'} has added a new report: $reportTitle',
      );
    } catch (e) {
      debugPrint('Error sending report notification: $e');
    }
  }
}
