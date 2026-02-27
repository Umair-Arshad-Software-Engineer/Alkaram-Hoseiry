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
  final bool isHours; // ← NEW

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
    this.isHours = false, // ← NEW
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
      isHours: map['isHours'] ?? false, // ← NEW
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
      'isHours': isHours, // ← NEW
    };
  }
}

