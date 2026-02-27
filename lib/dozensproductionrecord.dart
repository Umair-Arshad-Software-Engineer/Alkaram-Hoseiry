import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'models/employee_models.dart';
import 'package:alkaram_hosiery/services/dozen_production_service.dart';

// ─────────────────────────────────────────────────────────────
//  Design Tokens
// ─────────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceElevated = Color(0xFFF0F3F8);
  static const border = Color(0xFFDDE3EE);
  static const amber = Color(0xFFE8900A);
  static const green = Color(0xFF0F9E74);
  static const blue = Color(0xFF2473CC);
  static const red = Color(0xFFD63B3B);
  static const teal = Color(0xFF008080);
  static const textPrimary = Color(0xFF1A1F2E);
  static const textSecondary = Color(0xFF5A637A);
  static const textMuted = Color(0xFFA0ABBE);

  // PDF equivalents
  static final pdfAmber = PdfColor.fromHex('#E8900A');
  static final pdfGreen = PdfColor.fromHex('#0F9E74');
  static final pdfBlue = PdfColor.fromHex('#2473CC');
  static final pdfTeal = PdfColor.fromHex('#008080');
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
//  Dozen PDF Generator
// ─────────────────────────────────────────────────────────────
class DozenProductionPdfGenerator {
  static final DateFormat _dateFmt = DateFormat('dd MMM yyyy');
  static final DateFormat _timeFmt = DateFormat('hh:mm a');

