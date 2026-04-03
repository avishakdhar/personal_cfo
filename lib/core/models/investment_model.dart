class Investment {
  final int? id;
  final String name;
  final String type; // Stock, Mutual Fund, FD, PPF, Gold, Real Estate, Crypto, Other
  final String? symbol;
  final double quantity;
  final double buyPrice;
  final double currentPrice;
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
    required this.buyDate,
    this.notes = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get totalInvested => quantity * buyPrice;
  double get currentValue => quantity * currentPrice;
  double get profitLoss => currentValue - totalInvested;
  double get profitLossPercent => totalInvested > 0 ? (profitLoss / totalInvested) * 100 : 0;
  bool get isProfit => profitLoss >= 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'symbol': symbol,
        'quantity': quantity,
        'buy_price': buyPrice,
        'current_price': currentPrice,
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
        buyDate: buyDate ?? this.buyDate,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );

  static const List<String> types = [
    'Stock', 'Mutual Fund', 'Fixed Deposit', 'PPF', 'NPS',
    'Gold', 'Real Estate', 'Crypto', 'Bonds', 'Other',
  ];
}
