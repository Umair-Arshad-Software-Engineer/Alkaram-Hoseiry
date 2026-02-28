import 'package:firebase_database/firebase_database.dart';
import '../models/employee_models.dart';

class RealtimeDatabaseService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // Employee references
  DatabaseReference get _employeesRef => _db.child('employees');
  DatabaseReference _employeeRef(String id) => _employeesRef.child(id);

  // ─── Create or update employee ───────────────────────────────
  Future<void> saveEmployee(Employee employee) async {
    try {
      await _employeeRef(employee.id).set(employee.toMap());
    } catch (e) {
      print('Error saving employee: $e');
      rethrow;
    }
  }

  // ─── Delete employee ─────────────────────────────────────────
  Future<void> deleteEmployee(String id) async {
    try {
      await _employeeRef(id).remove();
      await _db.child('production_records').child(id).remove();
      await _db.child('active_sessions').child(id).remove();
      await _db.child('monthly_attendance').child(id).remove();
    } catch (e) {
      print('Error deleting employee: $e');
      rethrow;
    }
  }

  // ─── Get all employees as stream ─────────────────────────────
  Stream<List<Employee>> getEmployees() {
    return _employeesRef.onValue.map((event) {
      final List<Employee> employees = [];
      final data = event.snapshot.value;

      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            try {
              final employee = Employee.fromMap(
                  key.toString(), Map<String, dynamic>.from(value));
              employees.add(employee);
            } catch (e) {
              print('Error parsing employee $key: $e');
            }
          }
        });
      }

      employees.sort((a, b) => a.name.compareTo(b.name));
      return employees;
    });
  }

  // ─── Get employees by type ───────────────────────────────────
  Stream<List<Employee>> getEmployeesByType(String employeeType) {
    return _employeesRef.onValue.map((event) {
      final List<Employee> employees = [];
      final data = event.snapshot.value;

      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            try {
              final employee = Employee.fromMap(
                  key.toString(), Map<String, dynamic>.from(value));
              if (employee.employeeType == employeeType) {
                employees.add(employee);
              }
            } catch (e) {
              print('Error parsing employee $key: $e');
            }
          }
        });
      }

      employees.sort((a, b) => a.name.compareTo(b.name));
      return employees;
    });
  }

  // ─── Get employee by ID ──────────────────────────────────────
  Future<Employee?> getEmployeeById(String id) async {
    try {
      final snapshot = await _employeeRef(id).get();
      if (snapshot.exists) {
        return Employee.fromMap(
            id, Map<String, dynamic>.from(snapshot.value as Map));
      }
      return null;
    } catch (e) {
      print('Error getting employee: $e');
      rethrow;
    }
  }

  // ─── Statistics ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final snapshot = await _employeesRef.get();
      final data = snapshot.value;

      int total = 0, monthly = 0, daily = 0, perPiece = 0, perDozen = 0;

      if (data != null && data is Map) {
        total = data.length;
        data.forEach((key, value) {
          if (value is Map) {
            switch (value['employeeType'] ?? '') {
              case 'monthly':  monthly++;  break;
              case 'daily':    daily++;    break;
              case 'perpiece': perPiece++; break;
              case 'perdozen': perDozen++; break;
            }
          }
        });
      }

      return {
        'total': total,
        'monthly': monthly,
        'daily': daily,
        'perPiece': perPiece,
        'perDozen': perDozen,
      };
    } catch (e) {
      print('Error getting statistics: $e');
      return {'total': 0, 'monthly': 0, 'daily': 0, 'perPiece': 0, 'perDozen': 0};
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Monthly Attendance Methods
  // ─────────────────────────────────────────────────────────────

  /// Stream of all attendance records for a monthly employee
  Stream<List<MonthlyAttendanceRecord>> getMonthlyAttendanceRecords(
      String employeeId) {
    return _db.child('monthly_attendance/$employeeId').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <MonthlyAttendanceRecord>[];
      final map = Map<String, dynamic>.from(data as Map);
      final records = map.entries
          .map((e) => MonthlyAttendanceRecord.fromMap(
          e.key, Map<String, dynamic>.from(e.value as Map)))
          .toList();
      records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return records;
    });
  }

  /// Save attendance record + increment employee's daysWorked
  Future<void> saveMonthlyAttendanceRecord(
      MonthlyAttendanceRecord record) async {
    // a) Push new record
    final ref = _db.child('monthly_attendance/${record.employeeId}').push();
    final saved = MonthlyAttendanceRecord(
      id: ref.key!,
      employeeId: record.employeeId,
      employeeName: record.employeeName,
      daysAdded: record.daysAdded,
      dailyRate: record.dailyRate,
      earnings: record.earnings,
      notes: record.notes,
      timestamp: record.timestamp,
    );
    await ref.set(saved.toMap());

    // b) Increment daysWorked on the employee node
    final empRef = _db.child('employees/${record.employeeId}/daysWorked');
    final snap = await empRef.get();
    final currentDays = (snap.value as int?) ?? 0;
    await empRef.set(currentDays + record.daysAdded);
  }

  /// Delete an attendance record
  Future<void> deleteMonthlyAttendanceRecord(
      String employeeId, String recordId) async {
    await _db.child('monthly_attendance/$employeeId/$recordId').remove();
  }
}