  static String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '$h hr';
    return '$h hr $m min';
  }

  static Future<Uint8List> generate({
    required String employeeName,
    required List<DozenProductionRecord> records,
  }) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    final fontSemiBold = await PdfGoogleFonts.nunitoSemiBold();

    final totalEarnings = records.fold(0.0, (s, r) => s + r.totalEarnings);
    final totalDozens = records.fold(0, (s, r) => s + r.dozensProduced);
    // final totalPieces = records.fold(0, (s, r) => s + r.totalPieces);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildHeader(employeeName, fontBold, fontRegular),
        footer: (context) => _buildFooter(context, fontRegular),
        build: (context) => [
          pw.SizedBox(height: 12),
          _buildSummaryStrip(
            totalRecords: records.length,
            totalDozens: totalDozens,
            // totalPieces: totalPieces,
            totalEarnings: totalEarnings,
            fontBold: fontBold,
            fontRegular: fontRegular,
          ),
          pw.SizedBox(height: 16),
          _buildTable(
            records: records,
            fontBold: fontBold,
            fontRegular: fontRegular,
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
        border: pw.Border(bottom: pw.BorderSide(color: _C.pdfBorder, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(employeeName,
                  style: pw.TextStyle(
                      font: fontBold, fontSize: 16, color: _C.pdfTextPrimary)),
              pw.SizedBox(height: 2),
              pw.Text('Production Records (Dozens)',
                  style: pw.TextStyle(
                      font: fontRegular, fontSize: 11, color: _C.pdfTextSecondary)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: _C.pdfTeal,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text(
                  'AL-KARAM HOSIERY',
                  style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 9,
                      color: PdfColors.white,
                      letterSpacing: 0.8),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                style: pw.TextStyle(
                    font: fontRegular, fontSize: 8, color: _C.pdfTextMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────
  static pw.Widget _buildFooter(pw.Context context, pw.Font fontRegular) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _C.pdfBorder, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Al-Karam Hosiery — Confidential',
              style: pw.TextStyle(
                  font: fontRegular, fontSize: 8, color: _C.pdfTextMuted)),
          pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(
                  font: fontRegular, fontSize: 8, color: _C.pdfTextMuted)),
        ],
      ),
    );
  }

  // ── Summary Strip ─────────────────────────────────────────
  static pw.Widget _buildSummaryStrip({
    required int totalRecords,
    required int totalDozens,
    // required int totalPieces,
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
          _chip('Records', '$totalRecords', _C.pdfBlue, fontBold, fontRegular),
          _divider(),
          _chip('Dozens', '$totalDozens', _C.pdfTeal, fontBold, fontRegular),
          // _divider(),
          // _chip('Pieces', '$totalPieces', _C.pdfAmber, fontBold, fontRegular),
          _divider(),
          _chip('Earned', 'Rs ${totalEarnings.toStringAsFixed(0)}', _C.pdfGreen,
              fontBold, fontRegular),
        ],
      ),
    );
  }

  static pw.Widget _chip(String label, String value, PdfColor color,
      pw.Font fontBold, pw.Font fontRegular) {
    return pw.Expanded(
      child: pw.Column(
        children: [
          pw.Text(value,
              style: pw.TextStyle(font: fontBold, fontSize: 15, color: color)),
          pw.SizedBox(height: 2),
          pw.Text(label,
              style: pw.TextStyle(
                  font: fontRegular, fontSize: 9, color: _C.pdfTextMuted)),
        ],
      ),
    );
  }

  static pw.Widget _divider() =>
      pw.Container(width: 0.8, height: 30, color: _C.pdfBorder);

  // ── Table — NO Time column ────────────────────────────────
  static pw.Widget _buildTable({
    required List<DozenProductionRecord> records,
    required pw.Font fontBold,
    required pw.Font fontRegular,
  }) {
    // Columns: #  Date  Dozens  Pieces  Rate/doz  Earned
    final headers = ['#', 'Date', 'Dozens', 'Rate/doz', 'Earned'];
    // final headers = ['#', 'Date', 'Dozens', 'Pieces', 'Rate/doz', 'Earned'];

    final headerRow = headers.map((h) {
      return pw.Container(
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: pw.Text(h,
            style: pw.TextStyle(
                font: fontBold, fontSize: 9, color: PdfColors.white)),
      );
    }).toList();

    final dataRows = records.asMap().entries.map((entry) {
      final i = entry.key;
      final r = entry.value;
      final bgColor = i % 2 == 0 ? _C.pdfSurface : _C.pdfRowAlt;

      final cells = [
        '${i + 1}',
        _dateFmt.format(r.endTime),
        '${r.dozensProduced}',
        // '${r.totalPieces}',
        'Rs ${r.ratePerDozen.toStringAsFixed(2)}',
        'Rs ${r.totalEarnings.toStringAsFixed(2)}',
      ];

      return pw.TableRow(
        decoration: pw.BoxDecoration(color: bgColor),
        children: cells.asMap().entries.map((cell) {
          final isLast = cell.key == cells.length - 1;
          return pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            child: pw.Text(
              cell.value,
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
    final totalDozens = records.fold(0, (s, r) => s + r.dozensProduced);
    // final totalPieces = records.fold(0, (s, r) => s + r.totalPieces);
    final totalEarnings = records.fold(0.0, (s, r) => s + r.totalEarnings);

    final totalsRow = pw.TableRow(
      decoration: pw.BoxDecoration(color: _C.pdfSummaryBg),
      children: [
        _totalCell('', fontBold),
        _totalCell('TOTAL', fontBold, color: _C.pdfTextSecondary),
        _totalCell('$totalDozens doz', fontBold, color: _C.pdfTeal),
        // _totalCell('$totalPieces pcs', fontBold, color: _C.pdfAmber),
        _totalCell('', fontBold),
        _totalCell('Rs ${totalEarnings.toStringAsFixed(2)}', fontBold,
            color: _C.pdfGreen),
      ],
    );

    return pw.Table(
      border: pw.TableBorder.all(color: _C.pdfBorder, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(22),   // #
        1: const pw.FlexColumnWidth(2.2),   // Date
        2: const pw.FixedColumnWidth(48),   // Dozens
        // 3: const pw.FixedColumnWidth(48),   // Pieces
        3: const pw.FlexColumnWidth(1.8),   // Rate/doz
        4: const pw.FlexColumnWidth(2),     // Earned
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _C.pdfHeaderBg),
          children: headerRow,
        ),
        ...dataRows,
        totalsRow,
      ],
    );
  }

  static pw.Widget _totalCell(String text, pw.Font fontBold,
      {PdfColor? color}) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: pw.Text(text,
          style: pw.TextStyle(
              font: fontBold,
              fontSize: 9,
              color: color ?? _C.pdfTextPrimary)),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  PDF Preview Page
// ─────────────────────────────────────────────────────────────
class DozenProductionRecordsPdfPage extends StatelessWidget {
  final String employeeName;
  final List<DozenProductionRecord> records;

  const DozenProductionRecordsPdfPage({
    super.key,
    required this.employeeName,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: _C.bg,
        colorScheme: const ColorScheme.light(primary: _C.teal),
      ),
      child: Scaffold(
        backgroundColor: _C.bg,
        appBar: AppBar(
          backgroundColor: _C.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: _C.border),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: _C.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PDF Preview',
                  style: TextStyle(
                      color: _C.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              Text('Production Records (Dozens)',
                  style: TextStyle(color: _C.textSecondary, fontSize: 12)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined,
                  size: 20, color: _C.blue),
              onPressed: () async {
                final bytes = await DozenProductionPdfGenerator.generate(
                  employeeName: employeeName,
                  records: records,
                );
                await Printing.sharePdf(
                  bytes: bytes,
                  filename:
                  '${employeeName.replaceAll(' ', '_')}_dozens_production.pdf',
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.download_outlined,
                  size: 20, color: _C.green),
              onPressed: () async {
                final bytes = await DozenProductionPdfGenerator.generate(
                  employeeName: employeeName,
                  records: records,
                );
                await Printing.layoutPdf(
                  onLayout: (_) async => bytes,
                  name:
                  '${employeeName.replaceAll(' ', '_')}_dozens_production.pdf',
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: PdfPreview(
          build: (format) => DozenProductionPdfGenerator.generate(
            employeeName: employeeName,
            records: records,
          ),
          allowPrinting: true,
          allowSharing: true,
          canChangePageFormat: false,
          canChangeOrientation: false,
          pdfFileName:
          '${employeeName.replaceAll(' ', '_')}_dozens_production.pdf',
          actions: const [],
          previewPageMargin:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Dozen Production Records Page (with PDF button)
// ─────────────────────────────────────────────────────────────
class DozenProductionRecordsPage extends StatefulWidget {
  final PerDozenEmployee employee;
  const DozenProductionRecordsPage({super.key, required this.employee});

  @override
  State<DozenProductionRecordsPage> createState() =>
      _DozenProductionRecordsPageState();
}

class _DozenProductionRecordsPageState
    extends State<DozenProductionRecordsPage> {
  final DozenProductionService _service = DozenProductionService();
  final DateFormat _dateFmt = DateFormat('dd MMM yyyy');
  final DateFormat _timeFmt = DateFormat('hh:mm a');

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Cache latest records for PDF export
  List<DozenProductionRecord> _latestRecords = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── PDF Export ─────────────────────────────────────────────
  void _exportPdf() {
    if (_latestRecords.isEmpty) {
      _showSnack('No records to export', color: _C.amber);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DozenProductionRecordsPdfPage(
          employeeName: widget.employee.name,
          records: _latestRecords,
        ),
      ),
    );
  }

  // ─── Delete ─────────────────────────────────────────────────
  Future<void> _deleteRecord(DozenProductionRecord record) async {
    final confirm = await _showConfirmDialog(
      title: 'Delete Record',
      message:
      'Delete record of ${record.dozensProduced} dozens (${record.totalEarnings.toStringAsFixed(2)} Rs)? This cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: _C.red,
    );
    if (confirm != true) return;

    try {
      await _service.deleteProductionRecord(
        employeeId: widget.employee.id,
        record: record,
      );
      _showSnack('Record deleted', color: _C.red);
      HapticFeedback.mediumImpact();
    } catch (e) {
      _showSnack('Error: $e', color: _C.red);
    }
  }

  // ─── Edit ───────────────────────────────────────────────────
  Future<void> _editRecord(DozenProductionRecord record) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _EditDozenRecordSheet(record: record, employee: widget.employee),
    );

    if (result == null) return;

    try {
      await _service.updateProductionRecord(
        employeeId: widget.employee.id,
        oldRecord: record,
        newDozens: result['dozens'] as int,
        newTotalEarnings: result['totalEarnings'] as double,
        newDurationMinutes: result['durationMinutes'] as int,
        newRatePerDozen: result['ratePerDozen'] as double,
      );
      _showSnack('Record updated successfully');
      HapticFeedback.lightImpact();
    } catch (e) {
      _showSnack('Error: $e', color: _C.red);
    }
  }

  // ─── Helpers ────────────────────────────────────────────────
  void _showSnack(String msg, {Color color = _C.green}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Container(width: 4, height: 32, color: color),
          const SizedBox(width: 12),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(color: _C.textPrimary))),
        ]),
        backgroundColor: _C.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withOpacity(0.4)),
        ),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _C.surface,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(
                color: _C.textPrimary, fontWeight: FontWeight.w600)),
        content: Text(message,
            style:
            const TextStyle(color: _C.textSecondary, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: _C.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel,
                style: TextStyle(
                    color: confirmColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '$h hr';
    return '$h hr $m min';
  }

  // ─── BUILD ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: _C.bg,
        colorScheme: const ColorScheme.light(primary: _C.teal),
      ),
      child: Scaffold(
        backgroundColor: _C.bg,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(child: _buildRecordsList()),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _C.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _C.border),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            size: 18, color: _C.textSecondary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.employee.name,
              style: const TextStyle(
                  color: _C.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const Text('Production Records (Dozens)',
              style: TextStyle(color: _C.textSecondary, fontSize: 12)),
        ],
      ),
      // ── PDF Export Button ──────────────────────────────────
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            onPressed: _exportPdf,
            icon: const Icon(
              Icons.picture_as_pdf_outlined,
              size: 18,
              color: _C.red,
            ),
            label: const Text(
              'PDF',
              style: TextStyle(
                color: _C.red,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0x12D63B3B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: _C.red.withOpacity(0.25)),
              ),
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        style: const TextStyle(color: _C.textPrimary, fontSize: 14),
        cursorColor: _C.teal,
        decoration: InputDecoration(
          hintText: 'Search by date or dozens...',
          hintStyle: const TextStyle(color: _C.textMuted, fontSize: 14),
          prefixIcon:
          const Icon(Icons.search, color: _C.textMuted, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.close,
                color: _C.textMuted, size: 18),
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildRecordsList() {
    return StreamBuilder<List<DozenProductionRecord>>(
      stream: _service.getEmployeeProductionRecords(widget.employee.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _C.teal));
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: _C.red, size: 48),
                const SizedBox(height: 12),
                Text('Error loading records',
                    style: TextStyle(color: _C.textSecondary)),
              ],
            ),
          );
        }

        final allRecords = snapshot.data ?? [];

        // Cache for PDF
        _latestRecords = allRecords;

        final records = _searchQuery.isEmpty
            ? allRecords
            : allRecords.where((r) {
          final dateStr =
          _dateFmt.format(r.endTime).toLowerCase();
          final dozensStr = r.dozensProduced.toString();
          final earningsStr = r.totalEarnings.toStringAsFixed(0);
          return dateStr.contains(_searchQuery) ||
              dozensStr.contains(_searchQuery) ||
              earningsStr.contains(_searchQuery);
        }).toList();

        if (records.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                      color: _C.surfaceElevated, shape: BoxShape.circle),
                  child: const Icon(Icons.receipt_long_outlined,
                      size: 36, color: _C.textMuted),
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty ? 'No records yet' : 'No results found',
                  style: const TextStyle(
                      color: _C.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                Text(
                  _searchQuery.isEmpty
                      ? 'Saved production entries will appear here'
                      : 'Try a different search term',
                  style: const TextStyle(color: _C.textMuted, fontSize: 13),
                ),
              ],
            ),
          );
        }

        final totalEarnings =
        allRecords.fold(0.0, (s, r) => s + r.totalEarnings);
        final totalDozens =
        allRecords.fold(0, (s, r) => s + r.dozensProduced);
        final totalPieces =
        allRecords.fold(0, (s, r) => s + r.totalPieces);

        return Column(
          children: [
            _buildSummaryStrip(
              totalRecords: allRecords.length,
              totalDozens: totalDozens,
              totalPieces: totalPieces,
              totalEarnings: totalEarnings,
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: records.length,
                itemBuilder: (context, index) =>
                    _buildRecordCard(records[index], index),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryStrip({
    required int totalRecords,
    required int totalDozens,
    required int totalPieces,
    required double totalEarnings,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          _summaryChip(label: 'Records', value: '$totalRecords', color: _C.blue),
          _summaryDivider(),
          _summaryChip(label: 'Dozens', value: '$totalDozens', color: _C.teal),
          _summaryDivider(),
          _summaryChip(label: 'Pieces', value: '$totalPieces', color: _C.amber),
          _summaryDivider(),
          _summaryChip(
              label: 'Earned',
              value: totalEarnings.toStringAsFixed(0),
              color: _C.green),
        ],
      ),
    );
  }

  Widget _summaryChip(
      {required String label,
        required String value,
        required Color color}) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Courier')),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: _C.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _summaryDivider() =>
      Container(width: 1, height: 32, color: _C.border);

  Widget _buildRecordCard(DozenProductionRecord record, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
            child: Row(
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _C.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _C.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 11, color: _C.textMuted),
                      const SizedBox(width: 4),
                      Text(_dateFmt.format(record.endTime),
                          style: const TextStyle(
                              color: _C.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _C.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _C.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time_outlined,
                          size: 11, color: _C.textMuted),
                      const SizedBox(width: 4),
                      Text(_timeFmt.format(record.endTime),
                          style: const TextStyle(
                              color: _C.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 18, color: _C.blue),
                  onPressed: () => _editRecord(record),
                  tooltip: 'Edit',
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: _C.red),
                  onPressed: () => _deleteRecord(record),
                  tooltip: 'Delete',
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _C.border),
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _statCell(
                    icon: Icons.inventory_outlined,
                    label: 'Dozens',
                    value: '${record.dozensProduced}',
                    color: _C.teal),
                _statCell(
                    icon: Icons.layers_outlined,
                    label: 'Pieces',
                    value: '${record.totalPieces}',
                    color: _C.amber),
                _statCell(
                    icon: Icons.timer_outlined,
                    label: 'Duration',
                    value: _formatDuration(record.durationInMinutes),
                    color: _C.blue),
                _statCell(
                    icon: Icons.payments_outlined,
                    label: 'Rate',
                    value:
                    '${record.ratePerDozen.toStringAsFixed(2)}/doz',
                    color: _C.textSecondary),
                _statCell(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Earned',
                    value:
                    'Rs ${record.totalEarnings.toStringAsFixed(2)}',
                    color: _C.green,
                    highlight: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCell({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool highlight = false,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 11, color: color.withOpacity(0.7)),
            const SizedBox(width: 3),
            Text(label,
                style: const TextStyle(
                    color: _C.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  color: highlight ? color : _C.textPrimary,
                  fontSize: highlight ? 13 : 12,
                  fontWeight:
                  highlight ? FontWeight.w700 : FontWeight.w600,
                  fontFamily: 'Courier')),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Edit Dozen Record Bottom Sheet (unchanged)
// ─────────────────────────────────────────────────────────────
class _EditDozenRecordSheet extends StatefulWidget {
  final DozenProductionRecord record;
  final PerDozenEmployee employee;

  const _EditDozenRecordSheet(
      {required this.record, required this.employee});

  @override
  State<_EditDozenRecordSheet> createState() => _EditDozenRecordSheetState();
}

class _EditDozenRecordSheetState extends State<_EditDozenRecordSheet> {
  late final TextEditingController _rateCtrl;
  late final TextEditingController _dozensCtrl;
  late final TextEditingController _timeCtrl;
  bool _isHours = false;

  @override
  void initState() {
    super.initState();
    _isHours = widget.record.isHours;
    _rateCtrl = TextEditingController(
        text: widget.record.ratePerDozen.toStringAsFixed(2));
    _dozensCtrl = TextEditingController(
        text: widget.record.dozensProduced.toString());
    _timeCtrl = TextEditingController(
      text: widget.record.isHours
          ? (widget.record.durationInMinutes / 60).toStringAsFixed(
          widget.record.durationInMinutes % 60 == 0 ? 0 : 2)
          : widget.record.durationInMinutes.toString(),
    );
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    _dozensCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final rate = double.tryParse(_rateCtrl.text);
    final dozens = int.tryParse(_dozensCtrl.text);
    final timeVal = double.tryParse(_timeCtrl.text);

    if (rate == null || rate <= 0) {
      _showError('Enter a valid rate');
      return;
    }
    if (dozens == null || dozens <= 0) {
      _showError('Enter a valid dozen count');
      return;
    }
    if (timeVal == null || timeVal <= 0) {
      _showError('Enter a valid time');
      return;
    }

    final durationMinutes =
    _isHours ? (timeVal * 60).toInt() : timeVal.toInt();
    final totalEarnings = rate * dozens * timeVal;

    Navigator.pop(context, {
      'dozens': dozens,
      'totalEarnings': totalEarnings,
      'durationMinutes': durationMinutes,
      'ratePerDozen': rate,
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _C.red,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.edit_outlined, size: 18, color: _C.blue),
            const SizedBox(width: 8),
            const Text('Edit Record',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _C.textPrimary)),
            const Spacer(),
            IconButton(
              icon:
              const Icon(Icons.close, size: 20, color: _C.textMuted),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
          const SizedBox(height: 4),
          const Text(
            'Formula: Rate/Dozen × Dozens × Time',
            style: TextStyle(
                color: _C.textMuted,
                fontSize: 12,
                fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _editField(_rateCtrl, 'Rate/doz', 'Rs')),
            const SizedBox(width: 10),
            Expanded(
                child: _editField(_dozensCtrl, 'Dozens', 'doz',
                    isInt: true)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _editField(
                _timeCtrl,
                _isHours ? 'Time (Hours)' : 'Time (Minutes)',
                _isHours ? 'hr' : 'min',
                isDecimal: true,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _isHours = !_isHours),
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _isHours
                      ? _C.blue.withOpacity(0.1)
                      : _C.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _isHours
                        ? _C.blue.withOpacity(0.4)
                        : _C.teal.withOpacity(0.4),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isHours ? Icons.schedule : Icons.timer_outlined,
                      size: 14,
                      color: _isHours ? _C.blue : _C.teal,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isHours ? 'HRS' : 'MIN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _isHours ? _C.blue : _C.teal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          _buildPreview(),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.textSecondary,
                  side: const BorderSide(color: _C.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cancel',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Save Changes',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final rate = double.tryParse(_rateCtrl.text) ?? 0;
    final dozens = int.tryParse(_dozensCtrl.text) ?? 0;
    final timeVal = double.tryParse(_timeCtrl.text) ?? 0;
    final total = rate * dozens * timeVal;
    final unit = _isHours ? 'hr' : 'min';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x120F9E74),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.green.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${rate.toStringAsFixed(2)} × $dozens × ${timeVal.toStringAsFixed(timeVal % 1 == 0 ? 0 : 2)}$unit',
            style: const TextStyle(
                color: _C.textSecondary,
                fontSize: 12,
                fontFamily: 'Courier'),
          ),
          Text(
            '= ${total.toStringAsFixed(2)}',
            style: const TextStyle(
                color: _C.green,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFamily: 'Courier'),
          ),
        ],
      ),
    );
  }

  Widget _editField(
      TextEditingController ctrl,
      String label,
      String suffix, {
        bool isInt = false,
        bool isDecimal = false,
      }) {
    return TextFormField(
      controller: ctrl,
      onChanged: (_) => setState(() {}),
      keyboardType: isInt
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: _C.textPrimary, fontSize: 14),
      cursorColor: _C.teal,
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
        const TextStyle(color: _C.textSecondary, fontSize: 12),
        suffixText: suffix,
        suffixStyle:
        const TextStyle(color: _C.textMuted, fontSize: 11),
        filled: true,
        fillColor: _C.surfaceElevated,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _C.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _C.teal, width: 1.5),
        ),
        isDense: true,
      ),
    );
  }
}