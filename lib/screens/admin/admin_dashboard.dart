import 'package:clinic_web_dashboard/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'register_user_screen.dart';
import 'appointments_screen.dart';
import 'patient_records_screen.dart';
import 'admin_profile_screen.dart';

const double _mobileBreakpoint = 900;
const double _sidebarExpandedWidth = 240;
const double _sidebarCollapsedWidth = 76;

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _isSidebarExpanded = true;
  int _selectedIndex = 0;
  String _adminName = 'Admin';

  final List<Map<String, dynamic>> _sidebarItems = const [
    {'title': 'Overview', 'icon': Icons.dashboard_rounded},
    {'title': 'Register User', 'icon': Icons.person_add_alt_1_rounded},
    {'title': 'Appointments', 'icon': Icons.calendar_today_rounded},
    {'title': 'Patient Records', 'icon': Icons.folder_shared_rounded},
    {'title': 'Profile', 'icon': Icons.person_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadAdminName();
  }

  Future<void> _loadAdminName() async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final snapshot = await FirebaseFirestore.instance
          .collection(Collections.users)
          .doc(userId)
          .get();
      final data = snapshot.data();
      if (mounted) {
        setState(() => _adminName = data?['name'] ?? 'Admin');
      }
    } catch (e) {
      debugPrint('Error loading admin name: $e');
    }
  }

  void _onSidebarItemTap(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _logout(BuildContext context) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await FirebaseFirestore.instance.collection(Collections.presence).doc(userId).update({
          'online': false,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
      await FirebaseAuth.instance.signOut();
      if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      debugPrint('Logout error: $e');
      if (context.mounted) {
        _showSnackBar(context, 'Error logging out: $e', isError: true);
      }
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'Log out',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          content: Text(
            'Are you sure you want to log out of your admin account?',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _logout(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Log out'),
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
        );
      },
    );
  }

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
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

  Widget _getCurrentScreen() {
    switch (_selectedIndex) {
      case 0:
        return AdminOverviewScreen(adminName: _adminName);
      case 1:
        return const RegisterUserScreen();
      case 2:
        return const AppointmentsScreen();
      case 3:
        return const PatientRecordsScreen();
      case 4:
        return const AdminProfileScreen();
      default:
        return AdminOverviewScreen(adminName: _adminName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < _mobileBreakpoint;

        final content = AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey(_selectedIndex),
            child: _getCurrentScreen(),
          ),
        );

        if (isMobile) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: Text(_sidebarItems[_selectedIndex]['title']),
            ),
            drawer: Drawer(
              backgroundColor: Colors.white,
              child: SafeArea(
                child: _buildSidebarContent(expanded: true, closeOnTap: true),
              ),
            ),
            body: content,
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: _isSidebarExpanded ? _sidebarExpandedWidth : _sidebarCollapsedWidth,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(right: BorderSide(color: AppColors.border)),
                ),
                child: _buildSidebarContent(expanded: _isSidebarExpanded, closeOnTap: false),
              ),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebarContent({required bool expanded, required bool closeOnTap}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Row(
            mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'images/Logo.jpg',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 36,
                    height: 36,
                    color: AppColors.primary,
                    child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
              if (expanded) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Deseret Hospital',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (expanded && !closeOnTap)
                IconButton(
                  icon: const Icon(Icons.menu_open_rounded, size: 20, color: AppColors.textSecondary),
                  onPressed: () => setState(() => _isSidebarExpanded = false),
                  tooltip: 'Collapse',
                ),
            ],
          ),
        ),
        if (!expanded)
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppColors.textSecondary),
            onPressed: () => setState(() => _isSidebarExpanded = true),
            tooltip: 'Expand',
          ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            itemCount: _sidebarItems.length,
            itemBuilder: (context, index) {
              return _buildSidebarItem(
                icon: _sidebarItems[index]['icon'],
                title: _sidebarItems[index]['title'],
                expanded: expanded,
                isSelected: _selectedIndex == index,
                onTap: () {
                  _onSidebarItemTap(index);
                  if (closeOnTap) Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: _buildSidebarItem(
            icon: Icons.logout_rounded,
            title: 'Logout',
            expanded: expanded,
            isSelected: false,
            isDestructive: true,
            onTap: () => _showLogoutDialog(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String title,
    required bool expanded,
    required bool isSelected,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final Color fg = isDestructive
        ? AppColors.error
        : (isSelected ? AppColors.primary : AppColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Tooltip(
            message: expanded ? '' : title,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: expanded ? 14 : 0, vertical: 12),
              child: Row(
                mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 21, color: fg),
                  if (expanded) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: fg,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminOverviewScreen extends StatefulWidget {
  final String adminName;

  const AdminOverviewScreen({super.key, this.adminName = 'Admin'});

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final horizontalPadding = width > 1200 ? 40.0 : (width > 700 ? 28.0 : 16.0);

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(width),
              const SizedBox(height: 28),
              Text(
                'Overview',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              FutureBuilder<Map<String, dynamic>>(
                future: _fetchDashboardData(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildCardGrid(width, _buildLoadingCards());
                  }
                  if (snapshot.hasError) {
                    return _buildErrorWidget(snapshot.error.toString());
                  }
                  return _buildCardGrid(width, _buildDataCards(context, snapshot.data!));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(double width) {
    final isSmall = width < 500;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good ${_getGreeting()}',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                isSmall ? widget.adminName : 'Welcome back, ${widget.adminName}',
                style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.notifications_outlined, color: AppColors.primary, size: 22),
        ),
      ],
    );
  }

  int _crossAxisCount(double width) {
    if (width > 1400) return 4;
    if (width > 1000) return 3;
    if (width > 640) return 2;
    return 1;
  }

  Widget _buildCardGrid(double width, List<Widget> cards) {
    final columns = _crossAxisCount(width);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: columns,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: cards,
    );
  }

  List<Widget> _buildLoadingCards() {
    return List.generate(4, (index) => _cardShell(
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
          ),
        ));
  }

  List<Widget> _buildDataCards(BuildContext context, Map<String, dynamic> data) {
    return [
      _buildStatCard(
        title: "Today's Appointments",
        value: data['appointments']?.toString() ?? '0',
        subtitle: 'Scheduled visits',
        icon: Icons.calendar_today_rounded,
        onTap: () => Navigator.pushNamed(context, '/appointments'),
      ),
      _buildStatCard(
        title: 'Active Staff',
        value: data['staff']?.toString() ?? '0',
        subtitle: 'Medical professionals',
        icon: Icons.local_hospital_rounded,
      ),
      _buildActionCard(
        title: 'Register User',
        subtitle: 'Add new medical staff',
        icon: Icons.person_add_alt_1_rounded,
        onTap: () => Navigator.pushNamed(context, '/register'),
      ),
      _buildActionCard(
        title: 'Patient Records',
        subtitle: 'View all patient data',
        icon: Icons.folder_shared_rounded,
        onTap: () => Navigator.pushNamed(context, '/patient-records'),
      ),
    ];
  }

  Widget _cardShell({required Widget child, VoidCallback? onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return _cardShell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: AppColors.primary),
          ),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return _cardShell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: AppColors.secondary),
          ),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, size: 40, color: AppColors.error),
          const SizedBox(height: 12),
          Text(
            'Unable to load dashboard',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.error),
          ),
          const SizedBox(height: 4),
          Text(
            'Please try again later or contact support',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  Future<Map<String, dynamic>> _fetchDashboardData() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final appointments = await FirebaseFirestore.instance
        .collection(Collections.appointments)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    final doctors = await FirebaseFirestore.instance.collection(Collections.doctors).get();

    return {
      'appointments': appointments.docs.length,
      'staff': doctors.docs.length,
    };
  }
}
