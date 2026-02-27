import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'models/production_record.dart';

// ─────────────────────────────────────────────────────────────
//  ADD TO pubspec.yaml dependencies:
//
//  pdf: ^3.10.8
//  printing: ^5.12.0
// ─────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────
//  Design Tokens (mirrors your existing _C class)
// ─────────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFDDE3EE);
  static const amber = Color(0xFFE8900A);
  static const green = Color(0xFF0F9E74);
  static const blue = Color(0xFF2473CC);
  static const red = Color(0xFFD63B3B);
  static const textPrimary = Color(0xFF1A1F2E);
  static const textSecondary = Color(0xFF5A637A);
  static const textMuted = Color(0xFFA0ABBE);

  // PDF equivalents
  static final pdfAmber = PdfColor.fromHex('#E8900A');
  static final pdfGreen = PdfColor.fromHex('#0F9E74');
  static final pdfBlue = PdfColor.fromHex('#2473CC');
  static final pdfRed = PdfColor.fromHex('#D63B3B');
  static final pdfTextPrimary = PdfColor.fromHex('#1A1F2E');
  static final pdfTextSecondary = PdfColor.fromHex('#5A637A');
  static final pdfTextMuted = PdfColor.fromHex('#A0ABBE');
  static final pdfBorder = PdfColor.fromHex('#DDE3EE');
  static final pdfSurface = PdfColors.white;
  static final pdfBg = PdfColor.fromHex('#F5F7FA');
  static final pdfHeaderBg = PdfColor.fromHex('#1A1F2E');
  static final pdfRowAlt = PdfColor.fromHex('#F0F3F8');
  static final pdfSummaryBg = PdfColor.fromHex('#EEF3FB');
  static final pdfGreenDim = PdfColor.fromHex('#E8F7F2');
}



// ─────────────────────────────────────────────────────────────
//  PDF Generator Class
// ─────────────────────────────────────────────────────────────
class ProductionPdfGenerator {
  static final DateFormat _dateFmt = DateFormat('dd MMM yyyy');
  static final DateFormat _timeFmt = DateFormat('hh:mm a');

