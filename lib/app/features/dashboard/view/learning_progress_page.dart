import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/core/views/elements/unauthorized_handler.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/dashboard/model/learning_progress_model.dart';
import 'package:lms/app/features/dashboard/view/dashboard_page.dart';
import 'package:lms/app/features/dashboard/viewmodel/learning_progress_view_model.dart';

const _purple = FigmaTokens.primaryPurple;
const _muted = FigmaTokens.noteBodyText;

/// Learning Progress screen — opened via the play button in the app bar.
///
/// Renders the exact same content as [DashboardPage] (banner excluded)
/// by reusing [DashboardBody], which is already driven by
/// [LearningProgressViewModel]. This guarantees the two screens stay
/// pixel-identical without any duplicated widget code.
class LearningProgressPage extends ConsumerWidget {
  const LearningProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(LearningProgressViewModel.provider);

    return AppScaffold(
      backgroundColor: FigmaTokens.pageBackground,
      title: 'My Learning Progress',
      onRefresh: () => ref.read(LearningProgressViewModel.provider.notifier).fetch(),
      body: _Body(state: state),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});
  final DataState<LearningProgressData> state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (state.state) {
      case DataProviderState.loading:
      case DataProviderState.idle:
        return const Center(child: CircularProgressIndicator(color: _purple));
      case DataProviderState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: _muted),
                const SizedBox(height: 12),
                Text(
                  state.error ?? 'Unable to load progress.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, fontSize: 14),
                ),
                const SizedBox(height: 20),
                RetryButton(
                  errorMessage: state.error ?? '',
                  onRetry: () =>
                      ref.read(LearningProgressViewModel.provider.notifier).fetch(),
                ),
              ],
            ),
          ),
        );
      case DataProviderState.data:
        if (state.data == null) return const SizedBox.shrink();
        // Reuse the dashboard's body widget directly — same data, same UI,
        // no banner section (auth is not needed here since DashboardBody
        // only uses auth for the banner which we're skipping).
        return DashboardBody(
          auth: ref.watch(AuthStateNotifier.provider),
          state: state,
          onRefetchAll: () =>
              ref.read(LearningProgressViewModel.provider.notifier).fetch(),
          showBanner: false,
        );
    }
  }
}
