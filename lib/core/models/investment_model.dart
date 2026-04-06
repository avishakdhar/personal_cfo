import 'dart:math';

class Investment {
  final int? id;
  final String name;
  final String type; // Stock, Mutual Fund, FD, PPF, Gold, Real Estate, Crypto, Other
  final String? symbol;
  final double quantity;
  final double buyPrice;
  final double currentPrice;
  final double annualRate; // % p.a. — for fixed-income types (FD, PPF, Bonds, NPS)
  final DateTime buyDate;
  final String notes;
  final DateTime createdAt;

  Investment({
    this.id,
    required this.name,
    required this.type,
    this.symbol,
    required this.quantity,
    required this.buyPrice,
    required this.currentPrice,
    this.annualRate = 0,
    required this.buyDate,
    this.notes = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // For fixed-income types with annual rate, auto-compute current price via compound interest.
  // Otherwise use stored current_price.
  double get effectiveCurrentPrice {
    if (annualRate > 0 && fixedIncomeTypes.contains(type)) {
      final years = DateTime.now().difference(buyDate).inDays / 365.0;
      return buyPrice * pow(1 + annualRate / 100, years.clamp(0, double.infinity)).toDouble();
    }
    return currentPrice;
  }

  double get totalInvested => quantity * buyPrice;
  double get currentValue => quantity * effectiveCurrentPrice;
  double get profitLoss => currentValue - totalInvested;
  double get profitLossPercent => totalInvested > 0 ? (profitLoss / totalInvested) * 100 : 0;
  bool get isProfit => profitLoss >= 0;

  static const List<String> fixedIncomeTypes = [
    'Fixed Deposit', 'PPF', 'NPS', 'Bonds',
  ];

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'symbol': symbol,
        'quantity': quantity,
        'buy_price': buyPrice,
        'current_price': currentPrice,
        'annual_rate': annualRate,
        'buy_date': buyDate.toIso8601String(),
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory Investment.fromMap(Map<String, dynamic> map) => Investment(
        id: map['id'],
        name: map['name'],
        type: map['type'],
        symbol: map['symbol'],
        quantity: (map['quantity'] as num).toDouble(),
        buyPrice: (map['buy_price'] as num).toDouble(),
        currentPrice: (map['current_price'] as num).toDouble(),
        annualRate: (map['annual_rate'] as num? ?? 0).toDouble(),
        buyDate: DateTime.parse(map['buy_date']),
        notes: map['notes'] ?? '',
        createdAt: DateTime.parse(map['created_at']),
      );

  Investment copyWith({
    int? id,
    String? name,
    String? type,
    String? symbol,
    double? quantity,
    double? buyPrice,
    double? currentPrice,
    double? annualRate,
    DateTime? buyDate,
    String? notes,
  }) =>
      Investment(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        symbol: symbol ?? this.symbol,
        quantity: quantity ?? this.quantity,
        buyPrice: buyPrice ?? this.buyPrice,
        currentPrice: currentPrice ?? this.currentPrice,
        annualRate: annualRate ?? this.annualRate,
        buyDate: buyDate ?? this.buyDate,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );

  static const List<String> types = [
    'Stock', 'Mutual Fund', 'Fixed Deposit', 'PPF', 'NPS',
    'Gold', 'Real Estate', 'Crypto', 'Bonds', 'Other',
  ];
}
