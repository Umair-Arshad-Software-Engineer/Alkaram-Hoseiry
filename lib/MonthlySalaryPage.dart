import 'package:alkaram_hosiery/services/employee_services.dart';
import 'package:alkaram_hosiery/services/ledger_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'models/employee_models.dart';

// ─────────────────────────────────────────────────────────────
//  Design Tokens (match app theme)
// ─────────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceElevated = Color(0xFFF0F3F8);
  static const border = Color(0xFFDDE3EE);

  static const green = Color(0xFF0F9E74);
  static const greenDim = Color(0xFFE8F7F2);
  static const red = Color(0xFFD63B3B);
  static const blue = Color(0xFF2473CC);
  static const blueDim = Color(0xFFEAF2FF);
  static const amber = Color(0xFFE8900A);
  static const amberDim = Color(0xFFFFF3E0);

  static const textPrimary = Color(0xFF1A1F2E);
  static const textSecondary = Color(0xFF5A637A);
  static const textMuted = Color(0xFFA0ABBE);
}

// ─────────────────────────────────────────────────────────────
//  Monthly Salary Tracking Page
// ─────────────────────────────────────────────────────────────
class MonthlySalaryTrackingPage extends StatefulWidget {
  final MonthlyEmployee employee;
  const MonthlySalaryTrackingPage({super.key, required this.employee});

  @override
  State<MonthlySalaryTrackingPage> createState() =>
      _MonthlySalaryTrackingPageState();
}

