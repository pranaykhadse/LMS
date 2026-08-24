import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';

class AllCourseProgressItem {
  const AllCourseProgressItem({
    required this.courseId,
    required this.courseName,
    required this.progress,
    this.category = '',
    this.dueDate = '',
  });

  final String courseId;
  final String courseName;
  final int progress;
  final String category;
  final String dueDate;

  factory AllCourseProgressItem.fromJson(Map<String, dynamic> json) {
    return AllCourseProgressItem(
      courseId: json['course_id']?.toString() ?? '',
      courseName: json['course_name']?.toString() ?? '',
      progress: _asInt(json['progress']),
      // Show "Category Here" placeholder when category is absent/null
      category: (json['category']?.toString().isNotEmpty == true)
          ? json['category'].toString()
          : 'Category Here',
      // due_date may be pre-formatted "August 12, 2026" or ISO "2026-08-12"
      dueDate: _formatDate(json['due_date']?.toString()),
    );
  }
}

class AllCourseProgressResult {
  const AllCourseProgressResult({
    required this.totalCourses,
    required this.page,
    required this.pages,
    required this.perPage,
    required this.courses,
  });

  final int totalCourses;
  final int page;
  final int pages;
  final int perPage;
  final List<AllCourseProgressItem> courses;

  factory AllCourseProgressResult.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] is Map
        ? Map<String, dynamic>.from(json['payload'] as Map)
        : <String, dynamic>{};
    return AllCourseProgressResult(
      totalCourses: _asInt(json['total_courses']),
      page: _asInt(json['page']),
      pages: _asInt(json['pages']),
      perPage: _asInt(json['per_page']),
      courses: (payload['courses'] as List? ?? [])
          .whereType<Map>()
          .map((m) => AllCourseProgressItem.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}

/// Converts ISO date "2026-08-12" → "August 12, 2026".
/// Already-formatted strings are returned as-is. Null/empty → "".
String _formatDate(String? raw) {
  if (raw == null || raw.isEmpty || raw == 'null') return '';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(raw)) return raw;
  try {
    final parts = raw.substring(0, 10).split('-');
    if (parts.length != 3) return raw;
    final year = parts[0];
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[month]} $day, $year';
  } catch (_) {
    return raw;
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

class AllCourseProgressRepository with RepoNetworkHelper {
  AllCourseProgressRepository(this.config);

  static final provider = Provider<AllCourseProgressRepository>((ref) {
    return AllCourseProgressRepository(ref.watch(ServerProvider.repoConfigProvider));
  });

  @override
  final RepoNetworkConfig config;

  Future<AllCourseProgressResult> fetch({
    required int userId,
    int page = 1,
    int perPage = 10,
  }) async {
    final response = await getRequest(
      'lms-screen/all-course-progress',
      queryParameters: {'user_id': userId, 'page': page, 'limit': perPage},
      cacheType: RequestCacheType.none,
    );
    final data = Map<String, dynamic>.from(response as Map);
    if (data['status']?.toString() != '1') {
      throw Exception(data['message']?.toString() ?? 'Unable to load course progress.');
    }
    return AllCourseProgressResult.fromJson(data);
  }
}