  static String _formatDuration(int minutes, bool isHours) {
    if (isHours) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      if (m == 0) return '$h hr';
      return '$h hr $m min';
    } else {
      return '$minutes min';
    }
  }

  /// Generate and return PDF bytes
  static Future<Uint8List> generate({
    required String employeeName,
    required List<ProductionRecord> records,
  }) async {
    final pdf = pw.Document();

    // Load fonts
    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    final fontSemiBold = await PdfGoogleFonts.nunitoSemiBold();
    final fontMono = await PdfGoogleFonts.sourceCodeProRegular();

    // Totals
    final totalEarnings =
    records.fold(0.0, (s, r) => s + r.totalEarnings);
    final totalPieces =
    records.fold(0, (s, r) => s + r.piecesProduced);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) =>
            _buildHeader(employeeName, fontBold, fontRegular),
        footer: (context) => _buildFooter(context, fontRegular),
        build: (context) => [
          pw.SizedBox(height: 12),
          _buildSummaryStrip(
            totalRecords: records.length,
            totalPieces: totalPieces,
            totalEarnings: totalEarnings,
            fontBold: fontBold,
            fontRegular: fontRegular,
          ),
          pw.SizedBox(height: 16),
          _buildTable(
            records: records,
            fontBold: fontBold,
            fontRegular: fontRegular,
            fontSemiBold: fontSemiBold,
            fontMono: fontMono,
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ── Header ────────────────────────────────────────────────
  static pw.Widget _buildHeader(
      String employeeName,
      pw.Font fontBold,
      pw.Font fontRegular,
      ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _C.pdfBorder, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                employeeName,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 16,
                  color: _C.pdfTextPrimary,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Production Records Report',
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 11,
                  color: _C.pdfTextSecondary,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding:
                const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: _C.pdfAmber,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text(
                  'AL-KARAM HOSIERY',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 9,
                    color: PdfColors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 8,
                  color: _C.pdfTextMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────
  static pw.Widget _buildFooter(
      pw.Context context, pw.Font fontRegular) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
            top: pw.BorderSide(color: _C.pdfBorder, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Al-Karam Hosiery — Confidential',
            style: pw.TextStyle(
                font: fontRegular, fontSize: 8, color: _C.pdfTextMuted),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(
                font: fontRegular, fontSize: 8, color: _C.pdfTextMuted),
          ),
        ],
      ),
    );
  }

  // ── Summary Strip ─────────────────────────────────────────
  static pw.Widget _buildSummaryStrip({
    required int totalRecords,
    required int totalPieces,
    required double totalEarnings,
    required pw.Font fontBold,
    required pw.Font fontRegular,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: pw.BoxDecoration(
        color: _C.pdfSurface,
        border: pw.Border.all(color: _C.pdfBorder, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        children: [
          _summaryChipPdf(
              label: 'Total Records',
              value: '$totalRecords',
              color: _C.pdfBlue,
              fontBold: fontBold,
              fontRegular: fontRegular),
          _summaryDividerPdf(),
          _summaryChipPdf(
              label: 'Total Pieces',
              value: '$totalPieces',
              color: _C.pdfAmber,
              fontBold: fontBold,
              fontRegular: fontRegular),
          _summaryDividerPdf(),
          _summaryChipPdf(
              label: 'Total Earned',
              value: 'Rs ${totalEarnings.toStringAsFixed(0)}',
              color: _C.pdfGreen,
              fontBold: fontBold,
              fontRegular: fontRegular),
        ],
      ),
    );
  }

  static pw.Widget _summaryChipPdf({
    required String label,
    required String value,
    required PdfColor color,
    required pw.Font fontBold,
    required pw.Font fontRegular,
  }) {
    return pw.Expanded(
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
                font: fontBold, fontSize: 16, color: color),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            label,
            style: pw.TextStyle(
                font: fontRegular, fontSize: 9, color: _C.pdfTextMuted),
          ),
        ],
      ),
    );
  }

  static pw.Widget _summaryDividerPdf() {
    return pw.Container(
        width: 0.8, height: 30, color: _C.pdfBorder);
  }

  // ── Table ─────────────────────────────────────────────────
  static pw.Widget _buildTable({
    required List<ProductionRecord> records,
    required pw.Font fontBold,
    required pw.Font fontRegular,
    required pw.Font fontSemiBold,
    required pw.Font fontMono,
  }) {
    // Column headers
    final headers = ['#', 'Date', 'Time', 'Pieces', 'Duration', 'Rate/pc', 'Earned'];

    final headerRow = headers.map((h) {
      return pw.Container(
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: pw.Text(
          h,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 9,
            color: PdfColors.white,
          ),
        ),
      );
    }).toList();

    // Data rows
    final dataRows = records.asMap().entries.map((entry) {
      final i = entry.key;
      final r = entry.value;
      final isEven = i % 2 == 0;
      final bgColor = isEven ? _C.pdfSurface : _C.pdfRowAlt;

      final cells = [
        '${i + 1}',
        _dateFmt.format(r.endTime),
        _timeFmt.format(r.endTime),
        '${r.piecesProduced}',
        _formatDuration(r.durationInMinutes, r.isHours),
        'Rs ${r.ratePerPiece.toStringAsFixed(2)}',
        'Rs ${r.totalEarnings.toStringAsFixed(2)}',
      ];

      return pw.TableRow(
        decoration: pw.BoxDecoration(color: bgColor),
        children: cells.asMap().entries.map((cellEntry) {
          final isLast = cellEntry.key == cells.length - 1;
          return pw.Container(
            alignment: pw.Alignment.center,
            padding:
            const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            child: pw.Text(
              cellEntry.value,
              style: pw.TextStyle(
                font: isLast ? fontBold : fontRegular,
                fontSize: 9,
                color: isLast ? _C.pdfGreen : _C.pdfTextPrimary,
              ),
            ),
          );
        }).toList(),
      );
    }).toList();

    // Totals row
    final totalPieces = records.fold(0, (s, r) => s + r.piecesProduced);
    final totalEarnings =
    records.fold(0.0, (s, r) => s + r.totalEarnings);

    final totalsRow = pw.TableRow(
      decoration: pw.BoxDecoration(color: _C.pdfSummaryBg),
      children: [
        _totalCell('', fontBold, isLabel: false),
        _totalCell('TOTAL', fontBold, isLabel: true, span: 3),
        _totalCell('', fontBold, isLabel: false),
        _totalCell('$totalPieces pcs', fontBold, isLabel: false, color: _C.pdfAmber),
        _totalCell('', fontBold, isLabel: false),
        _totalCell('Rs ${totalEarnings.toStringAsFixed(2)}', fontBold,
            isLabel: false, color: _C.pdfGreen),
      ],
    );

    return pw.Table(
      border: pw.TableBorder.all(color: _C.pdfBorder, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(20),  // #
        1: const pw.FlexColumnWidth(2),    // Date
        2: const pw.FlexColumnWidth(1.5),  // Time
        3: const pw.FixedColumnWidth(40),  // Pieces
        4: const pw.FlexColumnWidth(1.5),  // Duration
        5: const pw.FlexColumnWidth(1.5),  // Rate
        6: const pw.FlexColumnWidth(1.8),  // Earned
      },
      children: [
        // Header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _C.pdfHeaderBg),
          children: headerRow,
        ),
        ...dataRows,
        totalsRow,
      ],
    );
  }

  static pw.Widget _totalCell(
      String text,
      pw.Font fontBold, {
        bool isLabel = false,
        PdfColor? color,
        int span = 1,
      }) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: fontBold,
          fontSize: 9,
          color: color ?? (isLabel ? _C.pdfTextSecondary : _C.pdfTextPrimary),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  PDF Preview Page — drop into your Navigator
