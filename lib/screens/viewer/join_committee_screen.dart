import 'package:committee_app/core/theme/app_theme.dart';
import 'package:committee_app/features/auth/data/auth_service.dart';
import 'package:committee_app/screens/host/payment_sheet_screen.dart';
import 'package:committee_app/services/database_service.dart';
import 'package:committee_app/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

class JoinCommitteeScreen extends StatefulWidget {
  const JoinCommitteeScreen({super.key});

  @override
  State<JoinCommitteeScreen> createState() => _JoinCommitteeScreenState();
}

class _JoinCommitteeScreenState extends State<JoinCommitteeScreen> {
  final _committeeCodeController = TextEditingController();
  final _memberCodeController = TextEditingController();
  final _dbService = DatabaseService();
  final _syncService = SyncService();
  final _authService = AuthService();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _committeeCodeController.dispose();
    _memberCodeController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _recentCommittees = [];

  @override
  void initState() {
    super.initState();
    _loadRecentCommittees();
  }

  Future<void> _loadRecentCommittees() async {
    final box = await Hive.openBox('viewer_prefs');
    final List<dynamic>? saved = box.get('recent_committees');
    if (saved != null) {
      setState(() {
        _recentCommittees = List<Map<String, dynamic>>.from(
          saved.map((e) => Map<String, dynamic>.from(e)),
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
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text(
              'Remove from Recent',
              style: TextStyle(color: Colors.black87),
            ),
            content: Text(
              'Remove "$name" from your recent kametis?',
              style: TextStyle(color: Colors.grey[600]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteRecentCommittee(index);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Remove'),
              ),
            ],
          ),
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
      if (!_authService.isLoggedIn) {
        try {
          await _authService.signInAnonymously();
        } catch (e) {
          debugPrint('Anonymous auth failed: $e');
        }
      }

      try {
        await _syncService.syncCommitteeByCode(committeeCode);
      } catch (e) {
        debugPrint('Sync failed, falling back to local: $e');
      }

      final committee = _dbService.getCommitteeByCode(committeeCode);

      if (committee == null) {
        setState(() {
          _errorMessage =
              'Kameti not found. Please check connectivity or the code.';
        });
        return;
      }

      final memberObj = _dbService.getMemberByCode(committee.id, memberCode);
      if (memberObj == null) {
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
                  viewAsMember: memberObj,
                ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'View Payments',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),

            if (_recentCommittees.isNotEmpty) ...[
              Text(
                'Recent Kametis',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              ..._recentCommittees.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: Colors.white,
                  elevation: 2,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                    ),
                  ),
                  child: ListTile(
                    onTap: () => _fillFromRecent(item),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.history,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    title: Text(
                      item['name'] ?? 'Unknown Kameti',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      'Code: ${item['committeeCode']}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed:
                              () => _showDeleteConfirmation(
                                index,
                                item['name'] ?? 'this kameti',
                              ),
                          tooltip: 'Remove from recent',
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
              const Divider(color: Colors.grey),
              const SizedBox(height: 24),
            ],

            Center(
              child: Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.visibility_rounded,
                  size: 40,
                  color: AppTheme.secondaryColor,
                ),
              ),
            ),
            Center(
              child: Text(
                'View Your Payments',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Enter the codes provided by your kameti host',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 32),

            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.errorColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppTheme.errorColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 13,
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
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                labelText: 'Kameti Code',
                labelStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: const Icon(
                  Icons.group_outlined,
                  color: Colors.grey,
                ),
                hintText: 'e.g., 847293',
                hintStyle: TextStyle(color: Colors.grey[400]),
                counterText: '',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _memberCodeController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: Colors.black87),
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
                labelStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: const Icon(
                  Icons.person_outline,
                  color: Colors.grey,
                ),
                hintText: 'e.g., ABD-1577',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _viewPayments(),
              icon:
                  _isLoading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.visibility, color: Colors.white),
              label: Text(
                _isLoading ? 'Loading...' : 'View My Payments',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.help_outline,
                        color: Colors.grey[600],
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'How to get codes?',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Kameti Code: Ask your kameti host\n• Member Code: Your unique code given by the host',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.5,
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
}
