import 'package:alkaram_hosiery/services/production_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/employee_models.dart';

// ─────────────────────────────────────────────────────────────
//  Design Tokens — Light Theme
// ─────────────────────────────────────────────────────────────
class _AppColors {
  static const bg = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceElevated = Color(0xFFF0F3F8);
  static const border = Color(0xFFDDE3EE);

  static const teal = Colors.teal;
  static const green = Color(0xFF0F9E74);
  static const blue = Color(0xFF2473CC);
  static const red = Color(0xFFD63B3B);
  static const amber = Color(0xFFE8900A);

  static const textPrimary = Color(0xFF1A1F2E);
  static const textSecondary = Color(0xFF5A637A);
  static const textMuted = Color(0xFFA0ABBE);
}

class _AppTextStyles {
  static const tableHeader = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: _AppColors.textSecondary,
    letterSpacing: 0.3,
  );

  static const tableCell = TextStyle(
    fontSize: 14,
    color: _AppColors.textPrimary,
    fontFamily: 'Courier',
  );

  static const totalText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: _AppColors.green,
    fontFamily: 'Courier',
  );
}

// ─────────────────────────────────────────────────────────────
//  Dozen Production Entry Model
//  total = ratePerDozen × dozens
// ─────────────────────────────────────────────────────────────
class DozenProductionEntry {
  int index;
  double ratePerDozen;
  double dozens;
  double total;

  DozenProductionEntry({
    required this.index,
    required this.ratePerDozen,
    required this.dozens,
  }) : total = ratePerDozen * dozens;

  void calculateTotal() {
    total = ratePerDozen * dozens;
  }

  int get totalPieces => (dozens * 12).round();

  String get breakdownLabel =>
      '${ratePerDozen.toStringAsFixed(2)} × ${dozens.toStringAsFixed(dozens % 1 == 0 ? 0 : 2)} doz';
}

// ─────────────────────────────────────────────────────────────
//  Main Page
// ─────────────────────────────────────────────────────────────
class DozenProductionTrackingPage extends StatefulWidget {
  final PerDozenEmployee employee;
  const DozenProductionTrackingPage({super.key, required this.employee});

  @override
  State<DozenProductionTrackingPage> createState() =>
      _DozenProductionTrackingPageState();
}

