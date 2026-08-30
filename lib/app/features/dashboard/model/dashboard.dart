import 'package:lms/app/core/utils/format_utils.dart';

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
    final ongoingRaw = payload['ongoing_courses'] as List? ?? [];
    return DashboardResponse(
      ongoingCourses:
          ongoingRaw
              .whereType<Map>()
              .map(
                (m) => DashboardCourse.fromJson(Map<String, dynamic>.from(m)),
              )
              .toList(),
      resources:
          (payload['articles'] as List? ?? [])
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .where(_isActiveArticle)
              .map(DashboardResource.fromJson)
              .toList(),
    );
  }
}

bool _isActiveArticle(Map<String, dynamic> json) {
  final isDeleted = json['is_deleted']?.toString() ?? '0';
  final status = json['status']?.toString() ?? '1';
  return isDeleted != '1' && status != '0';
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
    this.isNonCourse = false,
    this.notEnrolled = false,
    this.description,
    this.category,
    this.dueDate,
    this.dueDateRaw,
    this.nextSession,
    this.completedDate,
  });

  final int id;
  final String name;
  final String? logo;
  final int progress;

  /// Next scheduled session/class date, when the course has one.
  final DateTime? nextSession;

  /// Date the course was completed, when reported by the API.
  final DateTime? completedDate;

  /// Only populated when built from the learning-progress endpoint's
  /// "continue_learning" list, which is the only place a description is
  /// actually available - null everywhere else (fromJson below doesn't set
  /// it, since ongoing_courses never carried one).
  final String? description;

  /// The class name (e.g. "Learning Arcade Game") shown as a small
  /// category tag above the title - same "continue_learning"-only
  /// availability as [description].
  final String? category;

  /// Already-formatted ("August 1, 2026") - same "continue_learning"-only
  /// availability as [description]. Display-only; use [dueDateRaw] for any
  /// actual date comparison (e.g. overdue checks), since this string isn't
  /// re-parseable.
  final String? dueDate;

  /// The actual comparable due-date value backing [dueDate]'s display
  /// string - same "continue_learning"-only availability.
  final DateTime? dueDateRaw;
  final bool displayRating;
  final double averageRating;
  final int ratingCount;
  // True when this entry has no real course_id - e.g. a custom
  // "Non Course Development Plan" item, which has no course to view and is
  // instead updated by percentage via lms-screen/non-course-development-plan.
  final bool isNonCourse;

  // True when the API reports this course as not enrolled - it sends the
  // literal string "Not Enrolled" in the `progress` field for these
  // (instead of a number), rather than a separate flag. [progress] can't
  // represent that (_asInt collapses it to 0, indistinguishable from a
  // real 0% for an enrolled-but-unstarted course), so this is the only way
  // to tell the two apart - the Development Plan table shows "Not
  // Enrolled" instead of "0%" for it, matching the website.
  final bool notEnrolled;

  factory DashboardCourse.fromJson(Map<String, dynamic> json) {
    final hasCourseId = json['course_id'] != null;
    // Confirmed via debug logging: this endpoint's `progress` field is a
    // string with a literal trailing "%" (e.g. "21.43%"), handled by
    // _asInt below.
    final progressValue = json['progress'] ?? (hasCourseId ? null : json['status']);
    final nextSessionValue = (json['next_session'] ??
            json['nextSession'] ??
            json['start_date'] ??
            json['startDate'] ??
            json['available_at'])
        ?.toString();
    final completedDateValue = (json['completion_time'] ??
            json['completionTime'] ??
            json['completed_at'] ??
            json['completedAt'] ??
            json['completed_date'] ??
            json['completedDate'] ??
            json['completion_date'])
        ?.toString();
    final course = DashboardCourse(
      // Non-course dev plan items carry their id as `non_course_id`, not
      // `id` - the development-plan API's own "Non Course ID" field (see
      // non-course-development-plan's `id` param). Falling back to `id`
      // for course entries kept resolving to 0 for these, which the update
      // endpoint then rejected with "Non-course ID is required."
      id: _asInt(json['course_id'] ?? json['non_course_id'] ?? json['id']),
      name:
          json['course_name']?.toString() ??
          json['name']?.toString() ??
          json['title']?.toString() ??
          '',
      logo:
          json['logo']?.toString().isNotEmpty == true
              ? json['logo'].toString()
              : null,
      // Non-course items report their completion percentage via `status`
      // instead of `progress` (which is always null for them).
      progress: _asInt(progressValue),
      notEnrolled:
          progressValue?.toString().trim().toLowerCase() == 'not enrolled',
      displayRating:
          json['display_rating'] == true ||
          json['display_rating']?.toString() == '1',
      averageRating: _asDouble(json['average_rating']),
      ratingCount: _asInt(json['rating_count']),
      isNonCourse: !hasCourseId,
      nextSession: nextSessionValue == null || nextSessionValue.isEmpty
          ? null
          : nextSessionValue.parseApiUtc(),
      completedDate:
          completedDateValue == null || completedDateValue.isEmpty
              ? null
              : completedDateValue.parseApiUtc(),
    );
    return course;
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
    // Dashboard "articles" carry either an external resource_link (e.g. a
    // deep link into a web page) or a directly-hosted resource_file (e.g. an
    // uploaded video) — both are just a URL to open, so either satisfies
    // actionType 'link'. Falls back to the older link/url/resource_link
    // shape other endpoints have used, for safety.
    final link =
        json['resource_link']?.toString().isNotEmpty == true
            ? json['resource_link'].toString()
            : json['resource_file']?.toString().isNotEmpty == true
            ? json['resource_file'].toString()
            : json['link']?.toString().isNotEmpty == true
            ? json['link'].toString()
            : json['url']?.toString().isNotEmpty == true
            ? json['url'].toString()
            : null;
    final hasResourceId =
        json['resource_id'] != null || json['resource_type'] != null;
    final type =
        link != null
            ? 'link'
            : hasResourceId
            ? 'resource'
            : 'none';

    final logoPath = json['logo_path']?.toString() ?? '';
    final logoBaseUrl = json['logo_base_url']?.toString() ?? '';
    final logo =
        logoPath.isNotEmpty
            ? '$logoBaseUrl$logoPath'
            : json['logo']?.toString().isNotEmpty == true
            ? json['logo'].toString()
            : json['image']?.toString().isNotEmpty == true
            ? json['image'].toString()
            : null;

    return DashboardResource(
      id: _asInt(json['id'] ?? json['resource_id']),
      name:
          json['title']?.toString() ??
          json['name']?.toString() ??
          json['resource_name']?.toString() ??
          '',
      subtitle:
          json['body']?.toString().isNotEmpty == true
              ? json['body'].toString()
              : json['description']?.toString().isNotEmpty == true
              ? json['description'].toString()
              : json['subtitle']?.toString(),
      logo: logo,
      actionType: type,
      actionUrl: link,
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  var str = value?.toString().trim();
  if (str == null || str.isEmpty) return 0;
  // API fields like `progress` arrive as e.g. "21.43%" — a decimal string
  // with a literal trailing percent sign, confirmed via debug logging
  // (raw payload: progress=21.43%, progress=5.56%, progress=25%, ...).
  // int.tryParse rejects both the decimal point and the "%" outright and
  // returns null, which previously collapsed every such value to 0 (the
  // progress ring rendering with no visible arc regardless of the real
  // percentage). Stripping a trailing "%" then falling back to a double
  // parse + truncation handles it.
  if (str.endsWith('%')) str = str.substring(0, str.length - 1);
  return int.tryParse(str) ?? double.tryParse(str)?.toInt() ?? 0;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}
