class CourseCatalogResponse {
  const CourseCatalogResponse({
    required this.skills,
    required this.courses,
    required this.total,
    required this.page,
    required this.pages,
  });

  final List<CatalogSkill> skills;
  final List<CatalogCourse> courses;
  final int total;
  final int page;
  final int pages;

  factory CourseCatalogResponse.fromJson(Map<String, dynamic> json) {
    return CourseCatalogResponse(
      skills: (json['available_skills'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => CatalogSkill.fromJson(Map<String, dynamic>.from(value)))
          .toList(),
      courses: (json['payload'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => CatalogCourse.fromJson(Map<String, dynamic>.from(value)))
          .toList(),
      total: _asInt(json['total']),
      page: _asInt(json['page'], fallback: 1),
      pages: _asInt(json['pages'], fallback: 1),
    );
  }
}

class CatalogSkill {
  const CatalogSkill({required this.id, required this.name});

  final String id;
  final String name;

  factory CatalogSkill.fromJson(Map<String, dynamic> json) {
    return CatalogSkill(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class CatalogCourse {
  const CatalogCourse({
    required this.id,
    required this.name,
    required this.logo,
    required this.progress,
    required this.nextSession,
    required this.displayRating,
    required this.averageRating,
    required this.ratingCount,
  });

  final int id;
  final String name;
  final String? logo;
  final double progress;
  final DateTime? nextSession;
  final bool displayRating;
  final double averageRating;
  final int ratingCount;

  factory CatalogCourse.fromJson(Map<String, dynamic> json) {
    final nextSessionValue = json['next_session']?.toString();
    return CatalogCourse(
      id: _asInt(json['course_id']),
      name: json['course_name']?.toString() ?? '',
      logo: _nullableString(json['logo']),
      progress: _asDouble(json['progress']),
      nextSession: nextSessionValue == null || nextSessionValue.isEmpty
          ? null
          : DateTime.tryParse(nextSessionValue),
      displayRating: json['display_rating'] == true ||
          json['display_rating']?.toString() == '1',
      averageRating: _asDouble(json['average_rating']),
      ratingCount: _asInt(json['rating_count']),
    );
  }
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String? _nullableString(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
