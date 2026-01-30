import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:committee_app/services/database_service.dart';
import 'package:committee_app/core/models/committee.dart';
import 'package:committee_app/core/models/member.dart';
import 'package:committee_app/core/theme/app_theme.dart';

class MemberViewScreen extends StatefulWidget {
  final Committee committee;
  final Member member;

  const MemberViewScreen({
    super.key,
    required this.committee,
    required this.member,
  });

  @override
  State<MemberViewScreen> createState() => _MemberViewScreenState();
}

class _MemberViewScreenState extends State<MemberViewScreen> {
  final _dbService = DatabaseService();
  List<DateTime> _dates = [];
  int _paidCount = 0;
  int _totalDays = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _generateDates();
    _calculateStats();
  }

  void _generateDates() {
    _dates = [];
    final now = DateTime.now();
    final startDate = widget.committee.startDate;

    int daysToGenerate = 30;
    switch (widget.committee.frequency) {
      case 'daily':
        for (int i = 0; i < daysToGenerate; i++) {
          final date = now.subtract(Duration(days: i));
          if (date.isAfter(startDate.subtract(const Duration(days: 1)))) {
            _dates.add(DateTime(date.year, date.month, date.day));
          }
        }
        break;
      case 'weekly':
        for (int i = 0; i < daysToGenerate ~/ 7; i++) {
          final date = now.subtract(Duration(days: i * 7));
          if (date.isAfter(startDate.subtract(const Duration(days: 1)))) {
            _dates.add(DateTime(date.year, date.month, date.day));
          }
        }
        break;
      case 'monthly':
        for (int i = 0; i < 12; i++) {
          final date = DateTime(now.year, now.month - i, now.day);
          if (date.isAfter(startDate.subtract(const Duration(days: 1)))) {
            _dates.add(DateTime(date.year, date.month, 1));
          }
        }
        break;
    }
    _dates = _dates.reversed.toList();
  }

  void _calculateStats() {
    _totalDays = _dates.length;
    _paidCount = 0;

    for (final date in _dates) {
      final payment = _dbService.getPayment(widget.member.id, date);
      if (payment != null && payment.isPaid) {
        _paidCount++;
      }
    }
    setState(() {});
  }

  bool _isPaymentMarked(DateTime date) {
    final payment = _dbService.getPayment(widget.member.id, date);
    return payment != null && payment.isPaid;
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalDays > 0 ? _paidCount / _totalDays : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.committee.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Member Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.secondaryColor, Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            widget.member.name.isNotEmpty
                                ? widget.member.name[0].toUpperCase()
                                : '?',
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
                              widget.member.name,
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Member Code: ${widget.member.memberCode}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Payout Info
                  if (widget.member.payoutOrder > 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            widget.member.hasReceivedPayout
                                ? Icons.check_circle
                                : Icons.schedule,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.member.hasReceivedPayout
                                ? 'You have received your payout!'
                                : 'Your turn: #${widget.member.payoutOrder}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payment Progress
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Payment Progress',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[800],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.secondaryColor,
                    ),
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_paidCount of $_totalDays payments marked',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payment History
            Text(
              'Payment History',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 12),

            // Payment Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _dates.length,
              itemBuilder: (context, index) {
                final date = _dates[index];
                final isPaid = _isPaymentMarked(date);
                final format = widget.committee.frequency == 'monthly'
                    ? DateFormat('MMM')
                    : DateFormat('d');

                return Container(
                  decoration: BoxDecoration(
                    color:
                        isPaid ? AppTheme.secondaryColor : Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isPaid)
                        const Icon(Icons.check, color: Colors.white, size: 14)
                      else
                        const Icon(Icons.close, color: Colors.grey, size: 14),
                      const SizedBox(height: 2),
                      Text(
                        format.format(date),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: isPaid ? Colors.white : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegend(AppTheme.secondaryColor, 'Paid'),
                const SizedBox(width: 24),
                _buildLegend(Colors.grey[800]!, 'Not Paid'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}
