import 'package:firebase_database/firebase_database.dart';
import '../models/production_record.dart';
import '../models/employee_models.dart';

class ProductionServiceRealtime {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // Reference paths
  DatabaseReference get _activeSessionsRef => _db.child('active_sessions');
  DatabaseReference get _productionRecordsRef => _db.child('production_records');
  DatabaseReference get _employeesRef => _db.child('employees');

  // Helper methods for type conversion
  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? 0;
    }
    return 0;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  // Start a new production session
  Future<void> startProductionSession(PerPieceEmployee employee) async {
    try {
      // Check if there's already an active session
      final sessionSnapshot = await _activeSessionsRef.child(employee.id).get();
      if (sessionSnapshot.exists) {
        throw Exception('Employee already has an active session');
      }

      final session = ActiveProductionSession(
        employeeId: employee.id,
        employeeName: employee.name,
        startTime: DateTime.now(),
        piecesProduced: 0,
        ratePerPiece: employee.ratePerPiece,
      );

      await _activeSessionsRef.child(employee.id).set(session.toMap());
    } catch (e) {
      print('Error starting production session: $e');
      rethrow;
    }
  }

  // Update pieces during active session
  Future<void> updatePiecesInSession(String employeeId, int additionalPieces) async {
    try {
      final sessionRef = _activeSessionsRef.child(employeeId);
      final snapshot = await sessionRef.get();

      if (!snapshot.exists) {
        throw Exception('No active session found');
      }

      final currentPieces = _toInt(snapshot.child('piecesProduced').value);
      await sessionRef.update({
        'piecesProduced': currentPieces + additionalPieces,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error updating pieces: $e');
      rethrow;
    }
  }

  // End production session and save record
  Future<void> endProductionSession(String employeeId) async {
    try {
      final sessionSnapshot = await _activeSessionsRef.child(employeeId).get();

      if (!sessionSnapshot.exists) {
        throw Exception('No active session found');
      }

      final data = Map<String, dynamic>.from(sessionSnapshot.value as Map);
      final session = ActiveProductionSession.fromMap(data);
      final endTime = DateTime.now();
      final durationInMinutes = endTime.difference(session.startTime).inMinutes;
      final totalEarnings = session.ratePerPiece * session.piecesProduced;
      final piecesPerHour = durationInMinutes > 0
          ? (session.piecesProduced / durationInMinutes) * 60
          : 0.0;

      // Create production record
      final recordId = _productionRecordsRef.child(employeeId).push().key!;
      final record = ProductionRecord(
        id: recordId,
        employeeId: employeeId,
        employeeName: session.employeeName,
        piecesProduced: session.piecesProduced,
        startTime: session.startTime,
        endTime: endTime,
        durationInMinutes: durationInMinutes,
        ratePerPiece: session.ratePerPiece,
        totalEarnings: totalEarnings,
        piecesPerHour: piecesPerHour,
      );

      // Save record under employee's records
      await _productionRecordsRef
          .child(employeeId)
          .child(recordId)
          .set(record.toMap());

      // Get current values
      final currentPieces = await _getCurrentPiecesCompleted(employeeId);
      final currentEarnings = await _getCurrentTotalEarnings(employeeId);

      // Update employee's total pieces and earnings
      await _employeesRef.child(employeeId).update({
        'piecesCompleted': currentPieces + session.piecesProduced,
        'totalEarnings': currentEarnings + totalEarnings,
      });

      // Delete active session
      await _activeSessionsRef.child(employeeId).remove();
    } catch (e) {
      print('Error ending production session: $e');
      rethrow;
    }
  }

  Future<int> _getCurrentPiecesCompleted(String employeeId) async {
    final snapshot = await _employeesRef.child(employeeId).child('piecesCompleted').get();
    return _toInt(snapshot.value);
  }

  Future<double> _getCurrentTotalEarnings(String employeeId) async {
    final snapshot = await _employeesRef.child(employeeId).child('totalEarnings').get();
    return _toDouble(snapshot.value);
  }

  // Cancel active session
  Future<void> cancelProductionSession(String employeeId) async {
    try {
      await _activeSessionsRef.child(employeeId).remove();
    } catch (e) {
      print('Error cancelling session: $e');
      rethrow;
    }
  }

  // Get active session for an employee
  Stream<ActiveProductionSession?> getActiveSession(String employeeId) {
    return _activeSessionsRef.child(employeeId).onValue.map((event) {
      if (event.snapshot.exists) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        return ActiveProductionSession.fromMap(data);
      }
      return null;
    });
  }

  // Get production records for an employee
  Stream<List<ProductionRecord>> getEmployeeProductionRecords(String employeeId) {
    return _productionRecordsRef.child(employeeId).onValue.map((event) {
      final List<ProductionRecord> records = [];
      final data = event.snapshot.value;

      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            try {
              final record = ProductionRecord.fromMap(
                  key.toString(),
                  Map<String, dynamic>.from(value)
              );
              records.add(record);
            } catch (e) {
              print('Error parsing record $key: $e');
            }
          }
        });
      }

      // Sort by endTime descending
      records.sort((a, b) => b.endTime.compareTo(a.endTime));
      return records;
    });
  }

  // Get production statistics for an employee
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
                key.toString(),
                Map<String, dynamic>.from(value)
            );
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
        'averagePiecesPerHour': sessionCount > 0 ? totalPiecesPerHour / sessionCount : 0.0,
        'averagePiecesPerSession': sessionCount > 0 ? totalPieces / sessionCount : 0.0,
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
}