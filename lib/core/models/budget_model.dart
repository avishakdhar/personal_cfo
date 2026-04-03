class Budget {
  final int? id;
  final String category;
  final double amountLimit;
  final String period; // monthly, weekly
  final int month;
  final int year;

  Budget({
    this.id,
    required this.category,
    required this.amountLimit,
    this.period = 'monthly',
    required this.month,
    required this.year,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'category': category,
        'amount_limit': amountLimit,
        'period': period,
        'month': month,
        'year': year,
      };

  factory Budget.fromMap(Map<String, dynamic> map) => Budget(
        id: map['id'],
        category: map['category'],
        amountLimit: (map['amount_limit'] as num).toDouble(),
        period: map['period'] ?? 'monthly',
        month: map['month'],
        year: map['year'],
      );

  Budget copyWith({
    int? id,
    String? category,
    double? amountLimit,
    String? period,
    int? month,
    int? year,
  }) =>
      Budget(
        id: id ?? this.id,
        category: category ?? this.category,
        amountLimit: amountLimit ?? this.amountLimit,
        period: period ?? this.period,
        month: month ?? this.month,
        year: year ?? this.year,
      );
}
