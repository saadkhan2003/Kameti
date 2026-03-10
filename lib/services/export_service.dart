import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/committee.dart';
import '../models/payment.dart';
import 'database_service.dart';

class ExportService {
  final DatabaseService _dbService = DatabaseService();

  static const _primaryColor = PdfColor.fromInt(0xFF3347A8);
  static const _accentColor = PdfColor.fromInt(0xFF25348A);
  static const _lightGreen = PdfColor.fromInt(0xFFD1FAE5);
  static const _lightRed = PdfColor.fromInt(0xFFFEF2F2);
  static const _lightBg = PdfColor.fromInt(0xFFF7F8FC);
  static const _softBlue = PdfColor.fromInt(0xFFEAF0FF);
  static const _softBorder = PdfColor.fromInt(0xFFDCE4F7);

  // ============ CYCLE HELPERS ============

  /// Get the total number of cycles (equals number of members)
  int getMaxCycles(Committee committee) {
    final members = _dbService.getMembersByCommittee(committee.id);
    return members.isNotEmpty ? members.length : 1;
  }

  /// Get the date range for a specific cycle
  Map<String, DateTime> getCycleDateRange(Committee committee, int cycle) {
    final payoutIntervalDays = committee.paymentIntervalDays;
    final committeeStartDate = committee.startDate;

    // Calculate periods per payout based on frequency
    int periodsPerPayout;
    if (committee.frequency == 'monthly') {
      periodsPerPayout = (payoutIntervalDays / 30).ceil();
      if (periodsPerPayout < 1) periodsPerPayout = 1;
    } else if (committee.frequency == 'weekly') {
      periodsPerPayout = (payoutIntervalDays / 7).ceil();
      if (periodsPerPayout < 1) periodsPerPayout = 1;
    } else {
      periodsPerPayout = payoutIntervalDays;
      if (periodsPerPayout < 1) periodsPerPayout = 1;
    }

    // Calculate cycle start date
    DateTime cycleStartDate;
    DateTime cycleEndDate;

    if (committee.frequency == 'monthly') {
      cycleStartDate = _addMonths(
        committeeStartDate,
        (cycle - 1) * periodsPerPayout,
      );
      cycleEndDate = _addMonths(cycleStartDate, periodsPerPayout);
      cycleEndDate = cycleEndDate.subtract(const Duration(days: 1));
    } else {
      final daysOffset = (cycle - 1) * payoutIntervalDays;
      cycleStartDate = committeeStartDate.add(Duration(days: daysOffset));
      cycleEndDate = cycleStartDate.add(Duration(days: payoutIntervalDays - 1));
    }

    return {'start': cycleStartDate, 'end': cycleEndDate};
  }

  /// Check if a cycle is completed (end date is in the past)
  bool isCycleCompleted(Committee committee, int cycle) {
    final range = getCycleDateRange(committee, cycle);
    return range['end']!.isBefore(DateTime.now());
  }

  /// Check if a cycle is ongoing (current date is within the cycle)
  bool isCycleOngoing(Committee committee, int cycle) {
    final range = getCycleDateRange(committee, cycle);
    final now = DateTime.now();
    return !now.isBefore(range['start']!) && !now.isAfter(range['end']!);
  }

  // ============ PDF EXPORT ============

