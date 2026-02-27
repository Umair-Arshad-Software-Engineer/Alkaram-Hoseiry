import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  Design Tokens
// ─────────────────────────────────────────────────────────────
class _C {
  static const bgPrimary     = Color(0xFFF8FAFC);
  static const bgCard        = Color(0xFFFFFFFF);
  static const accentOrange  = Color(0xFFFF8A65);
  static const accentAmber   = Color(0xFFFFB74D);
  static const accentTeal    = Color(0xFF26A69A);
  static const accentGreen   = Color(0xFF66BB6A);
  static const accentPurple  = Color(0xFFAB47BC);
  static const accentBlue    = Color(0xFF42A5F5);
  static const accentRed     = Color(0xFFEF5350);
  static const textPrimary   = Color(0xFF2C3E50);
  static const textSecondary = Color(0xFF7F8C8D);
  static const border        = Color(0xFFE2E8F0);
  static const shadow        = Color(0x1A000000);
}

// ─────────────────────────────────────────────────────────────
//  Transfer Model
// ─────────────────────────────────────────────────────────────
class GodownTransfer {
  final String   id;
  final String   itemName;
  final int      qty;
  final String   note;
  final DateTime transferredAt;

  GodownTransfer({
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
  };

  factory GodownTransfer.fromMap(String id, Map<String, dynamic> m) =>
      GodownTransfer(
        id:            id,
        itemName:      m['itemName'] ?? '',
        qty:           (m['qty'] ?? 0) is int
            ? m['qty']
            : int.tryParse(m['qty'].toString()) ?? 0,
        note:          m['note'] ?? '',
        transferredAt: DateTime.tryParse(m['transferredAt'] ?? '') ??
            DateTime.now(),
      );
}

// ─────────────────────────────────────────────────────────────
//  Row entry used inside the dialog table
// ─────────────────────────────────────────────────────────────
class _TransferRow {
  final TextEditingController itemCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController noteCtrl;

  _TransferRow()
      : itemCtrl = TextEditingController(),
        qtyCtrl  = TextEditingController(),
        noteCtrl = TextEditingController();

  void dispose() {
    itemCtrl.dispose();
    qtyCtrl.dispose();
    noteCtrl.dispose();
  }

  bool get isEmpty =>
      itemCtrl.text.trim().isEmpty && qtyCtrl.text.trim().isEmpty;
}

// ─────────────────────────────────────────────────────────────
//  Godown Transfer Page
// ─────────────────────────────────────────────────────────────
class GodownTransferPage extends StatefulWidget {
  const GodownTransferPage({super.key});

