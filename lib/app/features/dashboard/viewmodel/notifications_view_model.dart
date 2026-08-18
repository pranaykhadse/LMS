import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/dashboard/model/notification_model.dart';
import 'package:lms/app/features/dashboard/repository/notifications_repository.dart';

class NotificationsState {
  const NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
  });

  final List<NotificationItem> notifications;
  final bool isLoading;
  final String? error;

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  NotificationsState copyWith({
    List<NotificationItem>? notifications,
    bool? isLoading,
    String? error,
  }) =>
      NotificationsState(
        notifications: notifications ?? this.notifications,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class NotificationsViewModel extends StateNotifier<NotificationsState> {
  NotificationsViewModel({
    required this.repository,
    required this.userId,
  }) : super(const NotificationsState()) {
    fetch();
  }

  // Not autoDispose — badge must persist while AppBar is visible.
  static final provider =
      StateNotifierProvider<NotificationsViewModel, NotificationsState>((ref) {
    final userId = ref.watch(AuthStateNotifier.provider)?.user?.id;
    return NotificationsViewModel(
      repository: ref.watch(NotificationsRepository.provider),
      userId: userId,
    );
  });

  static final unreadCountProvider = Provider<int>((ref) {
    return ref.watch(provider).unreadCount;
  });

  final NotificationsRepository repository;
  final int? userId;

  // Client-generated notifications (download status, learning-event
  // reminders, ...) that have no backend counterpart. Kept separately so a
  // server fetch() re-merges them back in instead of wiping them out - see
  // _merge below.
  final List<NotificationItem> _localNotifications = [];

  // Which learning-event sessions a reminder has already been shown for
  // this app session, so re-loading Dashboard's upcoming-sessions list
  // doesn't spam the same reminder on every fetch.
  final Set<String> _remindedSessionIds = {};

  Future<void> fetch() async {
    if (userId == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await repository.fetch(userId: userId!);
      if (!mounted) return;
      state = state.copyWith(notifications: _merge(items), isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  List<NotificationItem> _merge(List<NotificationItem> serverItems) {
    final serverIds = serverItems.map((n) => n.id).toSet();
    final localOnly =
        _localNotifications.where((n) => !serverIds.contains(n.id));
    final merged = [...localOnly, ...serverItems];
    merged.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return merged;
  }

  Future<String?> markAllAsRead() async {
    // Optimistic update — flip all to read in UI immediately.
    final updated = state.notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    state = state.copyWith(notifications: updated);
    for (var i = 0; i < _localNotifications.length; i++) {
      _localNotifications[i] = _localNotifications[i].copyWith(isRead: true);
    }
    // Persist to backend.
    try {
      await repository.markAllRead();
      return null;
    } catch (_) {
      return 'Failed to mark all notifications as read. Please try again.';
    }
  }

  Future<String?> markOneAsRead(String id) async {
    // Optimistic update.
    final updated = state.notifications
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
    state = state.copyWith(notifications: updated);
    final idx = _localNotifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _localNotifications[idx] = _localNotifications[idx].copyWith(isRead: true);
    }
    // Persist to backend.
    try {
      await repository.markOneRead(id);
      return null;
    } catch (_) {
      return 'Failed to mark notification as read. Please try again.';
    }
  }

  Future<String?> deleteOne(String id) async {
    final updated = state.notifications.where((n) => n.id != id).toList();
    state = state.copyWith(notifications: updated);
    _localNotifications.removeWhere((n) => n.id == id);
    try {
      await repository.deleteOne(id);
      return null;
    } catch (_) {
      return 'Failed to delete notification. Please try again.';
    }
  }

  /// Adds a client-generated notification (download status, learning-event
  /// reminder, ...) to the top of the list. No-ops if a notification with
  /// the same [NotificationItem.id] already exists, so callers can call
  /// this idempotently (e.g. on every Dashboard refresh) without spamming
  /// duplicates.
  void addLocal(NotificationItem item) {
    final alreadyExists = state.notifications.any((n) => n.id == item.id);
    if (alreadyExists) return;
    _localNotifications.insert(0, item);
    state = state.copyWith(notifications: [item, ...state.notifications]);
  }

  bool hasRemindedSession(String sessionKey) =>
      _remindedSessionIds.contains(sessionKey);

  void markSessionReminded(String sessionKey) =>
      _remindedSessionIds.add(sessionKey);
}
