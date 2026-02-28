import 'package:alkaram_hosiery/services/ledger_service.dart'; // ← NO 'hide' here
import 'package:alkaram_hosiery/services/ledgerpdf.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'models/employee_models.dart';

class _C {
  static const bg = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceElevated = Color(0xFFF0F3F8);
  static const border = Color(0xFFDDE3EE);

  static const green = Color(0xFF0F9E74);
  static const greenDim = Color(0xFFE8F7F2);
  static const red = Color(0xFFD63B3B);
  static const redDim = Color(0xFFFDECEC);
  static const blue = Color(0xFF2473CC);
  static const blueDim = Color(0xFFEAF2FF);
  static const amber = Color(0xFFE8900A);
  static const amberDim = Color(0xFFFFF3E0);

  static const textPrimary = Color(0xFF1A1F2E);
  static const textSecondary = Color(0xFF5A637A);
  static const textMuted = Color(0xFFA0ABBE);
}

class EmployeeLedgerPage extends StatefulWidget {
  final Employee employee;
  const EmployeeLedgerPage({super.key, required this.employee});

  @override
  State<EmployeeLedgerPage> createState() => _EmployeeLedgerPageState();
}

class _EmployeeLedgerPageState extends State<EmployeeLedgerPage> {
  final LedgerService _ledgerService = LedgerService();
  final DateFormat _dateFmt = DateFormat('dd MMM yy');
  final DateFormat _timeFmt = DateFormat('hh:mm a');
  final LedgerPdfService _pdfService = LedgerPdfService(); // ← NEW
  List<LedgerEntry> _latestEntries = [];


  Future<void> _exportPdf() async {
    if (_latestEntries.isEmpty) {
      _showSnack('No entries to export', color: _C.amber);
      return;
    }
    try {
      _showSnack('Generating PDF…', color: _C.blue);
      await _pdfService.shareOrPrintLedger(
        employee: widget.employee,
        entries: _latestEntries,
      );
    } catch (e) {
      _showSnack('PDF error: $e', color: _C.red);
    }
  }