class _MonthlySalaryTrackingPageState
    extends State<MonthlySalaryTrackingPage> {
  final RealtimeDatabaseService _db = RealtimeDatabaseService();
  final LedgerService _ledgerService = LedgerService();

  final _daysCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  // Live stream of attendance records for this employee
  late Stream<List<MonthlyAttendanceRecord>> _recordsStream;

  @override
  void initState() {
    super.initState();
    _recordsStream =
        _db.getMonthlyAttendanceRecords(widget.employee.id);
  }

  @override
  void dispose() {
    _daysCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ─── Preview calculation ────────────────────────────────────
  double get _previewDays =>
      double.tryParse(_daysCtrl.text.trim()) ?? 0;
  double get _previewEarnings =>
      _previewDays * widget.employee.dailyRate;

  // ─── Save ───────────────────────────────────────────────────
  Future<void> _saveEntry() async {
    final days = double.tryParse(_daysCtrl.text.trim());
    if (days == null || days <= 0) {
      _showSnack('Enter valid number of days', color: _C.red);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final earnings = days * widget.employee.dailyRate;
      final record = MonthlyAttendanceRecord(
        id: '',
        employeeId: widget.employee.id,
        employeeName: widget.employee.name,
        daysAdded: days.toInt(),
        dailyRate: widget.employee.dailyRate,
        earnings: earnings,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        timestamp: _selectedDate,
      );

      // 1. Save attendance record + update employee daysWorked
      await _db.saveMonthlyAttendanceRecord(record);

      // 2. Auto-credit ledger
      final desc = _notesCtrl.text.trim().isEmpty
          ? 'Salary – ${days.toInt()} day${days == 1 ? '' : 's'}'
          : '${_notesCtrl.text.trim()} (${days.toInt()} days)';

      await _ledgerService.addCreditEntry(
        employeeId: widget.employee.id,
        amount: earnings,
        description: desc,
        date: _selectedDate,
        referenceId: 'monthly_attendance',      );

      _daysCtrl.clear();
      _notesCtrl.clear();
      _selectedDate = DateTime.now();
      HapticFeedback.mediumImpact();
      _showSnack(
        '${days.toInt()} days saved · Rs ${earnings.toStringAsFixed(2)} credited',
        color: _C.green,
      );
    } catch (e) {
      _showSnack('Error: $e', color: _C.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // ─── Delete record ───────────────────────────────────────────
  Future<void> _deleteRecord(MonthlyAttendanceRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _C.surface,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Record',
            style: TextStyle(
                color: _C.textPrimary, fontWeight: FontWeight.w600)),
        content: Text(
          'Delete ${record.daysAdded} days entry '
              '(Rs ${record.earnings.toStringAsFixed(2)})? '
              'This will NOT automatically reverse the ledger credit.',
          style: const TextStyle(color: _C.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: _C.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style:
                TextStyle(color: _C.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _db.deleteMonthlyAttendanceRecord(
          widget.employee.id, record.id);
      _showSnack('Record deleted', color: _C.red);
    } catch (e) {
      _showSnack('Error: $e', color: _C.red);
    }
  }

  void _showSnack(String msg, {Color color = _C.green}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Container(width: 4, height: 32, color: color),
          const SizedBox(width: 12),
          Expanded(
              child:
              Text(msg, style: const TextStyle(color: _C.textPrimary))),
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

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: _C.bg,
        colorScheme: const ColorScheme.light(primary: _C.green),
      ),
      child: Scaffold(
        backgroundColor: _C.bg,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildInputCard(),
            const SizedBox(height: 4),
            _buildRecordsHeader(),
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
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.employee.name,
              style: const TextStyle(
                  color: _C.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          Text(
            'Monthly · Rs ${widget.employee.monthlySalary.toStringAsFixed(0)}/mo'
                ' · Rs ${widget.employee.dailyRate.toStringAsFixed(2)}/day',
            style: const TextStyle(color: _C.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ─── Input Card ─────────────────────────────────────────────
  Widget _buildInputCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _C.greenDim,
                borderRadius: BorderRadius.circular(8),
              ),
              child:
              const Icon(Icons.calendar_month, color: _C.green, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Add Working Days',
                style: TextStyle(
                    color: _C.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ]),
          const SizedBox(height: 4),
          const Text('Salary will be auto-credited to ledger',
              style: TextStyle(
                  color: _C.textMuted,
                  fontSize: 11,
                  fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),

          // Days field
          _buildTextField(
            controller: _daysCtrl,
            label: 'Working Days',
            hint: 'e.g. 25',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),

          // Notes field
          _buildTextField(
            controller: _notesCtrl,
            label: 'Notes (optional)',
            hint: 'e.g. November 2024',
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 10),

          // Date picker
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                builder: (c, child) => Theme(
                  data: Theme.of(c).copyWith(
                    colorScheme: const ColorScheme.light(primary: _C.green),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color: _C.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _C.border),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 15, color: _C.textMuted),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd MMM yyyy').format(_selectedDate),
                  style: const TextStyle(
                      color: _C.textPrimary, fontSize: 14),
                ),
                const Spacer(),
                const Text('Change',
                    style: TextStyle(
                        color: _C.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ]),
            ),
          ),

          // Preview
          if (_previewDays > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _C.greenDim,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _C.green.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_previewDays.toInt()} days'
                            ' × Rs ${widget.employee.dailyRate.toStringAsFixed(2)}/day',
                        style: const TextStyle(
                            color: _C.green, fontSize: 12),
                      ),
                      const Text('Will be credited to ledger',
                          style: TextStyle(
                              color: _C.textMuted, fontSize: 10)),
                    ],
                  ),
                  Text(
                    'Rs ${_previewEarnings.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: _C.green,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        fontFamily: 'Courier'),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveEntry,
              icon: _isSaving
                  ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: Text(
                _isSaving ? 'Saving…' : 'Save & Credit Ledger',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.green,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(color: _C.textPrimary, fontSize: 14),
      cursorColor: _C.green,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: _C.textSecondary, fontSize: 13),
        hintStyle: const TextStyle(color: _C.textMuted, fontSize: 13),
        filled: true,
        fillColor: _C.surfaceElevated,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _C.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _C.green, width: 1.5),
        ),
        isDense: true,
      ),
    );
  }

  // ─── Records header ──────────────────────────────────────────
  Widget _buildRecordsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        const Text('Attendance History',
            style: TextStyle(
                color: _C.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
        const Spacer(),
        StreamBuilder<List<MonthlyAttendanceRecord>>(
          stream: _recordsStream,
          builder: (context, snap) {
            final records = snap.data ?? [];
            final totalDays =
            records.fold<int>(0, (s, r) => s + r.daysAdded);
            final totalEarned =
            records.fold<double>(0, (s, r) => s + r.earnings);
            return Text(
              '$totalDays days · Rs ${totalEarned.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: _C.green,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  fontFamily: 'Courier'),
            );
          },
        ),
      ]),
    );
  }

  // ─── Records list ────────────────────────────────────────────
  Widget _buildRecordsList() {
    return StreamBuilder<List<MonthlyAttendanceRecord>>(
      stream: _recordsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _C.green));
        }

        final records = snapshot.data ?? [];
        if (records.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                      color: _C.surfaceElevated, shape: BoxShape.circle),
                  child: const Icon(Icons.calendar_month_outlined,
                      size: 36, color: _C.textMuted),
                ),
                const SizedBox(height: 16),
                const Text('No attendance records yet',
                    style: TextStyle(
                        color: _C.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                const Text('Add working days above to generate salary',
                    style: TextStyle(color: _C.textMuted, fontSize: 13)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: records.length,
          itemBuilder: (context, i) {
            final r = records[i];
            return _buildRecordTile(r, i);
          },
        );
      },
    );
  }

  Widget _buildRecordTile(MonthlyAttendanceRecord r, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 1))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Index circle
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _C.greenDim,
                shape: BoxShape.circle,
                border: Border.all(color: _C.green.withOpacity(0.25)),
              ),
              child: Center(
                child: Text('${index + 1}',
                    style: const TextStyle(
                        color: _C.green,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(
                      '${r.daysAdded} day${r.daysAdded == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: _C.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _C.greenDim,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: _C.green.withOpacity(0.25)),
                      ),
                      child: const Text('▲ Credited',
                          style: TextStyle(
                              color: _C.green,
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  if (r.notes != null && r.notes!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(r.notes!,
                        style: const TextStyle(
                            color: _C.textSecondary, fontSize: 12)),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(r.timestamp),
                    style: const TextStyle(
                        color: _C.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            // Earnings
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rs ${r.earnings.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: _C.green,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      fontFamily: 'Courier'),
                ),
                Text(
                  '@ Rs ${r.dailyRate.toStringAsFixed(2)}/day',
                  style: const TextStyle(
                      color: _C.textMuted, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(width: 8),
            // Delete
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 17, color: _C.textMuted),
              onPressed: () => _deleteRecord(r),
              padding: EdgeInsets.zero,
              constraints:
              const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ),
    );
  }
}