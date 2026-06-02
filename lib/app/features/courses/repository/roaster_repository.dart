import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
      cacheType: RequestCacheType.none,
      data: {"course_id": courseId, "user_id": userId},
    );
    debugPrint('[RoasterRepo] fetch-user-roaster raw: $response');
    return DataResponse.parse(response, Roaster.fromJson);
  }

  /// Marks a class as completed using the same GET endpoint the web platform
  /// uses when the user opens a video, article, PDF, or webpage.
  ///
  /// Web call: GET /learning-event-log/create?courseId=642&learningEventId=1965
  ///
  /// [learningEventId] = courseClass.id — the learning event (or learning-event-
  /// class) ID embedded in the course-classes API response.
  Future<void> createLearningEventLog({
    required String courseId,
    required String learningEventId,
  }) async {
    final response = await getRequest(
      "learning-event-log/create",
      queryParameters: {
        "courseId": int.tryParse(courseId),
        "learningEventId": int.tryParse(learningEventId),
      },
      cacheType: RequestCacheType.none,
    );
    debugPrint('[RoasterRepo] learning-event-log/create response: $response');
    if (response == null) throw 'No response';
    // Response shape: {status: 1, message: "success", payload: []}
    if (response['message'] == 'success' ||
        response['status'] == 1 ||
        response['status'] == '1') return;
    throw response['message'] ?? 'createLearningEventLog failed';
  }

  Future<void> saveRoaster(
    String courseId,
    String classId,
    String userId,
    String learningEventClassId,
  ) async {
    final data = {
      "course_id": int.tryParse(courseId),
      "class_id": int.tryParse(classId),
      "user_id": int.tryParse(userId),
      "learning_event_class_id": int.tryParse(learningEventClassId),
    };
    // Use Dio directly to avoid caching/serialization issues.
    final response = await dio.post(
      "learning-event/save-roaster",
      data: data,
      options: Options(
        headers: header,
        validateStatus: (_) => true,
      ),
    );
    debugPrint('[RoasterRepo] save-roaster status=${response.statusCode} body=${response.data}');
    final body = response.data;
    if (body == null) return;
    if (body is! Map) return;
    if (body['success'] == 'true' || body['success'] == true) return;
    throw body['message'] ?? 'saveRoaster failed';
  }

  /// Marks a learning event as completed.
  ///
  /// This is the same API the web platform uses. On success the server returns
  /// the updated [Roaster] record (status = "3") which can be applied directly
  /// to local state without a separate fetch.
  Future<Roaster?> markLearningEventCompletion(
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
      cacheType: RequestCacheType.none,
      data: data,
    );
    if (response == null) throw 'No response from server';
    final success = response['success'];
    if (success == 'true' || success == true) {
      final roasterJson = response['roaster'];
      if (roasterJson != null && roasterJson is Map) {
        return Roaster.fromJson(roasterJson);
      }
      return null;
    }
    throw response['message'] ?? 'markLearningEventCompletion failed';
  }
}
