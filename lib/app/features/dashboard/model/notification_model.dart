import 'package:lms/app/core/utils/format_utils.dart';

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.referenceId,
    this.createdAt,
    this.redirectUrl,
  });

  final String id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final String? referenceId;
  final DateTime? createdAt;
  final String? redirectUrl;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final isReadRaw = json['is_read'];
    final isRead = isReadRaw == true || isReadRaw == 1 ||
        isReadRaw?.toString() == '1' ||
        isReadRaw?.toString().toLowerCase() == 'true';

    final createdAtStr = json['created_at']?.toString();
    DateTime? createdAt;
    if (createdAtStr != null && createdAtStr.isNotEmpty) {
      createdAt = createdAtStr.parseApiUtc();
    }

    return NotificationItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      isRead: isRead,
      referenceId: json['reference_id']?.toString(),
      createdAt: createdAt,
      redirectUrl: json['redirect_url']?.toString(),
    );
  }

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
        id: id,
        title: title,
        message: message,
        type: type,
        isRead: isRead ?? this.isRead,
        referenceId: referenceId,
        createdAt: createdAt,
        redirectUrl: redirectUrl,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'type': type,
        'is_read': isRead,
        'reference_id': referenceId,
        // toUtc() keeps the local disk cache round-trip-safe: parseApiUtc()
        // always re-anchors a parsed value to UTC, so caching the already
        // local-converted value verbatim would shift it further on every
        // reload.
        'created_at': createdAt?.toUtc().toIso8601String(),
        'redirect_url': redirectUrl,
      };
}
