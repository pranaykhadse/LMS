import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  Future<MyCoursesResult> fetch() async {
    final response = await getRequest(
      'lms-screen/my-courses',
      cacheType: RequestCacheType.none,
    );
    final data = Map<String, dynamic>.from(response as Map);
    if (data['status']?.toString() != '1') {
      throw Exception(data['message']?.toString() ?? 'Unable to load your courses.');
    }
    return MyCoursesResult.fromJson(data);
  }
}
