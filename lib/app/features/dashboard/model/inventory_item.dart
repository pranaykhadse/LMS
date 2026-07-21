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
    this.groupName,
    this.managedBy,
  });

  final int id;
  final String name;
  final int points;
  final String description;
  final bool isRedeemed;
  final bool canRedeem;
  final String? image;
  final String? groupName;
  final String? managedBy;

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    // Redeem-history items carry group/description/managed_by nested under
    // "item_details" rather than flat — inventory items likely share that
    // same underlying shape, so check both.
    final details = json['item_details'] is Map
        ? Map<String, dynamic>.from(json['item_details'] as Map)
        : <String, dynamic>{};

    final img = (json['image']?.toString().trim().isNotEmpty == true
            ? json['image'].toString()
            : json['logo']?.toString().trim().isNotEmpty == true
            ? json['logo'].toString()
            : details['image']?.toString().trim() ?? '');

    final group = json['group_name']?.toString().isNotEmpty == true
        ? json['group_name'].toString()
        : details['group_name']?.toString();

    final managedBy = json['managed_by']?.toString().isNotEmpty == true
        ? json['managed_by'].toString()
        : details['managed_by']?.toString();

    return InventoryItem(
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? '',
      points: _asInt(json['points']),
      description: json['description']?.toString().isNotEmpty == true
          ? json['description'].toString()
          : details['description']?.toString() ?? '',
      isRedeemed: json['is_redeemed'] == true || json['is_redeemed'].toString() == '1',
      canRedeem: json['can_redeem'] == true || json['can_redeem'].toString() == '1',
      image: img.trim().isNotEmpty ? img.trim() : null,
      groupName: (group?.trim().isNotEmpty ?? false) ? group!.trim() : null,
      managedBy: (managedBy?.trim().isNotEmpty ?? false) ? managedBy!.trim() : null,
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
