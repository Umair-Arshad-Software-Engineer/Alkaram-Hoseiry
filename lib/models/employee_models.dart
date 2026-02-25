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

  // Convert to Map for Realtime Database
  Map<String, dynamic> toMap();

  // Create from Map
  factory Employee.fromMap(String id, Map<String, dynamic> map) {
    final String type = map['employeeType'] ?? '';

    switch (type) {
      case 'monthly':
        return MonthlyEmployee.fromMap(id, map);
      case 'daily':
        return DailyEmployee.fromMap(id, map);
      case 'perpiece':
        return PerPieceEmployee.fromMap(id, map);
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
      default:
        return Colors.blue;
    }
  }
}

class MonthlyEmployee extends Employee {
  final double monthlySalary;

  MonthlyEmployee({
    required super.id,
    required super.name,
    required super.phone,
    required super.position,
    required super.joiningDate,
    required this.monthlySalary,
  }) : super(employeeType: 'monthly');

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
    };
  }

  factory MonthlyEmployee.fromMap(String id, Map<String, dynamic> map) {
    return MonthlyEmployee(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      position: map['position'] ?? '',
      joiningDate: DateTime.parse(map['joiningDate'] ?? DateTime.now().toIso8601String()),
      monthlySalary: (map['monthlySalary'] ?? 0).toDouble(),
    );
  }
}

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
      joiningDate: DateTime.parse(map['joiningDate'] ?? DateTime.now().toIso8601String()),
      dailyRate: (map['dailyRate'] ?? 0).toDouble(),
      daysWorked: map['daysWorked'] ?? 0,
    );
  }
}

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
      joiningDate: DateTime.parse(map['joiningDate'] ?? DateTime.now().toIso8601String()),
      ratePerPiece: (map['ratePerPiece'] ?? 0).toDouble(),
      piecesCompleted: map['piecesCompleted'] ?? 0,
    );
  }
}