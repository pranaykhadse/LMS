import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
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

      if (!mounted) return;
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
    debugPrint('[RoasterVM] markAsRead called — classId=${courseClass.classId}  offline=$_isEffectivelyOffline');
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

    // Online path.
    final cId = courseId ?? "";
    final clId = courseClass.classId ?? "";
    final uId = userId?.toString() ?? "";

    // courseClass.id (learning_event_class_id) is often null on mobile because
    // the mobile course-fetch API doesn't populate it. Fall back to the value
    // carried by the already-fetched roaster record for this class, which DOES
    // contain learning_event_class_id from fetch-user-roaster.
    final existingRoaster = getForClass(courseClass);
    final lecId = (courseClass.id?.isNotEmpty == true)
        ? courseClass.id!
        : (existingRoaster?.learningEventClassId?.toString() ?? "");

    debugPrint(
      '[RoasterVM] markAsRead — clId=$clId  lecId=$lecId  '
      '(courseClass.id=${courseClass.id}  '
      'roasterLecId=${existingRoaster?.learningEventClassId})',
    );

    // Use the same API the web platform uses. The server returns the updated
    // Roaster (status="3") directly, so we apply it to local state immediately
    // without a loading flash and then confirm with a background fetch.
    try {
      final roaster = await repository.markLearningEventCompletion(
        cId,
        clId,
        uId,
        learningEventClassId: lecId.isNotEmpty ? lecId : null,
      );
      // Apply the server-returned roaster (or fall back to optimistic update).
      if (roaster != null) {
        _applyRoaster(roaster);
      } else {
        _markClassCompleted(clId);
      }
      _fetchInBackground();
    } catch (e, stack) {
      debugPrint('[RoasterVM] markLearningEventCompletion error: $e\n$stack');
      // Fall back to saveRoaster so completion still works even if the
      // learning-event-completion endpoint returns 404.
      try {
        await repository.saveRoaster(cId, clId, uId, lecId);
        debugPrint('[RoasterVM] saveRoaster succeeded for classId=$clId');
        _markClassCompleted(clId);
        // Do NOT call _fetchInBackground here: saveRoaster may take time to
        // propagate on the server, so an immediate re-fetch would overwrite
        // the optimistic status=3 state with stale data.
        // The state will be confirmed on the next natural page load.
      } catch (e2, stack2) {
        debugPrint('[RoasterVM] saveRoaster fallback error: $e2\n$stack2');
        fetch();
      }
    }
  }

  /// Applies a server-returned [Roaster] directly to local state.
  /// Replaces an existing record for the same classId, or appends if none exists.
  /// Preserves learningEventClassId and learningEventClass from the old record when
  /// the new one (returned by markLearningEventCompletion) doesn't carry them.
  void _applyRoaster(Roaster roaster) {
    if (!mounted) return;
    final classId = roaster.classId;
    final existing = state.data.data ?? [];
    final updated = existing.map((r) {
      if (r.classId?.toString() != classId?.toString()) return r;
      final preservedLecId = roaster.learningEventClassId ?? r.learningEventClassId;
      final preservedLec   = roaster.learningEventClass   ?? r.learningEventClass;
      return roaster.copyWith(
        learningEventClassId: preservedLecId,
        learningEventClass:   preservedLec,
      );
    }).toList();
    if (!existing.any((r) => r.classId?.toString() == classId?.toString())) {
      updated.add(roaster);
    }
    state = PaginatedState(
      data: DataState.onData(updated),
      pageInfo: state.pageInfo,
    );
  }

  /// Optimistically marks a class as completed in local state so the chip
  /// flips immediately after saveRoaster succeeds, without waiting for
  /// fetch-user-roaster to return the updated record.
  void _markClassCompleted(String classId) {
    if (!mounted) return;
    final existing = state.data.data ?? [];
    final updated = existing.map((r) {
      if (r.classId?.toString() == classId) {
        return r.copyWith(status: '3', isActive: '1');
      }
      return r;
    }).toList();

    // If no existing roaster for this class, add a new one.
    if (!existing.any((r) => r.classId?.toString() == classId)) {
      updated.add(Roaster(
        courseId: courseId,
        classId: classId,
        userId: userId?.toString(),
        status: '3',
        isActive: '1',
      ));
    }

    state = PaginatedState(
      data: DataState.onData(updated),
      pageInfo: state.pageInfo,
    );
  }

  /// Fetches fresh data from the server without wiping the existing local state
  /// first (avoids the DataState.loading null-data flash that clears chips).
  Future<void> _fetchInBackground() async {
    if (!mounted) return;
    try {
      final data = await repository.getData(
        courseId: courseId ?? "",
        userId: userId?.toString() ?? "",
      );
      if (!mounted) return;
      state = PaginatedState(
        data: DataState.onData(data.data),
        pageInfo: data.pageInfo,
      );
    } catch (_) {
      // Swallow — the optimistic state is still correct.
    }
  }

  Roaster? getForClass(CourseClass courseClass) {
    final matches = state.data.data
        ?.where((r) => r.classId?.toString() == courseClass.classId?.toString())
        .toList();
    if (matches == null || matches.isEmpty) return null;

    // Warn when multiple roasters exist for the same class so we can diagnose
    // status conflicts between Flutter and the website.
    if (matches.length > 1) {
      debugPrint(
        '[RoasterVM] ${matches.length} roasters for classId=${courseClass.classId}: '
        '${matches.map((r) => 'id=${r.id}/status=${r.status}').join(', ')}',
      );
    }

    // Always return the MOST RECENTLY CREATED record (highest id).
    // The old strategy of preferring status=3 caused stale "Completed" chips
    // to survive when the server later downgraded the record to status=2 (Started).
    return matches.reduce((a, b) {
      final aId = int.tryParse(a.id ?? '0') ?? 0;
      final bId = int.tryParse(b.id ?? '0') ?? 0;
      return aId >= bId ? a : b;
    });
  }
}
