import 'package:firebase_database/firebase_database.dart';
import '../models/employee_models.dart';

// ─────────────────────────────────────────────────────────────
//  Ledger Entry Model
// ─────────────────────────────────────────────────────────────
enum LedgerEntryType { credit, debit }

class LedgerEntry {
  final String id;
  final String employeeId;
  final LedgerEntryType type;
  final double amount;
  final String description;
  final DateTime date;
  final String? referenceId; // production record id if auto-linked

  LedgerEntry({
    required this.id,
    required this.employeeId,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    this.referenceId,
  });

  bool get isCredit => type == LedgerEntryType.credit;

  Map<String, dynamic> toMap() => {
    'id': id,
    'employeeId': employeeId,
    'type': type.name, // 'credit' or 'debit'
    'amount': amount,
    'description': description,
    'date': date.toIso8601String(),
    if (referenceId != null) 'referenceId': referenceId,
  };

  factory LedgerEntry.fromMap(String id, Map<String, dynamic> map) =>
      LedgerEntry(
        id: id,
        employeeId: map['employeeId'] ?? '',
        type: map['type'] == 'credit'
            ? LedgerEntryType.credit
            : LedgerEntryType.debit,
        amount: _toDouble(map['amount']),
        description: map['description'] ?? '',
        date: DateTime.parse(
            map['date'] ?? DateTime.now().toIso8601String()),
        referenceId: map['referenceId'],
      );

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}

// ─────────────────────────────────────────────────────────────
//  Ledger Service
// ─────────────────────────────────────────────────────────────
class LedgerService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  DatabaseReference _ledgerRef(String employeeId) =>
      _db.child('ledger').child(employeeId);

  // ─── Add credit (production earned) ────────────────────────
  Future<void> addCreditEntry({
    required String employeeId,
    required double amount,
    required String description,
    String? referenceId,
    DateTime? date,
  }) async {
    final ref = _ledgerRef(employeeId).push();
    final entry = LedgerEntry(
      id: ref.key!,
      employeeId: employeeId,
      type: LedgerEntryType.credit,
      amount: amount,
      description: description,
      date: date ?? DateTime.now(),
      referenceId: referenceId,
    );
    await ref.set(entry.toMap());
  }

  // ─── Add debit (payment made) ───────────────────────────────
  Future<void> addDebitEntry({
    required String employeeId,
    required double amount,
    required String description,
    DateTime? date,
  }) async {
    final ref = _ledgerRef(employeeId).push();
    final entry = LedgerEntry(
      id: ref.key!,
      employeeId: employeeId,
      type: LedgerEntryType.debit,
      amount: amount,
      description: description,
      date: date ?? DateTime.now(),
    );
    await ref.set(entry.toMap());
  }

  // ─── Delete entry ───────────────────────────────────────────
  Future<void> deleteEntry(String employeeId, String entryId) async {
    await _ledgerRef(employeeId).child(entryId).remove();
  }

  // ─── Stream all entries for employee (sorted by date desc) ──
  Stream<List<LedgerEntry>> getEntries(String employeeId) {
    return _ledgerRef(employeeId).onValue.map((event) {
      final data = event.snapshot.value;
      final List<LedgerEntry> entries = [];

      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            try {
              entries.add(LedgerEntry.fromMap(
                  key.toString(), Map<String, dynamic>.from(value)));
            } catch (e) {
              print('Error parsing ledger entry $key: $e');
            }
          }
        });
      }

      entries.sort((a, b) => b.date.compareTo(a.date));
      return entries;
    });
  }

  // ─── Balance summary ────────────────────────────────────────
  Future<Map<String, double>> getBalance(String employeeId) async {
    final snapshot = await _ledgerRef(employeeId).get();
    double totalCredit = 0;
    double totalDebit = 0;

    if (snapshot.value != null && snapshot.value is Map) {
      (snapshot.value as Map).forEach((key, value) {
        if (value is Map) {
          final type = value['type'];
          final amount = LedgerEntry._toDouble(value['amount']);
          if (type == 'credit') {
            totalCredit += amount;
          } else {
            totalDebit += amount;
          }
        }
      });
    }

    return {
      'totalCredit': totalCredit,
      'totalDebit': totalDebit,
      'balance': totalCredit - totalDebit,
    };
  }
}