part of 'payment_sheet_screen.dart';

extension _PaymentSheetExportPart on _PaymentSheetScreenState {
  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _PaymentSheetScreenState._surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.cFFCBD5E1,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Export Payment Sheet',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _PaymentSheetScreenState._textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a cycle to export',
                  style: GoogleFonts.inter(
                    color: _PaymentSheetScreenState._textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 44,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _maxCycles + 1,
                    itemBuilder: (context, index) {
                      final isAllCycles = index == 0;
                      final cycleNum = index;
                      final isOngoing =
                          !isAllCycles &&
                          _exportService.isCycleOngoing(
                            widget.committee,
                            cycleNum,
                          );
                      final isCompleted =
                          !isAllCycles &&
                          _exportService.isCycleCompleted(
                            widget.committee,
                            cycleNum,
                          );

                      String label;
                      Color bgColor;
                      Color textColor;
                      Color borderColor;
                      if (isAllCycles) {
                        label = 'All Cycles';
                        bgColor = _PaymentSheetScreenState._primary.withOpacity(
                          0.12,
                        );
                        textColor = _PaymentSheetScreenState._primary;
                        borderColor = _PaymentSheetScreenState._primary
                            .withOpacity(0.35);
                      } else if (isOngoing) {
                        label = 'Cycle $cycleNum (Ongoing)';
                        bgColor = _PaymentSheetScreenState._warning.withOpacity(
                          0.14,
                        );
                        textColor = _PaymentSheetScreenState._warning;
                        borderColor = _PaymentSheetScreenState._warning
                            .withOpacity(0.35);
                      } else if (isCompleted) {
                        label = 'Cycle $cycleNum';
                        bgColor = _PaymentSheetScreenState._success.withOpacity(
                          0.12,
                        );
                        textColor = _PaymentSheetScreenState._success;
                        borderColor = _PaymentSheetScreenState._success
                            .withOpacity(0.35);
                      } else {
                        label = 'Cycle $cycleNum (Upcoming)';
                        bgColor = AppColors.mutedSurface;
                        textColor = _PaymentSheetScreenState._textSecondary;
                        borderColor = AppColors.cFFD7DFEE;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.pop(context);
                              _showExportFormatDialog(
                                isAllCycles ? null : cycleNum,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: Text(
                                label,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tap a cycle above to export, or scroll for more cycles',
                  style: GoogleFonts.inter(
                    color: _PaymentSheetScreenState._textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _showExportFormatDialog(int? cycle) {
    final cycleLabel = cycle != null ? 'Cycle $cycle' : 'All Cycles';
    String? dateRange;
    if (cycle != null) {
      final range = _exportService.getCycleDateRange(widget.committee, cycle);
      final start = range['start']!;
      final end = range['end']!;
      dateRange = '${_formatDate(start)} - ${_formatDate(end)}';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: _PaymentSheetScreenState._surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.cFFCBD5E1,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Export $cycleLabel',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _PaymentSheetScreenState._textPrimary,
                  ),
                ),
                if (dateRange != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    dateRange,
                    style: GoogleFonts.inter(
                      color: _PaymentSheetScreenState._textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      AppIcons.picture_as_pdf,
                      color: Colors.red,
                    ),
                  ),
                  title: Text(
                    'Export as PDF',
                    style: GoogleFonts.inter(
                      color: _PaymentSheetScreenState._textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Print or share as document',
                    style: GoogleFonts.inter(
                      color: _PaymentSheetScreenState._textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    ToastService.info(context, 'Generating PDF...');
                    await _exportService.exportToPdf(
                      widget.committee,
                      cycle: cycle,
                    );
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      AppIcons.table_chart,
                      color: Colors.green,
                    ),
                  ),
                  title: Text(
                    'Export as CSV (Excel)',
                    style: GoogleFonts.inter(
                      color: _PaymentSheetScreenState._textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Open in Excel or Google Sheets',
                    style: GoogleFonts.inter(
                      color: _PaymentSheetScreenState._textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    ToastService.info(context, 'Generating CSV...');
                    await _exportService.exportToCsv(
                      widget.committee,
                      cycle: cycle,
                    );
                  },
                ),
              ],
            ),
          ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
