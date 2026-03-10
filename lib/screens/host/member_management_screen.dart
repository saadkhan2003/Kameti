import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../../services/database_service.dart';
import '../../services/auto_sync_service.dart';
import '../../services/toast_service.dart';
import '../../models/committee.dart';
import '../../models/member.dart';
import '../../utils/code_generator.dart';
import 'package:committee_app/ui/theme/theme.dart';
import '../../ui/widgets/ads/banner_ad_widget.dart';

class MemberManagementScreen extends StatefulWidget {
  final Committee committee;

  const MemberManagementScreen({super.key, required this.committee});

  @override
  State<MemberManagementScreen> createState() => _MemberManagementScreenState();
}

class _MemberManagementScreenState extends State<MemberManagementScreen> {
  static const Color _bg = AppColors.bg;
  static const Color _surface = AppColors.surface;
  static const Color _primary = AppColors.primary;
  static const Color _success = AppColors.success;
  static const Color _warning = AppColors.warning;
  static const Color _danger = AppColors.error;
  static const Color _textPrimary = AppColors.textPrimary;
  static const Color _textSecondary = AppColors.textSecondary;

  final _dbService = DatabaseService();
  final _autoSyncService = AutoSyncService();
  final _searchController = TextEditingController();
  List<Member> _allMembers = [];
  List<Member> _filteredMembers = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadMembers() {
    setState(() {
      _allMembers = _dbService.getMembersByCommittee(widget.committee.id);
      _filterMembers();
    });
  }