  @override
  State<GodownTransferPage> createState() => _GodownTransferPageState();
}

class _GodownTransferPageState extends State<GodownTransferPage>
    with SingleTickerProviderStateMixin {

  final _transfersRef = FirebaseDatabase.instance.ref('godown_transfers');
  final _itemsRef     = FirebaseDatabase.instance.ref('items');

  List<GodownTransfer> _allTransfers = [];
  List<GodownTransfer> _filtered     = [];
  List<String>         _itemNames    = [];
  bool                 _isLoading    = true;
  String               _searchQuery  = '';
  String               _filterPeriod = 'All';

  late TabController   _tabCtrl;
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

  // ── Load data ───────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _transfersRef.get(),
        _itemsRef.get(),
      ]);

      final List<GodownTransfer> transfers = [];
      if (results[0].value != null && results[0].value is Map) {
        for (final e in (results[0].value as Map).entries) {
          try {
            transfers.add(GodownTransfer.fromMap(
                e.key.toString(),
                Map<String, dynamic>.from(e.value as Map)));
          } catch (_) {}
        }
      }
      transfers.sort(
              (a, b) => b.transferredAt.compareTo(a.transferredAt));

      final List<String> names = [];
      if (results[1].value != null && results[1].value is Map) {
        for (final e in (results[1].value as Map).values) {
          final name = (e as Map)['name']?.toString() ?? '';
          if (name.isNotEmpty) names.add(name);
        }
        names.sort();
      }

      setState(() {
        _allTransfers = transfers;
        _filtered     = _applyFilters(transfers);
        _itemNames    = names;
        _isLoading    = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _snack('Error loading data: $e', color: _C.accentRed);
    }
  }

  // ── Filters ─────────────────────────────────────────────────
  List<GodownTransfer> _applyFilters(List<GodownTransfer> src) {
    final now = DateTime.now();
    return src.where((t) {
      bool inPeriod = true;
      if (_filterPeriod == 'Today') {
        inPeriod = t.transferredAt.year  == now.year  &&
            t.transferredAt.month == now.month &&
            t.transferredAt.day   == now.day;
      } else if (_filterPeriod == 'Week') {
        inPeriod = now.difference(t.transferredAt).inDays <= 7;
      } else if (_filterPeriod == 'Month') {
        inPeriod = t.transferredAt.year  == now.year &&
            t.transferredAt.month == now.month;
      }
      final q = _searchQuery.toLowerCase();
      return inPeriod &&
          (q.isEmpty ||
              t.itemName.toLowerCase().contains(q) ||
              t.note.toLowerCase().contains(q));
    }).toList();
  }

  void _onSearch(String q) => setState(() {
    _searchQuery = q.toLowerCase();
    _filtered    = _applyFilters(_allTransfers);
  });

  void _setPeriod(String p) => setState(() {
    _filterPeriod = p;
    _filtered     = _applyFilters(_allTransfers);
  });

  // ── Add Dialog — table layout ────────────────────────────────
  Future<void> _showAddDialog() async {
    final rows     = List.generate(3, (_) => _TransferRow());
    final noteCtrl = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {

          // Compact inline text field for table cells
          Widget cell(
              TextEditingController ctrl,
              String hint, {
                bool numeric = false,
                FocusNode? focusNode,
              }) =>
              TextField(
                controller: ctrl,
                focusNode: focusNode,
                keyboardType: numeric
                    ? TextInputType.number
                    : TextInputType.text,
                style: const TextStyle(
                    color: _C.textPrimary, fontSize: 12),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(
                      color: _C.textSecondary, fontSize: 11),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                      borderSide:
                      const BorderSide(color: _C.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                      borderSide:
                      const BorderSide(color: _C.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                      borderSide: const BorderSide(
                          color: _C.accentTeal, width: 1.2)),
                ),
              );

          // One data row
          Widget dataRow(int index, _TransferRow row) =>
              Container(
                decoration: BoxDecoration(
                  color: index.isEven
                      ? Colors.white
                      : _C.bgPrimary,
                  border: const Border(
                      top: BorderSide(color: _C.border)),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                child: Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.center,
                  children: [
                    // Row number
                    SizedBox(
                      width: 24,
                      child: Text('${index + 1}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: _C.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 6),

                    // Item — autocomplete
                    Expanded(
                      flex: 4,
                      child: Autocomplete<String>(
                        optionsBuilder: (v) => _itemNames
                            .where((n) => n.toLowerCase()
                            .contains(v.text.toLowerCase()))
                            .toList(),
                        onSelected: (s) {
                          row.itemCtrl.text = s;
                          setS(() {});
                        },
                        fieldViewBuilder:
                            (ctx2, autoCtrl, fn, onSubmit) {
                          autoCtrl.text = row.itemCtrl.text;
                          autoCtrl.addListener(
                                  () => row.itemCtrl.text =
                                  autoCtrl.text);
                          return cell(autoCtrl, 'Item name',
                              focusNode: fn);
                        },
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Qty
                    Expanded(
                        flex: 2,
                        child: cell(row.qtyCtrl, 'Qty',
                            numeric: true)),
                    const SizedBox(width: 6),

                    // Row note
                    Expanded(
                        flex: 3,
                        child: cell(row.noteCtrl, 'Note')),
                    const SizedBox(width: 4),

                    // Remove row
                    GestureDetector(
                      onTap: rows.length > 1
                          ? () => setS(
                              () => rows.removeAt(index))
                          : null,
                      child: Icon(
                          Icons.remove_circle_outline,
                          size: 18,
                          color: rows.length > 1
                              ? _C.accentRed
                              : _C.border),
                    ),
                  ],
                ),
              );

          // Live count of non-empty rows
          final validCount =
              rows.where((r) => !r.isEmpty).length;

          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 28),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 700),
              decoration: BoxDecoration(
                  color: _C.bgCard,
                  borderRadius: BorderRadius.circular(20)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // ── Teal header ───────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(
                        20, 18, 12, 14),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _C.accentTeal,
                          Color(0xFF80CBC4)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.local_shipping,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text('Factory → Godown',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16)),
                          Text(
                              'Fill rows — leave blank to skip',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11)),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 20),
                        onPressed: () {
                          for (final r in rows) r.dispose();
                          noteCtrl.dispose();
                          Navigator.pop(ctx);
                        },
                      ),
                    ]),
                  ),

                  // ── Scrollable body ────────────────────────
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                          12, 14, 12, 0),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                        children: [

                          // ── Table ─────────────────────────
                          Container(
                            decoration: BoxDecoration(
                                border: Border.all(
                                    color: _C.border),
                                borderRadius:
                                BorderRadius.circular(12)),
                            child: ClipRRect(
                              borderRadius:
                              BorderRadius.circular(12),
                              child: Column(children: [

                                // Header row
                                Container(
                                  color: const Color(
                                      0xFFE0F2F1),
                                  padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 9),
                                  child: Row(children: [
                                    // # column
                                    const SizedBox(width: 24),
                                    const SizedBox(width: 6),
                                    _hCell('Item Name',
                                        flex: 4),
                                    const SizedBox(width: 6),
                                    _hCell('Qty',
                                        flex: 2,
                                        align: TextAlign
                                            .center),
                                    const SizedBox(width: 6),
                                    _hCell('Row Note',
                                        flex: 3),
                                    // space for delete icon
                                    const SizedBox(width: 22),
                                  ]),
                                ),

                                // Data rows
                                ...rows
                                    .asMap()
                                    .entries
                                    .map((e) => dataRow(
                                    e.key, e.value)),

                                // ＋ Add row
                                GestureDetector(
                                  onTap: () => setS(() =>
                                      rows.add(
                                          _TransferRow())),
                                  child: Container(
                                    color: _C.bgPrimary,
                                    padding:
                                    const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment
                                          .center,
                                      children: [
                                        Icon(
                                            Icons
                                                .add_circle_outline,
                                            color: _C
                                                .accentTeal
                                                .withOpacity(
                                                0.7),
                                            size: 16),
                                        const SizedBox(
                                            width: 6),
                                        Text('Add Row',
                                            style: TextStyle(
                                                color: _C
                                                    .accentTeal
                                                    .withOpacity(
                                                    0.8),
                                                fontSize: 12,
                                                fontWeight:
                                                FontWeight
                                                    .w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Shared transfer note
                          TextField(
                            controller: noteCtrl,
                            maxLines: 2,
                            style: const TextStyle(
                                color: _C.textPrimary,
                                fontSize: 13),
                            decoration: InputDecoration(
                              labelText:
                              'Transfer Note (optional — applies to all)',
                              labelStyle: const TextStyle(
                                  color: _C.textSecondary,
                                  fontSize: 12),
                              prefixIcon: const Icon(
                                  Icons.note_outlined,
                                  color: _C.accentTeal,
                                  size: 18),
                              contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12),
                              filled: true,
                              fillColor: _C.bgPrimary,
                              border: OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(
                                      10),
                                  borderSide: const BorderSide(
                                      color: _C.border)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(
                                      10),
                                  borderSide: const BorderSide(
                                      color: _C.border)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(
                                      10),
                                  borderSide: const BorderSide(
                                      color: _C.accentTeal,
                                      width: 1.5)),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Row count badge
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4),
                              decoration: BoxDecoration(
                                color: _C.accentTeal
                                    .withOpacity(0.08),
                                borderRadius:
                                BorderRadius.circular(6),
                                border: Border.all(
                                    color: _C.accentTeal
                                        .withOpacity(0.2)),
                              ),
                              child: Text(
                                '$validCount / ${rows.length} row${rows.length == 1 ? '' : 's'} filled',
                                style: const TextStyle(
                                    color: _C.accentTeal,
                                    fontSize: 11,
                                    fontWeight:
                                    FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Footer buttons ─────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        16, 10, 16, 16),
                    child: Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            for (final r in rows) r.dispose();
                            noteCtrl.dispose();
                            Navigator.pop(ctx);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: _C.border),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(
                                    10)),
                            padding:
                            const EdgeInsets.symmetric(
                                vertical: 13),
                          ),
                          child: const Text('Cancel',
                              style: TextStyle(
                                  color:
                                  _C.textSecondary)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _C.accentTeal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(
                                    10)),
                            padding:
                            const EdgeInsets.symmetric(
                                vertical: 13),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.check,
                              size: 18),
                          label: Text(
                            'Save $validCount Transfer${validCount == 1 ? '' : 's'}',
                            style: const TextStyle(
                                fontWeight:
                                FontWeight.w600),
                          ),
                          onPressed: () async {
                            // Collect & validate filled rows
                            final valid = <_TransferRow>[];
                            for (int i = 0;
                            i < rows.length;
                            i++) {
                              final r = rows[i];
                              if (r.isEmpty) continue;
                              if (r.itemCtrl.text
                                  .trim()
                                  .isEmpty) {
                                _snack(
                                    'Row ${i + 1}: Item name required',
                                    color: _C.accentRed);
                                return;
                              }
                              final qty = int.tryParse(
                                  r.qtyCtrl.text
                                      .trim()) ??
                                  0;
                              if (qty <= 0) {
                                _snack(
                                    'Row ${i + 1}: Enter valid quantity',
                                    color: _C.accentRed);
                                return;
                              }
                              valid.add(r);
                            }
                            if (valid.isEmpty) {
                              _snack(
                                  'Fill at least one row',
                                  color: _C.accentRed);
                              return;
                            }

                            final sharedNote =
                            noteCtrl.text.trim();
                            Navigator.pop(ctx);
                            _showSavingOverlay();

                            try {
                              final now = DateTime.now();
                              final List<GodownTransfer>
                              saved = [];

                              for (final r in valid) {
                                final rowNote = r.noteCtrl
                                    .text
                                    .trim();
                                final t = GodownTransfer(
                                  id: '',
                                  itemName: r.itemCtrl.text
                                      .trim(),
                                  qty: int.parse(r.qtyCtrl
                                      .text
                                      .trim()),
                                  note: rowNote.isNotEmpty
                                      ? rowNote
                                      : sharedNote,
                                  transferredAt: now,
                                );
                                final ref =
                                await _transfersRef
                                    .push();
                                await ref.set(t.toMap());
                                saved.add(GodownTransfer(
                                  id: ref.key!,
                                  itemName: t.itemName,
                                  qty: t.qty,
                                  note: t.note,
                                  transferredAt:
                                  t.transferredAt,
                                ));
                              }

                              _allTransfers.insertAll(
                                  0,
                                  saved.reversed.toList());
                              setState(() {
                                _filtered = _applyFilters(
                                    _allTransfers);
                              });

                              for (final r in rows) {
                                r.dispose();
                              }
                              noteCtrl.dispose();

                              _hideOverlay();
                              _snack(
                                'Saved ${saved.length} transfer${saved.length == 1 ? '' : 's'}!',
                                color: _C.accentGreen,
                              );
                            } catch (e) {
                              _hideOverlay();
                              _snack('Error: $e',
                                  color: _C.accentRed);
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

  // Shared header cell builder (used inside StatefulBuilder scope)
  static Widget _hCell(String label,
      {int flex = 1, TextAlign align = TextAlign.left}) =>
      Expanded(
        flex: flex,
        child: Text(label,
            textAlign: align,
            style: const TextStyle(
                color: _C.accentTeal,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
      );

  // ── Delete ───────────────────────────────────────────────────
  Future<void> _deleteTransfer(GodownTransfer t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Transfer',
            style: TextStyle(
                color: _C.textPrimary,
                fontWeight: FontWeight.w600)),
        content: Text(
            'Delete transfer of ${t.qty} × "${t.itemName}"?',
            style: const TextStyle(color: _C.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: _C.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(
                      color: _C.accentRed,
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (ok != true) return;
    await _transfersRef.child(t.id).remove();
    setState(() {
      _allTransfers.removeWhere((x) => x.id == t.id);
      _filtered = _applyFilters(_allTransfers);
    });
    _snack('Deleted', color: _C.accentRed);
  }

  // ── Report helpers ───────────────────────────────────────────
  Map<String, int> get _itemTotals {
    final map = <String, int>{};
    for (final t in _filtered) {
      map[t.itemName] = (map[t.itemName] ?? 0) + t.qty;
    }
    return Map.fromEntries(map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)));
  }

  int get _totalQty =>
      _filtered.fold(0, (sum, t) => sum + t.qty);

  // ── Overlay / snack ──────────────────────────────────────────
  OverlayEntry? _overlayEntry;

  void _showSavingOverlay() {
    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: Container(
          color: Colors.black26,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: _C.bgCard,
                  borderRadius: BorderRadius.circular(16)),
              child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                        color: _C.accentTeal),
                    SizedBox(height: 12),
                    Text('Saving...',
                        style: TextStyle(
                            color: _C.textPrimary)),
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

  void _snack(String msg, {Color color = _C.accentGreen}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(color: _C.textPrimary)),
      backgroundColor: _C.bgCard,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withOpacity(0.5)),
      ),
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
      backgroundColor: _C.bgPrimary,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(
              color: _C.accentTeal))
          : Column(children: [
        _buildFilters(),
        TabBar(
          controller: _tabCtrl,
          labelColor: _C.accentTeal,
          unselectedLabelColor: _C.textSecondary,
          indicatorColor: _C.accentTeal,
          tabs: const [
            Tab(
                icon: Icon(Icons.list_alt),
                text: 'Transfers'),
            Tab(
                icon: Icon(Icons.bar_chart),
                text: 'Report'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildTransferList(),
              _buildReport(),
            ],
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: _C.accentTeal,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add),
        label: const Text('New Transfer',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    flexibleSpace: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.accentTeal, Color(0xFF80CBC4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    ),
    title: const Text('Godown Transfers'),
    titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700),
    iconTheme: const IconThemeData(color: Colors.white),
    elevation: 0,
    actions: [
      IconButton(
          icon: const Icon(Icons.sync),
          onPressed: _loadData,
          tooltip: 'Refresh'),
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
          style:
          const TextStyle(color: _C.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search by item or note...',
            hintStyle:
            const TextStyle(color: _C.textSecondary),
            prefixIcon: const Icon(Icons.search,
                color: _C.accentTeal, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                icon: const Icon(Icons.clear,
                    size: 18, color: _C.textSecondary),
                onPressed: () {
                  _searchCtrl.clear();
                  _onSearch('');
                })
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
            const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                const BorderSide(color: _C.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                const BorderSide(color: _C.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: _C.accentTeal, width: 1.5)),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(children: [
          for (final p in ['All', 'Today', 'Week', 'Month'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(p),
                selected: _filterPeriod == p,
                selectedColor:
                _C.accentTeal.withOpacity(0.15),
                labelStyle: TextStyle(
                    color: _filterPeriod == p
                        ? _C.accentTeal
                        : _C.textSecondary,
                    fontSize: 12,
                    fontWeight: _filterPeriod == p
                        ? FontWeight.w600
                        : FontWeight.normal),
                onSelected: (_) => _setPeriod(p),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                        color: _filterPeriod == p
                            ? _C.accentTeal
                            : _C.border)),
              ),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _C.accentTeal.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: _C.accentTeal.withOpacity(0.2)),
            ),
            child: Text('${_filtered.length} records',
                style: const TextStyle(
                    color: _C.accentTeal,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildTransferList() {
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping_outlined,
                size: 48,
                color: _C.accentTeal.withOpacity(0.3)),
            const SizedBox(height: 12),
            const Text('No transfers found',
                style: TextStyle(
                    color: _C.textSecondary, fontSize: 15)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _filtered.length,
      itemBuilder: (_, i) =>
          _buildTransferTile(_filtered[i]),
    );
  }

  Widget _buildTransferTile(GodownTransfer t) {
    final d = t.transferredAt;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _C.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
        boxShadow: const [
          BoxShadow(
              color: _C.shadow,
              blurRadius: 4,
              offset: Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 10),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              color: _C.accentTeal.withOpacity(0.1),
              shape: BoxShape.circle),
          child: Center(
              child: Text(t.qty.toString(),
                  style: const TextStyle(
                      color: _C.accentTeal,
                      fontWeight: FontWeight.w800,
                      fontSize: 15))),
        ),
        title: Text(t.itemName,
            style: const TextStyle(
                color: _C.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (t.note.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(t.note,
                  style: const TextStyle(
                      color: _C.textSecondary, fontSize: 12)),
            ],
            const SizedBox(height: 3),
            Text(dateStr,
                style: const TextStyle(
                    color: _C.textSecondary, fontSize: 11)),
          ],
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: _C.accentTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.arrow_forward,
                  color: _C.accentTeal, size: 12),
              SizedBox(width: 4),
              Text('Godown',
                  style: TextStyle(
                      color: _C.accentTeal,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _deleteTransfer(t),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: _C.accentRed.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.delete_outline,
                  color: _C.accentRed, size: 16),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart,
                size: 48,
                color: _C.accentTeal.withOpacity(0.3)),
            const SizedBox(height: 12),
            const Text('No data for selected period',
                style: TextStyle(
                    color: _C.textSecondary, fontSize: 15)),
          ],
        ),
      );
    }

    final maxQty = totals.values.reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Row(children: [
          Expanded(
              child: _summaryCard('Total Transfers',
                  _filtered.length.toString(),
                  Icons.swap_horiz, _C.accentTeal)),
          const SizedBox(width: 12),
          Expanded(
              child: _summaryCard('Total Qty',
                  _totalQty.toString(),
                  Icons.inventory_2, _C.accentPurple)),
          const SizedBox(width: 12),
          Expanded(
              child: _summaryCard('Unique Items',
                  totals.length.toString(),
                  Icons.category, _C.accentOrange)),
        ]),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.border),
            boxShadow: const [
              BoxShadow(
                  color: _C.shadow,
                  blurRadius: 6,
                  offset: Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.bar_chart,
                    color: _C.accentTeal, size: 18),
                const SizedBox(width: 8),
                Text('Items Transferred — $_filterPeriod',
                    style: const TextStyle(
                        color: _C.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
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
                        Expanded(
                            child: Text(e.key,
                                style: const TextStyle(
                                    color: _C.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Text('${e.value} pcs',
                            style: const TextStyle(
                                color: _C.accentTeal,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor:
                          _C.accentTeal.withOpacity(0.1),
                          valueColor:
                          const AlwaysStoppedAnimation(
                              _C.accentTeal),
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
            color: _C.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.border),
            boxShadow: const [
              BoxShadow(
                  color: _C.shadow,
                  blurRadius: 6,
                  offset: Offset(0, 2))
            ],
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFE0F2F1),
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(14)),
              ),
              child: const Row(children: [
                Expanded(
                    flex: 3,
                    child: Text('Item',
                        style: TextStyle(
                            color: _C.accentTeal,
                            fontWeight: FontWeight.w700,
                            fontSize: 13))),
                Expanded(
                    child: Text('Qty',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: _C.accentTeal,
                            fontWeight: FontWeight.w700,
                            fontSize: 13))),
                Expanded(
                    child: Text('Transfers',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: _C.accentTeal,
                            fontWeight: FontWeight.w700,
                            fontSize: 13))),
              ]),
            ),
            ...totals.entries.toList().asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              final count =
                  _filtered.where((t) => t.itemName == e.key).length;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: i.isEven ? Colors.white : _C.bgPrimary,
                  border:
                  const Border(top: BorderSide(color: _C.border)),
                ),
                child: Row(children: [
                  Expanded(
                      flex: 3,
                      child: Text(e.key,
                          style: const TextStyle(
                              color: _C.textPrimary, fontSize: 13),
                          overflow: TextOverflow.ellipsis)),
                  Expanded(
                      child: Text(e.value.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: _C.accentTeal,
                              fontWeight: FontWeight.w700,
                              fontSize: 13))),
                  Expanded(
                      child: Text(count.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: _C.textSecondary,
                              fontSize: 13))),
                ]),
              );
            }),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFE0F2F1),
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(14)),
                border: Border(
                    top: BorderSide(
                        color: _C.accentTeal, width: 1.5)),
              ),
              child: Row(children: [
                const Expanded(
                    flex: 3,
                    child: Text('TOTAL',
                        style: TextStyle(
                            color: _C.accentTeal,
                            fontWeight: FontWeight.w800,
                            fontSize: 13))),
                Expanded(
                    child: Text(_totalQty.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: _C.accentTeal,
                            fontWeight: FontWeight.w800,
                            fontSize: 13))),
                Expanded(
                    child: Text(_filtered.length.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: _C.accentTeal,
                            fontWeight: FontWeight.w800,
                            fontSize: 13))),
              ]),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _summaryCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
        boxShadow: const [
          BoxShadow(
              color: _C.shadow,
              blurRadius: 4,
              offset: Offset(0, 2))
        ],
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                color: _C.textSecondary, fontSize: 11),
            textAlign: TextAlign.center),
      ]),
    );
  }
}