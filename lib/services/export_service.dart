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

  // ============ PDF EXPORT ============

  Future<void> exportToPdf(
    Committee committee, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final members = _dbService.getMembersByCommittee(committee.id);
    members.sort((a, b) => a.payoutOrder.compareTo(b.payoutOrder));

    final payments = _dbService.getPaymentsByCommittee(committee.id);
    final dates = _generateDates(
      committee,
      startDate: startDate,
      endDate: endDate,
    );

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build:
            (context) => [
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      committee.name,
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Code: ${committee.code}',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildPdfSummaryItem(
                      'Contribution',
                      'PKR ${committee.contributionAmount.toInt()}',
                    ),
                    _buildPdfSummaryItem(
                      'Frequency',
                      committee.frequency.toUpperCase(),
                    ),
                    _buildPdfSummaryItem('Members', '${members.length}'),
                    _buildPdfSummaryItem(
                      'Payout Cycle',
                      '${committee.paymentIntervalDays} days',
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Date Range Info
              if (startDate != null || endDate != null)
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Date Range: ${startDate != null ? DateFormat('dd/MM/yyyy').format(startDate) : 'Start'} - ${endDate != null ? DateFormat('dd/MM/yyyy').format(endDate) : 'Today'}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ),

              // Payment Table
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      _buildPdfCell('Member', isHeader: true),
                      _buildPdfCell('#', isHeader: true),
                      ...dates.map(
                        (d) => _buildPdfCell(
                          DateFormat('dd/MM').format(d),
                          isHeader: true,
                        ),
                      ),
                      _buildPdfCell('Total', isHeader: true),
                    ],
                  ),
                  // Data Rows
                  ...members.map((member) {
                    int paidCount = 0;
                    for (var date in dates) {
                      if (_isPaymentMarked(payments, member.id, date)) {
                        paidCount++;
                      }
                    }
                    final totalPaid = paidCount * committee.contributionAmount;

                    return pw.TableRow(
                      children: [
                        _buildPdfCell(member.name),
                        _buildPdfCell('#${member.payoutOrder}'),
                        ...dates.map((date) {
                          final isPaid = _isPaymentMarked(
                            payments,
                            member.id,
                            date,
                          );
                          return _buildPdfCell(
                            isPaid ? '✓' : '✗',
                            bgColor:
                                isPaid ? PdfColors.green100 : PdfColors.red100,
                          );
                        }),
                        _buildPdfCell('PKR ${totalPaid.toInt()}'),
                      ],
                    );
                  }),
                  // Footer Row - Totals
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blue100,
                    ),
                    children: [
                      _buildPdfCell('TOTAL', isHeader: true),
                      _buildPdfCell(''),
                      ...dates.map((date) {
                        int count = 0;
                        for (var member in members) {
                          if (_isPaymentMarked(payments, member.id, date))
                            count++;
                        }
                        return _buildPdfCell('$count/${members.length}');
                      }),
                      _buildPdfCell(
                        'PKR ${(payments.where((p) => p.isPaid).length * committee.contributionAmount).toInt()}',
                        isHeader: true,
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Footer
              pw.Text(
                'Generated on ${DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now())}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ],
      ),
    );

    // Print or share the PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${committee.name}_payment_sheet.pdf',
    );
  }

  pw.Widget _buildPdfSummaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  pw.Widget _buildPdfCell(
    String text, {
    bool isHeader = false,
    PdfColor? bgColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      color: bgColor,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // ============ CSV EXPORT ============

  Future<void> exportToCsv(
    Committee committee, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final members = _dbService.getMembersByCommittee(committee.id);
    members.sort((a, b) => a.payoutOrder.compareTo(b.payoutOrder));

    final payments = _dbService.getPaymentsByCommittee(committee.id);
    final dates = _generateDates(
      committee,
      startDate: startDate,
      endDate: endDate,
    );

    List<List<dynamic>> rows = [];

    // Header Row
    rows.add([
      'Member',
      'Payout Order',
      'Phone',
      'Member Code',
      ...dates.map((d) => DateFormat('dd/MM/yyyy').format(d)),
      'Total Paid',
      'Total Amount',
    ]);

    // Data Rows
    for (var member in members) {
      int paidCount = 0;
      List<String> paymentStatus = [];

      for (var date in dates) {
        final isPaid = _isPaymentMarked(payments, member.id, date);
        paymentStatus.add(isPaid ? 'PAID' : 'NOT PAID');
        if (isPaid) paidCount++;
      }

      rows.add([
        member.name,
        member.payoutOrder,
        member.phone,
        member.memberCode,
        ...paymentStatus,
        paidCount,
        paidCount * committee.contributionAmount,
      ]);
    }

    // Summary Row
    rows.add([]);
    rows.add(['SUMMARY']);
    rows.add(['Committee Name', committee.name]);
    rows.add(['Committee Code', committee.code]);
    rows.add(['Contribution Amount', 'PKR ${committee.contributionAmount}']);
    rows.add(['Total Members', members.length]);
    rows.add([
      'Total Collected',
      'PKR ${payments.where((p) => p.isPaid).length * committee.contributionAmount}',
    ]);
    rows.add([
      'Generated On',
      DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now()),
    ]);

    String csv = const ListToCsvConverter().convert(rows);

    if (kIsWeb) {
      // For web, use printing/share
      await Printing.sharePdf(
        bytes: Uint8List.fromList(csv.codeUnits),
        filename: '${committee.name}_payment_sheet.csv',
      );
    } else {
      // For mobile, save and share
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/${committee.name}_payment_sheet.csv',
      );
      await file.writeAsString(csv);

      await Share.shareXFiles([
        XFile(file.path),
      ], subject: '${committee.name} Payment Sheet');
    }
  }

  // ============ HELPERS ============

  List<DateTime> _generateDates(
    Committee committee, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    List<DateTime> dates = [];
    final now = DateTime.now();
    final start = startDate ?? committee.startDate;
    final end = endDate ?? now;

    int interval = 1;
    if (committee.frequency == 'weekly') interval = 7;
    if (committee.frequency == 'monthly') interval = 30;

    DateTime current = DateTime(start.year, start.month, start.day);

    while (!current.isAfter(end)) {
      dates.add(current);
      if (committee.frequency == 'monthly') {
        current = DateTime(current.year, current.month + 1, current.day);
      } else {
        current = current.add(Duration(days: interval));
      }
    }

    return dates;
  }

  bool _isPaymentMarked(
    List<Payment> payments,
    String memberId,
    DateTime date,
  ) {
    try {
      final payment = payments.firstWhere(
        (p) =>
            p.memberId == memberId &&
            p.date.year == date.year &&
            p.date.month == date.month &&
            p.date.day == date.day,
      );
      return payment.isPaid;
    } catch (e) {
      return false;
    }
  }
}