  Future<void> _showAddPaymentSheet() async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController(text: 'Payment');
    DateTime selectedDate = DateTime.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _C.border),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _C.redDim,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.payments_outlined,
                          color: _C.red, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text('Add Payment',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _C.textPrimary)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 20, color: _C.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  const Text('This will be recorded as a debit entry',
                      style: TextStyle(
                          color: _C.textMuted,
                          fontSize: 12,
                          fontStyle: FontStyle.italic)),
                  const SizedBox(height: 20),
                  _sheetField(
                    controller: amountCtrl,
                    label: 'Amount Paid',
                    prefix: 'Rs',
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  _sheetField(
                    controller: descCtrl,
                    label: 'Description',
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (c, child) => Theme(
                          data: Theme.of(c).copyWith(
                            colorScheme:
                            const ColorScheme.light(primary: _C.red),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setSheetState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 13),
                      decoration: BoxDecoration(
                        color: _C.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _C.border),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 15, color: _C.textMuted),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd MMM yyyy').format(selectedDate),
                          style: const TextStyle(
                              color: _C.textPrimary, fontSize: 14),
                        ),
                        const Spacer(),
                        const Text('Change',
                            style: TextStyle(
                                color: _C.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
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
                        onPressed: () async {
                          final amount = double.tryParse(amountCtrl.text);
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                  content: Text('Enter valid amount'),
                                  backgroundColor: _C.red),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          try {
                            await _ledgerService.addDebitEntry(
                              employeeId: widget.employee.id,
                              amount: amount,
                              description: descCtrl.text.isEmpty
                                  ? 'Payment'
                                  : descCtrl.text,
                              date: selectedDate,
                            );
                            _showSnack(
                                'Payment of Rs ${amount.toStringAsFixed(2)} recorded',
                                color: _C.red);
                            HapticFeedback.mediumImpact();
                          } catch (e) {
                            _showSnack('Error: $e', color: _C.red);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Record Payment',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteEntry(LedgerEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _C.surface,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Entry',
            style: TextStyle(
                color: _C.textPrimary, fontWeight: FontWeight.w600)),
        content: Text(
          'Delete this ${entry.isCredit ? "credit" : "debit"} entry of Rs ${entry.amount.toStringAsFixed(2)}?',
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
      await _ledgerService.deleteEntry(widget.employee.id, entry.id);
      _showSnack('Entry deleted', color: _C.red);
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

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: _C.bg,
        colorScheme: const ColorScheme.light(primary: _C.blue),
      ),
      child: Scaffold(
        backgroundColor: _C.bg,
        appBar: _buildAppBar(),
        body: StreamBuilder<List<LedgerEntry>>(
          stream: _ledgerService.getEntries(widget.employee.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: _C.blue));
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: _C.red)),
              );
            }

            final entries = snapshot.data ?? [];
            _latestEntries = entries; // ← cache for PDF export

            return Column(
              children: [
                _buildBalanceHeader(entries),
                _buildTableHeader(),
                Expanded(child: _buildTable(entries)),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddPaymentSheet,
          backgroundColor: _C.red,
          foregroundColor: Colors.white,
          elevation: 2,
          icon: const Icon(Icons.remove_circle_outline, size: 20),
          label: const Text('Add Payment',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
          const Text('Ledger',
              style: TextStyle(color: _C.textSecondary, fontSize: 12)),
        ],
      ),
      // ── NEW: PDF export button ──────────────────────────────────────────
      actions: [
        IconButton(
          tooltip: 'Export PDF',
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _C.blueDim,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.picture_as_pdf_outlined,
                color: _C.blue, size: 18),
          ),
          onPressed: _exportPdf,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBalanceHeader(List<LedgerEntry> entries) {
    double totalCredit = 0;
    double totalDebit = 0;
    for (final e in entries) {
      if (e.isCredit) {
        totalCredit += e.amount;
      } else {
        totalDebit += e.amount;
      }
    }
    final balance = totalCredit - totalDebit;
    final isPositive = balance >= 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
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
        children: [
          Row(children: [
            _balanceChip(
              label: 'Total Earned',
              value: 'Rs ${totalCredit.toStringAsFixed(2)}',
              color: _C.green,
              bgColor: _C.greenDim,
              icon: Icons.arrow_downward_rounded,
            ),
            const SizedBox(width: 8),
            _balanceChip(
              label: 'Total Paid',
              value: 'Rs ${totalDebit.toStringAsFixed(2)}',
              color: _C.red,
              bgColor: _C.redDim,
              icon: Icons.arrow_upward_rounded,
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isPositive ? _C.greenDim : _C.redDim,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color:
                  (isPositive ? _C.green : _C.red).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Icon(
                    isPositive
                        ? Icons.account_balance_wallet_outlined
                        : Icons.warning_amber_outlined,
                    color: isPositive ? _C.green : _C.red,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPositive ? 'Balance Due (Payable)' : 'Overpaid',
                    style: TextStyle(
                        color: isPositive ? _C.green : _C.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ]),
                Text(
                  'Rs ${balance.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                      color: isPositive ? _C.green : _C.red,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      fontFamily: 'Courier'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _balanceChip({
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
                color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, size: 12, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color.withOpacity(0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 1),
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        fontFamily: 'Courier')),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _C.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        border: Border.all(color: _C.border),
      ),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(36),
          1: FixedColumnWidth(72),
          2: FlexColumnWidth(2.5),
          3: FlexColumnWidth(1.6),
          4: FlexColumnWidth(1.6),
          5: FlexColumnWidth(1.8),
          6: FixedColumnWidth(36),
        },
        children: [
          TableRow(children: [
            _th('#'),
            _th('Date'),
            _th('Description'),
            _th('Credit', color: _C.green),
            _th('Debit', color: _C.red),
            _th('Balance'),
            _th(''),
          ]),
        ],
      ),
    );
  }

  Widget _th(String text, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color ?? _C.textSecondary,
        letterSpacing: 0.3,
      ),
    ),
  );

  Widget _buildTable(List<LedgerEntry> entries) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  color: _C.surfaceElevated, shape: BoxShape.circle),
              child: const Icon(Icons.account_balance_outlined,
                  size: 36, color: _C.textMuted),
            ),
            const SizedBox(height: 16),
            const Text('No ledger entries yet',
                style: TextStyle(
                    color: _C.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            const Text(
                'Credits appear automatically when salary/production is saved.\nUse the button below to record payments.',
                style: TextStyle(
                    color: _C.textMuted, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    double running = 0;
    final List<double> runningBalances = [];
    for (final e in entries) {
      if (e.isCredit) {
        running += e.amount;
      } else {
        running -= e.amount;
      }
      runningBalances.add(running);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius:
        const BorderRadius.vertical(bottom: Radius.circular(10)),
        border: const Border(
          left: BorderSide(color: _C.border),
          right: BorderSide(color: _C.border),
          bottom: BorderSide(color: _C.border),
        ),
      ),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final balance = runningBalances[index];
          return _buildTableRow(
            entry: entry,
            rowNumber: index + 1,
            balance: balance,
            isEven: index.isEven,
            isLast: index == entries.length - 1,
          );
        },
      ),
    );
  }

  Widget _buildTableRow({
    required LedgerEntry entry,
    required int rowNumber,
    required double balance,
    required bool isEven,
    required bool isLast,
  }) {
    final isCredit = entry.isCredit;
    final balancePositive = balance >= 0;

    return Container(
      decoration: BoxDecoration(
        color: isEven ? _C.surface : _C.surfaceElevated,
        border: isLast
            ? null
            : const Border(
            bottom: BorderSide(color: _C.border, width: 0.5)),
      ),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(36),
          1: FixedColumnWidth(72),
          2: FlexColumnWidth(2.5),
          3: FlexColumnWidth(1.6),
          4: FlexColumnWidth(1.6),
          5: FlexColumnWidth(1.8),
          6: FixedColumnWidth(36),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(children: [
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Text('$rowNumber',
                  style: const TextStyle(
                      color: _C.textMuted,
                      fontSize: 11,
                      fontFamily: 'Courier')),
            ),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_dateFmt.format(entry.date),
                      style: const TextStyle(
                          color: _C.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  Text(_timeFmt.format(entry.date),
                      style:
                      const TextStyle(color: _C.textMuted, fontSize: 9)),
                ],
              ),
            ),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.description,
                      style: const TextStyle(
                          color: _C.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCredit ? _C.greenDim : _C.redDim,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: (isCredit ? _C.green : _C.red)
                              .withOpacity(0.3)),
                    ),
                    child: Text(
                      isCredit ? '▲ Credit' : '▼ Debit',
                      style: TextStyle(
                          color: isCredit ? _C.green : _C.red,
                          fontSize: 9,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: isCredit
                  ? Text(entry.amount.toStringAsFixed(2),
                  style: const TextStyle(
                      color: _C.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Courier'))
                  : const Text('—',
                  style:
                  TextStyle(color: _C.textMuted, fontSize: 12)),
            ),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: !isCredit
                  ? Text(entry.amount.toStringAsFixed(2),
                  style: const TextStyle(
                      color: _C.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Courier'))
                  : const Text('—',
                  style:
                  TextStyle(color: _C.textMuted, fontSize: 12)),
            ),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Text(balance.toStringAsFixed(2),
                  style: TextStyle(
                      color: balancePositive ? _C.green : _C.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Courier')),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 15, color: _C.textMuted),
                onPressed: () => _deleteEntry(entry),
                padding: EdgeInsets.zero,
                constraints:
                const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _sheetField({
    required TextEditingController controller,
    required String label,
    String? prefix,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: _C.textPrimary, fontSize: 14),
      cursorColor: _C.red,
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
        const TextStyle(color: _C.textSecondary, fontSize: 13),
        prefixText: prefix != null ? '$prefix  ' : null,
        prefixStyle: const TextStyle(
            color: _C.textMuted, fontWeight: FontWeight.w600),
        filled: true,
        fillColor: _C.surfaceElevated,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _C.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _C.red, width: 1.5),
        ),
        isDense: true,
      ),
    );
  }
}