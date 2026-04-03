class Goal {
  final int? id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final String description;
  final String iconName;
  final bool isCompleted;
  final DateTime createdAt;

  Goal({
    this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    this.targetDate,
    this.description = '',
    this.iconName = 'star',
    this.isCompleted = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get progress => targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0;
  double get remaining => (targetAmount - currentAmount).clamp(0, double.infinity);

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'target_amount': targetAmount,
        'current_amount': currentAmount,
        'target_date': targetDate?.toIso8601String(),
        'description': description,
        'icon_name': iconName,
        'is_completed': isCompleted ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory Goal.fromMap(Map<String, dynamic> map) => Goal(
        id: map['id'],
        name: map['name'],
        targetAmount: (map['target_amount'] as num).toDouble(),
        currentAmount: (map['current_amount'] as num).toDouble(),
        targetDate: map['target_date'] != null ? DateTime.parse(map['target_date']) : null,
        description: map['description'] ?? '',
        iconName: map['icon_name'] ?? 'star',
        isCompleted: (map['is_completed'] ?? 0) == 1,
        createdAt: DateTime.parse(map['created_at']),
      );

  Goal copyWith({
    int? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    String? description,
    String? iconName,
    bool? isCompleted,
  }) =>
      Goal(
        id: id ?? this.id,
        name: name ?? this.name,
        targetAmount: targetAmount ?? this.targetAmount,
        currentAmount: currentAmount ?? this.currentAmount,
        targetDate: targetDate ?? this.targetDate,
        description: description ?? this.description,
        iconName: iconName ?? this.iconName,
        isCompleted: isCompleted ?? this.isCompleted,
        createdAt: createdAt,
      );

  static const List<String> iconOptions = [
    'star', 'home', 'directions_car', 'flight', 'school',
    'favorite', 'savings', 'computer', 'shopping_bag', 'medical_services',
  ];
}
