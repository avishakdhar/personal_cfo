class CategoryModel {
  final int? id;
  final String name;
  final String type; // 'income' or 'expense'
  final String colorHex;
  final String iconName;

  const CategoryModel({
    this.id,
    required this.name,
    required this.type,
    this.colorHex = '#6750A4',
    this.iconName = 'category',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'color_hex': colorHex,
        'icon_name': iconName,
      };

  factory CategoryModel.fromMap(Map<String, dynamic> map) => CategoryModel(
        id: map['id'] as int?,
        name: map['name'] as String,
        type: map['type'] as String,
        colorHex: map['color_hex'] as String? ?? '#6750A4',
        iconName: map['icon_name'] as String? ?? 'category',
      );

  CategoryModel copyWith({
    int? id,
    String? name,
    String? type,
    String? colorHex,
    String? iconName,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
    );
  }
}
