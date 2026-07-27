import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/courses/model/calendar_event.dart';

class CalendarViewRepository with RepoNetworkHelper {
  CalendarViewRepository(this.config);

  static final provider = Provider<CalendarViewRepository>((ref) {
    return CalendarViewRepository(ref.watch(ServerProvider.repoConfigProvider));
  });

  @override
  final RepoNetworkConfig config;

  Future<CalendarViewResult> fetch({required int userId}) async {
    final response = await getRequest(
      'lms-screen/calendar-view',
      queryParameters: {'user_id': userId},
      cacheType: RequestCacheType.none,
    );
    final data = Map<String, dynamic>.from(response as Map);
    if (data['status']?.toString() != '1') {
      throw Exception(
        data['message']?.toString() ?? 'Unable to load calendar events.',
      );
    }
    return CalendarViewResult.fromJson(data);
  }
}
