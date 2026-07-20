class RedeemHistoryResult {
  const RedeemHistoryResult({required this.total, required this.items});
  final int total;
  final List<RedeemHistoryItem> items;

  factory RedeemHistoryResult.fromJson(Map<String, dynamic> json) {
    return RedeemHistoryResult(
      total: _asInt(json['total']),
      items: (json['payload'] as List? ?? [])
          .whereType<Map>()
          .map((m) => RedeemHistoryItem.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}

class RedeemHistoryItem {
  const RedeemHistoryItem({
    required this.redeemId,
    required this.itemId,
    required this.itemName,
    required this.pointsSpent,
    this.image,
    this.address,
    this.note,
    this.redeemedAt,
    this.groupId,
    this.description,
    this.managedBy,
  });

  final int redeemId;
  final int itemId;
  final String itemName;
  final int pointsSpent;
  final String? image;
  final String? address;
  final String? note;
  final DateTime? redeemedAt;
  final int? groupId;
  final String? description;
  final String? managedBy;

  factory RedeemHistoryItem.fromJson(Map<String, dynamic> json) {
    final details = json['item_details'] is Map
        ? Map<String, dynamic>.from(json['item_details'] as Map)
        : <String, dynamic>{};
    final img = json['image']?.toString().trim() ?? '';
    final note = json['note']?.toString().trim() ?? '';
    final address = json['address']?.toString().trim() ?? '';
    return RedeemHistoryItem(
      redeemId: _asInt(json['redeem_id']),
      itemId: _asInt(json['item_id']),
      itemName: json['item_name']?.toString() ?? '',
      pointsSpent: _asInt(json['points_spent']),
      image: img.isNotEmpty ? img : null,
      address: address.isNotEmpty ? address : null,
      note: note.isNotEmpty ? note : null,
      redeemedAt: json['redeemed_at'] == null
          ? null
          : DateTime.tryParse(json['redeemed_at'].toString()),
      groupId: details['group_id'] == null ? null : _asInt(details['group_id']),
      description: details['description']?.toString(),
      managedBy: details['managed_by']?.toString(),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
