part of 'payment_sheet_screen.dart';

extension _PaymentSheetRemindersPart on _PaymentSheetScreenState {
  String _normalizePhoneForWhatsApp(String phone) {
    var normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalized.startsWith('+')) {
      normalized = normalized.substring(1);
    }
    return normalized;
  }

  List<DateTime> _pendingDueDatesForMember(Member member) {
    final now = DateTime.now();
    final dueDates =
        _dates
            .where(
              (date) =>
                  !date.isAfter(now) && !_isPaymentMarked(member.id, date),
            )
            .toList()
          ..sort((a, b) => a.compareTo(b));
    return dueDates;
  }

  String _buildWhatsAppReminderMessage(Member member, List<DateTime> dueDates) {
    final dueCount = dueDates.length;
    final amountPerInstallment = widget.committee.contributionAmount;
    final totalDue = amountPerInstallment * dueCount;
    final dateFormatter = DateFormat('dd MMM yyyy');

    final dueDateLines = dueDates
        .take(6)
        .map((date) => '- ${dateFormatter.format(date)}')
        .join('\n');
    final extraLine =
        dueDates.length > 6 ? '\n- ...and ${dueDates.length - 6} more' : '';

    return 'Assalam o Alaikum ${member.name},\\n\\n'
        'Reminder from ${widget.committee.name}\\n'
        'Cycle $_selectedCycle\\n\\n'
        'Pending installments: $dueCount\\n'
        'Amount per installment: ${widget.committee.currency} ${amountPerInstallment.toStringAsFixed(0)}\\n'
        'Total due: ${widget.committee.currency} ${totalDue.toStringAsFixed(0)}\\n\\n'
        'Due dates:\\n$dueDateLines$extraLine\\n\\n'
        'Please clear your dues at your earliest convenience. Thank you.';
  }

  Future<void> _sendWhatsAppReminder(
    Member member,
    List<DateTime> dueDates,
  ) async {
    final normalizedPhone = _normalizePhoneForWhatsApp(member.phone);
    if (normalizedPhone.isEmpty) {
      ToastService.error(
        context,
        'Cannot send reminder: member phone number is missing/invalid.',
      );
      return;
    }

    if (dueDates.isEmpty) {
      ToastService.info(
        context,
        '${member.name} has no pending dues in this cycle.',
      );
      return;
    }

    final message = _buildWhatsAppReminderMessage(member, dueDates);
    final whatsappUri = Uri.parse(
      'whatsapp://send?phone=$normalizedPhone&text=${Uri.encodeComponent(message)}',
    );
    final webUri = Uri.parse(
      'https://wa.me/$normalizedPhone?text=${Uri.encodeComponent(message)}',
    );

    final openedApp = await launchUrl(
      whatsappUri,
      mode: LaunchMode.externalApplication,
    );

    if (!openedApp) {
      final openedWeb = await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
      if (!openedWeb && mounted) {
        ToastService.error(context, 'Could not open WhatsApp.');
        return;
      }
    }

    if (mounted) {
      ToastService.success(
        context,
        'WhatsApp reminder opened for ${member.name}.',
      );
    }
  }

  void _showReminderSheet() {
    final currencySymbol =
        CurrencyService.getCurrencyInfo(widget.committee.currency).symbol;

    final dueMap = {
      for (final member in _members)
        member.id: _pendingDueDatesForMember(member),
    };
    final pendingMembers =
        _members
            .where((member) => (dueMap[member.id] ?? const []).isNotEmpty)
            .toList();

    final totalPendingInstallments = pendingMembers.fold<int>(
      0,
      (sum, member) => sum + (dueMap[member.id]?.length ?? 0),
    );
    final totalPendingAmount =
        totalPendingInstallments * widget.committee.contributionAmount;

    showModalBottomSheet(
      context: context,
      backgroundColor: _PaymentSheetScreenState._surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WhatsApp Reminders',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _PaymentSheetScreenState._textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cycle $_selectedCycle • Send dues reminders to pending members',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _PaymentSheetScreenState._textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cFFF8FAFF,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.lightBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            icon: AppIcons.members,
                            color: _PaymentSheetScreenState._warning,
                            value: '${pendingMembers.length}',
                            label: 'Pending Members',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatItem(
                            color: _PaymentSheetScreenState._primary,
                            iconText: currencySymbol,
                            value:
                                '${widget.committee.currency} ${totalPendingAmount.toInt()}',
                            label: 'Total Due',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (pendingMembers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'No pending dues for this cycle.',
                          style: GoogleFonts.inter(
                            color: _PaymentSheetScreenState._textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: pendingMembers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final member = pendingMembers[index];
                          final dueDates =
                              dueMap[member.id] ?? const <DateTime>[];
                          final dueAmount =
                              dueDates.length *
                              widget.committee.contributionAmount;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.cFFF8FAFF,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.lightBorder),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        member.name,
                                        style: GoogleFonts.inter(
                                          color:
                                              _PaymentSheetScreenState
                                                  ._textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${dueDates.length} pending • ${widget.committee.currency} ${dueAmount.toInt()}',
                                        style: GoogleFonts.inter(
                                          color:
                                              _PaymentSheetScreenState
                                                  ._textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed:
                                      () => _sendWhatsAppReminder(
                                        member,
                                        dueDates,
                                      ),
                                  icon: const Icon(
                                    AppIcons.chat_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Send'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        _PaymentSheetScreenState._primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
    );
  }
}
