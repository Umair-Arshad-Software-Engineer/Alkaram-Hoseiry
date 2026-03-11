import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ─────────────────────────────────────────────────────────────
//  Design Tokens
// ─────────────────────────────────────────────────────────────
class _SC {
  static const bgPrimary     = Color(0xFFF8FAFC);
  static const bgCard        = Color(0xFFFFFFFF);
  static const accentPurple  = Color(0xFFAB47BC);
  static const accentLilac   = Color(0xFFCE93D8);
  static const accentAmber   = Color(0xFFFFB74D);
  static const accentGreen   = Color(0xFF66BB6A);
  static const accentRed     = Color(0xFFEF5350);
  static const accentOrange  = Color(0xFFFF8A65);
  static const accentTeal    = Color(0xFF26A69A);
  static const textPrimary   = Color(0xFF2C3E50);
  static const textSecondary = Color(0xFF7F8C8D);
  static const border        = Color(0xFFE2E8F0);
  static const shadow        = Color(0x1A000000);

  static const shopName = 'Alkaram Hoseiry Shop';
}

// ─────────────────────────────────────────────────────────────
//  Model
// ─────────────────────────────────────────────────────────────
class ShopTransfer {
  final String   id;
  final String   itemName;
  final int      qty;
  final String   note;
  final DateTime transferredAt;

  ShopTransfer({
    required this.id,
    required this.itemName,
    required this.qty,
    required this.note,
    required this.transferredAt,
  });

  Map<String, dynamic> toMap() => {
    'itemName':      itemName,
    'qty':           qty,
    'note':          note,
    'transferredAt': transferredAt.toIso8601String(),
    'destination':   _SC.shopName,
  };

  factory ShopTransfer.fromMap(String id, Map<String, dynamic> m) =>
      ShopTransfer(
        id:            id,
        itemName:      m['itemName'] ?? '',
        qty:           (m['qty'] ?? 0) is int
            ? m['qty']
            : int.tryParse(m['qty'].toString()) ?? 0,
        note:          m['note'] ?? '',
        transferredAt: DateTime.tryParse(m['transferredAt'] ?? '') ?? DateTime.now(),
      );
}

// ─────────────────────────────────────────────────────────────
//  Row entry for dialog
// ─────────────────────────────────────────────────────────────
class _ShopRow {
  final TextEditingController itemCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController noteCtrl;
  String selectedItem;

  _ShopRow({String item = '', String qty = '', String note = ''})
      : itemCtrl    = TextEditingController(text: item),
        qtyCtrl     = TextEditingController(text: qty),
        noteCtrl    = TextEditingController(text: note),
        selectedItem = item;

  void dispose() {
    itemCtrl.dispose();
    qtyCtrl.dispose();
    noteCtrl.dispose();
  }

  bool get isEmpty => selectedItem.trim().isEmpty && qtyCtrl.text.trim().isEmpty;
}

// ─────────────────────────────────────────────────────────────
//  Shop Transfer Page
// ─────────────────────────────────────────────────────────────
class ShopTransferPage extends StatefulWidget {
  const ShopTransferPage({super.key});

  @override
  State<ShopTransferPage> createState() => _ShopTransferPageState();
}

