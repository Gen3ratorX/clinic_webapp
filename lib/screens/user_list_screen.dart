import 'package:clinic_web_dashboard/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:rxdart/rxdart.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  int _currentPage = 0;
  final int _itemsPerPage = 12;
  String _searchQuery = '';
  String _selectedRole = 'All';
  String _statusFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  Map<String, bool> _onlineUsers = {};
  final ValueNotifier<int> _onlineCountNotifier = ValueNotifier(0);
  bool _isLoadingPresence = true;

  @override
  void initState() {
    super.initState();
    _initializePresence();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _onlineCountNotifier.dispose();
    super.dispose();
  }

  void _initializePresence() async {
    setState(() => _isLoadingPresence = true);
    final userSnapshot = await FirebaseFirestore.instance.collection(Collections.users).get();
    final doctorSnapshot = await FirebaseFirestore.instance.collection(Collections.doctors).get();
    final users = [...userSnapshot.docs, ...doctorSnapshot.docs];
    _onlineUsers = {for (var user in users) user.id: false};

    final presenceStream = FirebaseFirestore.instance.collection(Collections.presence).snapshots();
    presenceStream.listen((snapshot) {
      for (final doc in snapshot.docs) {
        final userId = doc.id;
        final isOnline = doc.data()['online'] ?? false;
        if (_onlineUsers.containsKey(userId)) {
          _onlineUsers[userId] = isOnline;
        }
      }
      _onlineCountNotifier.value = _onlineUsers.values.where((online) => online).length;
      if (mounted) setState(() => _isLoadingPresence = false);
    });
  }

  List<QueryDocumentSnapshot> _filterUsers(List<QueryDocumentSnapshot> users) {
    return users.where((user) {
      final userData = user.data() as Map<String, dynamic>;
      final firstName = userData['firstName']?.toString().toLowerCase() ?? '';
      final lastName = userData['lastName']?.toString().toLowerCase() ?? '';
      final fullName = '$firstName $lastName';
      final role = userData['role']?.toString().toLowerCase() ?? (user.reference.parent.id == 'doctors' ? 'doctor' : 'user');
      final userId = user.id;
      final isOnline = _onlineUsers[userId] ?? false;

      if (_searchQuery.isNotEmpty && !fullName.contains(_searchQuery.toLowerCase())) return false;
      if (_selectedRole != 'All' && role != _selectedRole.toLowerCase()) return false;
      if (_statusFilter == 'Online' && !isOnline) return false;
      if (_statusFilter == 'Offline' && isOnline) return false;
      return true;
    }).toList();
  }

  void _refreshStats() {
    setState(() => _isLoadingPresence = true);
    _initializePresence();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshStats,
            tooltip: 'Refresh stats',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                StreamBuilder<List<QuerySnapshot>>(
                  stream: Rx.combineLatest2(
                    FirebaseFirestore.instance.collection(Collections.users).snapshots(),
                    FirebaseFirestore.instance.collection(Collections.doctors).snapshots(),
                    (QuerySnapshot users, QuerySnapshot doctors) => [users, doctors],
                  ),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return _buildStatsShimmer();
                    final users = [...snapshot.data![0].docs, ...snapshot.data![1].docs];
                    return ValueListenableBuilder<int>(
                      valueListenable: _onlineCountNotifier,
                      builder: (context, onlineCount, child) {
                        if (_isLoadingPresence) return _buildStatsShimmer();
                        final totalUsers = users.length;
                        final offlineCount = totalUsers - onlineCount;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatCard('Total', totalUsers.toString(), Icons.people_rounded),
                              _buildStatCard('Online', onlineCount.toString(), Icons.circle, color: Colors.greenAccent),
                              _buildStatCard('Offline', offlineCount.toString(), Icons.circle_outlined, color: Colors.white70),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search users...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onChanged: (value) => setState(() {
                          _searchQuery = value;
                          _currentPage = 0;
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedRole,
                        isExpanded: true,
                        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
                        items: ['All', 'Admin', 'Doctor', 'Patient']
                            .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                            .toList(),
                        onChanged: (value) => setState(() {
                          _selectedRole = value!;
                          _currentPage = 0;
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _statusFilter,
                        isExpanded: true,
                        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
                        items: ['All', 'Online', 'Offline']
                            .map((status) => DropdownMenuItem(value: status, child: Text(status)))
                            .toList(),
                        onChanged: (value) => setState(() {
                          _statusFilter = value!;
                          _currentPage = 0;
                        }),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<QuerySnapshot>>(
              stream: Rx.combineLatest2(
                FirebaseFirestore.instance.collection(Collections.users).snapshots(),
                FirebaseFirestore.instance.collection(Collections.doctors).snapshots(),
                (QuerySnapshot users, QuerySnapshot doctors) => [users, doctors],
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return _buildLoadingState();
                if (snapshot.hasError) {
                  debugPrint('Error fetching users: ${snapshot.error}');
                  return _buildErrorState();
                }
                if (!snapshot.hasData || (snapshot.data![0].docs.isEmpty && snapshot.data![1].docs.isEmpty)) return _buildEmptyState();

                final allUsers = [...snapshot.data![0].docs, ...snapshot.data![1].docs];
                final filteredUsers = _filterUsers(allUsers);
                final totalPages = (filteredUsers.length / _itemsPerPage).ceil();
                final startIndex = _currentPage * _itemsPerPage;
                final endIndex = (startIndex + _itemsPerPage).clamp(0, filteredUsers.length);
                final currentPageUsers = filteredUsers.sublist(startIndex, endIndex);

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Showing ${startIndex + 1}-$endIndex of ${filteredUsers.length}',
                              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
                          Text('Page ${_currentPage + 1} of ${totalPages == 0 ? 1 : totalPages}',
                              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: currentPageUsers.length,
                        itemBuilder: (context, index) {
                          final userDoc = currentPageUsers[index];
                          return _buildUserCard(userDoc, key: ValueKey(userDoc.id));
                        },
                      ),
                    ),
                    if (totalPages > 1)
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.white,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                              icon: const Icon(Icons.chevron_left_rounded, size: 20),
                              style: IconButton.styleFrom(
                                backgroundColor: _currentPage > 0 ? AppColors.primary : AppColors.border,
                                foregroundColor: _currentPage > 0 ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ...List.generate(totalPages.clamp(0, 5), (index) {
                              final pageNumber = index;
                              final isCurrentPage = pageNumber == _currentPage;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: ElevatedButton(
                                  onPressed: () => setState(() => _currentPage = pageNumber),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isCurrentPage ? AppColors.primary : AppColors.border,
                                    foregroundColor: isCurrentPage ? Colors.white : AppColors.textSecondary,
                                    minimumSize: const Size(36, 36),
                                    elevation: 0,
                                  ),
                                  child: Text('${pageNumber + 1}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
                                ),
                              );
                            }),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                              icon: const Icon(Icons.chevron_right_rounded, size: 20),
                              style: IconButton.styleFrom(
                                backgroundColor: _currentPage < totalPages - 1 ? AppColors.primary : AppColors.border,
                                foregroundColor: _currentPage < totalPages - 1 ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.white, size: 16),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(title, style: GoogleFonts.inter(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildStatsShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: Colors.grey[100]!,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildShimmerStatCard(Icons.people_rounded),
            _buildShimmerStatCard(Icons.circle),
            _buildShimmerStatCard(Icons.circle_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerStatCard(IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(height: 4),
        Container(
          width: 24,
          height: 16,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(height: 4),
        Container(
          width: 40,
          height: 10,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(4)),
        ),
      ],
    );
  }

  Widget _buildUserCard(QueryDocumentSnapshot userDoc, {Key? key}) {
    final user = userDoc.data() as Map<String, dynamic>;
    final userId = userDoc.id;
    final isDoctor = userDoc.reference.parent.id == 'doctors';
    final displayName = (user['firstName'] != null && user['lastName'] != null)
        ? '${user['firstName']} ${user['lastName']}'
        : user['name'] ?? 'Unnamed User';

    return StreamBuilder<Map<String, dynamic>?>(
      key: key,
      stream: FirebaseFirestore.instance.collection(Collections.presence).doc(userId).snapshots().map((doc) => doc.data()),
      builder: (context, presenceSnapshot) {
        if (!presenceSnapshot.hasData) return const SizedBox.shrink();
        final presence = presenceSnapshot.data!;
        final isOnline = presence['online'] ?? false;
        final lastSeenTimestamp = presence['lastSeen'];
        final lastSeen = lastSeenTimestamp != null
            ? _formatLastSeen(lastSeenTimestamp is Timestamp
                ? lastSeenTimestamp.toDate()
                : DateTime.fromMillisecondsSinceEpoch(lastSeenTimestamp as int))
            : 'Never';

        if (_onlineUsers[userId] != isOnline) {
          _onlineUsers[userId] = isOnline;
          _onlineCountNotifier.value = _onlineUsers.values.where((online) => online).length;
        }

        final avatarColor = _getAvatarColor(displayName);
        final roleColor = _getRoleColor(isDoctor ? 'doctor' : user['role']);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isOnline ? AppColors.success.withOpacity(0.3) : AppColors.border),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: avatarColor, shape: BoxShape.circle),
                              child: Center(
                                child: Text(
                                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            if (isOnline)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary, size: 20),
                          onSelected: (value) {},
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'view',
                              child: Row(children: [
                                const Icon(Icons.visibility_outlined, size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                const Text('View profile'),
                              ]),
                            ),
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(children: [
                                const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                const Text('Edit user'),
                              ]),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                                const SizedBox(width: 8),
                                const Text('Delete user'),
                              ]),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      displayName,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isDoctor ? 'Doctor' : user['role'] ?? 'User',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: roleColor),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isOnline ? AppColors.success : AppColors.textSecondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            isOnline ? 'Online' : lastSeen,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: isOnline ? AppColors.success : AppColors.textSecondary,
                              fontWeight: isOnline ? FontWeight.w500 : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() => const Center(child: CircularProgressIndicator(color: AppColors.primary));

  Widget _buildErrorState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Error loading users', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text('Please try again later', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _refreshStats, child: const Text('Retry')),
          ],
        ),
      );

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline_rounded, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text('No users found', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text('Users will appear here once registered', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );

  Color _getAvatarColor(String name) {
    const colors = [
      Color(0xFF3B82F6),
      Color(0xFFA855F7),
      Color(0xFF22C55E),
      Color(0xFFF97316),
      Color(0xFFEC4899),
      Color(0xFF14B8A6),
      Color(0xFF6366F1),
      Color(0xFFEF4444),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return const Color(0xFFE57373);
      case 'doctor':
        return const Color(0xFF64B5F6);
      case 'patient':
        return const Color(0xFFBA68C8);
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatLastSeen(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
