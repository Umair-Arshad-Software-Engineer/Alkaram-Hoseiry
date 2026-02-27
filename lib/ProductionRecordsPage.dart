import 'package:alkaram_hosiery/pdfforrecords.dart';
import 'package:alkaram_hosiery/services/production_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'models/employee_models.dart';
import 'models/production_record.dart';

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
  static const redDim = Color(0x12D63B3B);
  static const amberDim = Color(0x12E8900A);
  static const greenDim = Color(0x120F9E74);

  static const textPrimary = Color(0xFF1A1F2E);
  static const textSecondary = Color(0xFF5A637A);
  static const textMuted = Color(0xFFA0ABBE);
}

// ─────────────────────────────────────────────────────────────
//  Production Records Page
// ─────────────────────────────────────────────────────────────
class ProductionRecordsPage extends StatefulWidget {
  final PerPieceEmployee employee;
  const ProductionRecordsPage({super.key, required this.employee});

  @override
  State<ProductionRecordsPage> createState() => _ProductionRecordsPageState();
}

class _ProductionRecordsPageState extends State<ProductionRecordsPage> {
  final ProductionServiceRealtime _service = ProductionServiceRealtime();
  final DateFormat _dateFmt = DateFormat('dd MMM yyyy');
  final DateFormat _timeFmt = DateFormat('hh:mm a');

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // ── Keep a reference to the latest records for PDF export ──
  List<ProductionRecord> _latestRecords = [];

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
        builder: (_) => ProductionRecordsPdfPage(
          employeeName: widget.employee.name,
          records: _latestRecords,
        ),
      ),
    );
  }

  // ─── Delete ─────────────────────────────────────────────────
  Future<void> _deleteRecord(ProductionRecord record) async {
    final confirm = await _showConfirmDialog(
      title: 'Delete Record',
      message:
      'Delete record of ${record.piecesProduced} pieces (${record.totalEarnings.toStringAsFixed(2)} Rs)? This cannot be undone.',
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
  Future<void> _editRecord(ProductionRecord record) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _EditRecordSheet(record: record, employee: widget.employee),
    );

    if (result == null) return;

    try {
      await _service.updateProductionRecord(
        employeeId: widget.employee.id,
        oldRecord: record,
        newPieces: result['pieces'] as int,
        newTotalEarnings: result['totalEarnings'] as double,
        newDurationMinutes: result['durationMinutes'] as int,
        newRatePerPiece: result['ratePerPiece'] as double,
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

  String _formatDuration(int minutes, bool isHours) {
    if (isHours) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      if (m == 0) return '$h hr';
      return '$h hr $m min';
    } else {
      return '$minutes min';
    }
  }

  // ─── BUILD ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: _C.bg,
        colorScheme: const ColorScheme.light(primary: _C.amber),
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
          const Text('Production Records',
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
              backgroundColor: _C.redDim,
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
        cursorColor: _C.amber,
        decoration: InputDecoration(
          hintText: 'Search by date or pieces...',
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
    return StreamBuilder<List<ProductionRecord>>(
      stream: _service.getEmployeeProductionRecords(widget.employee.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _C.amber));
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

        // ── Cache latest records for PDF export ──────────────
        _latestRecords = allRecords;

        // Filter by search
        final records = _searchQuery.isEmpty
            ? allRecords
            : allRecords.where((r) {
          final dateStr =
          _dateFmt.format(r.endTime).toLowerCase();
          final piecesStr = r.piecesProduced.toString();
          final earningsStr = r.totalEarnings.toStringAsFixed(0);
          return dateStr.contains(_searchQuery) ||
              piecesStr.contains(_searchQuery) ||
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
                  _searchQuery.isEmpty
                      ? 'No records yet'
                      : 'No results found',
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
                  style: const TextStyle(
                      color: _C.textMuted, fontSize: 13),
                ),
              ],
            ),
          );
        }

        final totalEarnings =
        allRecords.fold(0.0, (s, r) => s + r.totalEarnings);
        final totalPieces =
        allRecords.fold(0, (s, r) => s + r.piecesProduced);

        return Column(
          children: [
            _buildSummaryStrip(
                totalRecords: allRecords.length,
                totalPieces: totalPieces,
                totalEarnings: totalEarnings),
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
          _summaryChip(
              label: 'Records', value: '$totalRecords', color: _C.blue),
          _summaryDivider(),
          _summaryChip(
              label: 'Pieces', value: '$totalPieces', color: _C.amber),
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
              style:
              const TextStyle(color: _C.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _summaryDivider() =>
      Container(width: 1, height: 32, color: _C.border);

  Widget _buildRecordCard(ProductionRecord record, int index) {
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
                    icon: Icons.layers_outlined,
                    label: 'Pieces',
                    value: '${record.piecesProduced}',
                    color: _C.amber),
                _statCell(
                    icon: Icons.timer_outlined,
                    label: 'Duration',
                    value: _formatDuration(
                        record.durationInMinutes, record.isHours),
                    color: _C.blue),
                _statCell(
                    icon: Icons.payments_outlined,
                    label: 'Rate',
                    value:
                    '${record.ratePerPiece.toStringAsFixed(2)}/pc',
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
//  Edit Record Bottom Sheet (unchanged)
// ─────────────────────────────────────────────────────────────
class _EditRecordSheet extends StatefulWidget {
  final ProductionRecord record;
  final PerPieceEmployee employee;

  const _EditRecordSheet({required this.record, required this.employee});

  @override
  State<_EditRecordSheet> createState() => _EditRecordSheetState();
}

class _EditRecordSheetState extends State<_EditRecordSheet> {
  late final TextEditingController _rateCtrl;
  late final TextEditingController _piecesCtrl;
  late final TextEditingController _timeCtrl;
  bool _isHours = false;

  @override
  void initState() {
    super.initState();
    _isHours = widget.record.isHours;
    _rateCtrl = TextEditingController(
        text: widget.record.ratePerPiece.toStringAsFixed(2));
    _piecesCtrl = TextEditingController(
        text: widget.record.piecesProduced.toString());
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
    _piecesCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final rate = double.tryParse(_rateCtrl.text);
    final pieces = int.tryParse(_piecesCtrl.text);
    final timeVal = double.tryParse(_timeCtrl.text);

    if (rate == null || rate <= 0) {
      _showError('Enter a valid rate');
      return;
    }
    if (pieces == null || pieces <= 0) {
      _showError('Enter a valid piece count');
      return;
    }
    if (timeVal == null || timeVal <= 0) {
      _showError('Enter a valid time');
      return;
    }

    final durationMinutes =
    _isHours ? (timeVal * 60).toInt() : timeVal.toInt();
    final totalEarnings = rate * pieces * timeVal;

    Navigator.pop(context, {
      'pieces': pieces,
      'totalEarnings': totalEarnings,
      'durationMinutes': durationMinutes,
      'ratePerPiece': rate,
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
            'Formula: Rate × Pieces × Time',
            style: TextStyle(
                color: _C.textMuted,
                fontSize: 12,
                fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _editField(_rateCtrl, 'Rate/pc', 'Rs')),
            const SizedBox(width: 10),
            Expanded(
                child: _editField(_piecesCtrl, 'Pieces', 'pcs',
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
                      : _C.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _isHours
                        ? _C.blue.withOpacity(0.4)
                        : _C.amber.withOpacity(0.4),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isHours
                          ? Icons.schedule
                          : Icons.timer_outlined,
                      size: 14,
                      color: _isHours ? _C.blue : _C.amber,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isHours ? 'HRS' : 'MIN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _isHours ? _C.blue : _C.amber,
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
    final pieces = int.tryParse(_piecesCtrl.text) ?? 0;
    final timeVal = double.tryParse(_timeCtrl.text) ?? 0;
    final total = rate * pieces * timeVal;
    final unit = _isHours ? 'hr' : 'min';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _C.greenDim,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.green.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${rate.toStringAsFixed(2)} × $pieces × ${timeVal.toStringAsFixed(timeVal % 1 == 0 ? 0 : 2)}$unit',
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
      cursorColor: _C.amber,
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
          borderSide: const BorderSide(color: _C.amber, width: 1.5),
        ),
        isDense: true,
      ),
    );
  }
}