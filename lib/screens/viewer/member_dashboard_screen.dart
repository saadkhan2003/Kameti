import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../models/committee.dart';
import '../../models/member.dart';
import '../../utils/app_theme.dart';

class MemberDashboardScreen extends StatefulWidget {
  final Committee committee;
  final Member member;

  const MemberDashboardScreen({
    super.key,
    required this.committee,
    required this.member,
  });

  @override
  State<MemberDashboardScreen> createState() => _MemberDashboardScreenState();
}

class _MemberDashboardScreenState extends State<MemberDashboardScreen> {
  final _dbService = DatabaseService();
  int _totalPayments = 0;
  int _paidPayments = 0;
  int _pendingPayments = 0;
  DateTime? _payoutDate;
  int _daysUntilPayout = 0;
  DateTime? _nextPaymentDate;
  
  // Cycle support
  int _selectedCycle = 1;
  int _maxCycles = 1;
  List<DateTime> _cycleDates = [];

  @override
  void initState() {
    super.initState();
    final members = _dbService.getMembersByCommittee(widget.committee.id);
    _maxCycles = members.isNotEmpty ? members.length : 1;
    _selectedCycle = _findOngoingCycle();
    _calculateStats();
  }
  
  /// Find the ongoing cycle based on current date
  int _findOngoingCycle() {
    final now = DateTime.now();
    final startDate = widget.committee.startDate;
    final intervalDays = widget.committee.paymentIntervalDays;
    
    // Calculate which cycle we're in
    final daysSinceStart = now.difference(startDate).inDays;
    final cycle = (daysSinceStart / intervalDays).floor() + 1;
    
    return cycle.clamp(1, _maxCycles);
  }

