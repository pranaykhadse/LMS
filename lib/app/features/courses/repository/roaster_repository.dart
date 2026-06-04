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

  /// Fetches LEC records for a given lms_class_id + course_id.
  ///
  /// Uses dio.post() directly (bypassing the RepoNetworkHelper post() wrapper)
  /// because the endpoint returns a bare JSON array which the wrapper can't handle.
  Future<Map<dynamic, dynamic>?> fetchLecByClass({
    required String classId,
    required String courseId,
  }) async {
    try {
      final response = await dio.post(
        "learning-event-class/index",
        data: {
          "id": int.tryParse(classId),
          "course_id": int.tryParse(courseId),
        },
        options: Options(headers: header, validateStatus: (_) => true),
      );
      final body = response.data;
      debugPrint('[RoasterRepo] fetch-lec-by-class classId=$classId courseId=$courseId status=${response.statusCode} bodyType=${body.runtimeType}');
      if (body == null) return null;

      // Endpoint returns a bare JSON array or a wrapped map — handle both.
      List<dynamic>? items;
      if (body is List) {
        items = body;
      } else if (body is Map) {
        final inner = body['payload'] ?? body['data'] ?? body;
        if (inner is List) {
          items = inner;
        } else if (inner is Map) {
          return inner as Map<dynamic, dynamic>;
        }
      }
      if (items == null || items.isEmpty) return null;

      // Prefer the LEC that has a recording link; otherwise take the first.
      for (final lec in items) {
        if (lec is Map) {
          final rec = lec['training_session_recording_link']?.toString() ?? '';
          if (rec.isNotEmpty) {
            debugPrint('[RoasterRepo] found LEC with recording link: $rec');
            return lec as Map<dynamic, dynamic>;
          }
        }
      }
      return items.first is Map ? items.first as Map<dynamic, dynamic> : null;
    } catch (e) {
      debugPrint('[RoasterRepo] fetch-lec-by-class error (classId=$classId): $e');
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
