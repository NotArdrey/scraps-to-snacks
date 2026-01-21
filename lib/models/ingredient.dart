class Ingredient {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime? expiryDate;

  Ingredient({
    required this.id,
    required this.name,
    required this.createdAt,
    this.expiryDate,
  });

  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      expiryDate: map['expiry_date'] != null
          ? DateTime.parse(map['expiry_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      // 'expiry_date': expiryDate?.toIso8601String(), // Optional if we updated it
    };
  }

  // Visual helper for UI
  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final days = expiryDate!.difference(DateTime.now()).inDays;
    return days <= 2;
  }
}
