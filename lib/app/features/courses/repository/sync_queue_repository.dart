import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/provider/local_storage_provider.dart';

const _kQueueKey = 'pending_completions_queue';

/// A single lesson-completion that could not be sent to the server
/// because the device was offline at the time.
class PendingCompletion {
  final String courseId;
  final String classId;
  final String userId;
  final String learningEventClassId;
  final DateTime queuedAt;

  const PendingCompletion({
    required this.courseId,
    required this.classId,
    required this.userId,
    required this.learningEventClassId,
    required this.queuedAt,
  });

  Map<String, dynamic> toJson() => {
        'course_id': courseId,
        'class_id': classId,
        'user_id': userId,
        'learning_event_class_id': learningEventClassId,
        'queued_at': queuedAt.toIso8601String(),
      };

  factory PendingCompletion.fromJson(Map<String, dynamic> json) =>
      PendingCompletion(
        courseId: json['course_id'] as String,
        classId: json['class_id'] as String,
        userId: json['user_id'] as String,
        learningEventClassId: json['learning_event_class_id'] as String,
        queuedAt: DateTime.parse(json['queued_at'] as String),
      );
}

/// Local Hive-backed queue for lesson completions that failed while offline.
class SyncQueueRepository {
  static final provider = Provider<SyncQueueRepository>((ref) {
    return SyncQueueRepository(ref.watch(LocalStorage.provider));
  });

  SyncQueueRepository(this._storage);

  final LocalStorage _storage;

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<List<PendingCompletion>> getQueue() async {
    final raw = await _storage.getString(_kQueueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => PendingCompletion.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> getPendingCount() async {
    final q = await getQueue();
    return q.length;
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<void> enqueue(PendingCompletion item) async {
    final queue = await getQueue();
    queue.add(item);
    await _persist(queue);
  }

  /// Remove a specific item (matched by all key fields).
  Future<void> remove(PendingCompletion item) async {
    final queue = await getQueue();
    queue.removeWhere(
      (e) =>
          e.courseId == item.courseId &&
          e.classId == item.classId &&
          e.userId == item.userId &&
          e.learningEventClassId == item.learningEventClassId,
    );
    await _persist(queue);
  }

  /// Wipe the entire queue (e.g. after a successful full sync or on logout).
  Future<void> clear() async {
    await _storage.setString(_kQueueKey, null);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _persist(List<PendingCompletion> queue) async {
    final encoded = jsonEncode(queue.map((e) => e.toJson()).toList());
    await _storage.setString(_kQueueKey, encoded);
  }
}
