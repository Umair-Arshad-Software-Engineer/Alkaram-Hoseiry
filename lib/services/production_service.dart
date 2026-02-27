import 'package:firebase_database/firebase_database.dart';
import '../models/production_record.dart';
import '../models/employee_models.dart';
import 'ledger_service.dart';

class ProductionServiceRealtime {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final LedgerService _ledgerService = LedgerService();

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

  // ─── Save ───────────────────────────────────────────────────
  Future<void> saveProductionEntries({
    required PerPieceEmployee employee,
    required int totalPieces,
    required double totalEarnings,
    required int totalMinutes,
    required bool isHours, // ← NEW
  })
  async {
    try {
      final now = DateTime.now();
      final startTime = now.subtract(Duration(minutes: totalMinutes));
      final piecesPerHour =
      totalMinutes > 0 ? (totalPieces / totalMinutes) * 60.0 : 0.0;

      final recordId = _productionRecordsRef.child(employee.id).push().key!;

      final record = ProductionRecord(
        id: recordId,
        employeeId: employee.id,
        employeeName: employee.name,
        piecesProduced: totalPieces,
        startTime: startTime,
        endTime: now,
        durationInMinutes: totalMinutes,
        ratePerPiece: employee.ratePerPiece,
        totalEarnings: totalEarnings,
        piecesPerHour: piecesPerHour,
        isHours: isHours, // ← NEW
      );

      await _productionRecordsRef
          .child(employee.id)
          .child(recordId)
          .set(record.toMap());

      final currentPieces = await _getCurrentPiecesCompleted(employee.id);
      final currentEarnings = await _getCurrentTotalEarnings(employee.id);

      await _employeesRef.child(employee.id).update({
        'piecesCompleted': currentPieces + totalPieces,
        'totalEarnings': currentEarnings + totalEarnings,
      });

      // Auto-create credit entry in ledger
      await _ledgerService.addCreditEntry(
        employeeId: employee.id,
        amount: totalEarnings,
        description:
        'Production: $totalPieces pcs @ Rs ${employee.ratePerPiece.toStringAsFixed(2)}/pc',
        referenceId: recordId,
        date: now,
      );
    } catch (e) {
      print('Error saving production entries: $e');
      rethrow;
    }
  }

  // ─── Delete ─────────────────────────────────────────────────
  Future<void> deleteProductionRecord({
    required String employeeId,
    required ProductionRecord record,
  })
  async {
    try {
      // Remove the record
      await _productionRecordsRef.child(employeeId).child(record.id).remove();

      // Subtract from employee totals
      final currentPieces = await _getCurrentPiecesCompleted(employeeId);
      final currentEarnings = await _getCurrentTotalEarnings(employeeId);

      await _employeesRef.child(employeeId).update({
        'piecesCompleted':
        (currentPieces - record.piecesProduced).clamp(0, double.maxFinite).toInt(),
        'totalEarnings':
        (currentEarnings - record.totalEarnings).clamp(0.0, double.maxFinite),
      });
    } catch (e) {
      print('Error deleting record: $e');
      rethrow;
    }
  }

  // ─── Edit ───────────────────────────────────────────────────
  Future<void> updateProductionRecord({
    required String employeeId,
    required ProductionRecord oldRecord,
    required int newPieces,
    required double newTotalEarnings,
    required int newDurationMinutes,
    required double newRatePerPiece,
  })
  async {
    try {
      final piecesPerHour = newDurationMinutes > 0
          ? (newPieces / newDurationMinutes) * 60.0
          : 0.0;

      final updatedRecord = ProductionRecord(
        id: oldRecord.id,
        employeeId: oldRecord.employeeId,
        employeeName: oldRecord.employeeName,
        piecesProduced: newPieces,
        startTime: oldRecord.startTime,
        endTime: oldRecord.endTime,
        durationInMinutes: newDurationMinutes,
        ratePerPiece: newRatePerPiece,
        totalEarnings: newTotalEarnings,
        piecesPerHour: piecesPerHour,
      );

      await _productionRecordsRef
          .child(employeeId)
          .child(oldRecord.id)
          .set(updatedRecord.toMap());

      // Adjust employee totals by the difference
      final currentPieces = await _getCurrentPiecesCompleted(employeeId);
      final currentEarnings = await _getCurrentTotalEarnings(employeeId);

      final pieceDiff = newPieces - oldRecord.piecesProduced;
      final earningsDiff = newTotalEarnings - oldRecord.totalEarnings;

      await _employeesRef.child(employeeId).update({
        'piecesCompleted': (currentPieces + pieceDiff).clamp(0, 999999999),
        'totalEarnings': (currentEarnings + earningsDiff).clamp(0.0, double.maxFinite),
      });
    } catch (e) {
      print('Error updating record: $e');
      rethrow;
    }
  }

