class CourseCatalogResponse {
  const CourseCatalogResponse({
    required this.skills,
    required this.groups,
    required this.courses,
    required this.total,
    required this.page,
    required this.pages,
  });

  final List<CatalogSkill> skills;
  final List<CatalogCourseGroup> groups;
  final List<CatalogCourse> courses;
  final int total;
  final int page;
  final int pages;

  factory CourseCatalogResponse.fromJson(Map<String, dynamic> json) {
    final rawCourses =
        json['payload'] ??
        json['courses'] ??
        json['data'] ??
        json['items'] ??
        const [];
    final rawCourseList = rawCourses is List ? rawCourses : const [];
    final groups =
        rawCourseList
            .whereType<Map>()
            .map(
              (value) =>
                  CatalogCourseGroup.fromJson(Map<String, dynamic>.from(value)),
            )
            .where((group) => group.courses.isNotEmpty)
            .toList();
    final legacyCourses =
        groups.isEmpty
            ? rawCourseList
                .whereType<Map>()
                .map(
                  (value) =>
                      CatalogCourse.fromJson(Map<String, dynamic>.from(value)),
                )
                .toList()
            : groups.expand((group) => group.courses).toList();
    final firstPagination =
        groups.isNotEmpty ? groups.first.pagination : const CatalogPagination();
    return CourseCatalogResponse(
      skills:
          (json['available_skills'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (value) =>
                    CatalogSkill.fromJson(Map<String, dynamic>.from(value)),
              )
              .toList(),
      groups: groups,
      courses: legacyCourses,
      total: _asInt(json['total'], fallback: firstPagination.total),
      page: _asInt(json['page'], fallback: firstPagination.page),
      pages: _asInt(json['pages'], fallback: firstPagination.pages),
    );
  }
}

class CatalogCourseGroup {
  const CatalogCourseGroup({
    required this.id,
    required this.name,
    required this.pagination,
    required this.courses,
  });

  final String id;
  final String name;
  final CatalogPagination pagination;
  final List<CatalogCourse> courses;

  factory CatalogCourseGroup.fromJson(Map<String, dynamic> json) {
    final rawCourses = json['courses'];
    // Support both nested {"pagination": {...}} and flat {"page":1,"pages":3,...}
    final paginationMap = json['pagination'] is Map
        ? Map<String, dynamic>.from(json['pagination'] as Map)
        : <String, dynamic>{
            'total': json['total'],
            'page': json['page'],
            'pages': json['pages'] ?? json['total_pages'] ?? json['last_page'],
            'per_page': json['per_page'],
          };
    return CatalogCourseGroup(
      id: json['group_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['group_name']?.toString() ?? json['name']?.toString() ?? '',
      pagination: CatalogPagination.fromJson(paginationMap),
      courses:
          (rawCourses as List? ?? const [])
              .whereType<Map>()
              .map(
                (value) =>
                    CatalogCourse.fromJson(Map<String, dynamic>.from(value)),
              )
              .toList(),
    );
  }
}

class CatalogPagination {
  const CatalogPagination({
    this.total = 0,
    this.page = 1,
    this.pages = 1,
    this.perPage = 12,
  });

  final int total;
  final int page;
  final int pages;
  final int perPage;

  factory CatalogPagination.fromJson(Map<String, dynamic> json) {
    return CatalogPagination(
      total: _asInt(json['total']),
      page: _asInt(json['page'], fallback: 1),
      pages: _asInt(json['pages'], fallback: 1),
      perPage: _asInt(json['per_page'], fallback: 12),
    );
  }
}

class CatalogSkill {
  const CatalogSkill({
    required this.id,
    required this.name,
    required this.groupId,
  });

  final String id;
  final String name;
  final String groupId;

  factory CatalogSkill.fromJson(Map<String, dynamic> json) {
    return CatalogSkill(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
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
    required this.nextSessionLabel,
    required this.displayRating,
    required this.averageRating,
    required this.ratingCount,
  });

  final int id;
  final String name;
  final String? logo;
  final double progress;
  final DateTime? nextSession;
  final String? nextSessionLabel;
  final bool displayRating;
  final double averageRating;
  final int ratingCount;

  factory CatalogCourse.fromJson(Map<String, dynamic> json) {
    final course = _courseMap(json);
    final nextSessionValue =
        _firstValue(json, course, const [
          'next_session',
          'nextSession',
          'start_date',
          'startDate',
          'available_at',
        ])?.toString();
    return CatalogCourse(
      id: _asInt(
        _firstValue(json, course, const [
          'course_id',
          'courseId',
          'courseIdFk',
          'course_id_fk',
          'id',
        ]),
      ),
      name:
          _nullableString(
            _firstValue(json, course, const [
              'course_name',
              'courseName',
              'course_title',
              'courseTitle',
              'name',
              'title',
            ]),
          ) ??
          '',
      logo: _nullableString(
        _firstValue(json, course, const [
          'logo',
          'logo_link',
          'logoLink',
          'course_logo',
          'courseLogo',
          'image',
          'image_url',
          'imageUrl',
          'course_image',
          'courseImage',
          'banner',
          'thumbnail',
        ]),
      ),
      progress: _asDouble(
        _firstValue(json, course, const ['progress', 'percentage']),
      ),
      nextSession:
          nextSessionValue == null || nextSessionValue.isEmpty
              ? null
              : DateTime.tryParse(nextSessionValue),
      nextSessionLabel: _nullableString(nextSessionValue),
      displayRating:
          _firstValue(json, course, const [
                'display_rating',
                'displayRating',
              ]) ==
              true ||
          _firstValue(json, course, const [
                'display_rating',
                'displayRating',
              ])?.toString() ==
              '1',
      averageRating: _asDouble(
        _firstValue(json, course, const ['average_rating', 'averageRating']),
      ),
      ratingCount: _asInt(
        _firstValue(json, course, const ['rating_count', 'ratingCount']),
      ),
    );
  }
}

Map<String, dynamic> _courseMap(Map<String, dynamic> json) {
  for (final key in const [
    'course',
    'course_info',
    'courseInfo',
    'course_data',
    'courseData',
  ]) {
    final value = json[key];
    if (value is Map) return Map<String, dynamic>.from(value);
  }
  for (final value in json.values) {
    if (value is Map) {
      final nested = Map<String, dynamic>.from(value);
      if (_firstValue(nested, const {}, const [
            'course_name',
            'courseName',
            'course_title',
            'courseTitle',
            'name',
            'title',
          ]) !=
          null) {
        return nested;
      }
    }
  }
  return const {};
}

dynamic _firstValue(
  Map<String, dynamic> json,
  Map<String, dynamic> nested,
  List<String> keys,
) {
  for (final key in keys) {
    if (json.containsKey(key) && json[key] != null) return json[key];
    if (nested.containsKey(key) && nested[key] != null) return nested[key];
  }
  for (final source in [json, nested]) {
    final found = _findValueDeep(source, keys);
    if (found != null) return found;
  }
  return null;
}

dynamic _findValueDeep(Map<dynamic, dynamic> map, List<String> keys) {
  final normalizedKeys = keys.map(_normalizeKey).toSet();
  for (final entry in map.entries) {
    if (normalizedKeys.contains(_normalizeKey(entry.key.toString())) &&
        entry.value != null) {
      return entry.value;
    }
  }
  for (final value in map.values) {
    if (value is Map) {
      final found = _findValueDeep(value, keys);
      if (found != null) return found;
    }
  }
  return null;
}

String _normalizeKey(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

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
