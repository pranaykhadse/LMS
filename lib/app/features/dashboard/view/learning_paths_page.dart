import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/features/dashboard/model/learning_path.dart';
import 'package:lms/app/features/dashboard/view/view_competency_page.dart';
import 'package:lms/app/features/dashboard/viewmodel/learning_paths_view_model.dart';

const _purple = Color(0xFF5756C9);
const _ink = Color(0xFF172033);
const _muted = Color(0xFF7C879D);
const _bg = Color(0xFFF5F7FC);
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
      body: Column(
        children: [
          _SearchBar(
            controller: _searchController,
            onSearch: _onSearch,
          ),
          Expanded(
            child: _Body(
              state: state,
              onRetry: () => notifier.fetch(),
              onReset: _onReset,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Search bar ───────────────────────────────────────────────────────────────

class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.controller, required this.onSearch});
  final TextEditingController controller;
  final VoidCallback onSearch;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
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
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => widget.onSearch(),
              decoration: InputDecoration(
                hintText: 'Search learning paths...',
                hintStyle: const TextStyle(color: _muted, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: _muted, size: 22),
                suffixIcon: _hasText
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: _muted, size: 20),
                        onPressed: () {
                          widget.controller.clear();
                          widget.onSearch();
                        },
                      )
                    : null,
                filled: true,
                fillColor: _bg,
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
            color: _purple,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: widget.onSearch,
              borderRadius: BorderRadius.circular(10),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.search_rounded, color: Colors.white, size: 22),
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
  const _Body({required this.state, required this.onRetry, required this.onReset});
  final LearningPathsState state;
  final VoidCallback onRetry;
  final VoidCallback onReset;

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
            _ResetButton(onTap: onReset),
            const SizedBox(height: 18),
            const Text(
              'Learning Paths',
              style: TextStyle(color: _sectionTitle, fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
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
            const SizedBox(height: 16),
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
                children: [
                  for (var i = 0; i < state.paths.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: Color(0xFFEFF1F5)),
                    _PathRow(index: i + 1, path: state.paths[i]),
                  ],
                ],
              ),
            ),
            const AppFooter(),
          ],
        );
    }
  }
}

// ─── Reset button ───────────────────────────────────────────────────────────

class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: _purple,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.undo_rounded, color: Colors.white, size: 20),
          ),
        ),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '${widget.index}.',
                  style: const TextStyle(color: _muted, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.path.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        height: 1.3,
                      ),
                    ),
                    if (widget.path.groupName.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        widget.path.groupName,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: _purple,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: Icon(
                      _expanded ? Icons.remove_rounded : Icons.add_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
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
                  child: OutlinedButton.icon(
                    onPressed: () => _openViewCompetency(
                      context,
                      learningPathId: pathId,
                      competency: competency.name,
                    ),
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 14),
                    label: const Text('View'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _purple,
                      side: const BorderSide(color: _purple),
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
                    ),
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
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
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(backgroundColor: _purple),
                child: const Text(
                  'Try Again',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

