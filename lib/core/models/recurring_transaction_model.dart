class RecurringTransaction {
  final int? id;
  final String type; // income, expense, transfer
  final double amount;
  final int? fromAccountId;
  final int? toAccountId;
  final String category;
  final String note;
  final String frequency; // daily, weekly, monthly, yearly
  final DateTime nextDueDate;
  final DateTime? lastProcessedDate;
  final bool isActive;
  final DateTime createdAt;

  RecurringTransaction({
    this.id,
    required this.type,
    required this.amount,
    this.fromAccountId,
    this.toAccountId,
    required this.category,
    required this.note,
    required this.frequency,
    required this.nextDueDate,
    this.lastProcessedDate,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isDue => nextDueDate.isBefore(DateTime.now()) || nextDueDate.isAtSameMomentAs(DateTime.now());

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'amount': amount,
        'from_account': fromAccountId,
        'to_account': toAccountId,
        'category': category,
        'note': note,
        'frequency': frequency,
        'next_due_date': nextDueDate.toIso8601String(),
        'last_processed_date': lastProcessedDate?.toIso8601String(),
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory RecurringTransaction.fromMap(Map<String, dynamic> map) => RecurringTransaction(
        id: map['id'],
        type: map['type'],
        amount: (map['amount'] as num).toDouble(),
        fromAccountId: map['from_account'],
        toAccountId: map['to_account'],
        category: map['category'] ?? 'Other',
        note: map['note'] ?? '',
        frequency: map['frequency'],
        nextDueDate: DateTime.parse(map['next_due_date']),
        lastProcessedDate: map['last_processed_date'] != null
            ? DateTime.parse(map['last_processed_date'])
            : null,
        isActive: (map['is_active'] ?? 1) == 1,
        createdAt: DateTime.parse(map['created_at']),
      );

  static const List<String> frequencies = ['daily', 'weekly', 'monthly', 'yearly'];

  String get frequencyLabel {
    switch (frequency) {
      case 'daily': return 'Daily';
      case 'weekly': return 'Weekly';
      case 'monthly': return 'Monthly';
      case 'yearly': return 'Yearly';
      default: return frequency;
    }
  }
}
