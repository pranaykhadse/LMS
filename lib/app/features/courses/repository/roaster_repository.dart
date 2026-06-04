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
    debugPrint(
      '[RoasterRepo] fetch-user-roaster '
      'success=${response?["success"]}  '
      'count=${(response?["payload"] is List ? (response!["payload"] as List).length : "?")}',
    );
    return DataResponse.parse(response, Roaster.fromJson);
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

  /// Fetches a single LEC record by its ID (the id field from allcourse/events).
  ///
  /// The backend never populates learningEventClass in fetch-user-roaster,
  /// so we fetch it separately using the learning_event_class_id returned by
  /// allcourse/events (courseClass.id). Uses dio.post() directly to avoid
  /// the RepoNetworkHelper wrapper's Map-only assumption.
  Future<Map<dynamic, dynamic>?> fetchLecView(String lecId) async {
    try {
      final response = await dio.post(
        "learning-event-class/view",
        data: {"id": int.tryParse(lecId)},
        options: Options(headers: header, validateStatus: (_) => true),
      );
      final body = response.data;
      debugPrint('[RoasterRepo] fetch-lec-view id=$lecId status=${response.statusCode} bodyType=${body.runtimeType}');
      if (body == null) return null;
      if (body is Map) return body as Map<dynamic, dynamic>;
      if (body is List && body.isNotEmpty && body.first is Map) {
        return body.first as Map<dynamic, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[RoasterRepo] fetch-lec-view error (id=$lecId): $e');
      return null;
    }
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
    // Build the full param map, then drop every falsy entry
    // (null / 0 / empty string) so the server only receives valid values.
    final raw = <String, dynamic>{
      "course_id": int.tryParse(courseId),
      "class_id": int.tryParse(classId),
      "user_id": int.tryParse(userId),
      "learning_event_class_id": int.tryParse(learningEventClassId ?? ""),
      "course_status": 3,
    };
    raw.removeWhere((_, v) => v == null || v == 0 || v == '');

    debugPrint('[RoasterRepo] learning-event-completion REQUEST → $raw');
    final response = await post(
      "learning-event/learning-event-completion",
      cacheType: RequestCacheType.none,
      data: raw,
    );
    debugPrint('[RoasterRepo] learning-event-completion RESPONSE → $response');
    if (response == null) throw 'No response from server';
    final success = response['success'];
    if (success == 'true' || success == true) {
      final roasterJson = response['roaster'];
      debugPrint('[RoasterRepo] roaster from response → $roasterJson');
      if (roasterJson != null && roasterJson is Map) {
        return Roaster.fromJson(roasterJson);
      }
      return null;
    }
    throw response['message'] ?? 'markLearningEventCompletion failed';
  }
}
