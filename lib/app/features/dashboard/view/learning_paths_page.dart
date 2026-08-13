import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/core/views/elements/unauthorized_handler.dart';
import 'package:lms/app/features/dashboard/model/learning_path.dart';
import 'package:lms/app/features/dashboard/view/widgets/offline_courses_section.dart' show isEffectivelyOffline;
import 'package:lms/app/features/dashboard/view/view_competency_page.dart';
import 'package:lms/app/features/dashboard/viewmodel/learning_paths_view_model.dart';

const _purple = FigmaTokens.primaryPurple;
const _ink = FigmaTokens.cardTitles;
const _muted = FigmaTokens.noteBodyText;
const _bg = FigmaTokens.pageBackground;
const _sectionTitle = Color(0xFFB0006D);

void _openViewCompetency(
  BuildContext context, {
  required int learningPathId,
  required String competency,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ViewCompetencyPage(
        learningPathId: learningPathId,
        competency: competency,
      ),
    ),
  );
}

class LearningPathsPage extends ConsumerStatefulWidget {
  const LearningPathsPage({super.key});

  @override
  ConsumerState<LearningPathsPage> createState() => _LearningPathsPageState();
}

class _LearningPathsPageState extends ConsumerState<LearningPathsPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    ref
        .read(LearningPathsViewModel.provider.notifier)
        .fetch(name: _searchController.text.trim().isEmpty ? null : _searchController.text.trim());
  }

  void _onReset() {
    _searchController.clear();
    ref.read(LearningPathsViewModel.provider.notifier).fetch();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(LearningPathsViewModel.provider);
    final notifier = ref.read(LearningPathsViewModel.provider.notifier);

    return AppScaffold(
      backgroundColor: _bg,
      title: 'Learning Paths',
      selectedLabel: 'Learning Paths',
      onRefresh: () => notifier.fetch(
        name: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      ),
      body: Column(
        children: [
          _SearchBar(
            controller: _searchController,
            onSearch: _onSearch,
            onReset: _onReset,
          ),
          Expanded(
            child: _Body(
              state: state,
              onRetry: () => notifier.fetch(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Search bar ───────────────────────────────────────────────────────────────

class _SearchBar extends ConsumerStatefulWidget {
  const _SearchBar({
    required this.controller,
    required this.onSearch,
    required this.onReset,
  });
  final TextEditingController controller;
  final VoidCallback onSearch;
  final VoidCallback onReset;

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  Widget build(BuildContext context) {
    // Search hits the live API with no offline fallback - offering it while
    // there's no real connection just invites a tap that can only fail, the
    // same reasoning as RetryButton (see lib/app/core/views/elements).
    final offline = isEffectivelyOffline(ref);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              enabled: !offline,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => widget.onSearch(),
              decoration: InputDecoration(
                hintText: offline ? "You're offline" : 'Search learning paths...',
                hintStyle: const TextStyle(color: _muted, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: _muted, size: 22),
                suffixIcon: _hasText && !offline
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: _muted, size: 20),
                        onPressed: () {
                          widget.controller.clear();
                          widget.onSearch();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: offline ? _muted.withValues(alpha: 0.4) : _purple,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: offline ? null : widget.onReset,
              borderRadius: BorderRadius.circular(10),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.undo_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.onRetry});
  final LearningPathsState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    switch (state.providerState) {
      case DataProviderState.loading:
      case DataProviderState.idle:
        return const Center(child: CircularProgressIndicator(color: _purple));
      case DataProviderState.error:
        return _ErrorView(
          message: state.error ?? 'Unable to load learning paths.',
          onRetry: onRetry,
        );
      case DataProviderState.data:
        if (state.paths.isEmpty) return const _EmptyState();
        final total = state.paths.length;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 6)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Learning Paths',
                          style: TextStyle(
                              color: _sectionTitle, fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(color: _muted, fontSize: 12.5),
                            children: [
                              const TextSpan(text: 'Showing '),
                              TextSpan(
                                text: '1-$total',
                                style: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
                              ),
                              const TextSpan(text: ' of '),
                              TextSpan(
                                text: '$total',
                                style: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
                              ),
                              const TextSpan(text: ' items.'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _TableHeaderRow(),
                  const Divider(height: 1, color: FigmaTokens.cardBorders),
                  for (var i = 0; i < state.paths.length; i++) ...[
                    _PathRow(index: i + 1, path: state.paths[i]),
                    if (i != state.paths.length - 1)
                      const Divider(height: 1, color: FigmaTokens.cardBorders),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const AppFooter(),
          ],
        );
    }
  }
}

// ─── Table header row ───────────────────────────────────────────────────────

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFEEEEEE)],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: const Row(
        children: [
          SizedBox(width: 30),
          SizedBox(width: 10),
          Expanded(
            flex: 6,
            child: Text(
              'Learning Path',
              style: TextStyle(color: _purple, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Group',
              style: TextStyle(color: _purple, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Learning path row ────────────────────────────────────────────────────────

class _PathRow extends StatefulWidget {
  const _PathRow({required this.index, required this.path});
  final int index;
  final LearningPath path;

  @override
  State<_PathRow> createState() => _PathRowState();
}

class _PathRowState extends State<_PathRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: _purple,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: Icon(
                      _expanded ? Icons.remove_rounded : Icons.add_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 6,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.index}.',
                      style: const TextStyle(color: _purple, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.path.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _purple,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: widget.path.groupName.isEmpty
                    ? const SizedBox.shrink()
                    : Text(
                        widget.path.groupName,
                        style: const TextStyle(color: _purple, fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: _CompetencyPreview(path: widget.path),
          ),
      ],
    );
  }
}

class _CompetencyPreview extends StatelessWidget {
  const _CompetencyPreview({required this.path});
  final LearningPath path;

  @override
  Widget build(BuildContext context) {
    final competencies = path.competencies;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (competencies.isEmpty)
            Text(
              path.courses.isEmpty
                  ? 'No competency details available.'
                  : 'Courses: ${path.courses.map((c) => c.name).join(', ')}',
              style: const TextStyle(color: _ink, fontSize: 12.5, height: 1.4),
            )
          else
            for (var i = 0; i < competencies.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _CompetencyPreviewRow(
                index: i + 1,
                pathId: path.id,
                competency: competencies[i],
              ),
            ],
        ],
      ),
    );
  }
}

class _CompetencyPreviewRow extends StatelessWidget {
  const _CompetencyPreviewRow({
    required this.index,
    required this.pathId,
    required this.competency,
  });
  final int index;
  final int pathId;
  final LearningPathCompetency competency;

  @override
  Widget build(BuildContext context) {
    final courses = competency.courseNames;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(4)),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: _ink, fontSize: 12.5, fontWeight: FontWeight.w700),
                  children: [
                    const TextSpan(text: 'Competency: '),
                    TextSpan(
                      text: competency.name.isEmpty ? '—' : competency.name,
                      style: const TextStyle(color: _purple, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (courses.isNotEmpty) ...[
                const SizedBox(height: 3),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: _ink, fontSize: 12.5, fontWeight: FontWeight.w700),
                    children: [
                      const TextSpan(text: 'Courses: '),
                      TextSpan(
                        text: courses.join(', '),
                        style: const TextStyle(color: _muted, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
              if (competency.competencyType.isNotEmpty) ...[
                const SizedBox(height: 3),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: _ink, fontSize: 12.5, fontWeight: FontWeight.w700),
                    children: [
                      const TextSpan(text: 'Type: '),
                      TextSpan(
                        text: competency.competencyType.toUpperCase(),
                        style: const TextStyle(color: _muted, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
              if (competency.name.isNotEmpty) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: HoverBuilder(
                    builder: (context, hovering) {
                      final onPressed = () => _openViewCompetency(
                            context,
                            learningPathId: pathId,
                            competency: competency.name,
                          );
                      const shape = StadiumBorder();
                      const textStyle =
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5);
                      return hovering
                          ? ElevatedButton.icon(
                              onPressed: onPressed,
                              icon: const Icon(Icons.remove_red_eye_outlined,
                                  size: 14, color: Colors.white),
                              label: const Text('View'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _purple,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size(0, 30),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: shape,
                                textStyle: textStyle,
                              ),
                            )
                          : OutlinedButton.icon(
                              onPressed: onPressed,
                              icon: const Icon(Icons.remove_red_eye_outlined, size: 14),
                              label: const Text('View'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _purple,
                                side: const BorderSide(color: _purple),
                                minimumSize: const Size(0, 30),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: shape,
                                textStyle: textStyle,
                              ),
                            );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFF0ECFF),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(Icons.account_tree_outlined, color: _purple, size: 52),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Learning Paths',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Learning paths available to you will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends ConsumerWidget {
  const _ErrorView({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unauthorized = isUnauthorizedError(message);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _muted, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted),
            ),
            const SizedBox(height: 16),
            if (unauthorized)
              ElevatedButton(
                onPressed: () => redirectToLoginOnSessionExpired(context, ref),
                style: ElevatedButton.styleFrom(backgroundColor: _purple),
                child: const Text('Log In Again', style: TextStyle(color: Colors.white)),
              )
            else if (onRetry != null)
              RetryButton(onRetry: onRetry!),
          ],
        ),
      ),
    );
  }
}

