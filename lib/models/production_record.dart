class ProductionRecord {
  final String id;
  final String employeeId;
  final String employeeName;
  final int piecesProduced;
  final DateTime startTime;
  final DateTime endTime;
  final int durationInMinutes;
  final double ratePerPiece;
  final double totalEarnings;
  final double piecesPerHour;

  ProductionRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.piecesProduced,
    required this.startTime,
    required this.endTime,
    required this.durationInMinutes,
    required this.ratePerPiece,
    required this.totalEarnings,
    required this.piecesPerHour,
  });

  factory ProductionRecord.fromMap(String id, Map<String, dynamic> map) {
    return ProductionRecord(
      id: id,
      employeeId: map['employeeId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      piecesProduced: map['piecesProduced'] ?? 0,
      startTime: DateTime.parse(map['startTime'] ?? DateTime.now().toIso8601String()),
      endTime: DateTime.parse(map['endTime'] ?? DateTime.now().toIso8601String()),
      durationInMinutes: map['durationInMinutes'] ?? 0,
      ratePerPiece: (map['ratePerPiece'] ?? 0).toDouble(),
      totalEarnings: (map['totalEarnings'] ?? 0).toDouble(),
      piecesPerHour: (map['piecesPerHour'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'piecesProduced': piecesProduced,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'durationInMinutes': durationInMinutes,
      'ratePerPiece': ratePerPiece,
      'totalEarnings': totalEarnings,
      'piecesPerHour': piecesPerHour,
    };
  }
}

class ActiveProductionSession {
  final String employeeId;
  final String employeeName;
  final DateTime startTime;
  final int piecesProduced;
  final double ratePerPiece;
  final DateTime? lastUpdated;

  ActiveProductionSession({
    required this.employeeId,
    required this.employeeName,
    required this.startTime,
    required this.piecesProduced,
    required this.ratePerPiece,
    this.lastUpdated,
  });

  factory ActiveProductionSession.fromMap(Map<String, dynamic> map) {
    return ActiveProductionSession(
      employeeId: map['employeeId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      startTime: DateTime.parse(map['startTime'] ?? DateTime.now().toIso8601String()),
      piecesProduced: map['piecesProduced'] ?? 0,
      ratePerPiece: (map['ratePerPiece'] ?? 0).toDouble(),
      lastUpdated: map['lastUpdated'] != null
          ? DateTime.parse(map['lastUpdated'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'startTime': startTime.toIso8601String(),
      'piecesProduced': piecesProduced,
      'ratePerPiece': ratePerPiece,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }
}