import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/features/courses/repository/roaster_repository.dart';
import 'package:lms/app/features/courses/repository/sync_queue_repository.dart';

/// Manages the sync of offline-queued lesson completions back to the server.
///
/// Responsibilities
/// ────────────────
/// • Exposes [pendingCount] so the UI can show a badge.
/// • Exposes [isSyncing] for a loading indicator.
/// • [sync()] iterates the queue and calls [RoasterRepository.saveRoaster]
///   for each item, removing successfully synced entries one by one.
/// • Auto-syncs when connectivity is restored (listens to
///   [InternetConnectionProvider]).
class SyncViewModel extends ChangeNotifier {
  static final provider = ChangeNotifierProvider<SyncViewModel>((ref) {
    return SyncViewModel(
      queueRepo: ref.watch(SyncQueueRepository.provider),
      roasterRepo: ref.watch(RoasterRepository.provider),
      connectionProvider: ref.watch(InternetConnectionProvider.provider),
    );
  });

  SyncViewModel({
    required this.queueRepo,
    required this.roasterRepo,
    required this.connectionProvider,
  }) {
    _refreshCount();
    // Auto-sync whenever the device comes back online.
    connectionProvider.addListener(_onConnectionChange);
  }

  final SyncQueueRepository queueRepo;
  final RoasterRepository roasterRepo;
  final InternetConnectionProvider connectionProvider;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  int _pendingCount = 0;
  int get pendingCount => _pendingCount;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Push every queued completion to the server.
  /// Safe to call when offline — it will be a no-op.
  Future<void> sync() async {
    if (_isSyncing) return;
    if (!connectionProvider.isConnected) return;

    _isSyncing = true;
    notifyListeners();

    try {
      final queue = await queueRepo.getQueue();
      for (final item in queue) {
        try {
          await Future.wait([
            roasterRepo.saveRoaster(
              item.courseId,
              item.classId,
              item.userId,
              item.learningEventClassId,
            ),
            roasterRepo.markLearningEventCompletion(
              item.courseId,
              item.classId,
              item.userId,
              item.learningEventClassId,
            ),
          ]);
          await queueRepo.remove(item);
        } catch (_) {
          // Keep item in queue if the individual call fails.
        }
      }
      _lastSyncTime = DateTime.now();
    } finally {
      _isSyncing = false;
      await _refreshCount();
    }
  }

  /// Reload the pending count from the queue (call after enqueueing).
  Future<void> refreshCount() => _refreshCount();

  // ── Internal ──────────────────────────────────────────────────────────────

  void _onConnectionChange(bool isConnected) {
    // Always notify so OfflineBanner and any other UI watching this VM
    // rebuilds immediately when connectivity changes in either direction.
    notifyListeners();
    if (isConnected) sync();
  }

  Future<void> _refreshCount() async {
    _pendingCount = await queueRepo.getPendingCount();
    notifyListeners();
  }

  @override
  void dispose() {
    connectionProvider.removeListener(_onConnectionChange);
    super.dispose();
  }
}
