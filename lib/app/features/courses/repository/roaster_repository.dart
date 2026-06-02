import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/model/data_response.dart';
import 'package:lms/app/features/courses/model/roaster.dart';

class RoasterRepository with RepoNetworkHelper {
  static final provider = Provider<RoasterRepository>((ref) {
    return RoasterRepository(ref.watch(ServerProvider.repoConfigProvider));
  });
  @override
  final RepoNetworkConfig config;

  RoasterRepository(this.config);

  Future<DataResponse<Roaster>> getData({
    required String courseId,
    required String userId,
  }) async {
    final response = await post(
      "learning-event/fetch-user-roaster",
      cacheType: RequestCacheType.fetch,
      data: {"course_id": courseId, "user_id": userId},
    );
    return DataResponse.parse(response, Roaster.fromJson);
  }

  Future<void> saveRoaster(
    String courseId,
    String classId,
    String userId,
    String learningEventClassId,
  ) async {
    var data = {
      "course_id": int.tryParse(courseId),
      "class_id": int.tryParse(classId),
      "user_id": int.tryParse(userId),
      "learning_event_class_id": int.tryParse(learningEventClassId),
    };
    final response = await post(
      "learning-event/save-roaster",
      cacheType: RequestCacheType.post,
      data: data,
    );
    if (response == null) return;
    // Response may be a Map or a List depending on server/error state.
    final Map<dynamic, dynamic>? responseMap =
        response is Map ? response as Map : null;
    if (responseMap == null) return;
    if (responseMap['success'] == 'true' || responseMap['success'] == true) return;
    throw responseMap['message'];
  }

  /// Called whenever a user opens (views) a video or PDF.
  /// Tracks the learning event completion on the server.
  /// [learningEventClassId] is only required for Virtual Class events —
  /// omit it (leave null) for Watch Video, Read Article, etc.
  Future<void> markLearningEventCompletion(
    String courseId,
    String classId,
    String userId, {
    String? learningEventClassId,
  }) async {
    final data = <String, dynamic>{
      "course_id": int.tryParse(courseId),
      "class_id": int.tryParse(classId),
      "user_id": int.tryParse(userId),
      "learning_event_class_id": int.tryParse(learningEventClassId ?? ""),
    };
    final response = await post(
      "learning-event/learning-event-completion",
      cacheType: RequestCacheType.post,
      data: data,
    );
    if (response == null) return;
    if (response['success'] == 'true') return;

    throw response['message'];
  }
}
