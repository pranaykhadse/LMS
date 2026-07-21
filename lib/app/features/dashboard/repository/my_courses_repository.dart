import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/paginated_fetch.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/dashboard/model/my_course_item.dart';

class MyCoursesRepository with RepoNetworkHelper {
  MyCoursesRepository(this.config);

  static final provider = Provider<MyCoursesRepository>((ref) {
    return MyCoursesRepository(ref.watch(ServerProvider.repoConfigProvider));
  });

  @override
  final RepoNetworkConfig config;

  // My Courses feeds both the My Courses list and the Calendar's
  // Weekly/Monthly views, both of which need the user's FULL course set
  // (not just one page) — so this walks every page the backend has via
  // page/per_page/limit rather than exposing pagination to callers.
  Future<MyCoursesResult> fetch() async {
    var total = 0;
    final courses = await fetchAllPages<MyCourseItem>(
      fetchPage: (page, perPage) async {
        final response = await getRequest(
          'lms-screen/my-courses',
          queryParameters: {
            'page': page,
            'per_page': perPage,
            'limit': perPage,
          },
          cacheType: RequestCacheType.none,
        );
        final data = Map<String, dynamic>.from(response as Map);
        if (data['status']?.toString() != '1') {
          throw Exception(
            data['message']?.toString() ?? 'Unable to load your courses.',
          );
        }
        final result = MyCoursesResult.fromJson(data);
        total = result.total;
        return result.courses;
      },
    );
    return MyCoursesResult(total: total, courses: courses);
  }
}
