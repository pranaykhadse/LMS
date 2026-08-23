import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import '../model/mentor_modal.dart';

class MentorRepository with RepoNetworkHelper {
  MentorRepository(this.config);

  static final provider = Provider<MentorRepository>((ref) {
    return MentorRepository(ref.watch(ServerProvider.repoConfigProvider));
  });

  @override
  final RepoNetworkConfig config;

  /// Fetch mentor / supervisor modal data for the authenticated user.
  Future<MentorModalData> fetch({required int userId, String type = 'mentor'}) async {
    // Debug/logging - print unconditionally to ensure visibility in all build modes
    print('[MentorRepository] fetch called with userId=$userId, type=$type');
    if (kDebugMode) {
      debugPrint('[MentorRepository] fetch called with userId=$userId, type=$type');
    }

    final response = await getRequest(
      'lms-screen/get-mentor-supervisor',
      queryParameters: {'user_id': userId, 'type': type},
      cacheType: RequestCacheType.none,
    );

    final data = Map<String, dynamic>.from(response as Map);
    // Always print raw response so it appears in non-debug logs during testing
    print('[MentorRepository] raw response: ${data.toString()}');
    if (kDebugMode) {
      debugPrint('[MentorRepository] raw response: ${data.toString()}');
    }

    if (data['status']?.toString() != '1') {
      throw Exception(data['message']?.toString() ?? 'Unable to load mentor modal.');
    }

    final payload = data['payload'] is Map ? Map<String, dynamic>.from(data['payload'] as Map) : <String, dynamic>{};
    // Always print payload for visibility
    print('[MentorRepository] payload: ${payload.toString()}');
    if (kDebugMode) {
      debugPrint('[MentorRepository] payload: ${payload.toString()}');
    }
    return MentorModalData.fromJson(payload);
  }

  /// Confirms/updates the mentor or supervisor info the user reviewed in
  /// the dashboard's confirm modal.
  Future<void> confirm({
    required String type,
    required String firstname,
    required String lastname,
    required String email,
  }) async {
    final response = await post(
      'lms-screen/confirm-mentor-supervisor',
      data: {
        'type': type,
        'firstname': firstname,
        'lastname': lastname,
        'email': email,
      },
      cacheType: RequestCacheType.none,
    );

    final data = Map<String, dynamic>.from(response as Map);
    if (data['status']?.toString() != '1') {
      throw Exception(data['message']?.toString() ?? 'Unable to confirm $type details.');
    }
  }
}
