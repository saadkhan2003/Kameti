import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/payment.dart';
import '../../models/payment_proof.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/payment_proof_card.dart';
import 'proof_review_screen.dart';
import 'package:committee_app/ui/theme/theme.dart';

class PendingProofsScreen extends StatefulWidget {
  final String? committeeId;

  const PendingProofsScreen({super.key, this.committeeId});

  @override
  State<PendingProofsScreen> createState() => _PendingProofsScreenState();
}

class _PendingProofsScreenState extends State<PendingProofsScreen>
    with SingleTickerProviderStateMixin {
  final _auth = AuthService();
  final _supabase = SupabaseService();
  final _dbService = DatabaseService();

  late TabController _tabController;
  bool _loading = true;
  List<PaymentProof> _allProofs = [];

  static const _tabs = ['all', 'pending', 'approved', 'rejected'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadProofs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProofs({bool silent = false}) async {
    final hostId = _auth.currentUser?.id ?? '';
    if (hostId.isEmpty) return;

    if (!silent && mounted) {
      setState(() => _loading = true);
    }

    final proofs = await _supabase.getProofsForHost(hostId);
    final filteredProofs =
        widget.committeeId == null
            ? proofs
            : proofs.where((p) => p.committeeId == widget.committeeId).toList();
    if (!mounted) return;
    setState(() {
      _allProofs = filteredProofs;
      _loading = false;
    });
  }

  List<PaymentProof> _filtered(String status) {
    if (status == 'all') return _allProofs;
    return _allProofs.where((p) => p.status == status).toList();
  }

  int get _pendingCount => _allProofs.where((p) => p.isPending).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          'Payment Proofs',
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.textPrimary,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          tabs: [
            const Tab(text: 'All'),
            Tab(text: 'Pending ($_pendingCount)'),
            const Tab(text: 'Approved'),
            const Tab(text: 'Rejected'),
          ],
        ),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadProofs,
                child: TabBarView(
                  controller: _tabController,
                  children:
                      _tabs.map((tab) => _buildList(_filtered(tab))).toList(),
                ),
              ),
    );
  }

  Widget _buildList(List<PaymentProof> proofs) {
    if (proofs.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 140),
          Center(
            child: Column(
              children: [
                const Icon(
                  AppIcons.inbox_outlined,
                  color: AppColors.textSecondary,
                  size: 28,
                ),
                const SizedBox(height: 10),
                Text(
                  'No pending proofs',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'New submissions will appear here.',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: proofs.length,
      itemBuilder: (context, index) {
        final proof = proofs[index];
        final member = _dbService.getMemberById(proof.memberId);
        final committee = _dbService.getCommitteeById(proof.committeeId);
        final payment = _findPaymentById(proof.committeeId, proof.paymentId);

        final memberName = member?.name ?? 'Unknown Member';
        final committeeName = committee?.name ?? 'Committee';
        final amountLabel =
            '${committee?.currency ?? 'PKR'} ${(committee?.contributionAmount ?? 0).toInt()}';
        final periodLabel =
            payment != null
                ? _monthLabel(payment.date)
                : _monthLabel(proof.createdAt);
        final dueDateLabel =
            payment != null
                ? _fullDateLabel(payment.date)
                : _fullDateLabel(proof.createdAt);

        return PaymentProofCard(
          proof: proof,
          memberName: memberName,
          committeeName: committeeName,
          periodLabel: periodLabel,
          dueDateLabel: dueDateLabel,
          amountLabel: amountLabel,
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProofReviewScreen(proofId: proof.id),
              ),
            );
            if (result == true && mounted) {
              await _loadProofs(silent: true);
            }
          },
        );
      },
    );
  }

  String _monthLabel(DateTime date) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${monthNames[date.month - 1]} ${date.year}';
  }

  String _fullDateLabel(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Payment? _findPaymentById(String committeeId, String paymentId) {
    final payments = _dbService.getPaymentsByCommittee(committeeId);
    for (final payment in payments) {
      if (payment.id == paymentId) return payment;
    }
    return null;
  }
}
