import 'package:firebase_database/firebase_database.dart';
import '../models/employee_models.dart';

class RealtimeDatabaseService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // Employee references
  DatabaseReference get _employeesRef => _db.child('employees');

  // Get employee by ID reference
  DatabaseReference _employeeRef(String id) => _employeesRef.child(id);

  // Create or update employee
  Future<void> saveEmployee(Employee employee) async {
    try {
      await _employeeRef(employee.id).set(employee.toMap());
    } catch (e) {
      print('Error saving employee: $e');
      rethrow;
    }
  }

  // Delete employee
  Future<void> deleteEmployee(String id) async {
    try {
      await _employeeRef(id).remove();
      // Also delete related production records
      await _db.child('production_records').child(id).remove();
      await _db.child('active_sessions').child(id).remove();
    } catch (e) {
      print('Error deleting employee: $e');
      rethrow;
    }
  }

  // Get all employees as stream
  Stream<List<Employee>> getEmployees() {
    return _employeesRef.onValue.map((event) {
      final List<Employee> employees = [];
      final data = event.snapshot.value;

      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            try {
              final employee = Employee.fromMap(key.toString(), Map<String, dynamic>.from(value));
              employees.add(employee);
            } catch (e) {
              print('Error parsing employee $key: $e');
            }
          }
        });
      }

      // Sort by name
      employees.sort((a, b) => a.name.compareTo(b.name));
      return employees;
    });
  }

  // Get employees by type as stream
  Stream<List<Employee>> getEmployeesByType(String employeeType) {
    return _employeesRef.onValue.map((event) {
      final List<Employee> employees = [];
      final data = event.snapshot.value;

      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            try {
              final employee = Employee.fromMap(key.toString(), Map<String, dynamic>.from(value));
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

  // Get employee by ID
  Future<Employee?> getEmployeeById(String id) async {
    try {
      final snapshot = await _employeeRef(id).get();
      if (snapshot.exists) {
        return Employee.fromMap(id, Map<String, dynamic>.from(snapshot.value as Map));
      }
      return null;
    } catch (e) {
      print('Error getting employee: $e');
      rethrow;
    }
  }

  // Get statistics
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final snapshot = await _employeesRef.get();
      final data = snapshot.value;

      int total = 0;
      int monthly = 0;
      int daily = 0;
      int perPiece = 0;
      int perDozen = 0; // New counter

      if (data != null && data is Map) {
        total = data.length;
        data.forEach((key, value) {
          if (value is Map) {
            final type = value['employeeType'] ?? '';
            switch (type) {
              case 'monthly':
                monthly++;
                break;
              case 'daily':
                daily++;
                break;
              case 'perpiece':
                perPiece++;
                break;
              case 'perdozen': // New case
                perDozen++;
                break;
            }
          }
        });
      }

      return {
        'total': total,
        'monthly': monthly,
        'daily': daily,
        'perPiece': perPiece,
        'perDozen': perDozen, // New field
      };
    } catch (e) {
      print('Error getting statistics: $e');
      return {
        'total': 0,
        'monthly': 0,
        'daily': 0,
        'perPiece': 0,
        'perDozen': 0, // New field
      };
    }
  }
}