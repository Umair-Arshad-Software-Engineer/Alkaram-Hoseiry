import 'dart:ui';
import 'package:flutter/material.dart';

abstract class Employee {
  final String id;
  final String name;
  final String phone;
  final String position;
  final DateTime joiningDate;
  final String employeeType;

  Employee({
    required this.id,
    required this.name,
    required this.phone,
    required this.position,
    required this.joiningDate,
    required this.employeeType,
  });

  Map<String, dynamic> toMap();

  factory Employee.fromMap(String id, Map<String, dynamic> map) {
    final String type = map['employeeType'] ?? '';
    switch (type) {
      case 'monthly':
        return MonthlyEmployee.fromMap(id, map);
      case 'daily':
        return DailyEmployee.fromMap(id, map);
      case 'perpiece':
        return PerPieceEmployee.fromMap(id, map);
      case 'perdozen':
        return PerDozenEmployee.fromMap(id, map);
      default:
        throw Exception('Unknown employee type: $type');
    }
  }

  String getTypeDisplay() {
    switch (employeeType) {
      case 'monthly':
        return 'Monthly';
      case 'daily':
        return 'Daily';
      case 'perpiece':
        return 'Per Piece';
      case 'perdozen':
        return 'Per Dozen';
      default:
        return 'Unknown';
    }
  }