  Future<void> exportToPdf(
    Committee committee, {
    DateTime? startDate,
    DateTime? endDate,
    int? cycle,
  }) async {
    final members = _dbService.getMembersByCommittee(committee.id);
    members.sort((a, b) => a.payoutOrder.compareTo(b.payoutOrder));
    final allPayments = _dbService.getPaymentsByCommittee(committee.id);

    DateTime? effectiveStart = startDate;
    DateTime? effectiveEnd = endDate;
    if (cycle != null) {
      final range = getCycleDateRange(committee, cycle);
      effectiveStart = range['start'];
      effectiveEnd = range['end'];
    }

    final dates = _generateDates(
      committee,
      startDate: effectiveStart,
      endDate: effectiveEnd,
    );

    final payments =
        allPayments.where((p) {
          if (effectiveStart != null && p.date.isBefore(effectiveStart))
            return false;
          if (effectiveEnd != null && p.date.isAfter(effectiveEnd))
            return false;
          return true;
        }).toList();

    int totalPaymentsInCycle = 0;
    for (var date in dates) {
      for (var member in members) {
        if (_isPaymentMarked(payments, member.id, date)) {
          totalPaymentsInCycle++;
        }
      }
    }

    final totalCollected = totalPaymentsInCycle * committee.contributionAmount;
    final expectedCollection =
        members.length * dates.length * committee.contributionAmount;
    final pendingCollection =
        ((expectedCollection - totalCollected) < 0)
            ? 0.0
            : (expectedCollection - totalCollected);
    final paidMembersCount = members.where((m) => m.hasReceivedPayout).length;
    final totalExpected = members.length * dates.length;
    final pendingInstallments = totalExpected - totalPaymentsInCycle;
    final collectionRate =
        totalExpected > 0
            ? (totalPaymentsInCycle / totalExpected * 100).toStringAsFixed(1)
            : '0';
    final collectionPercent =
        totalExpected > 0 ? (totalPaymentsInCycle / totalExpected) : 0.0;
    final cycleLabel = cycle != null ? ' - Cycle $cycle' : '';
    final dateRangeLabel =
        effectiveStart != null && effectiveEnd != null
            ? '${DateFormat('dd MMM yyyy').format(effectiveStart)} - ${DateFormat('dd MMM yyyy').format(effectiveEnd)}'
            : null;

    final baseFont = await _loadPdfFont('assets/fonts/NotoSans-Regular.ttf');
    final boldFont = await _loadPdfFont('assets/fonts/NotoSans-Bold.ttf');
    final italicFont = await _loadPdfFont('assets/fonts/NotoSans-Italic.ttf');

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: baseFont,
        bold: boldFont,
        italic: italicFont,
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        maxPages: 1000,
        header:
            (ctx) => _buildHeader(
              committee,
              cycleLabel: cycleLabel,
              dateRange: dateRangeLabel,
            ),
        footer: (ctx) => _buildFooter(ctx),
        build:
            (ctx) => [
              _withSectionWatermark(
                pw.Container(
                  padding: const pw.EdgeInsets.all(18),
                  decoration: pw.BoxDecoration(
                    color: _lightBg,
                    borderRadius: pw.BorderRadius.circular(10),
                    border: pw.Border.all(color: _softBorder),
                  ),
                  child: pw.Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _summaryCard(
                        'Contribution',
                        _fmtMoney(
                          committee.currency,
                          committee.contributionAmount,
                        ),
                      ),
                      _summaryCard('Members', '${members.length}'),
                      _summaryCard('Periods', '${dates.length}'),
                      _summaryCard(
                        'Collection Rate',
                        '$collectionRate%',
                        highlight: true,
                      ),
                      _summaryCard(
                        'Collected',
                        _fmtMoney(committee.currency, totalCollected),
                        highlight: true,
                      ),
                      _summaryCard(
                        'Pending',
                        _fmtMoney(committee.currency, pendingCollection),
                      ),
                      _summaryCard(
                        'Installments',
                        '$totalPaymentsInCycle / $totalExpected',
                      ),
                      _summaryCard(
                        'Payouts',
                        '$paidMembersCount / ${members.length}',
                      ),
                    ],
                  ),
                ),
              ),

              pw.SizedBox(height: 10),
              _withSectionWatermark(
                _buildCollectionProgress(
                  percent: collectionPercent,
                  collected: _fmtMoney(committee.currency, totalCollected),
                  target: _fmtMoney(committee.currency, expectedCollection),
                ),
              ),

