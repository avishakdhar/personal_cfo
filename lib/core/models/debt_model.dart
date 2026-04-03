class Debt {
  final int? id;
  final String name;
  final String type; // Personal Loan, Home Loan, Car Loan, Credit Card, Education Loan, Other
  final double principal;
  final double outstanding;
  final double interestRate;
  final double emiAmount;
  final int emiDay; // day of month for EMI
  final DateTime startDate;
  final DateTime? endDate;
  final String lender;
  final String notes;
  final DateTime createdAt;

  Debt({
    this.id,
    required this.name,
    required this.type,
    required this.principal,
    required this.outstanding,
    this.interestRate = 0,
    this.emiAmount = 0,
    this.emiDay = 1,
    required this.startDate,
    this.endDate,
    this.lender = '',
    this.notes = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get paidAmount => principal - outstanding;
  double get progressPercent => principal > 0 ? (paidAmount / principal).clamp(0.0, 1.0) : 0;
  bool get isFullyPaid => outstanding <= 0;

  int? get remainingMonths {
    if (emiAmount <= 0 || outstanding <= 0) return null;
    return (outstanding / emiAmount).ceil();
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'principal': principal,
        'outstanding': outstanding,
        'interest_rate': interestRate,
        'emi_amount': emiAmount,
        'emi_day': emiDay,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'lender': lender,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory Debt.fromMap(Map<String, dynamic> map) => Debt(
        id: map['id'],
        name: map['name'],
        type: map['type'],
        principal: (map['principal'] as num).toDouble(),
        outstanding: (map['outstanding'] as num).toDouble(),
        interestRate: (map['interest_rate'] as num).toDouble(),
        emiAmount: (map['emi_amount'] as num).toDouble(),
        emiDay: map['emi_day'] ?? 1,
        startDate: DateTime.parse(map['start_date']),
        endDate: map['end_date'] != null ? DateTime.parse(map['end_date']) : null,
        lender: map['lender'] ?? '',
        notes: map['notes'] ?? '',
        createdAt: DateTime.parse(map['created_at']),
      );

  Debt copyWith({
    int? id,
    String? name,
    String? type,
    double? principal,
    double? outstanding,
    double? interestRate,
    double? emiAmount,
    int? emiDay,
    DateTime? startDate,
    DateTime? endDate,
    String? lender,
    String? notes,
  }) =>
      Debt(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        principal: principal ?? this.principal,
        outstanding: outstanding ?? this.outstanding,
        interestRate: interestRate ?? this.interestRate,
        emiAmount: emiAmount ?? this.emiAmount,
        emiDay: emiDay ?? this.emiDay,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        lender: lender ?? this.lender,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );

  static const List<String> types = [
    'Personal Loan', 'Home Loan', 'Car Loan',
    'Credit Card', 'Education Loan', 'Business Loan', 'Other',
  ];
}
