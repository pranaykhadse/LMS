import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';

class ReviewsRepository with RepoNetworkHelper {
  ReviewsRepository(this.config);

  static final provider = Provider<ReviewsRepository>((ref) {
    return ReviewsRepository(ref.watch(ServerProvider.repoConfigProvider));
  });

  @override
  final RepoNetworkConfig config;

  /// GET lms-screen/review-modal?course_id={id} - the Bearer-token-authed
  /// REST equivalent of the web app's cookie-session `course/load-reviews`
  /// route. Returns `payload.reviews_html`, a static server-rendered HTML
  /// fragment (`.rw-summary` + `.rw-card` list, or `.rw-empty`) - parsed
  /// by reviews_modal.dart, not here, since it's presentation-only markup
  /// tied to that one screen's rendering, not a reusable domain model.
  Future<String> fetchReviewsHtml(int courseId) async {
    final raw = await getRequest(
      'lms-screen/review-modal',
      queryParameters: {'course_id': courseId},
      cacheType: RequestCacheType.none,
    );
    final data =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    if (data['status']?.toString() != '1') {
      throw Exception(data['message']?.toString() ?? 'Unable to load reviews.');
    }
    final payload =
        data['payload'] is Map
            ? Map<String, dynamic>.from(data['payload'] as Map)
            : <String, dynamic>{};
    return payload['reviews_html']?.toString() ?? '';
  }
}
