import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/employee_models.dart';
import 'ledger_service.dart'; // ← single source of truth for LedgerEntry

// ─────────────────────────────────────────────
//  DEPENDENCIES (add to pubspec.yaml):
//
//  pdf: ^3.11.1
//  printing: ^5.13.1
//  path_provider: ^2.1.3
// ─────────────────────────────────────────────

class LedgerPdfService {
  // Color palette matching the app's _C constants
  static final _green = PdfColor.fromHex('0F9E74');
  static final _red = PdfColor.fromHex('D63B3B');
  static final _blue = PdfColor.fromHex('2473CC');
  static final _textPrimary = PdfColor.fromHex('1A1F2E');
  static final _textSecondary = PdfColor.fromHex('5A637A');
  static final _textMuted = PdfColor.fromHex('A0ABBE');
  static final _border = PdfColor.fromHex('DDE3EE');
  static final _surface = PdfColors.white;
  static final _surfaceElevated = PdfColor.fromHex('F0F3F8');

  final DateFormat _dateFmt = DateFormat('dd MMM yy');

  /// Generates a PDF and opens the system share/print sheet.
  Future<void> shareOrPrintLedger({
    required Employee employee,
    required List<LedgerEntry> entries,
  }) async {
    final pdfBytes = Uint8List.fromList(await _buildPdf(employee, entries));
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: '${employee.name.replaceAll(' ', '_')}_Ledger.pdf',
    );
  }

  /// Generates a PDF, saves to device storage, and returns the file path.
  Future<String> saveLedgerToFile({
    required Employee employee,
    required List<LedgerEntry> entries,
  }) async {
    final pdfBytes = await _buildPdf(employee, entries);
    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        '${employee.name.replaceAll(' ', '_')}_Ledger_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(pdfBytes);
    return file.path;
  }

  // ── Core builder ──────────────────────────────────────────────────────────

  Future<List<int>> _buildPdf(
      Employee employee, List<LedgerEntry> entries) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: await PdfGoogleFonts.nunitoRegular(),
        bold: await PdfGoogleFonts.nunitoBold(),
      ),
    );

    // Pre-compute totals and running balances
    double totalCredit = 0, totalDebit = 0;
    final List<double> runningBalances = [];
    double running = 0;
    for (final e in entries) {
      if (e.isCredit) {
        totalCredit += e.amount;
        running += e.amount;
      } else {
        totalDebit += e.amount;
        running -= e.amount;
      }
      runningBalances.add(running);
    }
    final balance = totalCredit - totalDebit;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(employee, context),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _summaryCard(totalCredit, totalDebit, balance),
          pw.SizedBox(height: 16),
          _tableSection(entries, runningBalances),
        ],
      ),
    );

    return pdf.save();
  }

  // ── Header ────────────────────────────────────────────────────────────────

  pw.Widget _buildHeader(Employee employee, pw.Context context) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Employee Ledger',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  employee.name,
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: _blue,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (employee.position != null && employee.position!.isNotEmpty)
                  pw.Text(
                    employee.position!,
                    style: pw.TextStyle(fontSize: 11, color: _textSecondary),
                  ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Generated on',
                  style: pw.TextStyle(fontSize: 9, color: _textMuted),
                ),
                pw.Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: _textSecondary,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: _border, thickness: 1),
        pw.SizedBox(height: 6),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Column(children: [
      pw.Divider(color: _border, thickness: 0.5),
      pw.SizedBox(height: 4),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Al Karam Hosiery — Confidential',
              style: pw.TextStyle(fontSize: 9, color: _textMuted)),
          pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 9, color: _textMuted)),
        ],
      ),
    ]);
  }

  // ── Summary card ──────────────────────────────────────────────────────────

  pw.Widget _summaryCard(
      double totalCredit, double totalDebit, double balance) {
    final isPositive = balance >= 0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _surfaceElevated,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Row(
        children: [
          _summaryChip('Total Earned', totalCredit, _green),
          pw.SizedBox(width: 10),
          _summaryChip('Total Paid', totalDebit, _red),
          // pw.SizedBox(width: 10),
          // _summaryChip(
          //   isPositive ? 'Balance Due' : 'Overpaid',
          //   balance.abs(),
          //   isPositive ? _green : _red,
          //   highlighted: true,
          // ),
        ],
      ),
    );
  }

  pw.Widget _summaryChip(
      String label,
      double amount,
      PdfColor color, {
        bool highlighted = false,
      }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: pw.BoxDecoration(
          color: highlighted
              ? PdfColor(color.red, color.green, color.blue, 0.1)
              : _surface,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(
              color: PdfColor(color.red, color.green, color.blue, 0.35)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(fontSize: 9, color: _textSecondary)),
            pw.SizedBox(height: 3),
            pw.Text(
              'Rs ${amount.toStringAsFixed(2)}',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Table ─────────────────────────────────────────────────────────────────

  pw.Widget _tableSection(
      List<LedgerEntry> entries, List<double> runningBalances) {
    const colWidths = [
      pw.FlexColumnWidth(0.5), // #
      pw.FlexColumnWidth(1.4), // Date
      pw.FlexColumnWidth(3.0), // Description
      pw.FlexColumnWidth(1.5), // Credit
      pw.FlexColumnWidth(1.5), // Debit
      pw.FlexColumnWidth(1.5), // Balance
    ];

    final headerCells = ['#', 'Date', 'Description', 'Credit', 'Debit', 'Balance'];

    return pw.Table(
      columnWidths: {
        for (int i = 0; i < colWidths.length; i++) i: colWidths[i],
      },
      border: pw.TableBorder.all(color: _border, width: 0.5),
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _surfaceElevated),
          children: headerCells.map((h) {
            final isCredit = h == 'Credit';
            final isDebit = h == 'Debit';
            return _cell(
              h,
              bold: true,
              fontSize: 9,
              color: isCredit
                  ? _green
                  : isDebit
                  ? _red
                  : _textSecondary,
            );
          }).toList(),
        ),

        // Data rows
        for (int i = 0; i < entries.length; i++)
          _buildRow(entries[i], i + 1, runningBalances[i], i.isEven),
      ],
    );
  }

  pw.TableRow _buildRow(
      LedgerEntry entry, int rowNum, double balance, bool isEven) {
    final isCredit = entry.isCredit;
    final balancePositive = balance >= 0;

    final bg = isEven ? _surface : _surfaceElevated;

    return pw.TableRow(
      decoration: pw.BoxDecoration(color: bg),
      children: [
        _cell('$rowNum', color: _textMuted, fontSize: 9),
        _dateCell(entry.date),
        _descriptionCell(entry.description, isCredit),
        // Credit column
        isCredit
            ? _cell(entry.amount.toStringAsFixed(2),
            color: _green, bold: true, fontSize: 10)
            : _cell('—', color: _textMuted),
        // Debit column
        !isCredit
            ? _cell(entry.amount.toStringAsFixed(2),
            color: _red, bold: true, fontSize: 10)
            : _cell('—', color: _textMuted),
        // Balance column
        _cell(
          balance.toStringAsFixed(2),
          color: balancePositive ? _green : _red,
          bold: true,
          fontSize: 10,
        ),
      ],
    );
  }

  pw.Widget _cell(
      String text, {
        PdfColor? color,
        bool bold = false,
        double fontSize = 10,
      }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          color: color ?? _textPrimary,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _dateCell(DateTime date) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            _dateFmt.format(date),
            style: pw.TextStyle(
                fontSize: 10,
                color: _textPrimary,
                fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            DateFormat('hh:mm a').format(date),
            style: pw.TextStyle(fontSize: 8, color: _textMuted),
          ),
        ],
      ),
    );
  }

  pw.Widget _descriptionCell(String description, bool isCredit) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            description,
            style: pw.TextStyle(
                fontSize: 10,
                color: _textPrimary,
                fontWeight: pw.FontWeight.bold),
            maxLines: 2,
          ),
          pw.SizedBox(height: 3),
          pw.Container(
            padding:
            const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: pw.BoxDecoration(
              color: isCredit
                  ? PdfColor.fromHex('E8F7F2')
                  : PdfColor.fromHex('FDECEC'),
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text(
              isCredit ? '▲ Credit' : '▼ Debit',
              style: pw.TextStyle(
                fontSize: 8,
                color: isCredit ? _green : _red,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}