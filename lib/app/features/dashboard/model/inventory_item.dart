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
    // Confirmed from a raw response capture: this endpoint returns a flat
    // object with no image/logo field and no managed_by at all — only
    // group_id (an int, no display name). So the image placeholder for
    // items without one is correct, not a bug; "Group N" is the best
    // available label until/unless the API adds a real group name.
    final img = json['image']?.toString().trim().isNotEmpty == true
        ? json['image'].toString().trim()
        : json['logo']?.toString().trim();

    final groupName = json['group_name']?.toString().trim();
    final groupId = json['group_id'];
    final resolvedGroup = (groupName?.isNotEmpty ?? false)
        ? groupName
        : (groupId != null ? 'Group $groupId' : null);

    return InventoryItem(
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? '',
      points: _asInt(json['points']),
      description: json['description']?.toString() ?? '',
      isRedeemed: json['is_redeemed'] == true || json['is_redeemed'].toString() == '1',
      canRedeem: json['can_redeem'] == true || json['can_redeem'].toString() == '1',
      image: (img?.isNotEmpty ?? false) ? img : null,
      groupName: (resolvedGroup?.isNotEmpty ?? false) ? resolvedGroup : null,
      managedBy: json['managed_by']?.toString().trim().isNotEmpty == true
          ? json['managed_by'].toString().trim()
          : null,
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
