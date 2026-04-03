class TransactionModel {
  final int? id;
  final String type; // income, expense, transfer
  final double amount;
  final int? fromAccount;
  final int? toAccount;
  final String category;
  final String note;
  final DateTime date;
  final bool isDeleted;

  TransactionModel({
    this.id,
    required this.type,
    required this.amount,
    this.fromAccount,
    this.toAccount,
    required this.category,
    required this.note,
    required this.date,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'amount': amount,
        'from_account': fromAccount,
        'to_account': toAccount,
        'category': category,
        'note': note,
        'date': date.toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory TransactionModel.fromMap(Map<String, dynamic> map) => TransactionModel(
        id: map['id'],
        type: map['type'] ?? 'expense',
        amount: (map['amount'] as num).toDouble(),
        fromAccount: map['from_account'],
        toAccount: map['to_account'],
        category: map['category'] ?? 'Other',
        note: map['note'] ?? '',
        date: DateTime.parse(map['date']),
        isDeleted: (map['is_deleted'] ?? 0) == 1,
      );

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
  bool get isTransfer => type == 'transfer';

  static const List<String> expenseCategories = [
    'Food', 'Transport', 'Shopping', 'Bills', 'Entertainment',
    'Health', 'Travel', 'Education', 'Groceries', 'Utilities',
    'Rent', 'Insurance', 'Subscriptions', 'Personal Care', 'Other',
  ];

  static const List<String> incomeCategories = [
    'Salary', 'Freelance', 'Business', 'Investment Returns',
    'Rental Income', 'Gift', 'Refund', 'Other Income',
  ];
}
