import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/logic/data_state/paginated_data.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/courses/model/course_class.dart';
import 'package:lms/app/features/courses/repository/sync_queue_repository.dart';
import 'package:lms/app/features/courses/viewmodel/sync_view_model.dart';

import '../model/roaster.dart';
import '../repository/roaster_repository.dart';

class RoasterViewModel extends StateNotifier<PaginatedState<Roaster>> {
  static final provider = StateNotifierProvider.family
      .autoDispose<RoasterViewModel, PaginatedState<Roaster>, String?>((
        ref,
        courseId,
      ) {
        return RoasterViewModel(
          repository: ref.watch(RoasterRepository.provider),
          syncQueueRepo: ref.watch(SyncQueueRepository.provider),
          syncViewModel: ref.watch(SyncViewModel.provider),
          connectionProvider: ref.watch(InternetConnectionProvider.provider),
          isManualOffline: ref.watch(OfflineModeNotifier.provider),
          courseId: courseId,
          userId: ref.watch(AuthStateNotifier.provider)?.user?.id,
        );
      });

  final String? courseId;
  final int? userId;
  final RoasterRepository repository;
  final SyncQueueRepository syncQueueRepo;
  final SyncViewModel syncViewModel;
  final InternetConnectionProvider connectionProvider;
  final bool isManualOffline;

  bool get _isEffectivelyOffline =>
      isManualOffline || !connectionProvider.isConnected;

  RoasterViewModel({
    required this.repository,
    required this.syncQueueRepo,
    required this.syncViewModel,
    required this.connectionProvider,
    required this.isManualOffline,
    required this.courseId,
    required this.userId,
  }) : super(PaginatedState(data: DataState.idle(), pageInfo: null)) {
    fetch();
    // Automatically refetch after the sync queue is flushed so the
    // ClassStatusChip flips to "Completed" without the user navigating away.
    syncViewModel.addListener(_onSyncCompleted);
  }

  /// The [lastSyncTime] we last triggered a fetch for.
  /// Guards against re-fetching on every [SyncViewModel.notifyListeners] call
  /// (e.g. pending-count updates) — we only refetch when a new sync cycle
  /// actually finishes.
  DateTime? _lastFetchedSyncTime;

  void _onSyncCompleted() {
    if (!mounted) return;
    final syncTime = syncViewModel.lastSyncTime;
    if (!syncViewModel.isSyncing &&
        syncTime != null &&
        syncTime != _lastFetchedSyncTime) {
      _lastFetchedSyncTime = syncTime;
      fetch();
    }
  }

  @override
  void dispose() {
    syncViewModel.removeListener(_onSyncCompleted);
    super.dispose();
  }

  Future<void> fetch() async {
    if (!mounted) return;
    state = state.copyWith(data: DataState.loading());
    try {
      final data = await repository.getData(
        courseId: courseId ?? "",
        userId: userId?.toString() ?? "",
      );
      state = PaginatedState(
        data: DataState.onData(data.data),
        pageInfo: data.pageInfo,
      );
    } catch (e) {
      state = state.copyWith(data: DataState.onError(e.toString()));
    }
  }

  /// Mark a lesson as completed.
  ///
  /// When offline the completion is saved to the local sync queue and will
  /// automatically be pushed to the server the next time the device goes
  /// online ([SyncViewModel] handles that).
  Future<void> markAsRead(CourseClass courseClass) async {
    if (_isEffectivelyOffline) {
      // Queue the completion locally.
      await syncQueueRepo.enqueue(
        PendingCompletion(
          courseId: courseId ?? "",
          classId: courseClass.classInfo?.id ?? "",
          userId: userId?.toString() ?? "",
          learningEventClassId: courseClass.id ?? "",
          queuedAt: DateTime.now(),
        ),
      );
      // Notify SyncViewModel so it refreshes its pending count badge.
      await syncViewModel.refreshCount();
      return;
    }

    // Online path — call API immediately.
    try {
      await repository.saveRoaster(
        courseId ?? "",
        courseClass.classInfo?.id ?? "",
        userId?.toString() ?? "",
        courseClass.id ?? "",
      );
    } catch (_) {
      // Ignore API errors — still refetch so the UI reflects server state.
    }
    fetch();
  }

  Roaster? getForClass(CourseClass courseClass) {
    return state.data.data?.firstWhereOrNull(
      (value) => value.classId?.toString() == courseClass.classId?.toString(),
    );
  }
}
