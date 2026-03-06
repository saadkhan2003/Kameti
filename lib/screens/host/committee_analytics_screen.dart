import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/committee.dart';
import '../../models/member.dart';
import '../../models/payment.dart';
import '../../services/database_service.dart';
import '../../services/currency_service.dart';

class CommitteeAnalyticsScreen extends StatefulWidget {
  final Committee committee;

  const CommitteeAnalyticsScreen({super.key, required this.committee});

  @override
  State<CommitteeAnalyticsScreen> createState() =>
      _CommitteeAnalyticsScreenState();
}

class _CommitteeAnalyticsScreenState extends State<CommitteeAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  static const Color _bg = Color(0xFFF6F8FD);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF3347A8);
  static const Color _success = Color(0xFF059669);
  static const Color _warning = Color(0xFFD97706);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  final _dbService = DatabaseService();
  List<Member> _members = [];
  List<Payment> _payments = [];
  late String _currencySymbol;
  late String _currencyCode;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    final info = CurrencyService.getCurrencyInfo(widget.committee.currency);
    _currencySymbol = info.symbol;
    _currencyCode = info.code;

    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadData();
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _members = _dbService.getMembersByCommittee(widget.committee.id);
      _payments = _dbService.getPaymentsByCommittee(widget.committee.id);
    });
  }

  // ============ COMPUTED DATA ============

  int get _totalPayments => _payments.length;
  int get _paidPayments => _payments.where((p) => p.isPaid).length;
  int get _unpaidPayments => _totalPayments - _paidPayments;

  double get _collectionRate =>
      _totalPayments == 0 ? 0 : (_paidPayments / _totalPayments) * 100;

  double get _totalCollected =>
      _paidPayments * widget.committee.contributionAmount;
  double get _totalPending =>
      _unpaidPayments * widget.committee.contributionAmount;
  double get _totalExpected =>
      _totalPayments * widget.committee.contributionAmount;

  int get _membersWithPayout =>
      _members.where((m) => m.hasReceivedPayout).length;

  List<_MemberStat> get _memberStats {
    return _members.map((m) {
        final memberPayments = _payments.where((p) => p.memberId == m.id);
        final total = memberPayments.length;
        final paid = memberPayments.where((p) => p.isPaid).length;
        final rate = total == 0 ? 0.0 : (paid / total) * 100;
        return _MemberStat(name: m.name, paid: paid, total: total, rate: rate);
      }).toList()
      ..sort((a, b) => b.rate.compareTo(a.rate));
  }

  List<_DateCollection> get _collectionTrend {
    final paymentsByDate = <String, _DateCollection>{};
    for (final p in _payments) {
      final key =
          '${p.date.year}-${p.date.month.toString().padLeft(2, '0')}-${p.date.day.toString().padLeft(2, '0')}';
      paymentsByDate.putIfAbsent(
        key,
        () => _DateCollection(date: p.date, paid: 0, total: 0),
      );
      paymentsByDate[key]!.total++;
      if (p.isPaid) paymentsByDate[key]!.paid++;
    }
    return paymentsByDate.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: _textPrimary,
        iconTheme: const IconThemeData(color: _textPrimary),
        title: Text(
          '${widget.committee.name} Analytics',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: _textPrimary,
          ),
        ),
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Collection Card
              _buildHeroCard(),
              const SizedBox(height: 20),

              // Quick Stats Row
              _buildQuickStats(),
              const SizedBox(height: 24),

              // Payment Donut
              _buildSectionHeader(
                'Payment Breakdown',
                Icons.pie_chart_rounded,
                const Color(0xFF7C4DFF),
              ),
              const SizedBox(height: 12),
              _buildPaymentDonut(),
              const SizedBox(height: 24),

              // Collection Trend
              if (_collectionTrend.length >= 2) ...[
                _buildSectionHeader(
                  'Collection Trend',
                  Icons.trending_up_rounded,
                  const Color(0xFF00BCD4),
                ),
                const SizedBox(height: 12),
                _buildCollectionTrendChart(),
                const SizedBox(height: 24),
              ],

              // Member Leaderboard
              _buildSectionHeader(
                'Member Leaderboard',
                Icons.leaderboard_rounded,
                const Color(0xFFFFB74D),
              ),
              const SizedBox(height: 12),
              _buildMemberLeaderboard(),
              const SizedBox(height: 24),

              // Payout Progress
              _buildSectionHeader(
                'Payout Progress',
                Icons.payments_rounded,
                const Color(0xFF448AFF),
              ),
              const SizedBox(height: 12),
              _buildPayoutProgress(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ============ HERO CARD ============

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEDF2FF), Color(0xFFE4ECFF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD2DDF8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3347A8).withOpacity(0.1),
            blurRadius: 20,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _success.withOpacity(0.35)),
                ),
                child: Text(
                  'Total Collected',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _success,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${_collectionRate.toStringAsFixed(0)}%',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color:
                      _collectionRate >= 80
                          ? _success
                          : _collectionRate >= 50
                          ? _warning
                          : _danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$_currencySymbol ${_formatNumber(_totalCollected.toInt())}',
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'of $_currencySymbol ${_formatNumber(_totalExpected.toInt())} expected',
            style: GoogleFonts.inter(fontSize: 13, color: _textSecondary),
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCFD9EF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: _collectionRate / 100,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_success, Color(0xFF34D399)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: _success.withOpacity(0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ QUICK STATS ============

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildMiniStat(
            icon: Icons.receipt_long_rounded,
            label: 'Payments',
            value: '$_paidPayments/$_totalPayments',
            color: const Color(0xFF7C4DFF),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniStat(
            icon: Icons.group_rounded,
            label: 'Members',
            value: '${_members.length}',
            color: const Color(0xFF448AFF),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniStat(
            icon: Icons.schedule_rounded,
            label: 'Pending',
            value: '$_currencySymbol${_formatCompact(_totalPending)}',
            color: const Color(0xFFFFB74D),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  // ============ SECTION HEADER ============

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
      ],
    );
  }

  // ============ PAYMENT DONUT ============

  Widget _buildPaymentDonut() {
    final hasData = _totalPayments > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE4F7)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 40,
                    startDegreeOffset: -90,
                    sections:
                        hasData
                            ? [
                              PieChartSectionData(
                                value: _paidPayments.toDouble(),
                                color: _success,
                                radius: 22,
                                title: '',
                              ),
                              PieChartSectionData(
                                value: _unpaidPayments.toDouble(),
                                color: _danger.withOpacity(0.6),
                                radius: 18,
                                title: '',
                              ),
                            ]
                            : [
                              PieChartSectionData(
                                value: 1,
                                color: Colors.grey.withAlpha(30),
                                radius: 18,
                                title: '',
                              ),
                            ],
                  ),
                ),
                // Center percentage
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_collectionRate.toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      'collected',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLegendRow(
                  'Paid',
                  '$_paidPayments',
                  '$_currencySymbol${_formatCompact(_totalCollected)}',
                  _success,
                ),
                const SizedBox(height: 16),
                _buildLegendRow(
                  'Unpaid',
                  '$_unpaidPayments',
                  '$_currencySymbol${_formatCompact(_totalPending)}',
                  _danger,
                ),
                const SizedBox(height: 16),
                Divider(color: const Color(0xFFE2E8F0), height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textSecondary,
                      ),
                    ),
                    Text(
                      '$_currencySymbol${_formatCompact(_totalExpected)}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(
    String label,
    String count,
    String amount,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [BoxShadow(color: color.withAlpha(60), blurRadius: 6)],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$label ($count)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _textSecondary,
                ),
              ),
              Text(
                amount,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============ COLLECTION TREND ============

  Widget _buildCollectionTrendChart() {
    final trends = _collectionTrend;
    if (trends.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE4F7)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine:
                      (value) => FlLine(
                        color: const Color(0xFFE2E8F0),
                        strokeWidth: 1,
                      ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: (trends.length / 4).ceilToDouble().clamp(1, 10),
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= trends.length)
                          return const SizedBox.shrink();
                        final d = trends[idx].date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${d.day}/${d.month}',
                            style: GoogleFonts.inter(
                              color: _textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      trends.length,
                      (i) => FlSpot(i.toDouble(), trends[i].paid.toDouble()),
                    ),
                    isCurved: true,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF06B6D4), _success],
                    ),
                    barWidth: 3,
                    dotData: FlDotData(
                      show: trends.length <= 12,
                      getDotPainter:
                          (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 4,
                            color: _success,
                            strokeWidth: 2,
                            strokeColor: _surface,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _success.withOpacity(0.2),
                          _success.withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: List.generate(
                      trends.length,
                      (i) => FlSpot(i.toDouble(), trends[i].total.toDouble()),
                    ),
                    isCurved: true,
                    color: const Color(0xFF94A3B8),
                    barWidth: 1.5,
                    dashArray: [6, 4],
                    dotData: FlDotData(show: false),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipPadding: const EdgeInsets.all(8),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final isMain = spot.barIndex == 0;
                        return LineTooltipItem(
                          isMain
                              ? '${spot.y.toInt()} paid'
                              : '${spot.y.toInt()} total',
                          GoogleFonts.inter(
                            color: isMain ? _success : _textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildChartLegend('Collected', _success),
              const SizedBox(width: 20),
              _buildChartLegend('Expected', _textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: _textSecondary),
        ),
      ],
    );
  }

  // ============ MEMBER LEADERBOARD ============

  Widget _buildMemberLeaderboard() {
    final stats = _memberStats;
    if (stats.isEmpty) {
      return _buildEmptyCard('No members added yet');
    }

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE4F7)),
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '#',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Member',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    'Score',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          ...stats.take(8).toList().asMap().entries.map((entry) {
            final i = entry.key;
            final stat = entry.value;
            final isTop3 = i < 3;
            final barColor =
                stat.rate >= 80
                    ? _success
                    : stat.rate >= 50
                    ? _warning
                    : _danger;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isTop3 ? barColor.withOpacity(0.08) : Colors.transparent,
                border: const Border(
                  bottom: BorderSide(color: Color(0xFFF0F3FA)),
                ),
              ),
              child: Row(
                children: [
                  // Rank
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${i + 1}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isTop3 ? FontWeight.w700 : FontWeight.w400,
                        color: isTop3 ? barColor : _textSecondary,
                      ),
                    ),
                  ),
                  // Name + bar
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stat.name,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight:
                                isTop3 ? FontWeight.w600 : FontWeight.w400,
                            color: _textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: stat.rate / 100,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(barColor),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Score
                  SizedBox(
                    width: 80,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${stat.rate.toStringAsFixed(0)}%',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: barColor,
                          ),
                        ),
                        Text(
                          '${stat.paid}/${stat.total}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ============ PAYOUT PROGRESS ============

  Widget _buildPayoutProgress() {
    final totalMembers = _members.length;
    final paid = _membersWithPayout;
    final remaining = totalMembers - paid;
    final progress = totalMembers == 0 ? 0.0 : paid / totalMembers;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE4F7)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(_primary),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$paid',
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      'of $totalMembers',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _textSecondary,
                      ),
                    ),
                    Text(
                      'received payout',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildPayoutStatCard('Received', '$paid', _success),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPayoutStatCard(
                  'Remaining',
                  '$remaining',
                  _warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPayoutStatCard(
                  'Per Turn',
                  '$_currencySymbol${_formatCompact(_members.length * widget.committee.contributionAmount)}',
                  _primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  // ============ HELPERS ============

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE4F7)),
      ),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.inter(fontSize: 13, color: _textSecondary),
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    return CurrencyService.formatAmount(
      number.toDouble(),
      _currencyCode,
    ).replaceAll('$_currencyCode ', '');
  }

  String _formatCompact(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}

// ============ DATA CLASSES ============

class _MemberStat {
  final String name;
  final int paid;
  final int total;
  final double rate;
  _MemberStat({
    required this.name,
    required this.paid,
    required this.total,
    required this.rate,
  });
}

class _DateCollection {
  final DateTime date;
  int paid;
  int total;
  _DateCollection({
    required this.date,
    required this.paid,
    required this.total,
  });
}
