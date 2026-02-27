enum LedgerEntryType {
  credit,
  debit,
}

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

class LedgerEntry {
  final String id;
  final String employeeId;
  final LedgerEntryType type;
  final double amount;
  final String description;
  final String? referenceId;
  final String referenceType;
  final DateTime date;
  final double balance;
  final Map<String, dynamic>? metadata;

  LedgerEntry({
    required this.id,
    required this.employeeId,
    required this.type,
    required this.amount,
    required this.description,
    this.referenceId,
    required this.referenceType,
    required this.date,
    required this.balance,
    this.metadata,
  });

  // Add this getter
  bool get isCredit => type == LedgerEntryType.credit;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employeeId': employeeId,
      'type': type.value,
      'amount': amount,
      'description': description,
      if (referenceId != null) 'referenceId': referenceId,
      'referenceType': referenceType,
      'date': date.toIso8601String(),
      'balance': balance,
      if (metadata != null) 'metadata': metadata,
    };
  }

  factory LedgerEntry.fromMap(String id, Map<String, dynamic> map) {
    return LedgerEntry(
      id: id,
      employeeId: map['employeeId'] ?? '',
      type: LedgerEntryTypeExtension.fromString(map['type'] ?? 'credit'),
      amount: (map['amount'] ?? 0).toDouble(),
      description: map['description'] ?? '',
      referenceId: map['referenceId'],
      referenceType: map['referenceType'] ?? 'production',
      date: DateTime.parse(map['date']),
      balance: (map['balance'] ?? 0).toDouble(),
      metadata: map['metadata'] != null ? Map<String, dynamic>.from(map['metadata']) : null,
    );
  }
}