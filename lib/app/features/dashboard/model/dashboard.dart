class DashboardResponse {
  const DashboardResponse({
    required this.ongoingCourses,
    required this.resources,
  });

  final List<DashboardCourse> ongoingCourses;
  final List<DashboardResource> resources;

  factory DashboardResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['payload'];
    final payload =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    return DashboardResponse(
      ongoingCourses:
          (payload['ongoing_courses'] as List? ?? [])
              .whereType<Map>()
              .map(
                (m) => DashboardCourse.fromJson(Map<String, dynamic>.from(m)),
              )
              .toList(),
      resources:
          (payload['resources'] as List? ?? [])
              .whereType<Map>()
              .map(
                (m) => DashboardResource.fromJson(Map<String, dynamic>.from(m)),
              )
              .toList(),
    );
  }
}

class DashboardCourse {
  const DashboardCourse({
    required this.id,
    required this.name,
    required this.logo,
    required this.progress,
    required this.displayRating,
    required this.averageRating,
    required this.ratingCount,
  });

  final int id;
  final String name;
  final String? logo;
  final int progress;
  final bool displayRating;
  final double averageRating;
  final int ratingCount;

  factory DashboardCourse.fromJson(Map<String, dynamic> json) {
    return DashboardCourse(
      id: _asInt(json['course_id'] ?? json['id']),
      name:
          json['course_name']?.toString() ??
          json['name']?.toString() ??
          json['title']?.toString() ??
          '',
      logo:
          json['logo']?.toString().isNotEmpty == true
              ? json['logo'].toString()
              : null,
      progress: _asInt(json['progress']),
      displayRating:
          json['display_rating'] == true ||
          json['display_rating']?.toString() == '1',
      averageRating: _asDouble(json['average_rating']),
      ratingCount: _asInt(json['rating_count']),
    );
  }
}

class DashboardResource {
  const DashboardResource({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.logo,
    required this.actionType,
    required this.actionUrl,
  });

  final int id;
  final String name;
  final String? subtitle;
  final String? logo;
  final String actionType; // 'link' | 'resource' | 'none'
  final String? actionUrl;

  factory DashboardResource.fromJson(Map<String, dynamic> json) {
    final link =
        json['link']?.toString().isNotEmpty == true
            ? json['link'].toString()
            : json['url']?.toString().isNotEmpty == true
            ? json['url'].toString()
            : json['resource_link']?.toString().isNotEmpty == true
            ? json['resource_link'].toString()
            : null;
    final hasResourceId =
        json['resource_id'] != null || json['resource_type'] != null;
    final type =
        link != null
            ? 'link'
            : hasResourceId
            ? 'resource'
            : 'none';
    return DashboardResource(
      id: _asInt(json['id'] ?? json['resource_id']),
      name:
          json['name']?.toString() ??
          json['title']?.toString() ??
          json['resource_name']?.toString() ??
          '',
      subtitle:
          json['description']?.toString().isNotEmpty == true
              ? json['description'].toString()
              : json['subtitle']?.toString(),
      logo:
          json['logo']?.toString().isNotEmpty == true
              ? json['logo'].toString()
              : json['image']?.toString().isNotEmpty == true
              ? json['image'].toString()
              : null,
      actionType: type,
      actionUrl: link,
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}
