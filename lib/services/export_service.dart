import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/committee.dart';
import '../models/member.dart';
import '../models/payment.dart';
import 'database_service.dart';

class ExportService {
  final DatabaseService _dbService = DatabaseService();

  static const _primaryColor = PdfColor.fromInt(0xFF1A1A2E);
  static const _accentColor = PdfColor.fromInt(0xFF00C853);
  static const _lightGreen = PdfColor.fromInt(0xFFE8F5E9);
  static const _lightRed = PdfColor.fromInt(0xFFFFEBEE);
  static const _lightBg = PdfColor.fromInt(0xFFF8F9FA);

  // ============ CYCLE HELPERS ============

  /// Get the total number of cycles (equals number of members)
  int getMaxCycles(Committee committee) {
    final members = _dbService.getMembersByCommittee(committee.id);
    return members.isNotEmpty ? members.length : 1;
  }

  /// Get the date range for a specific cycle
  Map<String, DateTime> getCycleDateRange(Committee committee, int cycle) {
    final members = _dbService.getMembersByCommittee(committee.id);
    final numMembers = members.isNotEmpty ? members.length : (committee.totalMembers > 0 ? committee.totalMembers : 1);
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
      cycleStartDate = _addMonths(committeeStartDate, (cycle - 1) * periodsPerPayout);
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

  Future<void> exportToPdf(Committee committee, {DateTime? startDate, DateTime? endDate, int? cycle}) async {
    final members = _dbService.getMembersByCommittee(committee.id);
    members.sort((a, b) => a.payoutOrder.compareTo(b.payoutOrder));
    final allPayments = _dbService.getPaymentsByCommittee(committee.id);
    
    // If cycle is specified, use cycle date range
    DateTime? effectiveStart = startDate;
    DateTime? effectiveEnd = endDate;
    if (cycle != null) {
      final range = getCycleDateRange(committee, cycle);
      effectiveStart = range['start'];
      effectiveEnd = range['end'];
    }
    
    final dates = _generateDates(committee, startDate: effectiveStart, endDate: effectiveEnd);
    
    // Filter payments to only those within the date range for accurate calculations
    final payments = allPayments.where((p) {
      if (effectiveStart != null && p.date.isBefore(effectiveStart)) return false;
      if (effectiveEnd != null && p.date.isAfter(effectiveEnd)) return false;
      return true;
    }).toList();

    // Count payments that are marked for dates in this cycle only
    int totalPaymentsInCycle = 0;
    for (var date in dates) {
      for (var member in members) {
        if (_isPaymentMarked(payments, member.id, date)) {
          totalPaymentsInCycle++;
        }
      }
    }
    
    final totalCollected = totalPaymentsInCycle * committee.contributionAmount;
    final paidMembersCount = members.where((m) => m.hasReceivedPayout).length;
    final totalExpected = members.length * dates.length;
    final collectionRate = totalExpected > 0 ? (totalPaymentsInCycle / totalExpected * 100).toStringAsFixed(1) : '0';
    final cycleLabel = cycle != null ? ' - Cycle $cycle' : '';

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _buildHeader(committee, cycleLabel: cycleLabel, dateRange: effectiveStart != null && effectiveEnd != null 
            ? '${DateFormat('dd MMM yyyy').format(effectiveStart)} - ${DateFormat('dd MMM yyyy').format(effectiveEnd)}' 
            : null),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(color: _lightBg, borderRadius: pw.BorderRadius.circular(8), border: pw.Border.all(color: PdfColors.grey300)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Summary${cycleLabel}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _primaryColor)),
              pw.SizedBox(height: 12),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                _statBox('Contribution', 'Rs. ${committee.contributionAmount.toInt()}'),
                _statBox('Frequency', committee.frequency.toUpperCase()),
                _statBox('Members', '${members.length}'),
                _statBox('Collection', '$collectionRate%'),
              ]),
              pw.Divider(color: PdfColors.grey300),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                _statBox('Collected', 'Rs. ${totalCollected.toInt()}', highlight: true),
                _statBox('Payouts', '$paidMembersCount/${members.length}', highlight: true),
                _statBox('Periods', '${dates.length}'),
                _statBox('Pending', 'Rs. ${((totalExpected - totalPaymentsInCycle) * committee.contributionAmount).toInt()}'),
              ]),
            ]),
          ),
          pw.SizedBox(height: 24),
          pw.Text('Member Details${cycleLabel}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _primaryColor)),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {0: const pw.FlexColumnWidth(0.8), 1: const pw.FlexColumnWidth(3), 2: const pw.FlexColumnWidth(2), 3: const pw.FlexColumnWidth(1.5), 4: const pw.FlexColumnWidth(1.2), 5: const pw.FlexColumnWidth(2), 6: const pw.FlexColumnWidth(1.5)},
            children: [
              pw.TableRow(decoration: const pw.BoxDecoration(color: _primaryColor), children: [_th('#'), _th('Name'), _th('Phone'), _th('Paid'), _th('%'), _th('Amount'), _th('Payout')]),
              ...members.asMap().entries.map((e) {
                int paid = 0;
                for (var d in dates) if (_isPaymentMarked(payments, e.value.id, d)) paid++;
                final pct = dates.isNotEmpty ? (paid / dates.length * 100).toInt() : 0;
                return pw.TableRow(decoration: pw.BoxDecoration(color: e.key % 2 == 0 ? PdfColors.white : _lightBg), children: [
                  _td('${e.value.payoutOrder}', center: true),
                  _td(e.value.name, bold: true),
                  _td(e.value.phone),
                  _td('$paid/${dates.length}', center: true),
                  _td('$pct%', center: true, bg: pct >= 80 ? _lightGreen : (pct < 50 ? _lightRed : null)),
                  _td('Rs. ${(paid * committee.contributionAmount).toInt()}'),
                  _td(e.value.hasReceivedPayout ? 'DONE' : 'Pending', center: true, bg: e.value.hasReceivedPayout ? _lightGreen : null, bold: e.value.hasReceivedPayout),
                ]);
              }),
              pw.TableRow(decoration: const pw.BoxDecoration(color: _accentColor), children: [_tf(''), _tf('TOTAL'), _tf(''), _tf('$totalPaymentsInCycle/$totalExpected'), _tf('$collectionRate%'), _tf('Rs. ${totalCollected.toInt()}'), _tf('$paidMembersCount')]),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text('Payout Schedule', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _primaryColor)),
          pw.SizedBox(height: 12),
          pw.Wrap(spacing: 8, runSpacing: 8, children: members.map((m) => pw.Container(
            width: 160, padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(color: m.hasReceivedPayout ? _lightGreen : PdfColors.white, border: pw.Border.all(color: m.hasReceivedPayout ? PdfColors.green400 : PdfColors.grey300), borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('#${m.payoutOrder}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: pw.BoxDecoration(color: m.hasReceivedPayout ? PdfColors.green : PdfColors.grey400, borderRadius: pw.BorderRadius.circular(4)), child: pw.Text(m.hasReceivedPayout ? 'DONE' : 'PENDING', style: pw.TextStyle(fontSize: 7, color: PdfColors.white, fontWeight: pw.FontWeight.bold))),
              ]),
              pw.SizedBox(height: 4),
              pw.Text(m.name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              if (m.payoutDate != null) pw.Text('Received: ${DateFormat('dd/MM/yy').format(m.payoutDate!)}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ]),
          )).toList()),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: '${committee.name}_report.pdf');
  }

  pw.Widget _buildHeader(Committee c, {String cycleLabel = '', String? dateRange}) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 20), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(c.name, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: _primaryColor)), 
        pw.Text('Payment Report$cycleLabel', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
        if (dateRange != null) pw.Text(dateRange, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
      ]),
      pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: pw.BoxDecoration(color: _accentColor, borderRadius: pw.BorderRadius.circular(8)), child: pw.Column(children: [pw.Text('Code', style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)), pw.Text(c.code, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white))])),
    ]),
  ]));

  pw.Widget _buildFooter(pw.Context ctx) => pw.Container(margin: const pw.EdgeInsets.only(top: 16), padding: const pw.EdgeInsets.only(top: 8), decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300))), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)), pw.Text('Page ${ctx.pageNumber}/${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))]));

  pw.Widget _statBox(String l, String v, {bool highlight = false}) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text(l, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)), pw.Text(v, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: highlight ? _accentColor : _primaryColor))]);
  pw.Widget _th(String t) => pw.Container(padding: const pw.EdgeInsets.all(8), child: pw.Text(t, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.center));
  pw.Widget _td(String t, {bool bold = false, bool center = false, PdfColor? bg}) => pw.Container(padding: const pw.EdgeInsets.all(6), color: bg, child: pw.Text(t, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal), textAlign: center ? pw.TextAlign.center : pw.TextAlign.left));
  pw.Widget _tf(String t) => pw.Container(padding: const pw.EdgeInsets.all(8), child: pw.Text(t, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.center));

  // ============ CSV EXPORT ============

  Future<void> exportToCsv(Committee committee, {DateTime? startDate, DateTime? endDate, int? cycle}) async {
    final members = _dbService.getMembersByCommittee(committee.id);
    members.sort((a, b) => a.payoutOrder.compareTo(b.payoutOrder));
    final allPayments = _dbService.getPaymentsByCommittee(committee.id);
    
    // If cycle is specified, use cycle date range
    DateTime? effectiveStart = startDate;
    DateTime? effectiveEnd = endDate;
    if (cycle != null) {
      final range = getCycleDateRange(committee, cycle);
      effectiveStart = range['start'];
      effectiveEnd = range['end'];
    }
    
    final dates = _generateDates(committee, startDate: effectiveStart, endDate: effectiveEnd);
    
    // Filter payments to only those within the date range
    final payments = allPayments.where((p) {
      if (effectiveStart != null && p.date.isBefore(effectiveStart)) return false;
      if (effectiveEnd != null && p.date.isAfter(effectiveEnd)) return false;
      return true;
    }).toList();

    // Count payments marked in this cycle only
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
    final totalPending = (totalExpected - totalPaymentsInCycle) * committee.contributionAmount;
    final collectionRate = totalExpected > 0 ? (totalPaymentsInCycle / totalExpected * 100).toStringAsFixed(1) : '0';
    final paidCount = members.where((m) => m.hasReceivedPayout).length;
    final cycleLabel = cycle != null ? ' - Cycle $cycle' : '';
    final dateRangeStr = effectiveStart != null && effectiveEnd != null 
        ? '${DateFormat('dd MMM yyyy').format(effectiveStart)} - ${DateFormat('dd MMM yyyy').format(effectiveEnd)}' 
        : '';

    List<List<dynamic>> rows = [];

    rows.add(['=========================================================']);
    rows.add(['${committee.name.toUpperCase()} - PAYMENT REPORT$cycleLabel']);
    rows.add(['=========================================================']);
    rows.add(['Committee Code', committee.code]);
    if (dateRangeStr.isNotEmpty) rows.add(['Date Range', dateRangeStr]);
    rows.add(['Generated', DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now())]);
    rows.add([]);
    rows.add(['------------------ SUMMARY$cycleLabel ------------------']);
    rows.add(['Field', 'Value']);
    rows.add(['Contribution', 'Rs. ${committee.contributionAmount.toInt()}']);
    rows.add(['Frequency', committee.frequency.toUpperCase()]);
    rows.add(['Members', members.length]);
    rows.add(['Periods', dates.length]);
    rows.add(['Collected', 'Rs. ${totalCollected.toInt()}']);
    rows.add(['Pending', 'Rs. ${totalPending.toInt()}']);
    rows.add(['Collection Rate', '$collectionRate%']);
    rows.add(['Payouts Done', '$paidCount / ${members.length}']);
    rows.add([]);
    rows.add(['------------------ PAYOUT SCHEDULE ------------------']);
    rows.add(['Order', 'Member', 'Phone', 'Code', 'Status', 'Date']);
    for (var m in members) rows.add([m.payoutOrder, m.name, m.phone, m.memberCode, m.hasReceivedPayout ? 'RECEIVED' : 'Pending', m.payoutDate != null ? DateFormat('dd/MM/yyyy').format(m.payoutDate!) : '-']);
    rows.add([]);
    rows.add(['------------------ MEMBER PAYMENTS$cycleLabel ------------------']);
    rows.add(['Order', 'Member', 'Paid', 'Missed', '%', 'Amount Paid', 'Amount Due']);
    for (var m in members) {
      int paid = 0;
      for (var d in dates) if (_isPaymentMarked(payments, m.id, d)) paid++;
      final missed = dates.length - paid;
      final pct = dates.isNotEmpty ? (paid / dates.length * 100).toInt() : 0;
      rows.add([m.payoutOrder, m.name, paid, missed, '$pct%', 'Rs. ${(paid * committee.contributionAmount).toInt()}', 'Rs. ${(missed * committee.contributionAmount).toInt()}']);
    }
    rows.add([]);
    rows.add(['', 'TOTAL', totalPaymentsInCycle, totalExpected - totalPaymentsInCycle, '$collectionRate%', 'Rs. ${totalCollected.toInt()}', 'Rs. ${totalPending.toInt()}']);
    rows.add([]);
    rows.add(['=========================================================']);
    rows.add(['END OF REPORT']);

    final filename = cycle != null ? '${committee.name}_cycle${cycle}_report.csv' : '${committee.name}_report.csv';
    String csv = const ListToCsvConverter().convert(rows);
    if (kIsWeb) {
      await Printing.sharePdf(bytes: Uint8List.fromList(csv.codeUnits), filename: filename);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)], subject: '${committee.name} Report');
    }
  }

  List<DateTime> _generateDates(Committee c, {DateTime? startDate, DateTime? endDate}) {
    List<DateTime> dates = [];
    DateTime cur = DateTime((startDate ?? c.startDate).year, (startDate ?? c.startDate).month, (startDate ?? c.startDate).day);
    final end = endDate ?? DateTime.now();
    while (!cur.isAfter(end)) {
      dates.add(cur);
      cur = c.frequency == 'monthly' ? _addMonths(cur, 1) : c.frequency == 'weekly' ? cur.add(const Duration(days: 7)) : cur.add(const Duration(days: 1));
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
    final lastDayOfTargetMonth = firstDayOfNextMonth.subtract(const Duration(days: 1)).day;
    final newDay = (date.day > lastDayOfTargetMonth) ? lastDayOfTargetMonth : date.day;

    return DateTime(newYear, newMonth, newDay);
  }

  bool _isPaymentMarked(List<Payment> payments, String memberId, DateTime date) {
    try { return payments.firstWhere((p) => p.memberId == memberId && p.date.year == date.year && p.date.month == date.month && p.date.day == date.day).isPaid; }
    catch (e) { return false; }
  }
}
