import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/features/courses/viewmodel/offline_view_model.dart';

/// True when opening a course's detail screen for [courseId] would fail -
/// there's no real (or manually toggled) internet connection AND the course
/// was never saved offline, so there's nothing cached to fall back to.
/// Course-listing screens (dashboard, catalog, my courses, calendar) use
/// this to disable their "View Course" button instead of letting the
/// learner tap into a course detail page that can only show an error.
bool isViewCourseDisabled(WidgetRef ref, int? courseId) {
  final isManualOffline = ref.watch(OfflineModeNotifier.provider);
  final connectionVM = ref.watch(InternetConnectionProvider.provider);
  final isOnline = !isManualOffline && connectionVM.isConnected;
  if (isOnline) return false;
  final offlineVM = ref.watch(OfflineViewModel.provider);
  return !offlineVM.isAvailableById(courseId);
}
