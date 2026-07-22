class UserBadge {
  const UserBadge({required this.id, required this.title, this.image});
  final int id;
  final String title;
  final String? image;

  factory UserBadge.fromJson(Map<String, dynamic> json) {
    return UserBadge(
      id: _asInt(json['id']),
      title: json['title']?.toString() ?? '',
      image: json['image']?.toString().isNotEmpty == true ? json['image'].toString() : null,
    );
  }
}

class BadgesResult {
  const BadgesResult({
    required this.earnedCount,
    required this.notEarnedCount,
    required this.earned,
    required this.notEarned,
  });
  final int earnedCount;
  final int notEarnedCount;
  final List<UserBadge> earned;
  final List<UserBadge> notEarned;

  factory BadgesResult.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] is Map
        ? Map<String, dynamic>.from(json['payload'] as Map)
        : <String, dynamic>{};
    return BadgesResult(
      earnedCount: _asInt(json['earned_count']),
      notEarnedCount: _asInt(json['not_earned_count']),
      earned: (payload['earned'] as List? ?? [])
          .whereType<Map>()
          .map((m) => UserBadge.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      notEarned: (payload['not_earned'] as List? ?? [])
          .whereType<Map>()
          .map((m) => UserBadge.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
