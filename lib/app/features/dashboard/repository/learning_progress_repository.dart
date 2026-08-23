import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/dashboard/model/learning_progress_model.dart';

class LearningProgressRepository with RepoNetworkHelper {
  LearningProgressRepository(this.config);

  static final provider = Provider<LearningProgressRepository>((ref) {
    return LearningProgressRepository(
      ref.watch(ServerProvider.repoConfigProvider),
    );
  });

  @override
  final RepoNetworkConfig config;

  Future<LearningProgressData> fetch({required int userId}) async {
    final raw = await getRequest(
      'lms-screen/learning-progress',
      queryParameters: {'user_id': userId},
      cacheType: RequestCacheType.none,
    );
    final json =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    // TEMP: dump the raw learning-progress response to check whether the
    // API sends any quote/motivational-text field.
    if (kDebugMode) debugPrint('[LearningProgressRepository] raw response: ${jsonEncode(json)}');
    return LearningProgressData.fromJson(json);
  }
}