class _ShopTransferPageState extends State<ShopTransferPage>
    with SingleTickerProviderStateMixin {

  final _shopRef   = FirebaseDatabase.instance.ref('shop_transfers');
  final _godownRef = FirebaseDatabase.instance.ref('godown_transfers');

  List<ShopTransfer>  _allTransfers  = [];
  List<ShopTransfer>  _filtered      = [];

  DateTime? _startDate;
  DateTime? _endDate;
  Map<String, int>    _godownStock   = {};

  bool   _isLoading    = true;
  String _searchQuery  = '';
  String _filterPeriod = 'All';

  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Load ────────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _shopRef.get(),
        _godownRef.get(),
      ]);

      final List<ShopTransfer> shopTransfers = [];
      if (results[0].value != null && results[0].value is Map) {
        for (final e in (results[0].value as Map).entries) {
          try {
            shopTransfers.add(ShopTransfer.fromMap(
                e.key.toString(),
                Map<String, dynamic>.from(e.value as Map)));
          } catch (_) {}
        }
      }
      shopTransfers.sort((a, b) => b.transferredAt.compareTo(a.transferredAt));

      final Map<String, int> received = {};
      if (results[1].value != null && results[1].value is Map) {
        for (final v in (results[1].value as Map).values) {
          final name = v['itemName']?.toString() ?? '';
          if (name.isEmpty) continue;
          final qty = (v['qty'] ?? 0) is int
              ? v['qty'] as int
              : int.tryParse(v['qty'].toString()) ?? 0;
          received[name] = (received[name] ?? 0) + qty;
        }
      }

      final Map<String, int> sentToShop = {};
      for (final t in shopTransfers) {
        sentToShop[t.itemName] = (sentToShop[t.itemName] ?? 0) + t.qty;
      }

      final Map<String, int> stock = {};
      for (final entry in received.entries) {
        final available = entry.value - (sentToShop[entry.key] ?? 0);
        if (available > 0) stock[entry.key] = available;
      }

      setState(() {
        _allTransfers = shopTransfers;
        _filtered     = _applyFilters(shopTransfers);
        _godownStock  = stock;
        _isLoading    = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _snack('Error loading data: $e', color: _SC.accentRed);
    }
  }

  // ── Filters ─────────────────────────────────────────────────
  List<ShopTransfer> _applyFilters(List<ShopTransfer> src) {
    final now = DateTime.now();
    return src.where((t) {
      bool inPeriod = true;

      if (_startDate != null && _endDate != null) {
        final transferDate = DateTime(t.transferredAt.year, t.transferredAt.month, t.transferredAt.day);
        final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
        inPeriod = transferDate.isAfter(start.subtract(const Duration(days: 1))) &&
            transferDate.isBefore(end.add(const Duration(days: 1)));
      } else if (_filterPeriod == 'Today') {
        inPeriod = t.transferredAt.year == now.year &&
            t.transferredAt.month == now.month &&
            t.transferredAt.day == now.day;
      } else if (_filterPeriod == 'Week') {
        inPeriod = now.difference(t.transferredAt).inDays <= 7;
      } else if (_filterPeriod == 'Month') {
        inPeriod = t.transferredAt.year == now.year &&
            t.transferredAt.month == now.month;
      }

      final q = _searchQuery.toLowerCase();
      return inPeriod &&
          (q.isEmpty ||
              t.itemName.toLowerCase().contains(q) ||
              t.note.toLowerCase().contains(q));
    }).toList();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _SC.accentPurple,
              onPrimary: Colors.white,
              onSurface: _SC.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _filterPeriod = 'Custom';
        _filtered = _applyFilters(_allTransfers);
      });
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _filterPeriod = 'All';
      _filtered = _applyFilters(_allTransfers);
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _onSearch(String q) => setState(() {
    _searchQuery = q.toLowerCase();
    _filtered    = _applyFilters(_allTransfers);
  });

  void _setPeriod(String p) => setState(() {
    _filterPeriod = p;
    _startDate = null;
    _endDate = null;
    _filtered = _applyFilters(_allTransfers);
  });

  // ── Add / Edit Dialog ────────────────────────────────────────
  Future<void> _showAddDialog({ShopTransfer? editing}) async {
    final isEdit = editing != null;

    Map<String, int> availableStock = Map.from(_godownStock);
    if (isEdit) {
      availableStock[editing.itemName] =
          (availableStock[editing.itemName] ?? 0) + editing.qty;
    }

    final godownItems = availableStock.keys.toList()..sort();

    if (!isEdit && godownItems.isEmpty) {
      _snack('No stock available in godown', color: _SC.accentOrange);
      return;
    }

    final rows = isEdit
        ? [_ShopRow(item: editing.itemName, qty: editing.qty.toString(), note: editing.note)]
        : List.generate(3, (_) => _ShopRow());
    final noteCtrl = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {

          Widget noteCell(TextEditingController ctrl, String hint,
              {FocusNode? focusNode}) =>
              TextField(
                controller: ctrl,
                focusNode: focusNode,
                style: const TextStyle(color: _SC.textPrimary, fontSize: 12),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: _SC.textSecondary, fontSize: 11),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: _SC.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: _SC.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: _SC.accentPurple, width: 1.2)),
                ),
              );

          Widget qtyCell(TextEditingController ctrl) =>
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: _SC.textPrimary, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Qty',
                  hintStyle: const TextStyle(color: _SC.textSecondary, fontSize: 11),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: _SC.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: _SC.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: _SC.accentPurple, width: 1.2)),
                ),
              );

          Widget itemDropdown(_ShopRow row) {
            return DropdownButtonFormField<String>(
              value: row.selectedItem.isEmpty ? null : row.selectedItem,
              isDense: true,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: 'Select item',
                hintStyle: const TextStyle(color: _SC.textSecondary, fontSize: 11),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: _SC.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: _SC.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: _SC.accentPurple, width: 1.2)),
              ),
              style: const TextStyle(color: _SC.textPrimary, fontSize: 12),
              items: godownItems.map((name) {
                return DropdownMenuItem(
                  value: name,
                  child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setS(() {
                    row.selectedItem = val;
                    row.itemCtrl.text = val;
                  });
                }
              },
            );
          }

          Widget dataRow(int index, _ShopRow row) => Container(
            decoration: BoxDecoration(
              color: index.isEven ? Colors.white : _SC.bgPrimary,
              border: const Border(top: BorderSide(color: _SC.border)),
            ),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SizedBox(
                    width: 24,
                    child: Text('${index + 1}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _SC.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(flex: 4, child: itemDropdown(row)),
                const SizedBox(width: 6),
                Expanded(flex: 2, child: qtyCell(row.qtyCtrl)),
                const SizedBox(width: 6),
                Expanded(flex: 3, child: noteCell(row.noteCtrl, 'Note')),
                const SizedBox(width: 4),
                if (!isEdit)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      onTap: rows.length > 1 ? () => setS(() => rows.removeAt(index)) : null,
                      child: Icon(Icons.remove_circle_outline, size: 18, color: rows.length > 1 ? _SC.accentRed : _SC.border),
                    ),
                  )
                else
                  const SizedBox(width: 18),
              ],
            ),
          );

          final validCount = rows.where((r) => !r.isEmpty).length;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 28),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 700),
              decoration: BoxDecoration(color: _SC.bgCard, borderRadius: BorderRadius.circular(20)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isEdit ? [_SC.accentAmber, const Color(0xFFFFE082)] : [_SC.accentPurple, _SC.accentLilac],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(children: [
                      Icon(isEdit ? Icons.edit : Icons.storefront, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isEdit ? 'Edit Transfer' : 'Godown → ${_SC.shopName}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                            Text(isEdit ? 'Update the transfer details' : 'Only items in godown stock shown',
                                style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        onPressed: () {
                          for (final r in rows) r.dispose();
                          noteCtrl.dispose();
                          Navigator.pop(ctx);
                        },
                      ),
                    ]),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: _SC.accentPurple.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _SC.accentPurple.withOpacity(0.2)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.storefront, color: _SC.accentPurple, size: 16),
                              const SizedBox(width: 8),
                              Text('Destination: ${_SC.shopName}',
                                  style: const TextStyle(color: _SC.accentPurple, fontSize: 12, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                          Container(
                            decoration: BoxDecoration(border: Border.all(color: _SC.border), borderRadius: BorderRadius.circular(12)),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Column(children: [
                                Container(
                                  color: const Color(0xFFF3E5F5),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                                  child: Row(children: [
                                    const SizedBox(width: 24),
                                    const SizedBox(width: 6),
                                    _hCell('Item (Godown Stock)', flex: 4),
                                    const SizedBox(width: 6),
                                    _hCell('Qty', flex: 2, align: TextAlign.center),
                                    const SizedBox(width: 6),
                                    _hCell('Note', flex: 3),
                                    const SizedBox(width: 22),
                                  ]),
                                ),
                                ...rows.asMap().entries.map((e) => dataRow(e.key, e.value)),
                                if (!isEdit)
                                  GestureDetector(
                                    onTap: () => setS(() => rows.add(_ShopRow())),
                                    child: Container(
                                      color: _SC.bgPrimary,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_circle_outline, color: _SC.accentPurple.withOpacity(0.7), size: 16),
                                          const SizedBox(width: 6),
                                          Text('Add Row',
                                              style: TextStyle(color: _SC.accentPurple.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ),
                              ]),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (!isEdit)
                            TextField(
                              controller: noteCtrl,
                              maxLines: 2,
                              style: const TextStyle(color: _SC.textPrimary, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Transfer Note (optional — applies to all)',
                                labelStyle: const TextStyle(color: _SC.textSecondary, fontSize: 12),
                                prefixIcon: const Icon(Icons.note_outlined, color: _SC.accentPurple, size: 18),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                filled: true,
                                fillColor: _SC.bgPrimary,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _SC.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _SC.border)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _SC.accentPurple, width: 1.5)),
                              ),
                            ),
                          const SizedBox(height: 8),
                          if (!isEdit)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _SC.accentPurple.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _SC.accentPurple.withOpacity(0.2)),
                                ),
                                child: Text(
                                  '$validCount / ${rows.length} row${rows.length == 1 ? '' : 's'} filled',
                                  style: const TextStyle(color: _SC.accentPurple, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            for (final r in rows) r.dispose();
                            noteCtrl.dispose();
                            Navigator.pop(ctx);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _SC.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: const Text('Cancel', style: TextStyle(color: _SC.textSecondary)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isEdit ? _SC.accentAmber : _SC.accentPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            elevation: 0,
                          ),
                          icon: Icon(isEdit ? Icons.save : Icons.check, size: 18),
                          label: Text(
                            isEdit ? 'Update Transfer' : 'Save $validCount Transfer${validCount == 1 ? '' : 's'}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onPressed: () async {
                            final valid = <_ShopRow>[];
                            final Map<String, int> batchUsage = {};

                            for (int i = 0; i < rows.length; i++) {
                              final r = rows[i];
                              if (r.isEmpty) continue;

                              if (r.selectedItem.isEmpty) {
                                _snack('Row ${i + 1}: Select an item', color: _SC.accentRed);
                                return;
                              }
                              final qty = int.tryParse(r.qtyCtrl.text.trim()) ?? 0;
                              if (qty <= 0) {
                                _snack('Row ${i + 1}: Enter valid quantity', color: _SC.accentRed);
                                return;
                              }

                              final avail = availableStock[r.selectedItem] ?? 0;
                              final alreadyUsed = batchUsage[r.selectedItem] ?? 0;
                              if (qty + alreadyUsed > avail) {
                                _snack('Row ${i + 1}: Only $avail pcs of "${r.selectedItem}" available in godown', color: _SC.accentRed);
                                return;
                              }

                              batchUsage[r.selectedItem] = alreadyUsed + qty;
                              valid.add(r);
                            }

                            if (valid.isEmpty) {
                              _snack('Fill at least one row', color: _SC.accentRed);
                              return;
                            }

                            final sharedNote = noteCtrl.text.trim();
                            Navigator.pop(ctx);
                            _showSavingOverlay();

                            try {
                              if (isEdit) {
                                final r = valid.first;
                                final updated = ShopTransfer(
                                  id: editing!.id,
                                  itemName: r.selectedItem.trim(),
                                  qty: int.parse(r.qtyCtrl.text.trim()),
                                  note: r.noteCtrl.text.trim(),
                                  transferredAt: editing.transferredAt,
                                );
                                await _shopRef.child(editing.id).update(updated.toMap());
                                final idx = _allTransfers.indexWhere((x) => x.id == editing.id);
                                if (idx != -1) _allTransfers[idx] = updated;
                                _hideOverlay();
                                await _loadData();
                                _snack('Transfer updated!', color: _SC.accentAmber);
                              } else {
                                final now = DateTime.now();
                                final List<ShopTransfer> saved = [];
                                for (final r in valid) {
                                  final rowNote = r.noteCtrl.text.trim();
                                  final t = ShopTransfer(
                                    id: '',
                                    itemName: r.selectedItem.trim(),
                                    qty: int.parse(r.qtyCtrl.text.trim()),
                                    note: rowNote.isNotEmpty ? rowNote : sharedNote,
                                    transferredAt: now,
                                  );
                                  final ref = await _shopRef.push();
                                  await ref.set(t.toMap());
                                  saved.add(ShopTransfer(id: ref.key!, itemName: t.itemName, qty: t.qty, note: t.note, transferredAt: t.transferredAt));
                                }
                                _hideOverlay();
                                await _loadData();
                                _snack('Saved ${saved.length} transfer${saved.length == 1 ? '' : 's'}!', color: _SC.accentGreen);
                              }

                              for (final r in rows) r.dispose();
                              noteCtrl.dispose();
                            } catch (e) {
                              _hideOverlay();
                              _snack('Error: $e', color: _SC.accentRed);
                            }
                          },
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget _hCell(String label, {int flex = 1, TextAlign align = TextAlign.left}) =>
      Expanded(
        flex: flex,
        child: Text(label, textAlign: align,
            style: const TextStyle(color: _SC.accentPurple, fontWeight: FontWeight.w700, fontSize: 12)),
      );

  // ── Delete ───────────────────────────────────────────────────
  Future<void> _deleteTransfer(ShopTransfer t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Transfer', style: TextStyle(color: _SC.textPrimary, fontWeight: FontWeight.w600)),
        content: Text('Delete transfer of ${t.qty} × "${t.itemName}"?\n\nThis will restore the qty back to godown stock.',
            style: const TextStyle(color: _SC.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: _SC.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: _SC.accentRed, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (ok != true) return;
    await _shopRef.child(t.id).remove();
    _snack('Deleted — stock restored to godown', color: _SC.accentRed);
    await _loadData();
  }

  // ── PDF Export ───────────────────────────────────────────────
  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final totals = _itemTotals;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Godown → Shop Transfers', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Destination: ${_SC.shopName}', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('Generated: $dateStr', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  pw.Text('Period: $_filterPeriod', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  if (_startDate != null && _endDate != null)
                    pw.Text('From: ${_formatDate(_startDate!)} To: ${_formatDate(_endDate!)}',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ]),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Divider(color: PdfColors.purple700),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (ctx) => [
          pw.Row(children: [
            _pdfBox('Total Transfers', _filtered.length.toString(), PdfColors.purple700),
            pw.SizedBox(width: 12),
            _pdfBox('Total Qty', _totalQty.toString(), PdfColors.teal700),
            pw.SizedBox(width: 12),
            _pdfBox('Unique Items', totals.length.toString(), PdfColors.orange700),
          ]),
          pw.SizedBox(height: 20),
          pw.Text('Item Summary', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1), 2: const pw.FlexColumnWidth(1)},
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.purple50),
                children: [
                  _pdfHeaderCell('Item Name', PdfColors.purple800),
                  _pdfHeaderCell('Total Qty', PdfColors.purple800, center: true),
                  _pdfHeaderCell('Transfers', PdfColors.purple800, center: true),
                ],
              ),
              ...totals.entries.map((e) {
                final count = _filtered.where((t) => t.itemName == e.key).length;
                return pw.TableRow(children: [
                  _pdfCell(e.key),
                  _pdfCell(e.value.toString(), center: true, bold: true, color: PdfColors.purple700),
                  _pdfCell(count.toString(), center: true),
                ]);
              }),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.purple50),
                children: [
                  _pdfCell('TOTAL', bold: true),
                  _pdfCell(_totalQty.toString(), center: true, bold: true, color: PdfColors.purple700),
                  _pdfCell(_filtered.length.toString(), center: true, bold: true),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text('Transfer Details', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1), 2: const pw.FlexColumnWidth(3), 3: const pw.FlexColumnWidth(2)},
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.purple50),
                children: [
                  _pdfHeaderCell('Item Name', PdfColors.purple800),
                  _pdfHeaderCell('Qty', PdfColors.purple800, center: true),
                  _pdfHeaderCell('Note', PdfColors.purple800),
                  _pdfHeaderCell('Date/Time', PdfColors.purple800),
                ],
              ),
              ..._filtered.map((t) {
                final d = t.transferredAt;
                final ds = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
                    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
                return pw.TableRow(children: [
                  _pdfCell(t.itemName),
                  _pdfCell(t.qty.toString(), center: true, bold: true, color: PdfColors.purple700),
                  _pdfCell(t.note),
                  _pdfCell(ds, fontSize: 9),
                ]);
              }),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (fmt) async => pdf.save());
  }

  static pw.Widget _pdfBox(String label, String value, PdfColor color) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            pw.Text(value, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: color)),
            pw.SizedBox(height: 4),
            pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600), textAlign: pw.TextAlign.center),
          ]),
        ),
      );

  static pw.Widget _pdfHeaderCell(String text, PdfColor color, {bool center = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(7),
        child: pw.Text(text, textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
      );

  static pw.Widget _pdfCell(String text, {bool center = false, bool bold = false, PdfColor? color, double fontSize = 10}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text, textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
            style: pw.TextStyle(fontSize: fontSize, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color ?? PdfColors.grey900)),
      );

  // ── Computed ─────────────────────────────────────────────────
  Map<String, int> get _itemTotals {
    final map = <String, int>{};
    for (final t in _filtered) {
      map[t.itemName] = (map[t.itemName] ?? 0) + t.qty;
    }
    return Map.fromEntries(map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  int get _totalQty => _filtered.fold(0, (sum, t) => sum + t.qty);

  // ── Overlay / Snack ──────────────────────────────────────────
  OverlayEntry? _overlayEntry;

  void _showSavingOverlay() {
    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: Container(
          color: Colors.black26,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: _SC.bgCard, borderRadius: BorderRadius.circular(16)),
              child: const Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: _SC.accentPurple),
                SizedBox(height: 12),
                Text('Saving...', style: TextStyle(color: _SC.textPrimary)),
              ]),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _snack(String msg, {Color color = _SC.accentGreen}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: _SC.textPrimary)),
      backgroundColor: _SC.bgCard,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: color.withOpacity(0.5))),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 3),
    ));
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _SC.bgPrimary,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _SC.accentPurple))
          : Column(children: [
        _buildFilters(),
        TabBar(
          controller: _tabCtrl,
          labelColor: _SC.accentPurple,
          unselectedLabelColor: _SC.textSecondary,
          indicatorColor: _SC.accentPurple,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt), text: 'Transfers'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Report'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [_buildTransferList(), _buildReport()],
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: _godownStock.isEmpty ? _SC.textSecondary : _SC.accentPurple,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add),
        label: const Text('New Transfer', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    flexibleSpace: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_SC.accentPurple, _SC.accentLilac], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
    ),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text('Shop Transfers', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        Text(_SC.shopName, style: TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    ),
    titleTextStyle: const TextStyle(color: Colors.white),
    iconTheme: const IconThemeData(color: Colors.white),
    elevation: 0,
    actions: [
      IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _exportPdf, tooltip: 'Export PDF'),
      IconButton(icon: const Icon(Icons.sync), onPressed: _loadData, tooltip: 'Refresh'),
      const SizedBox(width: 8),
    ],
  );

  Widget _buildFilters() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          controller: _searchCtrl,
          onChanged: _onSearch,
          style: const TextStyle(color: _SC.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search by item or note...',
            hintStyle: const TextStyle(color: _SC.textSecondary),
            prefixIcon: const Icon(Icons.search, color: _SC.accentPurple, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                icon: const Icon(Icons.clear, size: 18, color: _SC.textSecondary),
                onPressed: () { _searchCtrl.clear(); _onSearch(''); })
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _SC.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _SC.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _SC.accentPurple, width: 1.5)),
          ),
        ),
      ),
      // ── FIX: Wrap in Row with no Spacer inside SingleChildScrollView ──
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(
          children: [
            // Scrollable chips section
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final p in ['All', 'Today', 'Week', 'Month'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(p),
                        selected: _filterPeriod == p && _startDate == null,
                        selectedColor: _SC.accentPurple.withOpacity(0.15),
                        labelStyle: TextStyle(
                            color: _filterPeriod == p && _startDate == null ? _SC.accentPurple : _SC.textSecondary,
                            fontSize: 12,
                            fontWeight: _filterPeriod == p && _startDate == null ? FontWeight.w600 : FontWeight.normal),
                        onSelected: (_) { _clearDateRange(); _setPeriod(p); },
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: _filterPeriod == p && _startDate == null ? _SC.accentPurple : _SC.border)),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: Icon(Icons.date_range, size: 16, color: _startDate != null ? _SC.accentPurple : _SC.textSecondary),
                      label: Text(
                        _startDate != null && _endDate != null
                            ? '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}'
                            : 'Custom Range',
                        style: TextStyle(fontSize: 12, color: _startDate != null ? _SC.accentPurple : _SC.textSecondary),
                      ),
                      onPressed: _selectDateRange,
                      backgroundColor: _startDate != null ? _SC.accentPurple.withOpacity(0.15) : Colors.transparent,
                      side: BorderSide(color: _startDate != null ? _SC.accentPurple : _SC.border),
                    ),
                  ),
                  if (_startDate != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _clearDateRange,
                        color: _SC.accentRed,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                ]),
              ),
            ),
            // Records count badge — outside scroll, always visible
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _SC.accentPurple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _SC.accentPurple.withOpacity(0.2)),
              ),
              child: Text('${_filtered.length} records',
                  style: const TextStyle(color: _SC.accentPurple, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildTransferList() {
    if (_filtered.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.storefront_outlined, size: 48, color: _SC.accentPurple.withOpacity(0.3)),
          const SizedBox(height: 12),
          const Text('No transfers found', style: TextStyle(color: _SC.textSecondary, fontSize: 15)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _filtered.length,
      itemBuilder: (_, i) => _buildTransferTile(_filtered[i]),
    );
  }

  Widget _buildTransferTile(ShopTransfer t) {
    final d = t.transferredAt;
    final dateStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _SC.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _SC.border),
        boxShadow: const [BoxShadow(color: _SC.shadow, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: _SC.accentPurple.withOpacity(0.1), shape: BoxShape.circle),
          child: Center(child: Text(t.qty.toString(), style: const TextStyle(color: _SC.accentPurple, fontWeight: FontWeight.w800, fontSize: 15))),
        ),
        title: Text(t.itemName, style: const TextStyle(color: _SC.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (t.note.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(t.note, style: const TextStyle(color: _SC.textSecondary, fontSize: 12)),
            ],
            const SizedBox(height: 3),
            Text(dateStr, style: const TextStyle(color: _SC.textSecondary, fontSize: 11)),
          ],
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: _SC.accentPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.storefront, color: _SC.accentPurple, size: 12),
              SizedBox(width: 4),
              Text('Shop', style: TextStyle(color: _SC.accentPurple, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _showAddDialog(editing: t),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: _SC.accentAmber.withOpacity(0.12), shape: BoxShape.circle),
              child: const Icon(Icons.edit_outlined, color: _SC.accentAmber, size: 16),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _deleteTransfer(t),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: _SC.accentRed.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.delete_outline, color: _SC.accentRed, size: 16),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildReport() {
    final totals = _itemTotals;
    if (totals.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.bar_chart, size: 48, color: _SC.accentPurple.withOpacity(0.3)),
          const SizedBox(height: 12),
          const Text('No data for selected period', style: TextStyle(color: _SC.textSecondary, fontSize: 15)),
        ]),
      );
    }

    final maxQty = totals.values.reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_SC.accentPurple, _SC.accentLilac], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(children: [
            Icon(Icons.storefront, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text(_SC.shopName, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
        ),
        Row(children: [
          Expanded(child: _summaryCard('Total Transfers', _filtered.length.toString(), Icons.swap_horiz, _SC.accentPurple)),
          const SizedBox(width: 12),
          Expanded(child: _summaryCard('Total Qty', _totalQty.toString(), Icons.inventory_2, _SC.accentTeal)),
          const SizedBox(width: 12),
          Expanded(child: _summaryCard('Unique Items', totals.length.toString(), Icons.category, _SC.accentOrange)),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _SC.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _SC.border),
            boxShadow: const [BoxShadow(color: _SC.shadow, blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.bar_chart, color: _SC.accentPurple, size: 18),
                const SizedBox(width: 8),
                Text('Items Sent to Shop — $_filterPeriod',
                    style: const TextStyle(color: _SC.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
              ]),
              const SizedBox(height: 16),
              ...totals.entries.map((e) {
                final pct = maxQty > 0 ? e.value / maxQty : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(e.key,
                            style: const TextStyle(color: _SC.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Text('${e.value} pcs', style: const TextStyle(color: _SC.accentPurple, fontSize: 13, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: _SC.accentPurple.withOpacity(0.1),
                          valueColor: const AlwaysStoppedAnimation(_SC.accentPurple),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: _SC.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _SC.border),
            boxShadow: const [BoxShadow(color: _SC.shadow, blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(color: Color(0xFFF3E5F5), borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
              child: const Row(children: [
                Expanded(flex: 3, child: Text('Item', style: TextStyle(color: _SC.accentPurple, fontWeight: FontWeight.w700, fontSize: 13))),
                Expanded(child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(color: _SC.accentPurple, fontWeight: FontWeight.w700, fontSize: 13))),
                Expanded(child: Text('Transfers', textAlign: TextAlign.center, style: TextStyle(color: _SC.accentPurple, fontWeight: FontWeight.w700, fontSize: 13))),
              ]),
            ),
            ...totals.entries.toList().asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              final count = _filtered.where((t) => t.itemName == e.key).length;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: i.isEven ? Colors.white : _SC.bgPrimary,
                  border: const Border(top: BorderSide(color: _SC.border)),
                ),
                child: Row(children: [
                  Expanded(flex: 3, child: Text(e.key, style: const TextStyle(color: _SC.textPrimary, fontSize: 13), overflow: TextOverflow.ellipsis)),
                  Expanded(child: Text(e.value.toString(), textAlign: TextAlign.center, style: const TextStyle(color: _SC.accentPurple, fontWeight: FontWeight.w700, fontSize: 13))),
                  Expanded(child: Text(count.toString(), textAlign: TextAlign.center, style: const TextStyle(color: _SC.textSecondary, fontSize: 13))),
                ]),
              );
            }),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF3E5F5),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
                border: Border(top: BorderSide(color: _SC.accentPurple, width: 1.5)),
              ),
              child: Row(children: [
                const Expanded(flex: 3, child: Text('TOTAL', style: TextStyle(color: _SC.accentPurple, fontWeight: FontWeight.w800, fontSize: 13))),
                Expanded(child: Text(_totalQty.toString(), textAlign: TextAlign.center, style: const TextStyle(color: _SC.accentPurple, fontWeight: FontWeight.w800, fontSize: 13))),
                Expanded(child: Text(_filtered.length.toString(), textAlign: TextAlign.center, style: const TextStyle(color: _SC.accentPurple, fontWeight: FontWeight.w800, fontSize: 13))),
              ]),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _SC.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _SC.border),
        boxShadow: const [BoxShadow(color: _SC.shadow, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: _SC.textSecondary, fontSize: 11), textAlign: TextAlign.center),
      ]),
    );
  }
}