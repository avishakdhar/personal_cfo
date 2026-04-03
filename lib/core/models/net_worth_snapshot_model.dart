class NetWorthSnapshot {
  final int? id;
  final DateTime date;
  final double totalAssets;
  final double totalLiabilities;
  final double netWorth;

  NetWorthSnapshot({
    this.id,
    required this.date,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'total_assets': totalAssets,
        'total_liabilities': totalLiabilities,
        'net_worth': netWorth,
      };

  factory NetWorthSnapshot.fromMap(Map<String, dynamic> map) => NetWorthSnapshot(
        id: map['id'],
        date: DateTime.parse(map['date']),
        totalAssets: (map['total_assets'] as num).toDouble(),
        totalLiabilities: (map['total_liabilities'] as num).toDouble(),
        netWorth: (map['net_worth'] as num).toDouble(),
      );
}
