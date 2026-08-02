part of 'payment_sheet_screen.dart';

extension _PaymentSheetWidgetsPart on _PaymentSheetScreenState {
  void _showMemberActions(Member member) {
    final unpaidCount = _dates.where((date) {
      if (_isDateSkipped(date)) return false;
      return !_isPaymentMarked(member.id, date);
    }).length;

    showModalBottomSheet(
      context: context,
      backgroundColor: _PaymentSheetScreenState._surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(ctx).viewPadding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cFFD7E0F2,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              member.name,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _PaymentSheetScreenState._textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$unpaidCount unpaid period${unpaidCount != 1 ? 's' : ''} in this cycle',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _PaymentSheetScreenState._textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            if (unpaidCount > 0)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _markAllPaidForMember(member);
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Mark All Paid for This Cycle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _PaymentSheetScreenState._success,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            if (unpaidCount == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'All paid for this cycle ✓',
                  style: GoogleFonts.inter(
                    color: _PaymentSheetScreenState._success,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(double amountPerCell) {
    final totals = List<double>.generate(_dates.length, (index) {
      double total = 0;
      final date = _dates[index];
      for (var member in _members) {
        if (_isPaymentMarked(member.id, date)) {
          total += amountPerCell;
        }
      }
      return total;
    });

    final targetAmount = amountPerCell * _members.length;
    final payoutInterval = widget.committee.paymentIntervalDays;
    const double memberColWidth = 190;
    const double dateColWidth = 56;
    const double duesColWidth = 120;

    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.cFFF8FAFF,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.lightBorder),
          ),
          child: Row(
            children: [
              _buildMatrixHeaderCell('Member', memberColWidth, isStart: true),
              ..._dates.asMap().entries.map((entry) {
                final index = entry.key;
                final date = entry.value;
                final isFutureDate = date.isAfter(now);
                final isSkipped = _isDateSkipped(date);
                final format =
                    widget.committee.frequency == 'monthly'
                        ? DateFormat('MMM')
                        : DateFormat('dd/MM');

                // Count non-skipped dates up to this point to determine payout day
                int activeDatesBefore = 0;
                for (int i = 0; i <= index; i++) {
                  if (!_isDateSkipped(_dates[i])) activeDatesBefore++;
                }
                final isPayoutDay =
                    payoutInterval > 0 &&
                    !isSkipped &&
                    activeDatesBefore > 0 &&
                    (activeDatesBefore % payoutInterval == 0);

                return _buildDateHeaderCell(
                  width: dateColWidth,
                  label: format.format(date),
                  isFutureDate: isFutureDate,
                  isPayoutDay: isPayoutDay,
                  isSkipped: isSkipped,
                  onToggleSkip: () => _toggleSkippedDay(date),
                  progress: totals[index] / targetAmount,
                );
              }),
              _buildMatrixHeaderCell('Dues', duesColWidth, isEnd: true),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ..._members.asMap().entries.map((entry) {
          final member = entry.value;
          final memberDebt = _calculateMemberDebt(member.id);
          final isDefaulter = memberDebt['isDefaulter'] as bool;
          final unpaidCount = memberDebt['unpaidCount'] as int;
          final memberAdvance = _calculateMemberAdvance(member.id);
          final hasAdvance = memberAdvance['hasAdvance'] as bool;
          final advanceCount = memberAdvance['advanceCount'] as int;

          // Zero-indexed payout slot based on the member's assigned payout order.
          // Using payoutOrder (not the visual row index) ensures the star is on
          // the correct member even after reordering/shuffling.
          final memberPayoutSlot = member.payoutOrder - 1;

          return GestureDetector(
            onLongPress: () => _showMemberActions(member),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: _PaymentSheetScreenState._surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      isDefaulter
                          ? _PaymentSheetScreenState._warning.withOpacity(0.35)
                          : AppColors.cFFE5ECF9,
                ),
              ),
              child: Row(
                children: [
                  _buildMemberInfoCell(
                    member: member,
                    width: memberColWidth,
                    isDefaulter: isDefaulter,
                    hasAdvance: hasAdvance,
                    advanceCount: advanceCount,
                  ),
                  ..._dates.map((date) {
                    final isPaid = _isPaymentMarked(member.id, date);
                    final isSkipped = _isDateSkipped(date);

                    // Count non-skipped dates up to this one to determine payout round
                    int activeDatesBefore = 0;
                    for (int i = 0; i < _dates.length; i++) {
                      if (_dates[i] == date) break;
                      if (!_isDateSkipped(_dates[i])) activeDatesBefore++;
                    }
                    final currentRound =
                        payoutInterval > 0 ? (activeDatesBefore ~/ payoutInterval) : 0;
                    // Compare against the member's own payout slot (0-indexed),
                    // not the visual row position, so shuffled orders work correctly.
                    final receiverIndex = currentRound % _members.length;
                    final isPayoutReceiver = receiverIndex == memberPayoutSlot;

                    final isActiveDate = !isSkipped;
                    final isPayoutDay =
                        payoutInterval > 0 &&
                        isActiveDate &&
                        ((activeDatesBefore + 1) % payoutInterval == 0);
                    final isPayoutCell = isPayoutReceiver && isPayoutDay;

                    return _buildPaymentCell(
                      width: dateColWidth,
                      isPaid: isPaid,
                      isPayoutCell: isPayoutCell,
                      isSkipped: isSkipped,
                      onTap: isSkipped ? null : () => _togglePayment(member.id, date),
                    );
                  }),
                  _buildDuesCell(
                    width: duesColWidth,
                    isDefaulter: isDefaulter,
                    unpaidCount: unpaidCount,
                    hasAdvance: hasAdvance,
                    advanceCount: advanceCount,
                  ),
                ],
              ),
            ),
          );
        }),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cFFF8FAFF,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.lightBorder),
          ),
          child: Row(
            children: [
              SizedBox(
                width: memberColWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Collected',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: _PaymentSheetScreenState._textSecondary,
                    ),
                  ),
                ),
              ),
              ...totals.map((total) {
                final isMet = total >= targetAmount;
                return SizedBox(
                  width: dateColWidth,
                  child: Text(
                    '${total.toInt()}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color:
                          isMet
                              ? _PaymentSheetScreenState._success
                              : _PaymentSheetScreenState._textSecondary,
                    ),
                  ),
                );
              }),
              SizedBox(
                width: duesColWidth,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _calculateTotalDebt() > 0
                            ? _PaymentSheetScreenState._warning.withOpacity(
                              0.14,
                            )
                            : _PaymentSheetScreenState._success.withOpacity(
                              0.1,
                            ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _calculateTotalDebt() > 0
                        ? '${widget.committee.currency} ${_calculateTotalDebt().toInt()}'
                        : 'All Paid ✓',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color:
                          _calculateTotalDebt() > 0
                              ? _PaymentSheetScreenState._warning
                              : _PaymentSheetScreenState._success,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixHeaderCell(
    String title,
    double width, {
    bool isStart = false,
    bool isEnd = false,
  }) {
    return Container(
      width: width,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: AppColors.cFFE5ECF9, width: isEnd ? 0 : 1),
        ),
      ),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _PaymentSheetScreenState._textPrimary,
        ),
      ),
    );
  }

  Widget _buildDateHeaderCell({
    required double width,
    required String label,
    required bool isFutureDate,
    required bool isPayoutDay,
    required bool isSkipped,
    required VoidCallback onToggleSkip,
    required double progress,
  }) {
    return GestureDetector(
      onLongPress: onToggleSkip,
      child: Container(
        width: width,
        height: 56,
        decoration: BoxDecoration(
          border: const Border(
            right: BorderSide(color: AppColors.cFFE5ECF9, width: 1),
          ),
          color:
              isSkipped
                  ? _PaymentSheetScreenState._warning.withOpacity(0.12)
                  : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: onToggleSkip,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color:
                      isSkipped
                          ? _PaymentSheetScreenState._warning
                          : AppColors.cFFD7E0F2,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.block_rounded,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                decoration:
                    isSkipped ? TextDecoration.lineThrough : null,
                decorationColor: _PaymentSheetScreenState._warning,
                color:
                    isSkipped
                        ? _PaymentSheetScreenState._warning
                        : isFutureDate
                            ? _PaymentSheetScreenState._primary
                            : (isPayoutDay
                                ? _PaymentSheetScreenState._warning
                                : _PaymentSheetScreenState
                                    ._textSecondary),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 20,
              height: 3,
              decoration: BoxDecoration(
                color:
                    isSkipped
                        ? _PaymentSheetScreenState._warning
                        : progress >= 1
                            ? _PaymentSheetScreenState._success
                            : AppColors.cFFD7E0F2,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberInfoCell({
    required Member member,
    required double width,
    required bool isDefaulter,
    required bool hasAdvance,
    required int advanceCount,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.cFFE8EEFA,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '#${member.payoutOrder}',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: _PaymentSheetScreenState._primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                member.name,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color:
                      isDefaulter
                          ? _PaymentSheetScreenState._warning
                          : hasAdvance
                          ? _PaymentSheetScreenState._primary
                          : _PaymentSheetScreenState._textPrimary,
                ),
              ),
            ),
            if (isDefaulter)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  AppIcons.warning,
                  size: 14,
                  color: _PaymentSheetScreenState._warning,
                ),
              ),
            if (hasAdvance)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: _PaymentSheetScreenState._primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '+$advanceCount',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: _PaymentSheetScreenState._primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCell({
    required double width,
    required bool isPaid,
    required bool isPayoutCell,
    bool isSkipped = false,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: width,
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color:
                  isSkipped
                      ? AppColors.cFFD7E0F2.withOpacity(0.3)
                      : isPaid
                          ? _PaymentSheetScreenState._success
                          : AppColors.cFFEEF2FA,
              borderRadius: BorderRadius.circular(8),
              border:
                  isSkipped
                      ? Border.all(
                          color: AppColors.cFFD7E0F2,
                          width: 1,
                        )
                      : isPayoutCell
                          ? Border.all(
                              color: _PaymentSheetScreenState._warning,
                              width: 2,
                            )
                          : Border.all(
                              color:
                                  isPaid
                                      ? _PaymentSheetScreenState._success
                                      : AppColors.cFFD3DDEF,
                              width: 1,
                            ),
              boxShadow:
                  isPayoutCell && !isSkipped
                      ? [
                          BoxShadow(
                            color:
                                _PaymentSheetScreenState._warning.withOpacity(
                                  0.2,
                                ),
                            blurRadius: 5,
                          ),
                        ]
                      : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isSkipped)
                  Icon(
                    Icons.block_rounded,
                    color: AppColors.cFFD7E0F2,
                    size: 14,
                  )
                else if (isPaid)
                  const Icon(
                    AppIcons.check_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                if (isPayoutCell && !isPaid && !isSkipped)
                  const Icon(
                    AppIcons.star_outline_rounded,
                    color: _PaymentSheetScreenState._warning,
                    size: 16,
                  ),
                if (isPayoutCell && isPaid && !isSkipped)
                  const Positioned(
                    right: 1,
                    top: 1,
                    child: Icon(
                      AppIcons.star_rounded,
                      color: _PaymentSheetScreenState._warning,
                      size: 8,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDuesCell({
    required double width,
    required bool isDefaulter,
    required int unpaidCount,
    required bool hasAdvance,
    required int advanceCount,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color:
                isDefaulter
                    ? _PaymentSheetScreenState._warning.withOpacity(0.14)
                    : hasAdvance
                    ? _PaymentSheetScreenState._primary.withOpacity(0.12)
                    : _PaymentSheetScreenState._success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isDefaulter) ...[
                Text(
                  '${widget.committee.currency} ${(unpaidCount * widget.committee.contributionAmount).toInt()}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _PaymentSheetScreenState._warning,
                  ),
                ),
                Text(
                  '$unpaidCount unpaid',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: _PaymentSheetScreenState._textSecondary,
                  ),
                ),
              ] else if (hasAdvance) ...[
                Text(
                  '+$advanceCount',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _PaymentSheetScreenState._primary,
                  ),
                ),
                Text(
                  'advance',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: _PaymentSheetScreenState._textSecondary,
                  ),
                ),
              ] else ...[
                const Icon(
                  AppIcons.verified_rounded,
                  color: _PaymentSheetScreenState._success,
                  size: 14,
                ),
                Text(
                  'clear',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: _PaymentSheetScreenState._success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    IconData? icon,
    String? iconText,
    required Color color,
    required String value,
    required String label,
  }) {
    assert(icon != null || iconText != null);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null)
            Icon(icon, color: color, size: 18)
          else
            Text(
              iconText!,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1,
              ),
            ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: _PaymentSheetScreenState._textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
              AppIcons.grid_off_rounded,
              size: 44,
              color: _PaymentSheetScreenState._primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Members Yet',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _PaymentSheetScreenState._textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Add members to start collecting payments. The Period and Cycle options will appear once members are added.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: _PaymentSheetScreenState._textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) =>
                          MemberManagementScreen(committee: widget.committee),
                ),
              );
              _loadData();
            },
            icon: const Icon(AppIcons.memberAdd),
            label: const Text('Add Members'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _PaymentSheetScreenState._primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberPersonalView() {
    final member = widget.viewAsMember!;

    int paidCount = 0;
    int advanceCount = 0;
    int skippedCount = 0;
    final now = DateTime.now();

    for (var date in _dates) {
      if (_isDateSkipped(date)) {
        skippedCount++;
        continue;
      }
      if (_isPaymentMarked(member.id, date)) {
        paidCount++;
        if (date.isAfter(now)) advanceCount++;
      }
    }

    final totalDue = _dates.length - skippedCount;
    final totalContribution = paidCount * widget.committee.contributionAmount;
    final advanceAmount = advanceCount * widget.committee.contributionAmount;

    return MemberCalendarView(
      member: member,
      committee: widget.committee,
      members: _members,
      dates: _dates,
      paidCount: paidCount,
      totalDue: totalDue,
      totalContribution: totalContribution,
      advanceCount: advanceCount,
      advanceAmount: advanceAmount,
      isPaymentMarked: _isPaymentMarked,
      onRefresh: () => _syncAndLoad(waitForSync: true),
    );
  }
}