  Color getTypeColor() {
    switch (employeeType) {
      case 'monthly':
        return Colors.green;
      case 'daily':
        return Colors.orange;
      case 'perpiece':
        return Colors.purple;
      case 'perdozen':
        return Colors.teal;
      default:
        return Colors.blue;
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  Monthly Employee — now tracks daysWorked
// ─────────────────────────────────────────────────────────────
class MonthlyEmployee extends Employee {
  final double monthlySalary;
  final int daysWorked;       // total working days entered so far
  final int workingDaysInMonth; // denominator for per-day rate (default 26)

  MonthlyEmployee({
    required super.id,
    required super.name,
    required super.phone,
    required super.position,
    required super.joiningDate,
    required this.monthlySalary,
    this.daysWorked = 0,
    this.workingDaysInMonth = 26,
  }) : super(employeeType: 'monthly');

  /// Per-day rate
  double get dailyRate => monthlySalary / 30;

  /// Salary earned so far based on days entered
  double get earnedSalary => dailyRate * daysWorked;

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'position': position,
      'joiningDate': joiningDate.toIso8601String(),
      'employeeType': 'monthly',
      'monthlySalary': monthlySalary,
      'daysWorked': daysWorked,
      'workingDaysInMonth': workingDaysInMonth,
    };
  }

  factory MonthlyEmployee.fromMap(String id, Map<String, dynamic> map) {
    return MonthlyEmployee(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      position: map['position'] ?? '',
      joiningDate:
      DateTime.parse(map['joiningDate'] ?? DateTime.now().toIso8601String()),
      monthlySalary: (map['monthlySalary'] ?? 0).toDouble(),
      daysWorked: map['daysWorked'] ?? 0,
      workingDaysInMonth: map['workingDaysInMonth'] ?? 26,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Monthly Attendance Record (one record per entry)
// ─────────────────────────────────────────────────────────────
class MonthlyAttendanceRecord {
  final String id;
  final String employeeId;
  final String employeeName;
  final int daysAdded;
  final double dailyRate;
  final double earnings;
  final String? notes;
  final DateTime timestamp;

  MonthlyAttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.daysAdded,
    required this.dailyRate,
    required this.earnings,
    this.notes,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'employeeId': employeeId,
    'employeeName': employeeName,
    'daysAdded': daysAdded,
    'dailyRate': dailyRate,
    'earnings': earnings,
    if (notes != null) 'notes': notes,
    'timestamp': timestamp.toIso8601String(),
  };

  factory MonthlyAttendanceRecord.fromMap(
      String id, Map<String, dynamic> map) {
    return MonthlyAttendanceRecord(
      id: id,
      employeeId: map['employeeId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      daysAdded: map['daysAdded'] ?? 0,
      dailyRate: (map['dailyRate'] ?? 0).toDouble(),
      earnings: (map['earnings'] ?? 0).toDouble(),
      notes: map['notes'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Daily Employee
// ─────────────────────────────────────────────────────────────
class DailyEmployee extends Employee {
  final double dailyRate;
  final int daysWorked;

  DailyEmployee({
    required super.id,
    required super.name,
    required super.phone,
    required super.position,
    required super.joiningDate,
    required this.dailyRate,
    required this.daysWorked,
  }) : super(employeeType: 'daily');

  double get totalEarnings => dailyRate * daysWorked;

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'position': position,
      'joiningDate': joiningDate.toIso8601String(),
      'employeeType': 'daily',
      'dailyRate': dailyRate,
      'daysWorked': daysWorked,
      'totalEarnings': totalEarnings,
    };
  }

  factory DailyEmployee.fromMap(String id, Map<String, dynamic> map) {
    return DailyEmployee(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      position: map['position'] ?? '',
      joiningDate:
      DateTime.parse(map['joiningDate'] ?? DateTime.now().toIso8601String()),
      dailyRate: (map['dailyRate'] ?? 0).toDouble(),
      daysWorked: map['daysWorked'] ?? 0,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Per Piece Employee
// ─────────────────────────────────────────────────────────────
class PerPieceEmployee extends Employee {
  final double ratePerPiece;
  final int piecesCompleted;

  PerPieceEmployee({
    required super.id,
    required super.name,
    required super.phone,
    required super.position,
    required super.joiningDate,
    required this.ratePerPiece,
    required this.piecesCompleted,
  }) : super(employeeType: 'perpiece');

  double get totalEarnings => ratePerPiece * piecesCompleted;

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'position': position,
      'joiningDate': joiningDate.toIso8601String(),
      'employeeType': 'perpiece',
      'ratePerPiece': ratePerPiece,
      'piecesCompleted': piecesCompleted,
      'totalEarnings': totalEarnings,
    };
  }

  factory PerPieceEmployee.fromMap(String id, Map<String, dynamic> map) {
    return PerPieceEmployee(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      position: map['position'] ?? '',
      joiningDate:
      DateTime.parse(map['joiningDate'] ?? DateTime.now().toIso8601String()),
      ratePerPiece: (map['ratePerPiece'] ?? 0).toDouble(),
      piecesCompleted: map['piecesCompleted'] ?? 0,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Per Dozen Employee
// ─────────────────────────────────────────────────────────────
class PerDozenEmployee extends Employee {
  final double ratePerDozen;
  final int dozensCompleted;

  PerDozenEmployee({
    required super.id,
    required super.name,
    required super.phone,
    required super.position,
    required super.joiningDate,
    required this.ratePerDozen,
    required this.dozensCompleted,
  }) : super(employeeType: 'perdozen');

  double get totalEarnings => ratePerDozen * dozensCompleted;
  int get totalPieces => dozensCompleted * 12;

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'position': position,
      'joiningDate': joiningDate.toIso8601String(),
      'employeeType': 'perdozen',
      'ratePerDozen': ratePerDozen,
      'dozensCompleted': dozensCompleted,
      'totalEarnings': totalEarnings,
      'totalPieces': totalPieces,
    };
  }

  factory PerDozenEmployee.fromMap(String id, Map<String, dynamic> map) {
    return PerDozenEmployee(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      position: map['position'] ?? '',
      joiningDate:
      DateTime.parse(map['joiningDate'] ?? DateTime.now().toIso8601String()),
      ratePerDozen: (map['ratePerDozen'] ?? 0).toDouble(),
      dozensCompleted: map['dozensCompleted'] ?? 0,
    );
  }
}

class PerDozenProductionRecord {
  final String id;
  final String employeeId;
  final String employeeName;
  final double dozens;
  final int pieces;
  final double earnings;
  final double ratePerDozen;
  final DateTime timestamp;
  final String? notes;

  PerDozenProductionRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.dozens,
    required this.pieces,
    required this.earnings,
    required this.ratePerDozen,
    required this.timestamp,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'employeeId': employeeId,
    'employeeName': employeeName,
    'dozens': dozens,
    'pieces': pieces,
    'earnings': earnings,
    'ratePerDozen': ratePerDozen,
    'timestamp': timestamp.toIso8601String(),
    if (notes != null) 'notes': notes,
  };

  factory PerDozenProductionRecord.fromMap(
      String id, Map<String, dynamic> map) {
    return PerDozenProductionRecord(
      id: id,
      employeeId: map['employeeId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      dozens: (map['dozens'] ?? 0).toDouble(),
      pieces: map['pieces'] ?? 0,
      earnings: (map['earnings'] ?? 0).toDouble(),
      ratePerDozen: (map['ratePerDozen'] ?? 0).toDouble(),
      timestamp: DateTime.parse(map['timestamp']),
      notes: map['notes'],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Ledger models
// ─────────────────────────────────────────────────────────────
enum LedgerEntryType { credit, debit }

extension LedgerEntryTypeExtension on LedgerEntryType {
  String get value {
    switch (this) {
      case LedgerEntryType.credit:
        return 'credit';
      case LedgerEntryType.debit:
        return 'debit';
    }
  }

  static LedgerEntryType fromString(String value) {
    switch (value) {
      case 'credit':
        return LedgerEntryType.credit;
      case 'debit':
        return LedgerEntryType.debit;
      default:
        return LedgerEntryType.credit;
    }
  }
}