class _DozenProductionTrackingPageState
    extends State<DozenProductionTrackingPage> {
  final ProductionServiceRealtime _productionService =
  ProductionServiceRealtime();
  final List<DozenProductionEntry> _entries = [];

  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _dozensController = TextEditingController();

  double _grandTotal = 0;
  double _totalDozens = 0;
  int _totalPieces = 0;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _rateController.text = widget.employee.ratePerDozen.toString();
  }

  @override
  void dispose() {
    _rateController.dispose();
    _dozensController.dispose();
    super.dispose();
  }

  // ─── Entry Management ───────────────────────────────────────
  void _addEntry() {
    final rate =
        double.tryParse(_rateController.text) ?? widget.employee.ratePerDozen;
    final dozens = double.tryParse(_dozensController.text) ?? 0;

    if (dozens <= 0) {
      _showSnack('Enter a valid dozen count', color: _AppColors.amber);
      return;
    }

    setState(() {
      _entries.add(DozenProductionEntry(
        index: _entries.length + 1,
        ratePerDozen: rate,
        dozens: dozens,
      ));
      _calculateTotals();
      _dozensController.clear();
    });

    HapticFeedback.lightImpact();
  }

  void _removeEntry(int index) {
    setState(() {
      _entries.removeAt(index);
      for (int i = 0; i < _entries.length; i++) {
        _entries[i].index = i + 1;
      }
      _calculateTotals();
    });
    HapticFeedback.mediumImpact();
  }

  void _calculateTotals() {
    _grandTotal = 0;
    _totalDozens = 0;
    _totalPieces = 0;
    for (var entry in _entries) {
      entry.calculateTotal();
      _grandTotal += entry.total;
      _totalDozens += entry.dozens;
      _totalPieces += entry.totalPieces;
    }
  }

  void _clearAllEntries() {
    if (_entries.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _AppColors.surface,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All Entries',
            style: TextStyle(
                color: _AppColors.textPrimary,
                fontWeight: FontWeight.w600)),
        content: const Text('Are you sure you want to clear all entries?',
            style: TextStyle(color: _AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: _AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _entries.clear();
                _grandTotal = 0;
                _totalDozens = 0;
                _totalPieces = 0;
              });
              Navigator.pop(context);
              HapticFeedback.mediumImpact();
            },
            child: const Text('Clear All',
                style: TextStyle(color: _AppColors.red)),
          ),
        ],
      ),
    );
  }

  // ─── Save ───────────────────────────────────────────────────
  Future<void> _saveEntries() async {
    if (_entries.isEmpty) {
      _showSnack('No entries to save', color: _AppColors.amber);
      return;
    }

    final confirm = await _showConfirmSheet(
      title: 'Save Production Data',
      subtitle:
      '${_entries.length} entries · ${_totalDozens.toStringAsFixed(_totalDozens % 1 == 0 ? 0 : 2)} doz · $_totalPieces pcs · Rs ${_grandTotal.toStringAsFixed(2)}',
      confirmLabel: 'Save',
      confirmColor: _AppColors.green,
    );

    if (confirm != true) return;
    setState(() => _isSaving = true);

    try {
      await _productionService.saveDozenProductionEntries(
        employee: widget.employee,
        totalDozens: _totalDozens,
        totalPieces: _totalPieces,
        totalEarnings: _grandTotal,
      );

      setState(() {
        _entries.clear();
        _grandTotal = 0;
        _totalDozens = 0;
        _totalPieces = 0;
      });

      _showSnack('Production data saved successfully');
      HapticFeedback.heavyImpact();
    } catch (e) {
      _showSnack('Error: $e', color: _AppColors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // ─── Helpers ────────────────────────────────────────────────
  void _showSnack(String msg, {Color color = _AppColors.green}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Container(width: 4, height: 32, color: color),
          const SizedBox(width: 12),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(color: _AppColors.textPrimary))),
        ]),
        backgroundColor: _AppColors.surface,
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

  Future<bool?> _showConfirmSheet({
    required String title,
    required String subtitle,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _AppColors.border),
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
            Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(subtitle,
                style: const TextStyle(
                    color: _AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 28),
            Row(children: [
              Expanded(
                  child: _OutlineBtn(
                      label: 'Cancel',
                      onTap: () => Navigator.pop(context, false))),
              const SizedBox(width: 12),
              Expanded(
                  child: _SolidBtn(
                      label: confirmLabel,
                      color: confirmColor,
                      onTap: () => Navigator.pop(context, true))),
            ]),
          ],
        ),
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
        scaffoldBackgroundColor: _AppColors.bg,
        colorScheme: ColorScheme.light(primary: Colors.teal),
      ),
      child: Scaffold(
        backgroundColor: _AppColors.bg,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildInputForm(),
            _buildTableHeader(),
            Expanded(child: _buildEntriesTable()),
            _buildTotalsFooter(),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _AppColors.border),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            size: 18, color: _AppColors.textSecondary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.employee.name,
              style: const TextStyle(
                  color: _AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          Text(
              'Rate: ${widget.employee.ratePerDozen.toStringAsFixed(2)}/doz',
              style: const TextStyle(color: Colors.teal, fontSize: 12)),
        ],
      ),
      actions: [
        if (_entries.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined,
                color: _AppColors.red),
            onPressed: _clearAllEntries,
          ),
      ],
    );
  }

  Widget _buildInputForm() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _AppColors.border),
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
          // Row: Rate + Dozens + Add button
          Row(children: [
            Expanded(
                child: _LightTextField(
                    controller: _rateController,
                    label: 'Rate/dozen',
                    suffix: 'Rs',
                    accentColor: Colors.teal,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true))),
            const SizedBox(width: 8),
            Expanded(
                child: _LightTextField(
                    controller: _dozensController,
                    label: 'Dozens',
                    suffix: 'doz',
                    accentColor: Colors.teal,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true))),
            const SizedBox(width: 8),
            _SolidBtn(
                label: 'Add',
                color: Colors.teal,
                onTap: _addEntry,
                compact: true),
          ]),
          const SizedBox(height: 8),
          // Formula preview
          const Text(
            'Formula: Rate/dozen × Dozens  →  total  (1 dozen = 12 pieces)',
            style: TextStyle(
                fontSize: 11,
                color: _AppColors.textMuted,
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: _AppColors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        border: Border.all(color: _AppColors.border),
      ),
      child: const Row(
        children: [
          SizedBox(
              width: 28,
              child: Text('#', style: _AppTextStyles.tableHeader)),
          Expanded(
              flex: 2,
              child: Text('Rate', style: _AppTextStyles.tableHeader)),
          Expanded(
              flex: 2,
              child: Text('Dozens', style: _AppTextStyles.tableHeader)),
          Expanded(
              flex: 2,
              child: Text('Pieces', style: _AppTextStyles.tableHeader)),
          Expanded(
              flex: 3,
              child: Text('Total', style: _AppTextStyles.tableHeader)),
          SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _buildEntriesTable() {
    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  color: _AppColors.surfaceElevated,
                  shape: BoxShape.circle),
              child: const Icon(Icons.table_rows_outlined,
                  size: 36, color: _AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            const Text('No entries yet',
                style: TextStyle(
                    color: _AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            const Text('Add production entries using the form above',
                style:
                TextStyle(color: _AppColors.textMuted, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding:
          const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: index.isOdd
                ? _AppColors.surfaceElevated
                : _AppColors.surface,
            border: Border.all(
                color: _AppColors.border.withOpacity(0.6)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text('${entry.index}',
                    style: _AppTextStyles.tableCell
                        .copyWith(color: _AppColors.textMuted)),
              ),
              Expanded(
                  flex: 2,
                  child: Text(entry.ratePerDozen.toStringAsFixed(2),
                      style: _AppTextStyles.tableCell)),
              Expanded(
                flex: 2,
                child: Text(
                  entry.dozens.toStringAsFixed(
                      entry.dozens % 1 == 0 ? 0 : 2),
                  style: _AppTextStyles.tableCell,
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${entry.totalPieces} pcs',
                    style: _AppTextStyles.tableCell.copyWith(
                      fontSize: 12,
                      color: Colors.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.total.toStringAsFixed(2),
                        style: _AppTextStyles.tableCell.copyWith(
                            color: _AppColors.green,
                            fontWeight: FontWeight.w600)),
                    Text(entry.breakdownLabel,
                        style: const TextStyle(
                            fontSize: 9,
                            color: _AppColors.textMuted)),
                  ],
                ),
              ),
              SizedBox(
                width: 36,
                child: IconButton(
                  icon: const Icon(Icons.close,
                      size: 17, color: _AppColors.red),
                  onPressed: () => _removeEntry(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTotalsFooter() {
    if (_entries.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          _totalRow(
            'Total Dozens:',
            _totalDozens.toStringAsFixed(
                _totalDozens % 1 == 0 ? 0 : 2),
            _AppTextStyles.totalText.copyWith(color: Colors.teal),
          ),
          const SizedBox(height: 8),
          _totalRow(
            'Total Pieces:',
            '$_totalPieces',
            _AppTextStyles.totalText
                .copyWith(color: _AppColors.amber),
          ),
          const Divider(color: _AppColors.border, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('GRAND TOTAL:',
                  style: TextStyle(
                      color: _AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
              Text('Rs ${_grandTotal.toStringAsFixed(2)}',
                  style:
                  _AppTextStyles.totalText.copyWith(fontSize: 22)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalRow(
      String label, String value, TextStyle valueStyle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
            const TextStyle(color: _AppColors.textSecondary)),
        Text(value, style: valueStyle),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: SizedBox(
        width: double.infinity,
        child: _isSaving
            ? const Center(child: CircularProgressIndicator())
            : _SolidBtn(
          label: 'Save Entries',
          color: _AppColors.green,
          onTap: _saveEntries,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Reusable Widgets
// ─────────────────────────────────────────────────────────────

class _LightTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String suffix;
  final Color accentColor;
  final TextInputType keyboardType;

  const _LightTextField({
    required this.controller,
    required this.label,
    required this.suffix,
    this.accentColor = Colors.teal,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
          color: _AppColors.textPrimary, fontSize: 14),
      cursorColor: accentColor,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
            color: _AppColors.textSecondary, fontSize: 12),
        suffixText: suffix,
        suffixStyle: const TextStyle(
            color: _AppColors.textMuted, fontSize: 11),
        filled: true,
        fillColor: _AppColors.surfaceElevated,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
        isDense: true,
      ),
    );
  }
}

class _SolidBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  const _SolidBtn({
    required this.label,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 46 : 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 18)
              : null,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: compact ? 13 : 15)),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OutlineBtn({
    required this.label,
    this.color = _AppColors.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color == _AppColors.border
              ? _AppColors.textSecondary
              : color,
          side: BorderSide(
              color: color == _AppColors.border
                  ? _AppColors.border
                  : color.withOpacity(0.6)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
      ),
    );
  }
}