// ─────────────────────────────────────────────────────────────
class ProductionRecordsPdfPage extends StatelessWidget {
  final String employeeName;
  final List<ProductionRecord> records;

  const ProductionRecordsPdfPage({
    super.key,
    required this.employeeName,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        colorScheme: const ColorScheme.light(primary: Color(0xFFE8900A)),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: Color(0xFFDDE3EE)),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: Color(0xFF5A637A)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PDF Preview',
                  style: TextStyle(
                      color: Color(0xFF1A1F2E),
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              Text('Production Records',
                  style:
                  TextStyle(color: Color(0xFF5A637A), fontSize: 12)),
            ],
          ),
          actions: [
            // Share / Print button
            IconButton(
              icon: const Icon(Icons.share_outlined,
                  size: 20, color: Color(0xFF2473CC)),
              onPressed: () async {
                final bytes = await ProductionPdfGenerator.generate(
                  employeeName: employeeName,
                  records: records,
                );
                await Printing.sharePdf(
                  bytes: bytes,
                  filename:
                  '${employeeName.replaceAll(' ', '_')}_production.pdf',
                );
              },
            ),
            // Download / Save button
            IconButton(
              icon: const Icon(Icons.download_outlined,
                  size: 20, color: Color(0xFF0F9E74)),
              onPressed: () async {
                final bytes = await ProductionPdfGenerator.generate(
                  employeeName: employeeName,
                  records: records,
                );
                await Printing.layoutPdf(
                  onLayout: (_) async => bytes,
                  name:
                  '${employeeName.replaceAll(' ', '_')}_production.pdf',
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        // ── Inline PDF viewer ─────────────────────────────
        body: PdfPreview(
          build: (format) => ProductionPdfGenerator.generate(
            employeeName: employeeName,
            records: records,
          ),
          allowPrinting: true,
          allowSharing: true,
          canChangePageFormat: false,
          canChangeOrientation: false,
          pdfFileName:
          '${employeeName.replaceAll(' ', '_')}_production.pdf',
          actions: const [],
          previewPageMargin:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

