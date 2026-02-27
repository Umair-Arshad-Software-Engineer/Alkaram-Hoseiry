import 'package:firebase_database/firebase_database.dart';
import '../models/employee_models.dart';
import 'ledger_service.dart';

class DozenProductionRecord {
  final String id;
  final String employeeId;
  final String employeeName;
  final int dozensProduced;
  final int totalPieces;
  final DateTime startTime;
  final DateTime endTime;
  final int durationInMinutes;
  final double ratePerDozen;
  final double totalEarnings;
  final bool isHours;

  DozenProductionRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.dozensProduced,
    required this.totalPieces,
    required this.startTime,
    required this.endTime,
    required this.durationInMinutes,
    required this.ratePerDozen,
    required this.totalEarnings,
    required this.isHours,
  });

  factory DozenProductionRecord.fromMap(String id, Map<String, dynamic> map) {
    // Handle both old and new data structures
    return DozenProductionRecord(
      id: id,
      employeeId: map['employeeId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      // Check if using old structure (totalDozens) or new structure (dozensProduced)
      dozensProduced: map['dozensProduced'] ?? map['totalDozens'] ?? 0,
      totalPieces: map['totalPieces'] ??
          (map['piecesProduced'] ?? (map['dozensProduced'] ?? 0) * 12),
      startTime: DateTime.parse(map['startTime'] ?? DateTime.now().toIso8601String()),
      endTime: DateTime.parse(map['endTime'] ?? DateTime.now().toIso8601String()),
      durationInMinutes: map['durationInMinutes'] ?? 0,
      ratePerDozen: (map['ratePerDozen'] ?? 0).toDouble(),
      totalEarnings: (map['totalEarnings'] ?? 0).toDouble(),
      isHours: map['isHours'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'dozensProduced': dozensProduced,
      'totalPieces': totalPieces,
      'piecesProduced': totalPieces, // For backward compatibility
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'durationInMinutes': durationInMinutes,
      'ratePerDozen': ratePerDozen,
      'totalEarnings': totalEarnings,
      'isHours': isHours,
      'recordType': 'perdozen',
    };
  }
}

class DozenProductionService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final LedgerService _ledgerService = LedgerService();

  // Use the same path as ProductionServiceRealtime
  DatabaseReference get _productionRecordsRef => _db.child('production_records');
  DatabaseReference get _employeesRef => _db.child('employees');

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // ─── Save Production Entry ─────────────────────────────────
  Future<void> saveProductionEntry({
    required PerDozenEmployee employee,
    required int dozensProduced,
    required double totalEarnings,
    required int totalMinutes,
    required bool isHours,
  }) async {
    try {
      final now = DateTime.now();
      final startTime = now.subtract(Duration(minutes: totalMinutes));
      final totalPieces = dozensProduced * 12;

      final recordId = _productionRecordsRef.child(employee.id).push().key!;

      final record = DozenProductionRecord(
        id: recordId,
        employeeId: employee.id,
        employeeName: employee.name,
        dozensProduced: dozensProduced,
        totalPieces: totalPieces,
        startTime: startTime,
        endTime: now,
        durationInMinutes: totalMinutes,
        ratePerDozen: employee.ratePerDozen,
        totalEarnings: totalEarnings,
        isHours: isHours,
      );

      await _productionRecordsRef
          .child(employee.id)
          .child(recordId)
          .set(record.toMap());

      // Update employee totals
      final currentDozens = await _getCurrentDozensCompleted(employee.id);
      final currentEarnings = await _getCurrentTotalEarnings(employee.id);
      final currentPieces = await _getCurrentTotalPieces(employee.id);

      await _employeesRef.child(employee.id).update({
        'dozensCompleted': currentDozens + dozensProduced,
        'totalEarnings': currentEarnings + totalEarnings,
        'totalPieces': currentPieces + totalPieces,
      });

      // Auto-create credit entry in ledger
      await _ledgerService.addCreditEntry(
        employeeId: employee.id,
        amount: totalEarnings,
        description:
        'Production: $dozensProduced doz @ Rs ${employee.ratePerDozen.toStringAsFixed(2)}/doz (${dozensProduced * 12} pcs)',
        referenceId: recordId,
        date: now,
      );
    } catch (e) {
      print('Error saving dozen production entry: $e');
      rethrow;
    }
  }

  // ─── Delete Record ─────────────────────────────────────────
  Future<void> deleteProductionRecord({
    required String employeeId,
    required DozenProductionRecord record,
  }) async {
    try {
      // Remove the record
      await _productionRecordsRef.child(employeeId).child(record.id).remove();

      // Subtract from employee totals
      final currentDozens = await _getCurrentDozensCompleted(employeeId);
      final currentEarnings = await _getCurrentTotalEarnings(employeeId);
      final currentPieces = await _getCurrentTotalPieces(employeeId);

      await _employeesRef.child(employeeId).update({
        'dozensCompleted': (currentDozens - record.dozensProduced).clamp(0, 999999999).toInt(),
        'totalEarnings': (currentEarnings - record.totalEarnings).clamp(0.0, double.maxFinite),
        'totalPieces': (currentPieces - record.totalPieces).clamp(0, 999999999).toInt(),
      });
    } catch (e) {
      print('Error deleting record: $e');
      rethrow;
    }
  }

  // ─── Update Record ─────────────────────────────────────────
  Future<void> updateProductionRecord({
    required String employeeId,
    required DozenProductionRecord oldRecord,
    required int newDozens,
    required double newTotalEarnings,
    required int newDurationMinutes,
    required double newRatePerDozen,
  }) async {
    try {
      final newTotalPieces = newDozens * 12;

      final updatedRecord = DozenProductionRecord(
        id: oldRecord.id,
        employeeId: oldRecord.employeeId,
        employeeName: oldRecord.employeeName,
        dozensProduced: newDozens,
        totalPieces: newTotalPieces,
        startTime: oldRecord.startTime,
        endTime: oldRecord.endTime,
        durationInMinutes: newDurationMinutes,
        ratePerDozen: newRatePerDozen,
        totalEarnings: newTotalEarnings,
        isHours: oldRecord.isHours,
      );

      await _productionRecordsRef
          .child(employeeId)
          .child(oldRecord.id)
          .set(updatedRecord.toMap());

      // Adjust employee totals by the difference
      final currentDozens = await _getCurrentDozensCompleted(employeeId);
      final currentEarnings = await _getCurrentTotalEarnings(employeeId);
      final currentPieces = await _getCurrentTotalPieces(employeeId);

      final dozenDiff = newDozens - oldRecord.dozensProduced;
      final earningsDiff = newTotalEarnings - oldRecord.totalEarnings;
      final piecesDiff = newTotalPieces - oldRecord.totalPieces;

      await _employeesRef.child(employeeId).update({
        'dozensCompleted': (currentDozens + dozenDiff).clamp(0, 999999999).toInt(),
        'totalEarnings': (currentEarnings + earningsDiff).clamp(0.0, double.maxFinite),
        'totalPieces': (currentPieces + piecesDiff).clamp(0, 999999999).toInt(),
      });
    } catch (e) {
      print('Error updating record: $e');
      rethrow;
    }
  }

  // ─── Stream of Records ─────────────────────────────────────
  Stream<List<DozenProductionRecord>> getEmployeeProductionRecords(String employeeId) {
    return _productionRecordsRef.child(employeeId).onValue.map((event) {
      final List<DozenProductionRecord> records = [];
      final data = event.snapshot.value;

      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            try {
              // Only include records that are of type 'perdozen' or have dozens-related fields
              final recordType = value['recordType'];
              final hasDozenFields = value['dozensProduced'] != null ||
                  value['totalDozens'] != null ||
                  value['ratePerDozen'] != null;

              if (recordType == 'perdozen' || hasDozenFields) {
                final record = DozenProductionRecord.fromMap(
                    key.toString(), Map<String, dynamic>.from(value));
                records.add(record);
              }
            } catch (e) {
              print('Error parsing record $key: $e');
            }
          }
        });
      }

      records.sort((a, b) => b.endTime.compareTo(a.endTime));
      return records;
    });
  }

  // ─── Get Stats ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getEmployeeProductionStats(String employeeId) async {
    try {
      final snapshot = await _productionRecordsRef.child(employeeId).get();
      final data = snapshot.value;

      if (data == null || data is! Map) {
        return {
          'totalDozens': 0,
          'totalPieces': 0,
          'totalEarnings': 0.0,
          'totalSessions': 0,
        };
      }

      int totalDozens = 0;
      int totalPieces = 0;
      double totalEarnings = 0.0;
      int sessionCount = 0;

      data.forEach((key, value) {
        if (value is Map) {
          final recordType = value['recordType'];
          final hasDozenFields = value['dozensProduced'] != null ||
              value['totalDozens'] != null;

          if (recordType == 'perdozen' || hasDozenFields) {
            sessionCount++;
            try {
              final record = DozenProductionRecord.fromMap(
                  key.toString(), Map<String, dynamic>.from(value));
              totalDozens += record.dozensProduced;
              totalPieces += record.totalPieces;
              totalEarnings += record.totalEarnings;
            } catch (e) {
              print('Error processing record $key: $e');
            }
          }
        }
      });

      return {
        'totalDozens': totalDozens,
        'totalPieces': totalPieces,
        'totalEarnings': totalEarnings,
        'totalSessions': sessionCount,
      };
    } catch (e) {
      print('Error getting stats: $e');
      return {
        'totalDozens': 0,
        'totalPieces': 0,
        'totalEarnings': 0.0,
        'totalSessions': 0,
      };
    }
  }

  // ─── Helper Methods ────────────────────────────────────────
  Future<int> _getCurrentDozensCompleted(String employeeId) async {
    final snapshot = await _employeesRef.child(employeeId).child('dozensCompleted').get();
    return _toInt(snapshot.value);
  }

  Future<int> _getCurrentTotalPieces(String employeeId) async {
    final snapshot = await _employeesRef.child(employeeId).child('totalPieces').get();
    return _toInt(snapshot.value);
  }

  Future<double> _getCurrentTotalEarnings(String employeeId) async {
    final snapshot = await _employeesRef.child(employeeId).child('totalEarnings').get();
    return _toDouble(snapshot.value);
  }
}