              pw.SizedBox(height: 16),
              _withSectionWatermark(
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Committee Snapshot$cycleLabel'),
                    pw.SizedBox(height: 8),
                    pw.Table(
                      border: pw.TableBorder.all(color: _softBorder),
                      children: [
                        _metaRow(
                          'Committee Name',
                          committee.name,
                          'Committee Code',
                          committee.code,
                        ),
                        _metaRow(
                          'Frequency',
                          committee.frequency.toUpperCase(),
                          'Payout Interval',
                          '${committee.paymentIntervalDays} day(s)',
                        ),
                        _metaRow(
                          'Date Range',
                          dateRangeLabel ?? '-',
                          'Currency',
                          committee.currency,
                        ),
                        _metaRow(
                          'Pending Installments',
                          '$pendingInstallments',
                          'Expected Collection',
                          _fmtMoney(committee.currency, expectedCollection),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 18),
              _withSectionWatermark(_sectionTitle('Member Performance')),
              pw.SizedBox(height: 8),
              _withSectionWatermark(
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(0.8),
                    1: const pw.FlexColumnWidth(2.2),
                    2: const pw.FlexColumnWidth(1.8),
                    3: const pw.FlexColumnWidth(1.3),
                    4: const pw.FlexColumnWidth(1.2),
                    5: const pw.FlexColumnWidth(1.7),
                    6: const pw.FlexColumnWidth(1.6),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: _primaryColor),
                      children: [
                        _th('#'),
                        _th('Name'),
                        _th('Phone'),
                        _th('Paid'),
                        _th('%'),
                        _th('Amount'),
                        _th('Payout'),
                      ],
                    ),
                    ...members.asMap().entries.map((e) {
                      int paid = 0;
                      for (var d in dates) {
                        if (_isPaymentMarked(payments, e.value.id, d)) paid++;
                      }
                      final pct =
                          dates.isNotEmpty
                              ? (paid / dates.length * 100).toInt()
                              : 0;
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: e.key.isEven ? PdfColors.white : _lightBg,
                        ),
                        children: [
                          _td('${e.value.payoutOrder}', center: true),
                          _td(e.value.name, bold: true),
                          _td(e.value.phone),
                          _td('$paid/${dates.length}', center: true),
                          _td(
                            '$pct%',
                            center: true,
                            bg:
                                pct >= 80
                                    ? _lightGreen
                                    : (pct < 50 ? _lightRed : null),
                          ),
                          _td(
                            _fmtMoney(
                              committee.currency,
                              paid * committee.contributionAmount,
                            ),
                          ),
                          _td(
                            e.value.hasReceivedPayout ? 'DONE' : 'Pending',
                            center: true,
                            bg: e.value.hasReceivedPayout ? _lightGreen : null,
                            bold: e.value.hasReceivedPayout,
                          ),
                        ],
                      );
                    }),
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: _accentColor),
                      children: [
                        _tf(''),
                        _tf('TOTAL'),
                        _tf(''),
                        _tf('$totalPaymentsInCycle/$totalExpected'),
                        _tf('$collectionRate%'),
                        _tf(_fmtMoney(committee.currency, totalCollected)),
                        _tf('$paidMembersCount/${members.length}'),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 18),
              _withSectionWatermark(_sectionTitle('Date-wise Collection')),
              pw.SizedBox(height: 8),
              _withSectionWatermark(
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.3),
                    1: const pw.FlexColumnWidth(1.2),
                    2: const pw.FlexColumnWidth(1),
                    3: const pw.FlexColumnWidth(1),
                    4: const pw.FlexColumnWidth(1.2),
                    5: const pw.FlexColumnWidth(1.2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: _primaryColor),
                      children: [
                        _th('Date'),
                        _th('Period'),
                        _th('Paid'),
                        _th('Missed'),
                        _th('Collected'),
                        _th('Status'),
                      ],
                    ),
                    ...dates.asMap().entries.map((entry) {
                      final period = entry.key + 1;
                      final date = entry.value;
                      int paidForDate = 0;
                      for (final member in members) {
                        if (_isPaymentMarked(payments, member.id, date))
                          paidForDate++;
                      }
                      final missedForDate = members.length - paidForDate;
                      final amountForDate =
                          paidForDate * committee.contributionAmount;
                      final isFull =
                          members.isNotEmpty && paidForDate == members.length;
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: period.isEven ? PdfColors.white : _lightBg,
                        ),
                        children: [
                          _td(
                            DateFormat('dd MMM yyyy').format(date),
                            center: true,
                          ),
                          _td('$period', center: true),
                          _td('$paidForDate', center: true),
                          _td('$missedForDate', center: true),
                          _td(
                            _fmtMoney(committee.currency, amountForDate),
                            center: true,
                          ),
                          _td(
                            isFull ? 'COMPLETE' : 'PENDING',
                            center: true,
                            bg: isFull ? _lightGreen : _lightRed,
                            bold: true,
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),

              pw.SizedBox(height: 18),
              _withSectionWatermark(_sectionTitle('Payout Schedule')),
              pw.SizedBox(height: 8),
              _withSectionWatermark(
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(0.8),
                    1: const pw.FlexColumnWidth(2.4),
                    2: const pw.FlexColumnWidth(1.8),
                    3: const pw.FlexColumnWidth(1.6),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: _primaryColor),
                      children: [
                        _th('#'),
                        _th('Member'),
                        _th('Status'),
                        _th('Payout Date'),
                      ],
                    ),
                    ...members.map(
                      (m) => pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color:
                              m.hasReceivedPayout
                                  ? _lightGreen
                                  : PdfColors.white,
                        ),
                        children: [
                          _td('${m.payoutOrder}', center: true),
                          _td(m.name, bold: true),
                          _td(
                            m.hasReceivedPayout ? 'DONE' : 'PENDING',
                            center: true,
                          ),
                          _td(
                            m.payoutDate != null
                                ? DateFormat(
                                  'dd MMM yyyy',
                                ).format(m.payoutDate!)
                                : '-',
                            center: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
      ),
    );
    await Printing.layoutPdf(
      onLayout: (f) async => pdf.save(),
      name: '${committee.name}_report.pdf',
    );
  }

  Future<pw.Font> _loadPdfFont(String assetPath) async {
    final normalized = assetPath.replaceAll('\\\\', '/');
    final fallbackCandidates = <String>{
      normalized,
      normalized.startsWith('assets/')
          ? normalized.substring('assets/'.length)
          : 'assets/$normalized',
      normalized.startsWith('assets/') ? 'assets/$normalized' : normalized,
    };

    for (final candidate in fallbackCandidates) {
      try {
        final fontData = await rootBundle.load(candidate);
        return pw.Font.ttf(fontData);
      } catch (_) {}
    }

    if (assetPath.contains('Bold')) return pw.Font.helveticaBold();
    if (assetPath.contains('Italic')) return pw.Font.helveticaOblique();
    return pw.Font.helvetica();
  }

  pw.Widget _buildHeader(
    Committee c, {
    String cycleLabel = '',
    String? dateRange,
  }) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 16),
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(
      color: _softBlue,
      borderRadius: pw.BorderRadius.circular(10),
      border: pw.Border.all(color: _softBorder),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              c.name,
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            pw.Text(
              'Payment Report$cycleLabel',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
            if (dateRange != null)
              pw.Text(
                dateRange,
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: pw.BoxDecoration(
            color: _accentColor,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'Committee Code',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.white),
              ),
              pw.Text(
                c.code,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  pw.Widget _buildFooter(pw.Context ctx) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 16),
    padding: const pw.EdgeInsets.only(top: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
    ),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        pw.Text(
          'KAMETI CONFIDENTIAL',
          style: pw.TextStyle(
            fontSize: 8,
            color: _primaryColor,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Expanded(
          child: pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Page ${ctx.pageNumber}/${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ),
        ),
      ],
    ),
  );

  pw.Widget _summaryCard(
    String label,
    String value, {
    bool highlight = false,
  }) => pw.Container(
    width: 118,
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: pw.BorderRadius.circular(6),
      border: pw.Border.all(color: _softBorder),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: highlight ? _accentColor : _primaryColor,
          ),
        ),
      ],
    ),
  );

  pw.Widget _sectionTitle(String title) => pw.Text(
    title,
    style: pw.TextStyle(
      fontSize: 14,
      fontWeight: pw.FontWeight.bold,
      color: _primaryColor,
    ),
  );

  pw.Widget _withSectionWatermark(pw.Widget child) => child;

  pw.Widget _buildCollectionProgress({
    required double percent,
    required String collected,
    required String target,
  }) {
    final normalized = percent.clamp(0.0, 1.0).toDouble();
    const trackWidth = 240.0;
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _softBorder),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Collection Progress',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: _primaryColor,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                '$collected of $target',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            height: 8,
            width: trackWidth,
            decoration: pw.BoxDecoration(
              color: PdfColors.grey300,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Container(
              width: trackWidth * normalized,
              decoration: pw.BoxDecoration(
                color: _accentColor,
                borderRadius: pw.BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.TableRow _metaRow(
    String leftLabel,
    String leftValue,
    String rightLabel,
    String rightValue,
  ) => pw.TableRow(
    children: [
      _metaCell(leftLabel, leftValue),
      _metaCell(rightLabel, rightValue),
    ],
  );

  pw.Widget _metaCell(String label, String value) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: _primaryColor,
          ),
        ),
      ],
    ),
  );

  String _fmtMoney(String currency, double amount) =>
      '$currency ${NumberFormat('#,##0').format(amount.round())}';
  pw.Widget _th(String t) => pw.Container(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(
      t,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      textAlign: pw.TextAlign.center,
    ),
  );
  pw.Widget _td(
    String t, {
    bool bold = false,
    bool center = false,
    PdfColor? bg,
  }) => pw.Container(
    padding: const pw.EdgeInsets.all(6),
    color: bg,
    child: pw.Text(
      t,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
      textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
    ),
  );
  pw.Widget _tf(String t) => pw.Container(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(
      t,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      textAlign: pw.TextAlign.center,
    ),
  );

  // ============ CSV EXPORT ============

  Future<void> exportToCsv(
    Committee committee, {
    DateTime? startDate,
    DateTime? endDate,
    int? cycle,
  }) async {
    final members = _dbService.getMembersByCommittee(committee.id);
    members.sort((a, b) => a.payoutOrder.compareTo(b.payoutOrder));
    final allPayments = _dbService.getPaymentsByCommittee(committee.id);

    DateTime? effectiveStart = startDate;
    DateTime? effectiveEnd = endDate;
    if (cycle != null) {
      final range = getCycleDateRange(committee, cycle);
      effectiveStart = range['start'];
      effectiveEnd = range['end'];
    }

    final dates = _generateDates(
      committee,
      startDate: effectiveStart,
      endDate: effectiveEnd,
    );

    final payments =
        allPayments.where((p) {
          if (effectiveStart != null && p.date.isBefore(effectiveStart))
            return false;
          if (effectiveEnd != null && p.date.isAfter(effectiveEnd))
            return false;
          return true;
        }).toList();

    int totalPaymentsInCycle = 0;
    for (var date in dates) {
      for (var member in members) {
        if (_isPaymentMarked(payments, member.id, date)) {
          totalPaymentsInCycle++;
        }
      }
    }

    final totalExpected = members.length * dates.length;
    final totalCollected = totalPaymentsInCycle * committee.contributionAmount;
    final totalPending =
        (totalExpected - totalPaymentsInCycle) * committee.contributionAmount;
    final collectionRate =
        totalExpected > 0
            ? (totalPaymentsInCycle / totalExpected * 100).toStringAsFixed(1)
            : '0';
    final paidCount = members.where((m) => m.hasReceivedPayout).length;
    final cycleLabel = cycle != null ? ' - Cycle $cycle' : '';
    final dateRangeStr =
        effectiveStart != null && effectiveEnd != null
            ? '${DateFormat('dd MMM yyyy').format(effectiveStart)} - ${DateFormat('dd MMM yyyy').format(effectiveEnd)}'
            : '';

    List<List<dynamic>> rows = [];

    rows.add(['WATERMARK', 'KAMETI CONFIDENTIAL DOCUMENT']);
    rows.add(['NOTICE', 'For internal use only']);
    rows.add([]);

    rows.add(['REPORT', '${committee.name} Payment Report$cycleLabel']);
    rows.add(['COMMITTEE CODE', committee.code]);
    rows.add([
      'GENERATED',
      DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
    ]);
    if (dateRangeStr.isNotEmpty) rows.add(['DATE RANGE', dateRangeStr]);
    rows.add([]);

    rows.add(['SUMMARY']);
    rows.add(['Metric', 'Value']);
    rows.add([
      'Contribution (per period)',
      _fmtMoney(committee.currency, committee.contributionAmount),
    ]);
    rows.add(['Frequency', committee.frequency.toUpperCase()]);
    rows.add(['Members', members.length]);
    rows.add(['Periods', dates.length]);
    rows.add(['Installments Paid', '$totalPaymentsInCycle / $totalExpected']);
    rows.add(['Collected', _fmtMoney(committee.currency, totalCollected)]);
    rows.add(['Pending', _fmtMoney(committee.currency, totalPending)]);
    rows.add(['Collection Rate', '$collectionRate%']);
    rows.add(['Payouts Done', '$paidCount / ${members.length}']);
    rows.add([]);

    rows.add(['DATE WISE COLLECTION']);
    rows.add([
      'Period',
      'Date',
      'Paid Members',
      'Unpaid Members',
      'Collected',
      'Expected',
      'Gap',
      'Completion',
    ]);
    for (var i = 0; i < dates.length; i++) {
      final date = dates[i];
      int paidForDate = 0;
      for (final member in members) {
        if (_isPaymentMarked(payments, member.id, date)) paidForDate++;
      }
      final unpaidForDate = members.length - paidForDate;
      final collectedForDate = paidForDate * committee.contributionAmount;
      final expectedForDate = members.length * committee.contributionAmount;
      final gap = expectedForDate - collectedForDate;
      final completion =
          members.isNotEmpty
              ? (paidForDate / members.length * 100).toStringAsFixed(1)
              : '0.0';
      rows.add([
        i + 1,
        DateFormat('dd/MM/yyyy').format(date),
        paidForDate,
        unpaidForDate,
        _fmtMoney(committee.currency, collectedForDate),
        _fmtMoney(committee.currency, expectedForDate),
        _fmtMoney(committee.currency, gap),
        '$completion%',
      ]);
    }
    rows.add([]);

    rows.add(['PAYOUT SCHEDULE']);
    rows.add(['Order', 'Member', 'Phone', 'Code', 'Status', 'Payout Date']);
    for (var m in members) {
      rows.add([
        m.payoutOrder,
        m.name,
        m.phone,
        m.memberCode,
        m.hasReceivedPayout ? 'RECEIVED' : 'PENDING',
        m.payoutDate != null
            ? DateFormat('dd/MM/yyyy').format(m.payoutDate!)
            : '-',
      ]);
    }
    rows.add([]);

    rows.add(['MEMBER PERFORMANCE$cycleLabel']);
    rows.add([
      'Order',
      'Member',
      'Paid',
      'Missed',
      '%',
      'Amount Paid',
      'Amount Due',
    ]);
    for (var m in members) {
      int paid = 0;
      for (var d in dates) {
        if (_isPaymentMarked(payments, m.id, d)) paid++;
      }
      final missed = dates.length - paid;
      final pct = dates.isNotEmpty ? (paid / dates.length * 100).toInt() : 0;
      rows.add([
        m.payoutOrder,
        m.name,
        paid,
        missed,
        '$pct%',
        _fmtMoney(committee.currency, paid * committee.contributionAmount),
        _fmtMoney(committee.currency, missed * committee.contributionAmount),
      ]);
    }
    rows.add([]);

    final matrixHeader = <dynamic>[
      'MEMBER PAYMENT MATRIX',
      '',
      '',
      ...dates.map((d) => DateFormat('dd/MM').format(d)),
      'Paid',
      'Missed',
      'Amount',
    ];
    rows.add(matrixHeader);
    final matrixColumns = <dynamic>[
      'Order',
      'Member',
      'Phone',
      ...List.filled(dates.length, 'Status'),
      'Paid',
      'Missed',
      'Collected',
    ];
    rows.add(matrixColumns);

    for (final m in members) {
      int paid = 0;
      final statuses = <String>[];
      for (final d in dates) {
        final marked = _isPaymentMarked(payments, m.id, d);
        if (marked) paid++;
        statuses.add(marked ? 'PAID' : '-');
      }
      final missed = dates.length - paid;
      rows.add([
        m.payoutOrder,
        m.name,
        m.phone,
        ...statuses,
        paid,
        missed,
        _fmtMoney(committee.currency, paid * committee.contributionAmount),
      ]);
    }
    rows.add([]);
    rows.add([
      'TOTAL',
      '',
      '',
      ...List.filled(dates.length, ''),
      totalPaymentsInCycle,
      totalExpected - totalPaymentsInCycle,
      _fmtMoney(committee.currency, totalCollected),
    ]);

    rows.add([]);
    rows.add(['WATERMARK', 'KAMETI CONFIDENTIAL DOCUMENT']);

    final filename =
        cycle != null
            ? '${committee.name}_cycle${cycle}_report.csv'
            : '${committee.name}_report.csv';
    String csv = const ListToCsvConverter().convert(rows);
    if (kIsWeb) {
      await Printing.sharePdf(
        bytes: Uint8List.fromList(csv.codeUnits),
        filename: filename,
      );
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(csv);
      await Share.shareXFiles([
        XFile(file.path),
      ], subject: '${committee.name} Report');
    }
  }

  List<DateTime> _generateDates(
    Committee c, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    List<DateTime> dates = [];
    DateTime cur = DateTime(
      (startDate ?? c.startDate).year,
      (startDate ?? c.startDate).month,
      (startDate ?? c.startDate).day,
    );
    final end = endDate ?? DateTime.now();
    while (!cur.isAfter(end)) {
      dates.add(cur);
      cur =
          c.frequency == 'monthly'
              ? _addMonths(cur, 1)
              : c.frequency == 'weekly'
              ? cur.add(const Duration(days: 7))
              : cur.add(const Duration(days: 1));
    }
    return dates;
  }

  /// Helper to safely add months without skipping days (e.g., Jan 31 -> Feb 28)
  DateTime _addMonths(DateTime date, int monthsToAdd) {
    var newYear = date.year;
    var newMonth = date.month + monthsToAdd;

    while (newMonth > 12) {
      newYear++;
      newMonth -= 12;
    }
    while (newMonth < 1) {
      newYear--;
      newMonth += 12;
    }

    final firstDayOfNextMonth = DateTime(newYear, newMonth + 1, 1);
    final lastDayOfTargetMonth =
        firstDayOfNextMonth.subtract(const Duration(days: 1)).day;
    final newDay =
        (date.day > lastDayOfTargetMonth) ? lastDayOfTargetMonth : date.day;

    return DateTime(newYear, newMonth, newDay);
  }

  bool _isPaymentMarked(
    List<Payment> payments,
    String memberId,
    DateTime date,
  ) {
    try {
      return payments
          .firstWhere(
            (p) =>
                p.memberId == memberId &&
                p.date.year == date.year &&
                p.date.month == date.month &&
                p.date.day == date.day,
          )
          .isPaid;
    } catch (e) {
      return false;
    }
  }
}
