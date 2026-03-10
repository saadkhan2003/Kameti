import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/sync_service.dart';
import '../../services/auto_sync_service.dart';
import '../../services/realtime_sync_service.dart';
import '../../services/localization_service.dart';
import '../../services/toast_service.dart';
import '../../services/review_service.dart';
import '../../models/committee.dart';
import '../../models/member.dart';
import '../../utils/page_transitions.dart';
import 'package:committee_app/ui/theme/theme.dart';
import '../../ui/widgets/ads/native_ad_widget.dart';
import '../../ui/widgets/empty_state_widget.dart';
import '../../ui/widgets/sync_status_widget.dart';
import '../../services/sync_status_service.dart';
import '../settings_screen.dart';
import '../home_screen.dart';
import 'create_committee_screen.dart';
import 'committee_detail_screen.dart';
import '../viewer/join_committee_screen.dart';
import 'profile_screen.dart';
import 'contact_screen.dart';
import 'about_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';
import '../admin/admin_config_screen.dart';
import '../../services/remote_config_service.dart';

class HostDashboardScreen extends StatefulWidget {
  const HostDashboardScreen({super.key});

  @override
  State<HostDashboardScreen> createState() => _HostDashboardScreenState();
}

class _HostDashboardScreenState extends State<HostDashboardScreen>
    with SingleTickerProviderStateMixin {
  static const Color _bgTop = AppColors.bg;
  static const Color _bgBottom = AppColors.bgAlt;
  static const Color _surface = AppColors.surface;
  static const Color _primary = AppColors.primary;
  static const Color _success = AppColors.success;
  static const Color _danger = AppColors.error;
  static const Color _textPrimary = AppColors.textPrimary;
  static const Color _textSecondary = AppColors.textSecondary;

  final _authService = AuthService();
  final _dbService = DatabaseService();
  final _syncService = SyncService();
  final _autoSyncService = AutoSyncService();
  final _realtimeSyncService = RealtimeSyncService();
  List<Committee> _activeCommittees = [];
  List<Committee> _archivedCommittees = [];
  bool _isSyncing = false;
  late TabController _tabController;
  Timer? _emailVerificationTimer;
  final _syncStatusService = SyncStatusService();

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);
    _loadCommittees();

    // Start real-time sync listener
    final userId = _authService.currentUser?.id ?? '';
    if (userId.isNotEmpty) {
      _realtimeSyncService.onDataChanged = _loadCommittees;
      _realtimeSyncService.startListening(userId);
    }

    // Ensure data appears even if splash sync timed out or was delayed.
    // Uses silent sync (no toasts) and respects in-flight/cooldown logic in SyncService.
    Future.microtask(_syncDataSilentOnStart);

    // Schedule in-app review prompt after dashboard renders.
    // ReviewService internally checks whether all conditions are met.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) ReviewService().maybeShowReview(context);
      });
    });

    // Start email verification check timer
    _startEmailVerificationCheck();
  }

  Future<void> _syncDataSilentOnStart() async {
    if (_isSyncing) return;

    final hostId = _authService.currentUser?.id ?? '';
    if (hostId.isEmpty) return;

    setState(() => _isSyncing = true);
    _syncStatusService.setSyncing();

    try {
      final result = await _syncService.syncAll(hostId);
      if (!mounted) return;

      if (result.success) {
        _syncStatusService.setSynced();
        _loadCommittees();
      } else {
        _syncStatusService.setError(result.message);
      }
    } catch (_) {
      if (mounted) {
        _syncStatusService.setError('Startup sync failed');
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _startEmailVerificationCheck() {
    final user = _authService.currentUser;
    // Check if email confirmed (Supabase uses emailConfirmedAt)
    if (user != null && user.emailConfirmedAt == null) {
      _emailVerificationTimer = Timer.periodic(const Duration(seconds: 3), (
        timer,
      ) async {
        await _authService.reloadUser();
        if (_authService.isEmailVerified) {
          timer.cancel();
          if (mounted) {
            setState(() {}); // Refresh UI to hide banner
            ToastService.success(context, 'Email verified successfully! ✓');
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _emailVerificationTimer?.cancel();
    _realtimeSyncService.stopListening();
    _tabController.dispose();
    super.dispose();
  }

  void _loadCommittees() {
    if (!mounted) return;
    final userId = _authService.currentUser?.id ?? '';
    final all = _dbService.getHostedCommittees(userId);
    setState(() {
      _activeCommittees = all.where((c) => !c.isArchived).toList();
      _archivedCommittees = all.where((c) => c.isArchived).toList();
    });
  }

  // Sync with feedback (for manual sync tap)
  Future<void> _syncData() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);
    _syncStatusService.setSyncing();

    final hostId = _authService.currentUser?.id ?? '';
    final result = await _syncService.syncAll(hostId, force: true);

    if (mounted) {
      setState(() => _isSyncing = false);

      if (result.success) {
        _syncStatusService.setSynced();
        _loadCommittees();
      } else {
        _syncStatusService.setError(result.message);
        ToastService.error(context, result.message);
      }
    }
  }

  Future<void> _logout() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  void _showArchivedSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.cFFE9EEFC,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        AppIcons.archive_rounded,
                        color: _primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Archived Kametis',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_archivedCommittees.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'No archived kametis',
                        style: const TextStyle(color: _textSecondary),
                      ),
                    ),
                  )
                else
                  ...(_archivedCommittees
                      .map(
                        (committee) => ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.mutedSurface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              AppIcons.group,
                              color: _textSecondary,
                            ),
                          ),
                          title: Text(
                            committee.name,
                            style: const TextStyle(color: _textPrimary),
                          ),
                          subtitle: Text(
                            'Archived on ${committee.archivedAt != null ? "${committee.archivedAt!.day}/${committee.archivedAt!.month}/${committee.archivedAt!.year}" : "Unknown"}',
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: TextButton(
                            onPressed: () async {
                              await _autoSyncService.unarchiveCommittee(
                                committee,
                              );
                              _loadCommittees();
                              if (mounted) Navigator.pop(context);
                            },
                            child: const Text('Restore'),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => CommitteeDetailScreen(
                                      committee: committee,
                                    ),
                              ),
                            );
                          },
                        ),
                      )
                      .toList()),
              ],
            ),
          ),
    );
  }

  Future<void> _archiveCommittee(Committee committee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            backgroundColor: _surface,
            title: const Text('Archive Kameti?'),
            content: Text(
              'This will move "${committee.name}" to the archived section. You can restore it later.',
              style: const TextStyle(color: _textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: _textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Archive'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await _autoSyncService.archiveCommittee(committee);
      _loadCommittees();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${committee.name} archived'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await _autoSyncService.unarchiveCommittee(committee);
                _loadCommittees();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteCommittee(Committee committee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            backgroundColor: _surface,
            title: const Text(
              'Delete Kameti?',
              style: TextStyle(
                color: _textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              'This will permanently delete "${committee.name}" and all its data. This cannot be undone.',
              style: const TextStyle(color: _textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: _textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _danger,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final hostId = _authService.currentUser?.id ?? '';
      await _autoSyncService.deleteCommittee(committee.id, hostId);
      _loadCommittees();
      if (mounted) {
        ToastService.error(context, '${committee.name} deleted');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final displayName =
        user?.userMetadata?['full_name'] as String? ??
        user?.email?.split('@')[0] ??
        'Host';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _bgTop,
        appBar: AppBar(
          backgroundColor: _bgTop,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          title: Text(
            'My Kametis',
            style: GoogleFonts.inter(
              color: _textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 24,
            ),
          ),
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: Builder(
            builder:
                (context) => IconButton(
                  icon: const Icon(AppIcons.menu_rounded, color: _primary),
                  tooltip: 'Menu',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
          ),
          actions: [
            if (_archivedCommittees.isNotEmpty)
              TextButton.icon(
                onPressed: _showArchivedSheet,
                icon: const Icon(
                  AppIcons.archive_outlined,
                  size: 18,
                  color: _textSecondary,
                ),
                label: Text(
                  '${_archivedCommittees.length}',
                  style: const TextStyle(
                    color: _textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            SyncStatusWidget(compact: true, onTap: _syncData),
            const SizedBox(width: 8),
          ],
        ),
        drawer: _buildDrawer(context),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgTop, _bgBottom],
            ),
          ),
          child: RefreshIndicator(
            onRefresh: _syncData,
            color: _primary,
            backgroundColor: _surface,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // Email Verification Banner
                if (user != null && user.emailConfirmedAt == null)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    decoration: BoxDecoration(
                      color: AppColors.cFFFFF7ED,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cFFFED7AA),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.cFFFED7AA,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                AppIcons.mark_email_unread_outlined,
                                color: AppColors.cFFB45309,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Confirm Your Email',
                                    style: TextStyle(
                                      color: AppColors.cFF9A3412,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Please verify your email address',
                                    style: TextStyle(
                                      color: AppColors.cFFB45309,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                await _authService.sendEmailVerification();
                                if (mounted) {
                                  ToastService.success(
                                    context,
                                    'Verification link sent!',
                                  );
                                }
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: AppColors.cFF9A3412,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text('Confirm'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Welcome Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.darkBg.withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.cFFE9EEFC,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              AppIcons.waving_hand_rounded,
                              color: _primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Welcome, $displayName',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: _textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cFFF8FAFF,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cFFD0D9EE),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildHeaderStat(
                                value: '${_activeCommittees.length}',
                                label: 'Active',
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 28,
                              color: AppColors.cFFD0D9EE,
                            ),
                            Expanded(
                              child: _buildHeaderStat(
                                value:
                                    '${_activeCommittees.fold<int>(0, (sum, c) => sum + _dbService.getMembersByCommittee(c.id).length)}',
                                label: 'Members',
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 28,
                              color: AppColors.cFFD0D9EE,
                            ),
                            Expanded(
                              child: _buildHeaderStat(
                                value:
                                    _archivedCommittees.isEmpty
                                        ? '0'
                                        : '${_archivedCommittees.length}',
                                label: 'Archived',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildQuickAction(
                          icon: AppIcons.add_circle_outline_rounded,
                          title: 'Create New',
                          subtitle: 'Start committee',
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              ScalePageRoute(
                                page: const CreateCommitteeScreen(),
                              ),
                            );
                            if (result == true) _loadCommittees();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildQuickAction(
                          icon: AppIcons.archive_outlined,
                          title: 'Archived',
                          subtitle: '${_archivedCommittees.length} items',
                          onTap: _showArchivedSheet,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // View Payments Action Card
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const JoinCommitteeScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.cFFCCE6D8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.cFFECFDF3,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                AppIcons.visibility_rounded,
                                color: _success,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Joined a Kameti?',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: _textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'View Kameti Payments',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              AppIcons.chevron_right_rounded,
                              color: _textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Hosted Kametis',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Committees List
                if (_activeCommittees.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: _buildEmptyState(),
                  )
                else
                  ..._buildCommitteeListItems(),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              ScalePageRoute(page: const CreateCommitteeScreen()),
            );
            if (result == true) {
              _loadCommittees();
            }
          },
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          icon: const Icon(AppIcons.add_rounded),
          label: const Text('New Committee'),
        ),
      ),
    );
  }

  Widget _buildHeaderStat({required String value, required String label}) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: _textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.lightBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.cFFE9EEFC,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: _primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    final intValue = amount.toInt().toString();
    return intValue.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  String _frequencyLabel(String frequency) {
    if (frequency.isEmpty) return 'Cycle';
    return '${frequency[0].toUpperCase()}${frequency.substring(1).toLowerCase()}';
  }

  int _calculateDuePeriods(Committee committee, DateTime now) {
    final start = committee.startDate;
    if (now.isBefore(start)) return 0;

    if (committee.frequency == 'daily') {
      return now.difference(start).inDays + 1;
    }

    if (committee.frequency == 'weekly') {
      return (now.difference(start).inDays ~/ 7) + 1;
    }

    if (committee.frequency == 'monthly') {
      final monthsDiff =
          (now.year - start.year) * 12 + (now.month - start.month);
      final adjusted = now.day >= start.day ? monthsDiff + 1 : monthsDiff;
      return adjusted < 0 ? 0 : adjusted;
    }

    return (now.difference(start).inDays ~/ 30) + 1;
  }

  Map<String, dynamic> _calculateCommitteePaymentProgress(
    Committee committee,
    List<Member> members,
  ) {
    if (members.isEmpty) {
      return {
        'progress': 1.0,
        'pendingAmount': 0.0,
        'pendingCount': 0,
        'expectedDueCount': 0,
      };
    }

    final now = DateTime.now();
    final duePeriods = _calculateDuePeriods(committee, now);
    final expectedDueCount = duePeriods * members.length;

    if (expectedDueCount <= 0) {
      return {
        'progress': 1.0,
        'pendingAmount': 0.0,
        'pendingCount': 0,
        'expectedDueCount': 0,
      };
    }

    final paidCount =
        _dbService
            .getPaymentsByCommittee(committee.id)
            .where((payment) => payment.isPaid && !payment.date.isAfter(now))
            .length;

    final boundedPaid = paidCount.clamp(0, expectedDueCount);
    final pendingCount = (expectedDueCount - boundedPaid).clamp(
      0,
      expectedDueCount,
    );
    final pendingAmount = pendingCount * committee.contributionAmount;
    final progress =
        ((expectedDueCount - pendingCount) / expectedDueCount)
            .clamp(0.0, 1.0)
            .toDouble();

    return {
      'progress': progress,
      'pendingAmount': pendingAmount,
      'pendingCount': pendingCount,
      'expectedDueCount': expectedDueCount,
    };
  }

  Widget _buildDrawer(BuildContext context) {
    final user = _authService.currentUser;
    final displayName =
        user?.userMetadata?['full_name'] as String? ??
        user?.email?.split('@')[0] ??
        'Guest';
    final email = user?.email ?? 'Anonymous User';

    return Drawer(
      backgroundColor: _surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Drawer Header
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: AppColors.cFFDDE5F6, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.cFFE9EEFC,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(AppIcons.person, color: _primary, size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  displayName,
                  style: GoogleFonts.inter(
                    color: _textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  email,
                  style: GoogleFonts.inter(color: _textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),

          // Profile
          ListTile(
            leading: const Icon(AppIcons.person_outline, color: _textSecondary),
            title: Text(
              'profile'.tr,
              style: const TextStyle(color: _textPrimary),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),

          const Divider(color: AppColors.borderMuted),

          // About
          ListTile(
            leading: const Icon(AppIcons.info_outline, color: _textSecondary),
            title: Text(
              'about'.tr,
              style: const TextStyle(color: _textPrimary),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
          ),

          // Settings (Long-press for Admin Panel)
          ListTile(
            leading: const Icon(
              AppIcons.settings_outlined,
              color: _textSecondary,
            ),
            title: Text(
              'settings'.tr,
              style: const TextStyle(color: _textPrimary),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            onLongPress: () {
              // Hidden admin panel access with PIN protection
              Navigator.pop(context);
              _showAdminPinDialog(context);
            },
          ),

          // Terms & Conditions
          ListTile(
            leading: const Icon(
              AppIcons.article_outlined,
              color: _textSecondary,
            ),
            title: Text(
              'terms_conditions'.tr,
              style: const TextStyle(color: _textPrimary),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TermsScreen()),
              );
            },
          ),

          // Privacy Policy
          ListTile(
            leading: const Icon(
              AppIcons.privacy_tip_outlined,
              color: _textSecondary,
            ),
            title: Text(
              'privacy_policy'.tr,
              style: const TextStyle(color: _textPrimary),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyScreen(),
                ),
              );
            },
          ),

          // Contact Us
          ListTile(
            leading: const Icon(AppIcons.mail_outline, color: _textSecondary),
            title: Text(
              'contact_us'.tr,
              style: const TextStyle(color: _textPrimary),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ContactScreen()),
              );
            },
          ),

          const Divider(color: AppColors.borderMuted),

          // Logout
          ListTile(
            leading: const Icon(AppIcons.logout, color: _danger),
            title: Text('logout'.tr, style: const TextStyle(color: _danger)),
            onTap: () async {
              Navigator.pop(context);
              await _logout();
            },
          ),
        ],
      ),
    );
  }

  /// Builds the committee cards list with a native ad injected after the
  /// 2nd card (index 1). If there are 2 or fewer committees the ad appears
  /// at the end of the list. The ad is shown only once per screen.
  List<Widget> _buildCommitteeListItems() {
    // Inject the ad after the 2nd card; fall back to end of list
    const adInsertIndex = 2;
    final insertAt =
        _activeCommittees.length >= adInsertIndex
            ? adInsertIndex
            : _activeCommittees.length;

    final items = <Widget>[];
    for (var i = 0; i < _activeCommittees.length; i++) {
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildCommitteeCard(_activeCommittees[i]),
        ),
      );
      // Insert native ad at the designated position
      if (i + 1 == insertAt) {
        items.add(const NativeAdWidget());
      }
    }
    return items;
  }

  Widget _buildEmptyState() {
    return EmptyStateWidget(
      icon: AppIcons.group_off_rounded,
      title: 'No Kametis Yet',
      subtitle:
          'Create your first committee to get started and manage your savings groups',
      actionLabel: 'Create Kameti',
      actionIcon: AppIcons.add_rounded,
      onAction: () async {
        final result = await Navigator.push(
          context,
          ScalePageRoute(page: const CreateCommitteeScreen()),
        );
        if (result == true) _loadCommittees();
      },
    );
  }

  Widget _buildCommitteeCard(Committee committee) {
    final members = _dbService.getMembersByCommittee(committee.id);
    final targetMembers =
        committee.totalMembers > 0 ? committee.totalMembers : members.length;
    final totalPool = committee.contributionAmount * targetMembers;
    final paymentProgress = _calculateCommitteePaymentProgress(
      committee,
      members,
    );
    final progressValue = paymentProgress['progress'] as double;
    final pendingAmount = paymentProgress['pendingAmount'] as double;

    return Card(
      color: _surface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CommitteeDetailScreen(committee: committee),
            ),
          );
          _loadCommittees();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.cFFE9EEFC,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      AppIcons.group_rounded,
                      color: _primary,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          committee.name,
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_frequencyLabel(committee.frequency)} cycle • $targetMembers members',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(AppIcons.more, color: _textSecondary),
                    color: _surface,
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.cFFDCE5F6),
                    ),
                    onSelected: (value) {
                      if (value == 'archive') {
                        _archiveCommittee(committee);
                      } else if (value == 'delete') {
                        _deleteCommittee(committee);
                      }
                    },
                    itemBuilder:
                        (context) => [
                          PopupMenuItem(
                            value: 'archive',
                            child: Row(
                              children: [
                                const Icon(
                                  AppIcons.archive_outlined,
                                  size: 20,
                                  color: _textSecondary,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Archive',
                                  style: TextStyle(color: _textPrimary),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  AppIcons.delete_outline,
                                  size: 20,
                                  color: _danger,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: _danger),
                                ),
                              ],
                            ),
                          ),
                        ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cFFF8FAFF,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.cFFD0D9EE),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Per Cycle',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: _textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${committee.currency} ${_formatAmount(committee.contributionAmount)}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: _textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cFFF8FAFF,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.cFFD0D9EE),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Pool',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: _textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${committee.currency} ${_formatAmount(totalPool)}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: _textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        backgroundColor: AppColors.borderMuted,
                        color: pendingAmount <= 0 ? _success : _primary,
                        value: progressValue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          pendingAmount <= 0
                              ? AppColors.cFFECFDF3
                              : AppColors.cFFFEF2F2,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      pendingAmount <= 0
                          ? 'No Pending ✓'
                          : 'Pending ${committee.currency} ${_formatAmount(pendingAmount)}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color:
                            pendingAmount <= 0
                                ? AppColors.cFF047857
                                : AppColors.cFFB91C1C,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cFFE9EEFC,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () async {
                        await Clipboard.setData(
                          ClipboardData(text: committee.code),
                        );
                        if (mounted) {
                          ToastService.success(
                            context,
                            'Committee code copied',
                          );
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Code: ${committee.code}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: _primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            AppIcons.copy_rounded,
                            size: 12,
                            color: _primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.mutedSurface,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${committee.totalCycles} cycles',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: _textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdminPinDialog(BuildContext context) async {
    final pinController = TextEditingController();

    // Fetch PIN from remote config (or use default)
    final remoteConfig = RemoteConfigService();
    final correctPin = remoteConfig.getString(
      'admin_pin',
      defaultValue: '1234',
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: _surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Row(
              children: [
                const Icon(AppIcons.admin_panel_settings, color: _primary),
                const SizedBox(width: 12),
                const Text(
                  'Admin Access',
                  style: TextStyle(color: _textPrimary),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter admin PIN to continue',
                  style: TextStyle(color: _textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 16,
                    color: _textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••',
                    hintStyle: const TextStyle(
                      color: _textSecondary,
                      letterSpacing: 16,
                    ),
                    filled: true,
                    fillColor: AppColors.cFFF8FAFF,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Contact admin if you forgot the PIN',
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: _textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (pinController.text == correctPin) {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminConfigScreen(),
                      ),
                    );
                    ToastService.success(context, '🔧 Admin Panel Unlocked');
                  } else {
                    ToastService.error(context, '❌ Incorrect PIN');
                    pinController.clear();
                  }
                },
                child: const Text('Unlock'),
              ),
            ],
          ),
    );
  }
}
