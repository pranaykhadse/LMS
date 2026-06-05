import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
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

    // Log Virtual Class roasters to verify training_session_recording_link
    debugPrint('══ [fetch-user-roaster] courseId=$courseId');
    if (response is Map) {
      final items = response['payload'];
      if (items is List) {
        for (final item in items) {
          if (item is! Map) continue;
          final classData = item['class'];
          final classType = classData is Map ? classData['type']?.toString() : null;
          if (classType != '3') continue; // log only Virtual Class events
          final lec = item['learningEventClass'] ?? item['learning_event_class'];
          final recLink = lec is Map ? lec['training_session_recording_link'] : null;
          debugPrint('   class_id=${item['class_id']}  class_name=${classData is Map ? classData['name'] : '?'}');
          debugPrint('   learning_event_class_id=${item['learning_event_class_id']}');
          debugPrint('   learningEventClass is Map: ${lec is Map}');
          debugPrint('   training_session_recording_link: $recLink');
          debugPrint('   ──────────────────────────────');
        }
      }
    }
    debugPrint('══════════════════════════════════════');

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
    // Only include learning_event_class_id when it resolves to a valid non-zero int.
    // Omitting it entirely (rather than sending null/0) matches the web platform's
    // behaviour and avoids server-side validation errors when the ID isn't known.
    final raw = <String, dynamic>{
      "course_id": int.tryParse(courseId),
      "class_id": int.tryParse(classId),
      "user_id": int.tryParse(userId),
      "course_status": 3,
    };
    final lecIdInt = int.tryParse(learningEventClassId ?? "");
    if (lecIdInt != null && lecIdInt != 0) {
      raw["learning_event_class_id"] = lecIdInt;
    }
    raw.removeWhere((_, v) => v == null || v == 0 || v == '');

    final response = await post(
      "learning-event/learning-event-completion",
      cacheType: RequestCacheType.none,
      data: raw,
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
