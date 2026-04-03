class Account {
  final int? id;
  final String name;
  final String type; // Bank, Cash, Credit Card, Wallet
  final double balance;
  final String currency; // INR, USD, EUR, etc.
  final bool isActive;
  final DateTime createdAt;

  Account({
    this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.currency = 'INR',
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'balance': balance,
        'currency': currency,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory Account.fromMap(Map<String, dynamic> map) => Account(
        id: map['id'],
        name: map['name'],
        type: map['type'],
        balance: (map['balance'] as num).toDouble(),
        currency: map['currency'] ?? 'INR',
        isActive: (map['is_active'] ?? 1) == 1,
        createdAt: map['created_at'] != null && (map['created_at'] as String).isNotEmpty
            ? DateTime.parse(map['created_at'])
            : DateTime.now(),
      );

  Account copyWith({
    int? id,
    String? name,
    String? type,
    double? balance,
    String? currency,
    bool? isActive,
  }) =>
      Account(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        balance: balance ?? this.balance,
        currency: currency ?? this.currency,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );

  static const List<String> types = ['Bank', 'Cash', 'Credit Card', 'Wallet', 'Investment'];
  static const List<String> currencies = ['INR', 'USD', 'EUR', 'GBP', 'JPY', 'AED', 'SGD'];
}
