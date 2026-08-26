import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/features/courses/view/widgets/course_grid_card.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/features/courses/model/calendar_event.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/view/widgets/course_view_availability.dart';
import 'package:lms/app/features/courses/viewmodel/calendar_view_model.dart';

const _calPurple = FigmaTokens.primaryPurple;
const _calNavy = FigmaTokens.cardTitles;
const _calMuted = FigmaTokens.noteBodyText;
const _calBg = FigmaTokens.pageBackground;

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

class CalendarCoursesPage extends ConsumerStatefulWidget {
  const CalendarCoursesPage({super.key});

  @override
  ConsumerState<CalendarCoursesPage> createState() =>
      _CalendarCoursesPageState();
}

class _CalendarCoursesPageState extends ConsumerState<CalendarCoursesPage> {
  CalendarFormat _format = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime _weekAnchor = DateTime.now();

  Map<DateTime, List<CalendarEvent>> _buildEventMap(
    List<CalendarEvent> events,
  ) {
    final map = <DateTime, List<CalendarEvent>>{};
    for (final e in events) {
      final key = _dateOnly(e.startDate);
      map.putIfAbsent(key, () => []).add(e);
    }
    return map;
  }

  List<CalendarEvent> _eventsForDay(
    Map<DateTime, List<CalendarEvent>> map,
    DateTime day,
  ) => map[_dateOnly(day)] ?? [];

