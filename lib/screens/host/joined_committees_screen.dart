import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/database_service.dart';
import '../../services/toast_service.dart';
import 'package:committee_app/ui/theme/theme.dart';
import '../viewer/join_committee_screen.dart';
import 'payment_sheet_screen.dart';

class JoinedCommitteesScreen extends StatefulWidget {
  const JoinedCommitteesScreen({super.key});

  @override
  State<JoinedCommitteesScreen> createState() => _JoinedCommitteesScreenState();
}

class _JoinedCommitteesScreenState extends State<JoinedCommitteesScreen> {
  static const Color _bg = AppColors.bg;
  static const Color _surface = AppColors.surface;
  static const Color _primary = AppColors.primary;
  static const Color _success = AppColors.success;
  static const Color _danger = AppColors.error;
  static const Color _textPrimary = AppColors.textPrimary;
  static const Color _textSecondary = AppColors.textSecondary;

  final _dbService = DatabaseService();
  List<Map> _joinedCommittees = [];

  @override
  void initState() {
    super.initState();
    _loadJoinedCommittees();
  }

  void _loadJoinedCommittees() {
    setState(() {
      _joinedCommittees = _dbService.getJoinedCommittees();
    });
  }

  Future<void> _viewCommittee(Map joined) async {
    final committeeCode = joined['committeeCode'] as String;
    final memberCode = joined['memberCode'] as String;

    final committee = _dbService.getCommitteeByCode(committeeCode);
    if (committee == null) {
      ToastService.error(context, 'Kameti not found');
      return;
    }

    final member = _dbService.getMemberByCode(committee.id, memberCode);
    if (member == null) {
      ToastService.error(context, 'Member not found');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentSheetScreen(committee: committee),
      ),
    );
  }

  Future<void> _removeCommittee(String committeeCode) async {
    await _dbService.removeJoinedCommittee(committeeCode);
    _loadJoinedCommittees();
  }

  void _showRemoveDialog(String committeeCode) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: _surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Remove Committee?',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            content: Text(
              'Remove this committee from your joined list?',
              style: GoogleFonts.inter(color: _textSecondary),
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
                onPressed: () {
                  Navigator.pop(context);
                  _removeCommittee(committeeCode);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _danger,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Joined Committees',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: _textPrimary,
          ),
        ),
      ),
      body:
          _joinedCommittees.isEmpty
              ? _buildEmptyState()
              : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.lightBorder),
                    ),
                    child: Row(
                      children: [
                        _buildTopStat(
                          icon: AppIcons.groups_rounded,
                          label: 'Joined',
                          value: '${_joinedCommittees.length}',
                          tone: _primary,
                        ),
                        const SizedBox(width: 10),
                        _buildTopStat(
                          icon: AppIcons.verified_user_rounded,
                          label: 'Active',
                          value: '${_joinedCommittees.length}',
                          tone: _success,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  ..._buildListItems(),
                ],
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const JoinCommitteeScreen(),
            ),
          );
          _loadJoinedCommittees();
        },
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        icon: const Icon(AppIcons.add),
        label: const Text('Join New'),
      ),
    );
  }

  Widget _buildTopStat({
    required IconData icon,
    required String label,
    required String value,
    required Color tone,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: tone.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: tone),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                    ),
                  ),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _textSecondary,
                      fontWeight: FontWeight.w600,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: AppColors.cFFE9EEFC,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              AppIcons.group_off_outlined,
              size: 42,
              color: _primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Joined Committees',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Join a committee to view your payments',
            style: GoogleFonts.inter(fontSize: 14, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildListItems() {
    return _joinedCommittees
        .map((joined) => _buildCommitteeCard(joined))
        .toList();
  }

  Widget _buildCommitteeCard(Map joined) {
    final committeeCode = joined['committeeCode'] as String;
    final memberCode = joined['memberCode'] as String;
    final committee = _dbService.getCommitteeByCode(committeeCode);

    return Card(
      elevation: 0,
      color: _surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.lightBorder),
      ),
      child: InkWell(
        onTap: () => _viewCommittee(joined),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(AppIcons.group_rounded, color: _primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      committee?.name ?? 'Unknown Committee',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Code: $committeeCode • $memberCode',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Joined',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: _success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  AppIcons.delete_outline,
                  color: _textSecondary,
                ),
                onPressed: () => _showRemoveDialog(committeeCode),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