  void _filterMembers() {
    if (_searchQuery.isEmpty) {
      _filteredMembers = _allMembers;
    } else {
      _filteredMembers =
          _allMembers.where((member) {
            final nameLower = member.name.toLowerCase();
            final codeLower = member.memberCode.toLowerCase();
            final phoneLower = member.phone.toLowerCase();
            final queryLower = _searchQuery.toLowerCase();
            return nameLower.contains(queryLower) ||
                codeLower.contains(queryLower) ||
                phoneLower.contains(queryLower);
          }).toList();
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filterMembers();
    });
  }

  void _shareMemberCode(Member member) {
    String message =
        '📋 *${widget.committee.name}*\n\n'
        'Hi ${member.name}! 👋\n\n'
        '*Committee Code:* ${widget.committee.code}\n'
        '*Your Member Code:* ${member.memberCode}\n\n'
        '_Download Committee App to track your payments!_';
    Share.share(message, subject: '${member.name} - Committee Code');
  }

  void _showAddMemberDialog({Member? existingMember}) {
    final nameController = TextEditingController(
      text: existingMember?.name ?? '',
    );
    final phoneController = TextEditingController(
      text: existingMember?.phone ?? '',
    );
    final isEditing = existingMember != null;

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
                isEditing ? 'Edit Member' : 'Add Member',
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
                  labelText: 'Member Name',
                  labelStyle: GoogleFonts.inter(
                    color: _textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  floatingLabelStyle: GoogleFonts.inter(
                    color: _primary,
                    fontWeight: FontWeight.w700,
                  ),
                  hintStyle: GoogleFonts.inter(
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: const Icon(
                    AppIcons.person_outline,
                    color: _textSecondary,
                  ),
                  filled: true,
                  fillColor: AppColors.cFFF8FAFF,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.cFFD0D9EE),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primary, width: 1.6),
                  ),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                style: GoogleFonts.inter(
                  color: _textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: GoogleFonts.inter(
                    color: _textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  floatingLabelStyle: GoogleFonts.inter(
                    color: _primary,
                    fontWeight: FontWeight.w700,
                  ),
                  hintStyle: GoogleFonts.inter(
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: const Icon(
                    AppIcons.phone_outlined,
                    color: _textSecondary,
                  ),
                  filled: true,
                  fillColor: AppColors.cFFF8FAFF,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.cFFD0D9EE),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primary, width: 1.6),
                  ),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final phone = phoneController.text.trim();

                  if (name.isEmpty) {
                    return;
                  }

                  if (isEditing) {
                    final updatedMember = existingMember.copyWith(
                      name: name,
                      phone: phone,
                    );
                    await _autoSyncService.saveMember(updatedMember);
                  } else {
                    // Calculate the next payout order
                    final existingMembers = _dbService.getMembersByCommittee(
                      widget.committee.id,
                    );
                    int maxOrder = 0;
                    for (final m in existingMembers) {
                      if (m.payoutOrder > maxOrder) {
                        maxOrder = m.payoutOrder;
                      }
                    }
                    final nextOrder = maxOrder + 1;

                    final member = Member(
                      id: const Uuid().v4(),
                      committeeId: widget.committee.id,
                      memberCode: CodeGenerator.generateMemberCode(name),
                      name: name,
                      phone: phone,
                      payoutOrder: nextOrder,
                      createdAt: DateTime.now(),
                    );
                    await _autoSyncService.saveMember(member);
                  }

                  Navigator.pop(context);
                  _loadMembers();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(isEditing ? 'Save Changes' : 'Add Member'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _deleteMember(Member member) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: _surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Delete Member?',
              style: GoogleFonts.inter(
                color: _textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              'Are you sure you want to delete ${member.name}? This will also delete all their payment records.',
              style: const TextStyle(color: _textSecondary),
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
                onPressed: () async {
                  await _autoSyncService.deleteMember(
                    member.id,
                    widget.committee.id,
                  );
                  Navigator.pop(context);
                  _loadMembers();
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

  void _copyMemberCode(Member member) {
    Clipboard.setData(ClipboardData(text: member.memberCode));
    ToastService.success(context, 'Member code "${member.memberCode}" copied!');
  }

  @override
  Widget build(BuildContext context) {
    final paidCount = _allMembers.where((m) => m.hasReceivedPayout).length;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: _textPrimary,
        iconTheme: const IconThemeData(color: _textPrimary),
        elevation: 0,
        title: Text(
          'Members',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: _textPrimary,
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_allMembers.length} members',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.lightBorder),
              ),
              child: Row(
                children: [
                  _buildSummaryStat(
                    icon: AppIcons.people_rounded,
                    label: 'Total',
                    value: '${_allMembers.length}',
                    tone: _primary,
                  ),
                  const SizedBox(width: 10),
                  _buildSummaryStat(
                    icon: AppIcons.verified_rounded,
                    label: 'Paid Out',
                    value: '$paidCount',
                    tone: _success,
                  ),
                  const SizedBox(width: 10),
                  _buildSummaryStat(
                    icon: AppIcons.schedule_rounded,
                    label: 'Pending',
                    value: '${(_allMembers.length - paidCount).clamp(0, 999)}',
                    tone: _warning,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: GoogleFonts.inter(color: _textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by name, code, or phone...',
                hintStyle: GoogleFonts.inter(color: _textSecondary),
                prefixIcon: const Icon(AppIcons.search, color: _textSecondary),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(AppIcons.clear, color: _textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                        : null,
                filled: true,
                fillColor: _surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.lightBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.lightBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _primary, width: 1.6),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          Expanded(
            child:
                _allMembers.isEmpty
                    ? _buildEmptyState()
                    : _filteredMembers.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            AppIcons.search_off_rounded,
                            size: 56,
                            color: _textSecondary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No members found',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: _textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredMembers.length,
                      itemBuilder: (context, index) {
                        final member = _filteredMembers[index];
                        return _buildMemberCard(member, index);
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMemberDialog(),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        icon: const Icon(AppIcons.person_add_alt_1_rounded),
        label: const Text('Add Member'),
      ),
      bottomNavigationBar: const BannerAdWidget(),
    );
  }

  Widget _buildSummaryStat({
    required IconData icon,
    required String label,
    required String value,
    required Color tone,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: tone.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: tone),
            const SizedBox(height: 4),
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: AppColors.cFFE9EEFC,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              AppIcons.people_outline_rounded,
              size: 42,
              color: _primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Members Yet',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add members to your committee',
            style: GoogleFonts.inter(fontSize: 14, color: _textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddMemberDialog(),
            icon: const Icon(AppIcons.person_add),
            label: const Text('Add First Member'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Member member, int index) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.lightBorder),
      ),
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
              child: Center(
                child: Text(
                  member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (member.phone.isNotEmpty)
                    Text(
                      member.phone,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _textSecondary,
                      ),
                    ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _copyMemberCode(member),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _success.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            member.memberCode,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _success,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            AppIcons.copy,
                            size: 12,
                            color: _success.withOpacity(0.7),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (member.payoutOrder > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      member.hasReceivedPayout
                          ? _success.withOpacity(0.12)
                          : _warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '#${member.payoutOrder}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: member.hasReceivedPayout ? _success : _warning,
                  ),
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
                if (value == 'edit') {
                  _showAddMemberDialog(existingMember: member);
                } else if (value == 'delete') {
                  _deleteMember(member);
                } else if (value == 'share') {
                  _shareMemberCode(member);
                }
              },
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(AppIcons.share, size: 18, color: _primary),
                          SizedBox(width: 8),
                          Text(
                            'Share Code',
                            style: TextStyle(color: _textPrimary),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(AppIcons.edit, size: 18, color: _textSecondary),
                          SizedBox(width: 8),
                          Text('Edit', style: TextStyle(color: _textPrimary)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(AppIcons.delete, size: 18, color: _danger),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: _danger)),
                        ],
                      ),
                    ),
                  ],
            ),
          ],
        ),
      ),
    );
  }
}