  // ─── Streams ────────────────────────────────────────────────
  Stream<List<ProductionRecord>> getEmployeeProductionRecords(String employeeId) {
    return _productionRecordsRef.child(employeeId).onValue.map((event) {
      final List<ProductionRecord> records = [];
      final data = event.snapshot.value;

      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            try {
              final record = ProductionRecord.fromMap(
                  key.toString(), Map<String, dynamic>.from(value));
              records.add(record);
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

  // ─── Stats ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> getEmployeeProductionStats(String employeeId) async {
    try {
      final snapshot = await _productionRecordsRef.child(employeeId).get();
      final data = snapshot.value;

      if (data == null || data is! Map) {
        return {
          'totalPieces': 0,
          'totalEarnings': 0.0,
          'totalSessions': 0,
          'averagePiecesPerHour': 0.0,
          'averagePiecesPerSession': 0.0,
        };
      }

      int totalPieces = 0;
      double totalEarnings = 0.0;
      double totalPiecesPerHour = 0.0;
      int sessionCount = 0;

      data.forEach((key, value) {
        if (value is Map) {
          sessionCount++;
          try {
            final record = ProductionRecord.fromMap(
                key.toString(), Map<String, dynamic>.from(value));
            totalPieces += record.piecesProduced;
            totalEarnings += record.totalEarnings;
            totalPiecesPerHour += record.piecesPerHour;
          } catch (e) {
            print('Error processing record $key: $e');
          }
        }
      });

      return {
        'totalPieces': totalPieces,
        'totalEarnings': totalEarnings,
        'totalSessions': sessionCount,
        'averagePiecesPerHour':
        sessionCount > 0 ? totalPiecesPerHour / sessionCount : 0.0,
        'averagePiecesPerSession':
        sessionCount > 0 ? totalPieces / sessionCount : 0.0,
      };
    } catch (e) {
      print('Error getting stats: $e');
      return {
        'totalPieces': 0,
        'totalEarnings': 0.0,
        'totalSessions': 0,
        'averagePiecesPerHour': 0.0,
        'averagePiecesPerSession': 0.0,
      };
    }
  }

  Future<int> _getCurrentPiecesCompleted(String employeeId) async {
    final snapshot =
    await _employeesRef.child(employeeId).child('piecesCompleted').get();
    return _toInt(snapshot.value);
  }

  Future<double> _getCurrentTotalEarnings(String employeeId) async {
    final snapshot =
    await _employeesRef.child(employeeId).child('totalEarnings').get();
    return _toDouble(snapshot.value);
  }

  Future<void> saveDozenProductionEntries({
    required PerDozenEmployee employee,
    required double totalDozens,
    required int totalPieces,
    required double totalEarnings,
  })
  async {
    try {
      final now = DateTime.now();
      final recordId =
      _productionRecordsRef.child(employee.id).push().key!;

      // Reuse the production_records node; store dozens-specific fields
      await _productionRecordsRef.child(employee.id).child(recordId).set({
        'id': recordId,
        'employeeId': employee.id,
        'employeeName': employee.name,
        'recordType': 'perdozen',           // distinguishes from perpiece
        'totalDozens': totalDozens,
        'piecesProduced': totalPieces,       // kept for shared summary queries
        'ratePerDozen': employee.ratePerDozen,
        'totalEarnings': totalEarnings,
        'startTime': now.toIso8601String(),
        'endTime': now.toIso8601String(),
        // Fields below are zeroed out — not applicable for dozen tracking
        'durationInMinutes': 0,
        'piecesPerHour': 0.0,
        'isHours': false,
        'ratePerPiece': 0.0,
      });

      // Update employee aggregate totals
      final currentDozens = await _getCurrentDozensCompleted(employee.id);
      final currentEarnings = await _getCurrentTotalEarnings(employee.id);

      await _employeesRef.child(employee.id).update({
        'dozensCompleted': currentDozens + totalDozens,
        'totalEarnings': currentEarnings + totalEarnings,
        // Keep totalPieces in sync (dozensCompleted * 12 is derived, but store directly too)
        'totalPieces': ((currentDozens + totalDozens) * 12).round(),
      });

      // Auto-create credit entry in ledger
      await _ledgerService.addCreditEntry(
        employeeId: employee.id,
        amount: totalEarnings,
        description:
        'Production: ${totalDozens.toStringAsFixed(totalDozens % 1 == 0 ? 0 : 2)} doz '
            '($totalPieces pcs) @ Rs ${employee.ratePerDozen.toStringAsFixed(2)}/doz',
        referenceId: recordId,
        date: now,
      );
    } catch (e) {
      print('Error saving dozen production entries: $e');
      rethrow;
    }
  }

  Future<double> _getCurrentDozensCompleted(String employeeId) async {
    final snapshot =
    await _employeesRef.child(employeeId).child('dozensCompleted').get();
    return _toDouble(snapshot.value);
  }



}