  void _openEventDetails(CalendarEvent event) {
    showDialog(
      context: context,
      builder: (_) => _EventDetailsDialog(event: event),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calendarState = ref.watch(CalendarViewModel.provider);
    final allEvents =
        calendarState.state == DataProviderState.data
            ? (calendarState.data?.events ?? const <CalendarEvent>[])
            : const <CalendarEvent>[];

    final eventMap = _buildEventMap(allEvents);
    final selectedEvents =
        _selectedDay != null
            ? _eventsForDay(eventMap, _selectedDay!)
            : <CalendarEvent>[];

    // Upcoming events for the default "no date selected" view
    final upcoming = List<CalendarEvent>.from(allEvents)
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

    return AppScaffold(
      backgroundColor: _calBg,
      title: 'Course Calendar',
      centerTitle: true,
      onRefresh: () => ref.read(CalendarViewModel.provider.notifier).fetch(),
      bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            color: _calPurple,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 30,
              child: Material(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() {
                    _format = _format == CalendarFormat.month
                        ? CalendarFormat.week
                        : CalendarFormat.month;
                  }),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        _format == CalendarFormat.month ? 'Weekly View' : 'Monthly View',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      body: _format == CalendarFormat.week
          ? _buildWeekView(eventMap)
          : _buildMonthView(eventMap, selectedEvents, upcoming, calendarState),
    );
  }

  Widget _buildMonthView(
    Map<DateTime, List<CalendarEvent>> eventMap,
    List<CalendarEvent> selectedEvents,
    List<CalendarEvent> upcoming,
    DataState<CalendarViewResult> calendarState,
  ) {
    return Column(
        children: [
          // ── Calendar card ───────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D172033),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: TableCalendar<CalendarEvent>(
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              focusedDay: _focusedDay,
              calendarFormat: _format,
              eventLoader: (day) => _eventsForDay(eventMap, day),
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = isSameDay(_selectedDay, selectedDay)
                      ? null // tap again to deselect
                      : selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (f) => setState(() => _format = f),
              onPageChanged: (fd) => setState(() => _focusedDay = fd),
              availableCalendarFormats: const {
                CalendarFormat.month: 'Monthly',
                CalendarFormat.week: 'Weekly',
              },
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: _calNavy,
                ),
                leftChevronIcon: Icon(Icons.chevron_left, color: _calPurple),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: _calPurple,
                ),
                headerPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: _calMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                weekendStyle: TextStyle(
                  color: _calMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              calendarStyle: CalendarStyle(
                rowDecoration: const BoxDecoration(),
                todayDecoration: BoxDecoration(
                  color: _calPurple.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: const TextStyle(
                  color: _calPurple,
                  fontWeight: FontWeight.w700,
                ),
                selectedDecoration: const BoxDecoration(
                  color: _calPurple,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                outsideTextStyle: TextStyle(
                  color: _calMuted.withValues(alpha: 0.45),
                ),
                defaultTextStyle: const TextStyle(color: _calNavy),
                weekendTextStyle: const TextStyle(color: _calNavy),
                markersMaxCount: 0, // we use calendarBuilders.markerBuilder
              ),
              rowHeight: 60,
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return const SizedBox.shrink();
                  final label = events.length == 1
                      ? _shortName(events.first.title.isNotEmpty
                          ? events.first.title
                          : events.first.courseName)
                      : '${events.length} events';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: GestureDetector(
                      onTap: events.length == 1
                          ? () => _openEventDetails(events.first)
                          : null,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 52),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _calPurple,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Section label ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Row(
              children: [
                Text(
                  _selectedDay != null
                      ? _formatDate(_selectedDay!)
                      : 'Upcoming Sessions',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _calNavy,
                  ),
                ),
                if (_selectedDay != null && selectedEvents.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _calPurple,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${selectedEvents.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Event list ─────────────────────────────────────────────────
          Expanded(
            child: Builder(builder: (context) {
              if (calendarState.state == DataProviderState.loading ||
                  calendarState.state == DataProviderState.idle) {
                return const Center(
                  child: CircularProgressIndicator(color: _calPurple),
                );
              }
              if (calendarState.state == DataProviderState.error) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 40, color: _calMuted.withValues(alpha: 0.6)),
                        const SizedBox(height: 12),
                        Text(
                          calendarState.error ?? 'Unable to load your sessions.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _calMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        RetryButton(
                          onRetry: () =>
                              ref.read(CalendarViewModel.provider.notifier).fetch(),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final list = _selectedDay != null ? selectedEvents : upcoming;
              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_available_rounded,
                        size: 48,
                        color: _calMuted.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedDay != null
                            ? 'No events on this date'
                            : 'No upcoming sessions found',
                        style: const TextStyle(
                          color: _calMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                itemCount: list.length + 1,
                itemBuilder: (context, i) => i < list.length
                    ? _CalendarEventTile(
                        event: list[i],
                        onTap: () => _openEventDetails(list[i]),
                      )
                    : const AppFooter(),
              );
            }),
          ),
        ],
      );
  }

  DateTime _weekStart(DateTime d) {
    final daysSinceSunday = d.weekday % 7;
    return _dateOnly(d.subtract(Duration(days: daysSinceSunday)));
  }

  String _weekRangeLabel(DateTime start) {
    final end = start.add(const Duration(days: 6));
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    if (start.month == end.month) {
      return '${months[start.month - 1]} ${start.day} – ${end.day}, ${end.year}';
    }
    return '${months[start.month - 1]} ${start.day} – '
        '${months[end.month - 1]} ${end.day}, ${end.year}';
  }

  String _dayHeaderLabel(DateTime d) {
    const weekdayAbbrev = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return '${weekdayAbbrev[d.weekday % 7]} ${d.month}/${d.day}';
  }

  Widget _buildWeekView(Map<DateTime, List<CalendarEvent>> eventMap) {
    final weekStart = _weekStart(_weekAnchor);
    final today = _dateOnly(DateTime.now());
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    return Builder(
      builder: (context) {
        // Phone: 7 equal-width Expanded columns get too narrow to read, so
        // give each day a fixed width and let the week scroll horizontally
        // instead of squeezing everything to fit.
        final isPhone = !Responsive.isTablet(context);
        const dayWidth = 110.0;

        Widget dayHeaderCell(DateTime day) {
          final cell = Container(
            decoration: BoxDecoration(
              color: isSameDay(day, today)
                  ? const Color(0xFFFFF6D9)
                  : const Color(0xFFF7F8FB),
              border: const Border(
                right: BorderSide(color: FigmaTokens.cardBorders),
                bottom: BorderSide(color: FigmaTokens.cardBorders),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            child: Text(
              _dayHeaderLabel(day),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _calNavy,
              ),
            ),
          );
          return isPhone ? SizedBox(width: dayWidth, child: cell) : Expanded(child: cell);
        }

        Widget dayBodyCell(DateTime day) {
          final cell = Container(
            constraints: const BoxConstraints(minHeight: 70),
            decoration: BoxDecoration(
              color: isSameDay(day, today) ? const Color(0xFFFFFBEF) : Colors.white,
              border: const Border(
                right: BorderSide(color: FigmaTokens.cardBorders),
              ),
            ),
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                for (final event in (eventMap[_dateOnly(day)] ?? const <CalendarEvent>[]))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: GestureDetector(
                      onTap: () => _openEventDetails(event),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                        decoration: BoxDecoration(
                          color: _calPurple,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _shortName(event.title.isNotEmpty ? event.title : event.courseName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
          return isPhone ? SizedBox(width: dayWidth, child: cell) : Expanded(child: cell);
        }

        final grid = Column(
          children: [
            Row(children: [for (final day in days) dayHeaderCell(day)]),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final day in days) dayBodyCell(day)],
              ),
            ),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Text(
                    _weekRangeLabel(weekStart),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _calNavy,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _weekAnchor = DateTime.now()),
                    style: TextButton.styleFrom(foregroundColor: _calMuted),
                    child: const Text('Today', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    onPressed: () => setState(
                        () => _weekAnchor = _weekAnchor.subtract(const Duration(days: 7))),
                    icon: const Icon(Icons.chevron_left, color: _calPurple),
                  ),
                  IconButton(
                    onPressed: () =>
                        setState(() => _weekAnchor = _weekAnchor.add(const Duration(days: 7))),
                    icon: const Icon(Icons.chevron_right, color: _calPurple),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  border: Border.all(color: FigmaTokens.cardBorders),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: isPhone
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(width: dayWidth * 7, child: grid),
                      )
                    : grid,
              ),
            ),
          ],
        );
      },
    );
  }

  String _shortName(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length <= 2) return name;
    return '${words[0]} ${words[1]}';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _CalendarEventTile extends StatelessWidget {
  const _CalendarEventTile({required this.event, required this.onTap});
  final CalendarEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayTitle = event.title.isNotEmpty ? event.title : event.courseName;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: FigmaTokens.cardBorders),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _calPurple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.event_rounded, color: _calPurple, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _calNavy,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: _calMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _sessionLabel(event.startDateTime),
                          style: const TextStyle(
                            color: _calMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _calMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _sessionLabel(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final date = '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    if (dt.hour == 0 && dt.minute == 0) return date;
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$date · $h:$m $ampm';
  }
}

// ─── Event details dialog ───────────────────────────────────────────────────

class _EventDetailsDialog extends ConsumerWidget {
  const _EventDetailsDialog({required this.event});
  final CalendarEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayTitle = event.title.isNotEmpty ? event.title : event.courseName;
    final viewDisabled = isViewCourseDisabled(ref, event.courseId);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  const Text(
                    'Event Details',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _calNavy,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: -6,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: _calMuted, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _DetailRow(label: 'Title:', value: displayTitle),
              _DetailRow(
                label: 'Register Status:',
                value: event.registrationStatus.isNotEmpty
                    ? event.registrationStatus
                    : 'Unknown',
              ),
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                const Text(
                  'Description:',
                  style: TextStyle(
                    color: _calNavy,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.description,
                  style: const TextStyle(color: _calMuted, fontSize: 13, height: 1.4),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: FigmaTokens.cardBorders),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: _calMuted, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ViewCourseButton(
                    onPressed: viewDisabled
                        ? null
                        : () {
                            Navigator.pop(context);
                            Modular.to.pushNamed(
                              CoursesModule.construct(
                                '${CoursesModule.detail}/${event.courseId}',
                              ),
                            );
                          },
                    width: 140,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                color: _calNavy,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: _calMuted, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