  void _calculateStats() {
    // Get all payments for this member
    _dbService.getPaymentsByMember(widget.member.id);
    final startDate = widget.committee.startDate;
    final today = DateTime.now();
    final intervalDays = widget.committee.paymentIntervalDays;
    
    // Calculate cycle start and end dates
    final cycleStartDate = startDate.add(Duration(days: intervalDays * (_selectedCycle - 1)));
    final cycleEndDate = cycleStartDate.add(Duration(days: intervalDays - 1));
    
    // Generate dates for THIS cycle only
    _cycleDates = [];
    DateTime current = cycleStartDate;
    int collectionInterval = widget.committee.frequency == 'daily' ? 1 
        : widget.committee.frequency == 'weekly' ? 7 : 30;
    
    while (!current.isAfter(cycleEndDate) && _cycleDates.length < 35) {
      _cycleDates.add(current);
      current = current.add(Duration(days: collectionInterval));
    }
    
    // Count payments for THIS cycle only
    _totalPayments = _cycleDates.length;
    _paidPayments = 0;
    for (var date in _cycleDates) {
      final payment = _dbService.getPayment(widget.member.id, date);
      if (payment != null && payment.isPaid) {
        _paidPayments++;
      }
    }
    _pendingPayments = _totalPayments - _paidPayments;
    if (_pendingPayments < 0) _pendingPayments = 0;

    if (widget.member.payoutOrder > 0) {
      _payoutDate = startDate.add(
        Duration(days: intervalDays * widget.member.payoutOrder),
      );
      _daysUntilPayout = _payoutDate!.difference(today).inDays;
      if (_daysUntilPayout < 0) _daysUntilPayout = 0;
    }

    if (widget.committee.frequency == 'daily') {
      _nextPaymentDate = DateTime(today.year, today.month, today.day + 1);
    } else if (widget.committee.frequency == 'weekly') {
      _nextPaymentDate = today.add(Duration(days: 7 - today.weekday % 7));
    } else {
      _nextPaymentDate = DateTime(today.year, today.month + 1, 1);
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final progressPercent = _totalPayments > 0 
        ? (_paidPayments / _totalPayments * 100).clamp(0, 100) 
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Dashboard'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${widget.member.name}!',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.committee.name,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Cycle Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _selectedCycle > 1 ? () => _changeCycle(-1) : null,
                    icon: Icon(
                      Icons.chevron_left,
                      color: _selectedCycle > 1 ? Colors.white : Colors.grey[600],
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        'Cycle $_selectedCycle of $_maxCycles',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (_cycleDates.isNotEmpty)
                        Text(
                          '${DateFormat('MMM d').format(_cycleDates.first)} - ${DateFormat('MMM d, yyyy').format(_cycleDates.last)}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    onPressed: _selectedCycle < _maxCycles ? () => _changeCycle(1) : null,
                    icon: Icon(
                      Icons.chevron_right,
                      color: _selectedCycle < _maxCycles ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Payment Calendar Grid
            if (_cycleDates.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cycle $_selectedCycle Payments',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: _cycleDates.length,
                      itemBuilder: (context, index) {
                        final date = _cycleDates[index];
                        final payment = _dbService.getPayment(widget.member.id, date);
                        final isPaid = payment != null && payment.isPaid;
                        
                        return Container(
                          decoration: BoxDecoration(
                            color: isPaid ? AppTheme.secondaryColor : Colors.grey[800],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isPaid ? Icons.check : Icons.close,
                                color: isPaid ? Colors.white : Colors.grey[600],
                                size: 16,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('d').format(date),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: isPaid ? Colors.white : Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLegendItem(AppTheme.secondaryColor, 'Paid'),
                        const SizedBox(width: 16),
                        _buildLegendItem(Colors.grey[800]!, 'Pending'),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Payout Card
            _buildInfoCard(
              icon: Icons.account_balance_wallet_rounded,
              title: 'Your Payout',
              content: widget.member.hasReceivedPayout
                  ? 'Already Received!'
                  : _payoutDate != null
                      ? DateFormat('MMMM d, yyyy').format(_payoutDate!)
                      : 'Not assigned yet',
              subtitle: widget.member.hasReceivedPayout
                  ? 'Congratulations!'
                  : _daysUntilPayout > 0
                      ? '$_daysUntilPayout days remaining'
                      : _payoutDate != null
                          ? 'Payout day!'
                          : 'Waiting for assignment',
              color: widget.member.hasReceivedPayout
                  ? AppTheme.secondaryColor
                  : AppTheme.warningColor,
            ),
            const SizedBox(height: 16),

            // Payment Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bar_chart_rounded, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Your Payment Status',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          'Paid',
                          '$_paidPayments/${_totalPayments > 0 ? _totalPayments : "-"}',
                          AppTheme.secondaryColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatItem(
                          'Pending',
                          '$_pendingPayments days',
                          AppTheme.errorColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progress',
                            style: TextStyle(color: Colors.grey[400], fontSize: 13),
                          ),
                          Text(
                            '${progressPercent.toStringAsFixed(0)}%',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progressPercent / 100,
                          minHeight: 12,
                          backgroundColor: Colors.grey[800],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progressPercent >= 80
                                ? AppTheme.secondaryColor
                                : progressPercent >= 50
                                    ? AppTheme.warningColor
                                    : AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Next Payment Card
            _buildInfoCard(
              icon: Icons.calendar_today_rounded,
              title: 'Next Payment',
              content: _nextPaymentDate != null
                  ? _isToday(_nextPaymentDate!)
                      ? 'Today'
                      : _isTomorrow(_nextPaymentDate!)
                          ? 'Tomorrow'
                          : DateFormat('EEEE, MMM d').format(_nextPaymentDate!)
                  : 'N/A',
              subtitle: 'Amount: PKR ${NumberFormat('#,###').format(widget.committee.contributionAmount.toInt())}',
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 16),

            // Committee Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Committee Details',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Committee Code', widget.committee.code),
                  _buildDetailRow('Your Member Code', widget.member.memberCode),
                  _buildDetailRow('Your Payout Order', '#${widget.member.payoutOrder}'),
                  _buildDetailRow('Collection', _capitalize(widget.committee.frequency)),
                  _buildDetailRow(
                    'Contribution',
                    'PKR ${NumberFormat('#,###').format(widget.committee.contributionAmount.toInt())}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Payout List Card
            _buildPayoutListCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutListCard() {
    final members = _dbService.getMembersByCommittee(widget.committee.id);
    members.sort((a, b) => a.payoutOrder.compareTo(b.payoutOrder));
    
    final intervalDays = widget.committee.paymentIntervalDays;
    final startDate = widget.committee.startDate;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_alt_rounded, color: AppTheme.primaryColor, size: 24),
              const SizedBox(width: 12),
              Text(
                'Payout Schedule',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Members who have received their payout',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: members.length,
            separatorBuilder: (context, index) => Divider(
              color: Colors.grey[800],
              height: 1,
            ),
            itemBuilder: (context, index) {
              final member = members[index];
              final isCurrentMember = member.id == widget.member.id;
              final payoutDate = startDate.add(Duration(days: intervalDays * member.payoutOrder));
              
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: isCurrentMember ? BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ) : null,
                child: Row(
                  children: [
                    // Payout order number
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: member.hasReceivedPayout
                            ? AppTheme.secondaryColor
                            : Colors.grey[700],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '#${member.payoutOrder}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Member info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  member.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: isCurrentMember ? FontWeight.bold : FontWeight.w500,
                                    color: isCurrentMember ? AppTheme.primaryColor : Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCurrentMember) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'You',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('MMM d, yyyy').format(payoutDate),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Payout status
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: member.hasReceivedPayout
                            ? AppTheme.secondaryColor.withOpacity(0.2)
                            : Colors.grey[800],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: member.hasReceivedPayout
                              ? AppTheme.secondaryColor
                              : Colors.grey[600]!,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            member.hasReceivedPayout
                                ? Icons.check_circle
                                : Icons.schedule,
                            size: 14,
                            color: member.hasReceivedPayout
                                ? AppTheme.secondaryColor
                                : Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            member.hasReceivedPayout ? 'Paid' : 'Pending',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: member.hasReceivedPayout
                                  ? AppTheme.secondaryColor
                                  : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: color, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500])),
          Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day;
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return '${s[0].toUpperCase()}${s.substring(1)}';
  }
  
  void _changeCycle(int delta) {
    final newCycle = _selectedCycle + delta;
    if (newCycle >= 1 && newCycle <= _maxCycles) {
      setState(() {
        _selectedCycle = newCycle;
      });
      _calculateStats();
    }
  }
  
  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
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
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }
}
