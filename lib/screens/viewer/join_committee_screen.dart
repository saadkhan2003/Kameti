import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../services/database_service.dart';
import '../../services/sync_service.dart';
import 'package:committee_app/ui/theme/theme.dart';
import '../host/payment_sheet_screen.dart';

class JoinCommitteeScreen extends StatefulWidget {
  const JoinCommitteeScreen({super.key});

  @override
  State<JoinCommitteeScreen> createState() => _JoinCommitteeScreenState();
}

class _JoinCommitteeScreenState extends State<JoinCommitteeScreen> {
  static const Color _bg = AppColors.bg;
  static const Color _surface = AppColors.surface;
  static const Color _primary = AppColors.primary;
  static const Color _accent = AppColors.success;
  static const Color _danger = AppColors.error;
  static const Color _textPrimary = AppColors.textPrimary;
  static const Color _textSecondary = AppColors.textSecondary;

  final _committeeCodeController = TextEditingController();
  final _memberCodeController = TextEditingController();
  final _dbService = DatabaseService();
  final _syncService = SyncService();

  String? _errorMessage;
  bool _isLoading = false;
  List<Map<String, dynamic>> _recentCommittees = [];

  @override
  void initState() {
    super.initState();
    _loadRecentCommittees();
  }

  @override
  void dispose() {
    _committeeCodeController.dispose();
    _memberCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentCommittees() async {
    final box = await Hive.openBox('viewer_prefs');
    final List<dynamic>? saved = box.get('recent_committees');
    if (saved != null) {
      setState(() {
        _recentCommittees = List<Map<String, dynamic>>.from(
          saved.map((entry) => Map<String, dynamic>.from(entry)),
        );
      });
    }
  }

  Future<void> _saveRecentCommittee(
    String name,
    String committeeCode,
    String memberCode,
  ) async {
    final box = await Hive.openBox('viewer_prefs');

    _recentCommittees.removeWhere(
      (item) =>
          item['committeeCode'] == committeeCode &&
          item['memberCode'] == memberCode,
    );

    _recentCommittees.insert(0, {
      'name': name,
      'committeeCode': committeeCode,
      'memberCode': memberCode,
      'timestamp': DateTime.now().toIso8601String(),
    });

    if (_recentCommittees.length > 5) {
      _recentCommittees = _recentCommittees.sublist(0, 5);
    }

    await box.put('recent_committees', _recentCommittees);
    setState(() {});
  }

  Future<void> _deleteRecentCommittee(int index) async {
    final box = await Hive.openBox('viewer_prefs');
    _recentCommittees.removeAt(index);
    await box.put('recent_committees', _recentCommittees);
    setState(() {});
  }

  void _showDeleteConfirmation(int index, String name) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Remove recent item',
            style: GoogleFonts.inter(
              color: _textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Remove "$name" from your recent kametis?',
            style: GoogleFonts.inter(color: _textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: _textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteRecentCommittee(index);
              },
              child: Text(
                'Remove',
                style: GoogleFonts.inter(
                  color: _danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _viewPayments({String? code, String? member}) async {
    final committeeCode = code ?? _committeeCodeController.text.trim();
    final memberCode =
        member?.toUpperCase() ??
        _memberCodeController.text.trim().toUpperCase();

    if (committeeCode.isEmpty || memberCode.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both codes';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      try {
        await _syncService.syncCommitteeByCode(committeeCode);
      } catch (_) {}

      final committee = _dbService.getCommitteeByCode(committeeCode);
      if (committee == null) {
        setState(() {
          _errorMessage =
              'Kameti not found. Please check connectivity or the code.';
        });
        return;
      }

      try {
        await _syncService.syncMemberByCode(committee.id, memberCode);
      } catch (_) {}

      final memberFound = _dbService.getMemberByCode(committee.id, memberCode);
      if (memberFound == null) {
        setState(() {
          _errorMessage = 'Member not found. Please check your member code.';
        });
        return;
      }

      await _saveRecentCommittee(committee.name, committeeCode, memberCode);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => PaymentSheetScreen(
                  committee: committee,
                  viewAsMember: memberFound,
                ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _fillFromRecent(Map<String, dynamic> item) {
    _committeeCodeController.text = item['committeeCode'];
    _memberCodeController.text = item['memberCode'];
    _viewPayments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'View Payments',
          style: GoogleFonts.inter(
            color: _textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHero(),
              if (_recentCommittees.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildRecentSection(),
              ],
              const SizedBox(height: 16),
              _buildJoinFormCard(),
              const SizedBox(height: 14),
              _buildHelpCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.24),
            blurRadius: 16,
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  AppIcons.visibility_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'View Your Kameti',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Enter the committee code and your member code to open your payment sheet.',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.92),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.history_rounded, color: _primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Recent Kametis',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._recentCommittees.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Container(
              margin: EdgeInsets.only(
                bottom: index == _recentCommittees.length - 1 ? 0 : 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.cFFF8FAFF,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cFFDDE6FA),
              ),
              child: ListTile(
                onTap: () => _fillFromRecent(item),
                leading: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    AppIcons.group_rounded,
                    color: _primary,
                    size: 18,
                  ),
                ),
                title: Text(
                  item['name'] ?? 'Unknown Kameti',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Code: ${item['committeeCode']} • ${item['memberCode']}',
                  style: GoogleFonts.inter(color: _textSecondary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(
                    AppIcons.delete_outline_rounded,
                    color: _danger,
                    size: 20,
                  ),
                  onPressed:
                      () => _showDeleteConfirmation(
                        index,
                        item['name'] ?? 'this kameti',
                      ),
                  tooltip: 'Remove from recent',
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildJoinFormCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter Access Codes',
            style: GoogleFonts.inter(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _danger.withOpacity(0.24)),
              ),
              child: Row(
                children: [
                  const Icon(
                    AppIcons.syncError,
                    color: _danger,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.inter(
                        color: _danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          TextFormField(
            controller: _committeeCodeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: 'Kameti Code',
              hintText: 'e.g., 847293',
              counterText: '',
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
                AppIcons.group_outlined,
                color: _textSecondary,
              ),
              filled: true,
              fillColor: AppColors.cFFF8FAFF,
              border: _inputBorder(),
              enabledBorder: _inputBorder(),
              focusedBorder: _inputBorder(color: _primary),
            ),
            style: GoogleFonts.inter(
              fontSize: 18,
              letterSpacing: 2,
              color: _textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _memberCodeController,
            textCapitalization: TextCapitalization.characters,
            onChanged: (value) {
              final upper = value.toUpperCase();
              if (upper.length == 3 && !upper.contains('-')) {
                _memberCodeController.text = '$upper-';
                _memberCodeController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _memberCodeController.text.length),
                );
              } else if (upper.length > 4 && !upper.contains('-')) {
                final letters = upper.substring(0, 3);
                final numbers = upper.substring(3);
                _memberCodeController.text = '$letters-$numbers';
                _memberCodeController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _memberCodeController.text.length),
                );
              }
            },
            decoration: InputDecoration(
              labelText: 'Your Member Code',
              hintText: 'e.g., ABD-1577',
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
                AppIcons.person_outline_rounded,
                color: _textSecondary,
              ),
              filled: true,
              fillColor: AppColors.cFFF8FAFF,
              border: _inputBorder(),
              enabledBorder: _inputBorder(),
              focusedBorder: _inputBorder(color: _primary),
            ),
            style: GoogleFonts.inter(
              fontSize: 18,
              letterSpacing: 1,
              color: _textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _viewPayments(),
              icon:
                  _isLoading
                      ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(AppIcons.visibility_rounded),
              label: Text(_isLoading ? 'Loading...' : 'View My Payments'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _accent.withOpacity(0.55),
                disabledForegroundColor: Colors.white,
                overlayColor: Colors.white.withOpacity(0.12),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              AppIcons.help_outline_rounded,
              color: _primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to get codes?',
                  style: GoogleFonts.inter(
                    color: _textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '• Kameti Code: Ask your kameti host\n• Member Code: Your unique code given by the host',
                  style: GoogleFonts.inter(
                    color: _textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _inputBorder({Color? color}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color ?? AppColors.cFFDDE5F6),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.cFFDCE5F6),
      boxShadow: [
        BoxShadow(
          color: AppColors.darkBg.withOpacity(0.05),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }
}
