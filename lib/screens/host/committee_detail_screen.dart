import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/database_service.dart';
import '../../services/sync_service.dart';
import '../../services/auto_sync_service.dart';
import '../../models/committee.dart';
import '../../models/member.dart';
import 'member_management_screen.dart';
import 'payment_sheet_screen.dart';
import 'shuffle_members_screen.dart';
import 'committee_analytics_screen.dart';
import '../../ui/widgets/sync_status_widget.dart';

class CommitteeDetailScreen extends StatefulWidget {
  final Committee committee;

  const CommitteeDetailScreen({super.key, required this.committee});

  @override
  State<CommitteeDetailScreen> createState() => _CommitteeDetailScreenState();
}

class _CommitteeDetailScreenState extends State<CommitteeDetailScreen> {
  static const Color _bgTop = Color(0xFFF7F8FC);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF3347A8);
  static const Color _success = Color(0xFF059669);
  static const Color _warning = Color(0xFFD97706);
  static const Color _purple = Color(0xFF7C4DFF);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  final _dbService = DatabaseService();
  final _syncService = SyncService();
  final _autoSyncService = AutoSyncService();
  late Committee _committee;
  List<Member> _members = [];
  bool _showCollectionDetails = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _committee = widget.committee;
    _loadMembers();
  }

  void _loadMembers() {
    if (!mounted) return;
    setState(() {
      _members = _dbService.getMembersByCommittee(_committee.id);
    });
  }

  Future<void> _refreshCommittee() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      // Sync only this committee's members and payments
      await _syncService.syncMembers(_committee.id);
      await _syncService.syncPayments(_committee.id);

      // Reload from local DB
      _loadMembers();

      // Refresh committee data from cloud
      final updatedCommittee = _dbService.getCommitteeById(_committee.id);
      if (updatedCommittee != null && mounted) {
        setState(() => _committee = updatedCommittee);
      }
    } catch (e) {
      debugPrint('Refresh error: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _showShareOptions() {
    // Share committee info only (no member codes)
    String message =
        '📋 *${_committee.name}*\n\n'
        '*Committee Code:* ${_committee.code}\n'
        '*Contribution:* ${_committee.currency} ${_committee.contributionAmount.toInt()}\n'
        '*Duration:* ${_members.length} months\n\n'
        '_Download Committee App to view payments!_';
    Share.share(message, subject: '${_committee.name} - Committee Details');
  }

  void _showEditDialog() {
    final nameController = TextEditingController(text: _committee.name);
    final amountController = TextEditingController(
      text: _committee.contributionAmount.toInt().toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit Committee',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                style: GoogleFonts.inter(
                  color: _textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'Kameti Name',
                  labelStyle: const TextStyle(color: _textSecondary),
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(
                    Icons.group_outlined,
                    color: _textSecondary,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD0D9EE)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primary, width: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(
                  color: _textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'Contribution Amount',
                  labelStyle: const TextStyle(color: _textSecondary),
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD0D9EE)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primary, width: 1.6),
                  ),
                  prefixIcon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    width: 60,
                    child: Text(
                      _committee.currency,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: _textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final amount =
                      double.tryParse(amountController.text.trim()) ?? 0;

                  if (name.isEmpty || amount <= 0) return;

                  final updated = _committee.copyWith(
                    name: name,
                    contributionAmount: amount,
                  );
                  await _autoSyncService.saveCommittee(updated);
                  setState(() {
                    _committee = updated;
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save Changes'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation() {
    // Store reference to the scaffold messenger before showing dialog
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: _surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Delete Committee?',
              style: GoogleFonts.inter(
                color: _textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              'This will permanently delete "${_committee.name}" and all its members and payment records. This action cannot be undone.',
              style: const TextStyle(color: _textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: _textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(dialogContext); // Close dialog first

                  // Delete locally first (instant), cloud in background
                  await _autoSyncService.deleteCommittee(
                    _committee.id,
                    _committee.hostId,
                  );

                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: const Text('Kameti deleted'),
                      backgroundColor: _danger,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );

                  // Go back to dashboard immediately
                  navigator.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _danger,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
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

  String _frequencyLabel() {
    final frequency = _committee.frequency;
    if (frequency.isEmpty) return 'Cycle';
    return '${frequency[0].toUpperCase()}${frequency.substring(1).toLowerCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final paidMembers = _members.where((m) => m.hasReceivedPayout).length;
    final totalAmount = _committee.contributionAmount * _members.length;

    // Calculate total money collected from payments
    final payments = _dbService.getPaymentsByCommittee(_committee.id);
    final paidPayments = payments.where((p) => p.isPaid).length;
    final totalCollected = paidPayments * _committee.contributionAmount;

    // Calculate per payout amount
    final collectionInterval =
        _committee.frequency == 'daily'
            ? 1
            : _committee.frequency == 'weekly'
            ? 7
            : 30;
    final collectionsPerPayout =
        _committee.paymentIntervalDays ~/ collectionInterval;

    // Calculate actual collected for current payout cycle (match payment sheet logic)
    final now = DateTime.now();
    final payoutInterval = _committee.paymentIntervalDays;
    final startDate = _committee.startDate;
    final daysElapsed = now.difference(startDate).inDays;
    final currentPayoutCycle = daysElapsed ~/ payoutInterval;
    double currentCycleCollected = 0;
    final isMonthlyMonthly =
        _committee.frequency == 'monthly' && payoutInterval == 30;
    for (var member in _members) {
      for (var payment in payments.where(
        (p) => p.memberId == member.id && p.isPaid,
      )) {
        final dateDaysElapsed = payment.date.difference(startDate).inDays;
        final datePayoutCycle = dateDaysElapsed ~/ payoutInterval;
        if (datePayoutCycle == currentPayoutCycle) {
          if (isMonthlyMonthly) {
            // Only count payments for current month, no advance
            if (payment.date.month == now.month &&
                payment.date.year == now.year) {
              currentCycleCollected += _committee.contributionAmount;
            }
          } else {
            // For daily/monthly or weekly/monthly, include advance as they become due
            currentCycleCollected += _committee.contributionAmount;
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: _bgTop,
      appBar: AppBar(
        backgroundColor: _bgTop,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: _textPrimary,
        iconTheme: const IconThemeData(color: _textPrimary),
        title: Text(
          _committee.name,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: _textPrimary,
          ),
        ),
        elevation: 0,
        actions: [
          SyncStatusWidget(compact: true, onTap: _refreshCommittee),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.share_rounded, color: _textSecondary),
            onPressed: _showShareOptions,
            tooltip: 'Share Code',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: _textSecondary),
            color: _surface,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFDCE5F6)),
            ),
            onSelected: (value) {
              if (value == 'edit') {
                _showEditDialog();
              } else if (value == 'delete') {
                _showDeleteConfirmation();
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit, size: 18, color: _textSecondary),
                        const SizedBox(width: 8),
                        const Text(
                          'Edit Committee',
                          style: TextStyle(color: _textPrimary),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, size: 18, color: _danger),
                        const SizedBox(width: 8),
                        Text(
                          'Delete Committee',
                          style: TextStyle(color: _danger),
                        ),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshCommittee,
        color: _primary,
        backgroundColor: _surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9EEFC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.group_rounded,
                            color: _primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _committee.name,
                                style: GoogleFonts.inter(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  color: _textPrimary,
                                ),
                              ),
                              Text(
                                '${_frequencyLabel()} • ${_members.length} members',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9EEFC),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () async {
                              await Clipboard.setData(
                                ClipboardData(text: _committee.code),
                              );
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Committee code copied'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _committee.code,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: _primary,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.copy_rounded,
                                  size: 13,
                                  color: _primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _buildStatItem(
                          'Members',
                          '${_members.length}',
                          Icons.people_outline_rounded,
                        ),
                        const SizedBox(width: 10),
                        _buildStatItem(
                          'Per Member',
                          '${_committee.currency} ${_formatAmount(_committee.contributionAmount)}',
                          Icons.payments_outlined,
                        ),
                        const SizedBox(width: 10),
                        _buildStatItem(
                          'Pool',
                          '${_committee.currency} ${_formatAmount(totalAmount)}',
                          Icons.account_balance_wallet_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD0D9EE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payout Progress',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value:
                          _members.isEmpty ? 0 : paidMembers / _members.length,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(_success),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$paidMembers of ${_members.length} members received payout',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCFE8D9)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showCollectionDetails = !_showCollectionDetails;
                        });
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: _success,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Per Cycle Collection',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: _textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      _showCollectionDetails
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: _textSecondary,
                                    ),
                                  ],
                                ),
                                Text(
                                  '${_committee.currency} ${_formatAmount(currentCycleCollected)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: _success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_showCollectionDetails) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFD0D9EE)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Collected',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: _textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${_committee.currency} ${_formatAmount(totalCollected)}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_members.length * collectionsPerPayout} payments/cycle',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: _textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${_members.length} × $collectionsPerPayout collections',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: _textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Financial Insights',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildInsightTile(
                      title: 'Collected',
                      value:
                          '${_committee.currency} ${_formatAmount(totalCollected)}',
                      icon: Icons.account_balance_wallet_outlined,
                      toneColor: _success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInsightTile(
                      title: 'Current Cycle',
                      value:
                          '${_committee.currency} ${_formatAmount(currentCycleCollected)}',
                      icon: Icons.stacked_line_chart_rounded,
                      toneColor: _primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildInsightTile(
                      title: 'Per Payout',
                      value:
                          '${_members.length * collectionsPerPayout} payments',
                      icon: Icons.repeat_rounded,
                      toneColor: _warning,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInsightTile(
                      title: 'Start Date',
                      value:
                          '${_committee.startDate.day}/${_committee.startDate.month}/${_committee.startDate.year}',
                      icon: Icons.event_available_rounded,
                      toneColor: _purple,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Text(
                'Actions',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.93,
                children: [
                  _buildActionTile(
                    icon: Icons.people_rounded,
                    title: 'Manage Members',
                    subtitle: 'Add or edit',
                    color: _primary,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  MemberManagementScreen(committee: _committee),
                        ),
                      );
                      _loadMembers();
                    },
                  ),
                  _buildActionTile(
                    icon: Icons.grid_on_rounded,
                    title: 'Payment Sheet',
                    subtitle: 'Mark dues',
                    color: _success,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  PaymentSheetScreen(committee: _committee),
                        ),
                      );
                    },
                  ),
                  _buildActionTile(
                    icon: Icons.shuffle_rounded,
                    title: 'Shuffle Order',
                    subtitle: 'Assign payout',
                    color: _warning,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  ShuffleMembersScreen(committee: _committee),
                        ),
                      );
                      _loadMembers();
                    },
                  ),
                  _buildActionTile(
                    icon: Icons.analytics_rounded,
                    title: 'Analytics',
                    subtitle: 'Insights',
                    color: _purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => CommitteeAnalyticsScreen(
                                committee: _committee,
                              ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightTile({
    required String title,
    required String value,
    required IconData icon,
    required Color toneColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE4F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: toneColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: toneColor),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: _textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: _textPrimary,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD0D9EE)),
        ),
        child: Column(
          children: [
            Icon(icon, color: _primary, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 10, color: _textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDCE4F7)),
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
                      color: color.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const Spacer(),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDCE4F7)),
                    ),
                    child: Icon(
                      Icons.arrow_outward_rounded,
                      size: 16,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 31 / 2,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Open',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded, size: 16, color: color),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
