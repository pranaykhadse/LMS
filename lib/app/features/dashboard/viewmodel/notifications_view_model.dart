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

  Future<void> fetch() async {
    if (userId == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await repository.fetch(userId: userId!);
      state = state.copyWith(notifications: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void markAllAsRead() {
    final updated = state.notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    state = state.copyWith(notifications: updated);
  }

  void markOneAsRead(String id) {
    final updated = state.notifications
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
    state = state.copyWith(notifications: updated);
  }
}
