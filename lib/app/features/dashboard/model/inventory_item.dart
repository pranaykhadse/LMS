class InventoryResult {
  const InventoryResult({
    required this.userPoints,
    required this.total,
    required this.items,
  });
  final int userPoints;
  final int total;
  final List<InventoryItem> items;

  factory InventoryResult.fromJson(Map<String, dynamic> json) {
    return InventoryResult(
      userPoints: _asInt(json['user_points']),
      total: _asInt(json['total']),
      items: (json['payload'] as List? ?? [])
          .whereType<Map>()
          .map((m) => InventoryItem.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    required this.points,
    required this.description,
    required this.isRedeemed,
    required this.canRedeem,
    this.image,
  });

  final int id;
  final String name;
  final int points;
  final String description;
  final bool isRedeemed;
  final bool canRedeem;
  final String? image;

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? '',
      points: _asInt(json['points']),
      description: json['description']?.toString() ?? '',
      isRedeemed: json['is_redeemed'] == true || json['is_redeemed'].toString() == '1',
      canRedeem: json['can_redeem'] == true || json['can_redeem'].toString() == '1',
      image: json['image']?.toString().isNotEmpty == true ? json['image'].toString() : null,
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
