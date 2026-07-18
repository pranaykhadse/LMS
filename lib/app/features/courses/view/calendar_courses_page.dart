import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:lms/app/features/courses/model/course_catalog.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/viewmodel/course_catalog_view_model.dart';

const _calPurple = Color(0xFF5756C9);
const _calNavy = Color(0xFF172033);
const _calMuted = Color(0xFF7C879D);
const _calBg = Color(0xFFF4F7F8);

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

  Map<DateTime, List<CatalogCourse>> _buildEventMap(
    List<CatalogCourse> courses,
  ) {
    final map = <DateTime, List<CatalogCourse>>{};
    for (final c in courses) {
      if (c.nextSession == null) continue;
      final key = _dateOnly(c.nextSession!);
      map.putIfAbsent(key, () => []).add(c);
    }
    return map;
  }

  List<CatalogCourse> _eventsForDay(
    Map<DateTime, List<CatalogCourse>> map,
    DateTime day,
  ) => map[_dateOnly(day)] ?? [];

  @override
  Widget build(BuildContext context) {
    final catalogState = ref.watch(CourseCatalogViewModel.provider);
    final allCourses =
        catalogState.result.data?.courses ??
        catalogState.result.data?.groups
            .expand((g) => g.courses)
            .toList() ??
        <CatalogCourse>[];

    final eventMap = _buildEventMap(allCourses);
    final selectedEvents =
        _selectedDay != null
            ? _eventsForDay(eventMap, _selectedDay!)
            : <CatalogCourse>[];

    // Upcoming courses (with dates) for the default "no date selected" view
    final upcoming =
        allCourses
            .where((c) => c.nextSession != null)
            .toList()
          ..sort((a, b) => a.nextSession!.compareTo(b.nextSession!));

    return Scaffold(
      backgroundColor: _calBg,
      appBar: AppBar(
        backgroundColor: _calPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Course Calendar',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: () => setState(() {
                _format = _format == CalendarFormat.month
                    ? CalendarFormat.week
                    : CalendarFormat.month;
              }),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _format == CalendarFormat.month ? 'Weekly View' : 'Monthly View',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
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
            child: TableCalendar<CatalogCourse>(
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
                      ? _shortName(events.first.name)
                      : '${events.length} courses';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
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

          // ── Course list ─────────────────────────────────────────────────
          Expanded(
            child: Builder(builder: (context) {
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
                            ? 'No courses on this date'
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
                itemCount: list.length,
                itemBuilder: (context, i) =>
                    _CourseEventTile(course: list[i]),
              );
            }),
          ),
        ],
      ),
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

class _CourseEventTile extends StatelessWidget {
  const _CourseEventTile({required this.course});
  final CatalogCourse course;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE9EDF4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Modular.to.pushNamed(
          CoursesModule.construct('${CoursesModule.detail}/${course.id}'),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: course.logo != null && course.logo!.isNotEmpty
                    ? Image.network(
                        course.logo!,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _logoPlaceholder(),
                      )
                    : _logoPlaceholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _calNavy,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (course.nextSession != null) ...[
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
                            _sessionLabel(course.nextSession!),
                            style: const TextStyle(
                              color: _calMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
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

  Widget _logoPlaceholder() => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: _calPurple.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.book_rounded, color: _calPurple, size: 24),
      );

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
