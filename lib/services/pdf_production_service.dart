import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../models/employee_models.dart';
import '../production_tracking_page.dart';

class ProductionPdfService {
  static Future<void> generateAndShowPdf({
    required BuildContext context,
    required PerPieceEmployee employee,
    required List<ProductionEntry> entries,
    required int totalPieces,
    required double grandTotal,
    required int totalMinutes,
    required DateTime date,
  }) async {
    try {
      // Generate PDF
      final pdf = await _generatePdf(
        employee: employee,
        entries: entries,
        totalPieces: totalPieces,
        grandTotal: grandTotal,
        totalMinutes: totalMinutes,
        date: date,
      );

      // Show PDF preview
      await Printing.layoutPdf(
        onLayout: (format) async => pdf,
        name: 'production_report_${employee.name}_${date.toIso8601String()}.pdf',
      );
    } catch (e) {
      throw Exception('Failed to generate PDF: $e');
    }
  }

  static Future<void> savePdfToDevice({
    required BuildContext context,
    required PerPieceEmployee employee,
    required List<ProductionEntry> entries,
    required int totalPieces,
    required double grandTotal,
    required int totalMinutes,
    required DateTime date,
  }) async {
    try {
      // Generate PDF
      final pdf = await _generatePdf(
        employee: employee,
        entries: entries,
        totalPieces: totalPieces,
        grandTotal: grandTotal,
        totalMinutes: totalMinutes,
        date: date,
      );

      // Save to device
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'production_${employee.name}_${date.month}-${date.day}-${date.year}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf);

      // Open the file
      await OpenFile.open(file.path);

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(child: Text('PDF saved: $fileName')),
              ],
            ),
            backgroundColor: Colors.white,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      throw Exception('Failed to save PDF: $e');
    }
  }

  static Future<Uint8List> _generatePdf({
    required PerPieceEmployee employee,
    required List<ProductionEntry> entries,
    required int totalPieces,
    required double grandTotal,
    required int totalMinutes,
    required DateTime date,
  }) async {
    final pdf = pw.Document();

    // Load fonts
    final font = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(date, fontBold),
        footer: (context) => _buildFooter(font),
        build: (context) => [
          _buildCompanyHeader(font, fontBold),
          pw.SizedBox(height: 20),
          _buildEmployeeInfo(employee, date, font, fontBold),
          pw.SizedBox(height: 20),
          _buildSummaryCards(totalPieces, grandTotal, totalMinutes, font, fontBold),
          pw.SizedBox(height: 30),
          _buildProductionTable(entries, font, fontBold),
          pw.SizedBox(height: 30),
          _buildTotalSection(grandTotal, totalPieces, totalMinutes, font, fontBold),
          pw.SizedBox(height: 20),
          _buildSignatureSection(font),
        ],
      ),
    );

    return await pdf.save();
  }

  static pw.Widget _buildHeader(DateTime date, pw.Font fontBold) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Production Report',
          style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey600),
        ),
        pw.Text(
          'Generated: ${_formatDateTime(date)}',
          style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.grey400),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Font font) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Text(
          'This is a computer generated document',
          style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey400),
        ),
      ],
    );
  }

  static pw.Widget _buildCompanyHeader(pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ALKARAM HOSIERY',
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 24,
            color: PdfColors.blue800,
          ),
        ),
        pw.Text(
          'Production Tracking System',
          style: pw.TextStyle(
            font: font,
            fontSize: 12,
            color: PdfColors.grey600,
          ),
        ),
        pw.Divider(color: PdfColors.grey300),
      ],
    );
  }

  static pw.Widget _buildEmployeeInfo(
      PerPieceEmployee employee,
      DateTime date,
      pw.Font font,
      pw.Font fontBold,
      ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Employee Details',
                  style: pw.TextStyle(font: fontBold, fontSize: 14),
                ),
                pw.SizedBox(height: 8),
                _buildInfoRow('Name:', employee.name, font, fontBold),
                _buildInfoRow('Rate per piece:', 'Rs. ${employee.ratePerPiece.toStringAsFixed(2)}', font, fontBold),
                _buildInfoRow('Date:', _formatDate(date), font, fontBold),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoRow(String label, String value, pw.Font font, pw.Font fontBold) {
    return pw.Row(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700),
        ),
        pw.SizedBox(width: 8),
        pw.Text(
          value,
          style: pw.TextStyle(font: fontBold, fontSize: 11),
        ),
      ],
    );
  }

  static pw.Widget _buildSummaryCards(
      int totalPieces,
      double grandTotal,
      int totalMinutes,
      pw.Font font,
      pw.Font fontBold,
      ) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final timeString = hours > 0
        ? '$hours hr ${minutes > 0 ? '$minutes min' : ''}'
        : '$minutes min';

    return pw.Row(
      children: [
        _buildSummaryCard(
          'Total Pieces',
          totalPieces.toString(),
          PdfColors.amber,
          font,
          fontBold,
        ),
        pw.SizedBox(width: 12),
        _buildSummaryCard(
          'Total Time',
          timeString,
          PdfColors.blue,
          font,
          fontBold,
        ),
        pw.SizedBox(width: 12),
        _buildSummaryCard(
          'Total Earnings',
          'Rs. ${grandTotal.toStringAsFixed(2)}',
          PdfColors.green,
          font,
          fontBold,
        ),
      ],
    );
  }

  static pw.Widget _buildSummaryCard(
      String title,
      String value,
      PdfColor color,
      pw.Font font,
      pw.Font fontBold,
      ) {
    // Get a lighter version of the color for background
    final PdfColor lighterColor = _getLighterColor(color);

    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: lighterColor,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: color),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              value,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 18,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get lighter version of a color
  static PdfColor _getLighterColor(PdfColor color) {
    // For common colors, use predefined lighter versions
    if (color == PdfColors.amber) return PdfColors.amber100;
    if (color == PdfColors.blue) return PdfColors.blue100;
    if (color == PdfColors.green) return PdfColors.green100;
    if (color == PdfColors.red) return PdfColors.red100;
    if (color == PdfColors.purple) return PdfColors.purple100;
    if (color == PdfColors.orange) return PdfColors.orange100;
    if (color == PdfColors.teal) return PdfColors.teal100;
    if (color == PdfColors.cyan) return PdfColors.cyan100;
    if (color == PdfColors.pink) return PdfColors.pink100;
    if (color == PdfColors.indigo) return PdfColors.indigo100;
    if (color == PdfColors.lime) return PdfColors.lime100;
    if (color == PdfColors.yellow) return PdfColors.yellow100;
    if (color == PdfColors.brown) return PdfColors.brown100;

    // Default fallback for any other colors
    return PdfColors.grey100;
  }

  static pw.Widget _buildProductionTable(
      List<ProductionEntry> entries,
      pw.Font font,
      pw.Font fontBold,
      ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Production Details',
          style: pw.TextStyle(font: fontBold, fontSize: 14),
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          headers: ['#', 'Rate (Rs.)', 'Pieces', 'Time', 'Total (Rs.)'],
          headerStyle: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.grey800),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          cellStyle: pw.TextStyle(font: font, fontSize: 10),
          data: entries.map((entry) => [
            entry.index.toString(),
            entry.ratePerPiece.toStringAsFixed(2),
            entry.pieces.toString(),
            entry.timeDisplay,
            entry.total.toStringAsFixed(2),
          ]).toList(),
        ),
      ],
    );
  }

  static pw.Widget _buildTotalSection(
      double grandTotal,
      int totalPieces,
      int totalMinutes,
      pw.Font font,
      pw.Font fontBold,
      ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.green200),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'GRAND TOTAL EARNINGS:',
                style: pw.TextStyle(font: fontBold, fontSize: 14),
              ),
              pw.Text(
                'Rs. ${grandTotal.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 20,
                  color: PdfColors.green700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                '($totalPieces pieces • ${totalMinutes ~/ 60}h ${totalMinutes % 60}m)',
                style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSignatureSection(pw.Font font) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Employee Signature',
              style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              width: 150,
              height: 1,
              color: PdfColors.grey400,
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Supervisor Signature',
              style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              width: 150,
              height: 1,
              color: PdfColors.grey400,
            ),
          ],
        ),
      ],
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  static String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}