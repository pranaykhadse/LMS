import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/features/courses/model/calendar_event.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/view/widgets/course_view_availability.dart';
import 'package:lms/app/features/courses/viewmodel/calendar_view_model.dart';

const _calPurple = FigmaTokens.primaryPurple;
const _calNavy = FigmaTokens.cardTitles;
const _calMuted = FigmaTokens.noteBodyText;
const _calBg = FigmaTokens.pageBackground;
const _weekdayAbbrev = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

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

    // CSS/markup ref, confirmed against `origin/staging`'s
    // `_calendarView.php`: the real page is a plain `container-fluid p-3`
    // with NO page-title app-bar of its own (that purple "Weekly View"
    // bar and the "Course Calendar" title were both invented — the real
    // page has neither). The toggle is a standalone `.btn.btn-primary`
    // ("Weekly View" / "Monthly View") sitting in its own right-aligned
    // row directly above the calendar, not inside a bar.
    return AppScaffold(
      backgroundColor: _calBg,
      title: 'Course Calendar',
      centerTitle: true,
      onRefresh: () => ref.read(CalendarViewModel.provider.notifier).fetch(),
      body: _buildBody(calendarState, allEvents, eventMap),
    );
  }

  Widget _buildBody(
    DataState<CalendarViewResult> calendarState,
    List<CalendarEvent> allEvents,
    Map<DateTime, List<CalendarEvent>> eventMap,
  ) {
    if (calendarState.state == DataProviderState.loading ||
        calendarState.state == DataProviderState.idle) {
      return const Center(child: CircularProgressIndicator(color: _calPurple));
    }
    if (calendarState.state == DataProviderState.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 40,
                color: _calMuted.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 12),
              Text(
                calendarState.error ?? 'Unable to load your sessions.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _calMuted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              RetryButton(
                onRetry:
                    () => ref.read(CalendarViewModel.provider.notifier).fetch(),
              ),
            ],
          ),
        ),
      );
    }
    // CSS/markup ref: `_calendarView.php`'s `if (empty($eventsdecode) ||
    // count($eventsdecode) === 0)` branch — when there are literally zero
    // events across the whole calendar (not just the visible month), the
    // real page shows nothing but a single centered `.btn-light` alert
    // and skips the toggle button and the calendar entirely; it isn't a
    // per-month "nothing this month" state (an empty month just renders
    // as a normal empty grid, same as any other month).
    if (allEvents.isEmpty) {
      // CSS ref: `<div class="container-fluid p-3">`(16px) wrapping
      // `<div class="row"><div class="col-md-12 p-4 text-center">`(24px)
      // wrapping `<div class="btn-light w-100 p-3">`(16px) — 40px total
      // outer inset, not the flat 16px this had.
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'There are no courses available to show on the calendar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF212529),
              fontSize: 24,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      );
    }
    return _format == CalendarFormat.week
        ? _buildWeekView(eventMap)
        : _buildMonthView(eventMap);
  }

  // CSS ref: `<div class="container-fluid p-3">` (16px all sides) wrapping
  // `<div class="row p-2">`/`<div class="row">`, each split
  // `col-md-1`(empty)/`col-md-10`/`col-md-1`(empty) — a `container-fluid`
  // has no max-width, so on any screen >=768px (Bootstrap's `md` breakpoint,
  // where col-md-* actually takes effect) the content column is inset by
  // a further 1/12 of the viewport on each side, scaling continuously with
  // width. Below 768px the col-md-* split doesn't apply at all (stacks to
  // 100%), leaving just the container's own 16px padding — was a flat
  // 12-16px at every width, which underscored the real inset badly on
  // wide/desktop screens (visibly edge-to-edge compared to the real page).
  double _contentInset(double width) {
    if (width < 768) return 16;
    return 16 + width / 12;
  }

  // CSS ref: `<button class="btn btn-primary View-btn m-2">` — real
  // Bootstrap primary button (this theme's `--primary-color`=#693D94),
  // not a translucent pill on a purple bar.
  Widget _viewToggleButton(double inset) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.fromLTRB(0, 12, inset, 0),
        child: _BootstrapPrimaryButton(
          label:
              _format == CalendarFormat.month ? 'Weekly View' : 'Monthly View',
          onPressed:
              () => setState(() {
                _format =
                    _format == CalendarFormat.month
                        ? CalendarFormat.week
                        : CalendarFormat.month;
              }),
        ),
      ),
    );
  }

  // CSS/markup ref, confirmed against `origin/staging`'s
  // `_calendarView.php`: `$('#calendar').fullCalendar({ events, defaultView:
  // 'month', eventClick })` passes no `header` option, so it renders
  // FullCalendar's own default toolbar (`{left:'title', right:'today
  // prev,next'}`) — title on the LEFT, "Today"+chevrons on the RIGHT, no
  // card/shadow wrapper around the grid at all (the real markup is a bare
  // `<div id="calendar">` in a `container-fluid`). The white rounded card,
  // centered small title with flanking chevrons, and the whole "Upcoming
  // Sessions" list below it were all invented — the real page shows
  // nothing but the grid itself; clicking an event opens the details
  // modal directly.
  Widget _buildMonthView(Map<DateTime, List<CalendarEvent>> eventMap) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = _contentInset(constraints.maxWidth);
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _viewToggleButton(inset),
              Padding(
                padding: EdgeInsets.fromLTRB(inset, 4, inset, 12),
                child: Column(
                  children: [
                    _calendarToolbar(),
                    const SizedBox(height: 8),
                    TableCalendar<CalendarEvent>(
                      firstDay: DateTime(2020),
                      lastDay: DateTime(2030),
                      focusedDay: _focusedDay,
                      calendarFormat: _format,
                      eventLoader: (day) => _eventsForDay(eventMap, day),
                      headerVisible: false,
                      onFormatChanged: (f) => setState(() => _format = f),
                      onPageChanged: (fd) => setState(() => _focusedDay = fd),
                      availableCalendarFormats: const {
                        CalendarFormat.month: 'Monthly',
                        CalendarFormat.week: 'Weekly',
                      },
                      // CSS ref, confirmed via live devtools: the real
                      // `th.fc-day-header` (day-of-week row) measures
                      // exactly 21px tall, and the real `td.fc-day` (a
                      // date cell) measures exactly 146px tall — was
                      // 16px (package default, never overridden) and
                      // 90px respectively.
                      daysOfWeekHeight: 21,
                      daysOfWeekStyle: const DaysOfWeekStyle(
                        weekdayStyle: TextStyle(
                          color: _calNavy,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        weekendStyle: TextStyle(
                          color: _calNavy,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      calendarStyle: CalendarStyle(
                        rowDecoration: const BoxDecoration(),
                        // CSS ref: `.fc-unthemed th, td, thead, tbody,
                        // .fc-row { border-color: #ddd }` (base `.fc` grid
                        // rule: `border-style:solid; border-width:1px`) —
                        // every day cell is boxed in a real 1px light-gray
                        // grid line, both horizontal and vertical. Was
                        // entirely borderless.
                        tableBorder: const TableBorder(
                          horizontalInside: BorderSide(
                            color: Color(0xFFDDDDDD),
                          ),
                          verticalInside: BorderSide(color: Color(0xFFDDDDDD)),
                          top: BorderSide(color: Color(0xFFDDDDDD)),
                          bottom: BorderSide(color: Color(0xFFDDDDDD)),
                          left: BorderSide(color: Color(0xFFDDDDDD)),
                          right: BorderSide(color: Color(0xFFDDDDDD)),
                        ),
                        // CSS ref: `.fc-unthemed td.fc-today { background:
                        // #fcf8e3 }` — FullCalendar's own default "today" tint
                        // (a pale yellow, not a purple ring).
                        todayDecoration: const BoxDecoration(
                          color: Color(0xFFFCF8E3),
                          shape: BoxShape.rectangle,
                        ),
                        todayTextStyle: const TextStyle(color: _calNavy),
                        outsideTextStyle: TextStyle(
                          color: _calMuted.withValues(alpha: 0.45),
                        ),
                        defaultTextStyle: const TextStyle(color: _calNavy),
                        weekendTextStyle: const TextStyle(color: _calNavy),
                        markersMaxCount:
                            0, // we use calendarBuilders.markerBuilder
                      ),
                      rowHeight: 146,
                      // CSS ref: `.fc-ltr .fc-basic-view .fc-day-top .fc-day-
                      // number { float:right }` — the date number sits at the
                      // TOP-RIGHT of the cell, not centered in a circle.
                      calendarBuilders: CalendarBuilders(
                        // CSS ref: same `.fc-unthemed th { border-color:
                        // #ddd }` grid — the day-of-week header row needs
                        // its own matching borders since `table_calendar`
                        // only grids the date cells via `tableBorder`, not
                        // this row.
                        dowBuilder:
                            (context, day) => Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border(
                                  left:
                                      day.weekday % 7 == 0
                                          ? const BorderSide(
                                            color: Color(0xFFDDDDDD),
                                          )
                                          : BorderSide.none,
                                  right: const BorderSide(
                                    color: Color(0xFFDDDDDD),
                                  ),
                                  top: const BorderSide(
                                    color: Color(0xFFDDDDDD),
                                  ),
                                  bottom: const BorderSide(
                                    color: Color(0xFFDDDDDD),
                                  ),
                                ),
                              ),
                              child: Text(
                                _weekdayAbbrev[day.weekday % 7],
                                style: const TextStyle(
                                  color: _calNavy,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        defaultBuilder:
                            (context, day, focusedDay) =>
                                _dayCell(day, isToday: false),
                        todayBuilder:
                            (context, day, focusedDay) =>
                                _dayCell(day, isToday: true),
                        outsideBuilder:
                            (context, day, focusedDay) => Padding(
                              padding: const EdgeInsets.all(4),
                              child: Align(
                                alignment: Alignment.topRight,
                                // CSS ref: `body{font-size:14px!important}`
                                // cascades through `body .fc{font-size:
                                // 1em}` — day numbers carry no further
                                // override, so they inherit that real 14px
                                // (was 13px, close but not exact).
                                child: Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    color: _calMuted.withValues(alpha: 0.45),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                        // CSS ref: `.fc-event`/`.fc-day-grid-event` — every
                        // event on a day renders as its OWN full-width bar,
                        // stacked vertically, each independently clickable —
                        // not summarized into a single "N events" pill (that
                        // pill, and disabling the tap once there was more
                        // than one event, was invented; the real page has
                        // no such summarization at all). Background
                        // `#3A87AD` (FullCalendar's own default event
                        // color — confirmed from the fetched stylesheet;
                        // this app never overrides it to purple), white
                        // text, radius 3px. `.fc-day-grid-event{margin-
                        // bottom:5px}` (the one real override in
                        // `_calendarView.php`'s own `<style>` block) sets
                        // the gap between stacked bars.
                        markerBuilder: (context, day, events) {
                          if (events.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(2, 20, 2, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final event in events)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 5),
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: () => _openEventDetails(event),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF3A87AD),
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                          child: Text(
                                            _shortName(
                                              event.title.isNotEmpty
                                                  ? event.title
                                                  : event.courseName,
                                            ),
                                            style: const TextStyle(
                                              // CSS ref: `.fc-content{font-
                                              // size:11px!important}` — the
                                              // one real override for
                                              // event/day content text; no
                                              // bold override exists on
                                              // `.fc-event`/`.fc-title`
                                              // either, so this stays the
                                              // default (regular) weight.
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w400,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const AppFooter(),
            ],
          ),
        );
      },
    );
  }

  // CSS ref: `body{font-size:14px!important}` cascades through
  // `body .fc{font-size:1em}` — no further override exists for
  // `.fc-day-number` (was 13px).
  Widget _dayCell(DateTime day, {required bool isToday}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isToday ? const Color(0xFFFCF8E3) : null,
      ),
      child: Align(
        alignment: Alignment.topRight,
        child: Text(
          '${day.day}',
          style: const TextStyle(color: _calNavy, fontSize: 14),
        ),
      ),
    );
  }

  // CSS ref: `.fc-toolbar` — `.fc-left` (title) floats left, `.fc-right`
  // (today/prev/next) floats right, margin-bottom 1em. `.fc-toolbar h2`
  // sets no font-size of its own (just `margin:0`), so it inherits this
  // theme's real `h2{font-size:2rem(32px); font-weight:500; line-
  // height:1.2}` — was 26px/weight700, both wrong. `.fc-state-default`
  // buttons — 1px border, 4px corner radius, light gray fill, dark gray
  // text (see `_toolbarButton`/`_toolbarButtonGroup` for exact sizing).
  Widget _calendarToolbar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            _monthTitle(_focusedDay),
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 32,
              height: 1.2,
              color: _calNavy,
            ),
          ),
        ),
        _toolbarButton(
          'Today',
          onTap: () => setState(() => _focusedDay = DateTime.now()),
        ),
        const SizedBox(width: 4),
        // UI ref: prev/next render as ONE joined pill (a shared border,
        // radius only on the group's outer corners, a single divider
        // line between them) — was two fully-separate individually-
        // rounded buttons sitting flush against each other, which reads
        // as a doubled-up border down the middle instead of one shared
        // divider.
        _toolbarButtonGroup(
          onPrev:
              () => setState(
                () =>
                    _focusedDay = DateTime(
                      _focusedDay.year,
                      _focusedDay.month - 1,
                    ),
              ),
          onNext:
              () => setState(
                () =>
                    _focusedDay = DateTime(
                      _focusedDay.year,
                      _focusedDay.month + 1,
                    ),
              ),
        ),
      ],
    );
  }

  // CSS ref: `.fc button { height:2.1em; padding:0 .6em; font-size:1em }`
  // — `em` here cascades from `body{font-size:14px!important}` (not the
  // 16px root `rem` size), so at 14px that's height ~29.4px, padding
  // ~8.4px horizontal, text 14px (was 34px/10px/16px, all computed off
  // the wrong 16px base).
  Widget _toolbarButton(String label, {required VoidCallback onTap}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 29.4,
          // CSS ref, confirmed via live devtools on the real "today"
          // button: box 49.46×29.4, content 41.462×21.4 — padding is
          // 4px on ALL sides (not the `.6em`(8.4px)-horizontal-only,
          // 0-vertical value this had been using, computed from
          // FullCalendar's own CSS source rather than measured).
          padding: const EdgeInsets.all(4),
          alignment: Alignment.center,
          // UI ref, exhaustively confirmed via live devtools computed
          // styles: real fill is `.fc-state-default`'s own 2-stop
          // gradient `#fff` -> `#e6e6e6` (was approximated as `#fff` ->
          // `#F0F0F5`); `border-radius:8px!important` from the generic
          // `.btn,button{...}` rule (was 10px, then 4px before that —
          // neither matched); real `box-shadow` is a subtle OUTER
          // shadow `0 1px 2px rgba(0,0,0,.05)` (was a much heavier
          // 8%-alpha/4px-blur/2px-offset guess) PLUS an inset top
          // highlight `inset 0 1px 0 rgba(255,255,255,.2)` that
          // Flutter's `BoxShadow` can't express (no inset support) —
          // skipped as too subtle to be worth a custom painter.
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFE6E6E6)],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            label,
            // CSS ref, confirmed via live devtools: real font-family is
            // `var(--primary-font)`='Inter' (this file had zero
            // `GoogleFonts` usage anywhere — see docs/course-catalog-ui
            // -audit.md); `font-weight:600!important` from the same
            // generic `.btn,button{...}` rule (was unset/w400 — missing
            // entirely); `text-shadow:0 1px 1px rgba(255,255,255,.75)`
            // — a subtle white shadow beneath the text, reproduced via
            // `TextStyle.shadows`.
            style: GoogleFonts.inter(
              color: const Color(0xFF333333),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  color: Colors.white.withValues(alpha: 0.75),
                  offset: const Offset(0, 1),
                  blurRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // UI ref: the real prev/next pair sits inside a single `.fc-button-
  // group` — one shared border/background with radius only on the
  // group's OUTER corners (left of "<", right of ">"), and a single
  // 1px divider between the two halves, not two independently-rounded
  // buttons touching edge to edge (which doubles the border down the
  // middle). Same live-measured 4px all-sides padding and 29.4px
  // height as `_toolbarButton`.
  Widget _toolbarButtonGroup({
    required VoidCallback onPrev,
    required VoidCallback onNext,
  }) {
    return Container(
      height: 29.4,
      margin: const EdgeInsets.only(left: 4),
      // UI ref: same exact gradient/radius/shadow values as
      // `_toolbarButton` — see its comments for the live-devtools
      // cascade this was traced from.
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFE6E6E6)],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toolbarGroupIcon(Icons.chevron_left, onTap: onPrev),
          Container(width: 1, height: 20, color: const Color(0xFFE0E0E5)),
          _toolbarGroupIcon(Icons.chevron_right, onTap: onNext),
        ],
      ),
    );
  }

  Widget _toolbarGroupIcon(IconData icon, {required VoidCallback onTap}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: const Color(0xFF333333)),
        ),
      ),
    );
  }

  String _monthTitle(DateTime dt) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  DateTime _weekStart(DateTime d) {
    final daysSinceSunday = d.weekday % 7;
    return _dateOnly(d.subtract(Duration(days: daysSinceSunday)));
  }

  String _weekRangeLabel(DateTime start) {
    final end = start.add(const Duration(days: 6));
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (start.month == end.month) {
      return '${months[start.month - 1]} ${start.day} – ${end.day}, ${end.year}';
    }
    return '${months[start.month - 1]} ${start.day} – '
        '${months[end.month - 1]} ${end.day}, ${end.year}';
  }

  String _dayHeaderLabel(DateTime d) {
    return '${_weekdayAbbrev[d.weekday % 7]} ${d.month}/${d.day}';
  }

  Widget _buildWeekView(Map<DateTime, List<CalendarEvent>> eventMap) {
    final weekStart = _weekStart(_weekAnchor);
    final today = _dateOnly(DateTime.now());
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    return LayoutBuilder(
      builder: (context, constraints) {
        // Phone: 7 equal-width Expanded columns get too narrow to read, so
        // give each day a fixed width and let the week scroll horizontally
        // instead of squeezing everything to fit.
        final isPhone = !Responsive.isTablet(context);
        final inset = _contentInset(constraints.maxWidth);
        const dayWidth = 110.0;

        Widget dayHeaderCell(DateTime day) {
          final cell = Container(
            // CSS ref: `.fc-unthemed td.fc-today{background:#fcf8e3}` — no
            // rule tints `.fc-widget-header`/`th` cells at all (was two
            // invented colors — `#FFF6D9` for today, `#F7F8FB` for every
            // other header cell — neither real; non-today header cells
            // have no fill).
            decoration: BoxDecoration(
              color:
                  isSameDay(day, today)
                      ? const Color(0xFFFCF8E3)
                      : Colors.white,
              // CSS ref: `.fc-unthemed th { border-color: #ddd }`.
              border: Border(
                left:
                    day.weekday % 7 == 0
                        ? const BorderSide(color: Color(0xFFDDDDDD))
                        : BorderSide.none,
                top: const BorderSide(color: Color(0xFFDDDDDD)),
                right: const BorderSide(color: Color(0xFFDDDDDD)),
                bottom: const BorderSide(color: Color(0xFFDDDDDD)),
              ),
            ),
            // CSS ref, confirmed via live devtools: `th.fc-day-header`
            // (the same class the real month view's day-of-week header
            // uses) measures exactly 21px tall — was sized by an 8px
            // vertical padding instead of this explicit height.
            height: 21,
            alignment: Alignment.center,
            // CSS ref: `.fc th{text-align:center}`; no explicit font-size/
            // weight override exists for header cells at all, so they
            // inherit `body{font-size:14px!important}` through `body .fc
            // {font-size:1em}` (was 11px). Kept weight700 as the one
            // reasonable assumption (`<th>` is bold by browser default,
            // which FullCalendar never resets).
            child: Text(
              _dayHeaderLabel(day),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _calNavy,
              ),
            ),
          );
          return isPhone
              ? SizedBox(width: dayWidth, child: cell)
              : Expanded(child: cell);
        }

        Widget dayBodyCell(DateTime day) {
          final cell = Container(
            // CSS ref: `.fc-agenda-view .fc-day-grid .fc-row { min-height:
            // 3em }` = 48px — the real "Weekly View" is FullCalendar's
            // agendaWeek with its hourly time-grid hidden entirely
            // (`.fc-agendaWeek-view .fc-time-grid-container{display:none}`,
            // confirmed from `_calendarView.php`'s own `<style>` block —
            // every event here is date-only/all-day, so nothing is lost),
            // leaving only this all-day row, minimum 48px tall (was 70).
            constraints: const BoxConstraints(minHeight: 48),
            // CSS ref: `.fc-unthemed td.fc-today{background:#fcf8e3}` —
            // same real tint as month view (was `#FFFBEF`, invented).
            decoration: BoxDecoration(
              color:
                  isSameDay(day, today)
                      ? const Color(0xFFFCF8E3)
                      : Colors.white,
              // CSS ref: `.fc-unthemed td { border-color: #ddd }`.
              border: Border(
                left:
                    day.weekday % 7 == 0
                        ? const BorderSide(color: Color(0xFFDDDDDD))
                        : BorderSide.none,
                right: const BorderSide(color: Color(0xFFDDDDDD)),
                bottom: const BorderSide(color: Color(0xFFDDDDDD)),
              ),
            ),
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                for (final event
                    in (eventMap[_dateOnly(day)] ?? const <CalendarEvent>[]))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => _openEventDetails(event),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            // CSS ref: `.fc-event` default background
                            // #3A87AD — same real color as the month view's
                            // event bars, not this app's purple.
                            color: const Color(0xFF3A87AD),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _shortName(
                              event.title.isNotEmpty
                                  ? event.title
                                  : event.courseName,
                            ),
                            // CSS ref: same `.fc-content{font-size:11px
                            // !important}` override, no bold on
                            // `.fc-event`/`.fc-title`.
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
          return isPhone
              ? SizedBox(width: dayWidth, child: cell)
              : Expanded(child: cell);
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

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _viewToggleButton(inset),
              // CSS ref: agendaWeek renders the exact same FullCalendar
              // toolbar as month view (title-left/today+chevrons-right,
              // real h2 32px/weight500, `.fc-button` sizing) — reused via
              // the same `_toolbarButton`/`_toolbarButtonGroup` helpers
              // instead of this row's own, differently-styled `TextButton`/
              // `IconButton`.
              Padding(
                padding: EdgeInsets.fromLTRB(inset, 4, inset, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        _weekRangeLabel(weekStart),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 32,
                          height: 1.2,
                          color: _calNavy,
                        ),
                      ),
                    ),
                    _toolbarButton(
                      'Today',
                      onTap: () => setState(() => _weekAnchor = DateTime.now()),
                    ),
                    const SizedBox(width: 4),
                    _toolbarButtonGroup(
                      onPrev:
                          () => setState(
                            () =>
                                _weekAnchor = _weekAnchor.subtract(
                                  const Duration(days: 7),
                                ),
                          ),
                      onNext:
                          () => setState(
                            () =>
                                _weekAnchor = _weekAnchor.add(
                                  const Duration(days: 7),
                                ),
                          ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: inset),
                // CSS ref: same as month view — no card/radius wrapper
                // around the real `.fc` grid, just the grid's own 1px
                // `#ddd` cell borders (now drawn per-cell above).
                child:
                    isPhone
                        ? SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(width: dayWidth * 7, child: grid),
                        )
                        : grid,
              ),
              const SizedBox(height: 16),
              const AppFooter(),
            ],
          ),
        );
      },
    );
  }

  String _shortName(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length <= 2) return name;
    return '${words[0]} ${words[1]}';
  }
}

// CSS ref, confirmed against `origin/staging`'s `dist/app.css`: this
// theme's own `.btn`/`.btn-primary` override (not vanilla Bootstrap) —
// padding 5px 20px, font-size 16px/line-height 21px, weight **400** (not
// bold), radius 4px, bg #693D94, white text; `:hover` → `#4043AF` (a
// distinct blue-purple, not this app's usual `--primary-dark`/#5A3480 —
// a real inconsistency in the site's own CSS, reproduced as-is since
// this literal rule governs both the "Weekly/Monthly View" toggle and
// the event modal's Close/View Course buttons). Disabled state (View
// Course when the course can't be opened) has no real spec to cite —
// a plain reduced-opacity fallback.
class _BootstrapPrimaryButton extends StatefulWidget {
  const _BootstrapPrimaryButton({required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  State<_BootstrapPrimaryButton> createState() =>
      _BootstrapPrimaryButtonState();
}

class _BootstrapPrimaryButtonState extends State<_BootstrapPrimaryButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    // CSS ref, corrected via a live devtools full-cascade dump on the
    // Dev Plan screen's own "Add Custom Plan Item" button (the SAME
    // `.btn.btn-primary` class): `bluetheme-layout.css` — loaded on
    // every page, `!important` — carries a SITE-WIDE override that
    // beats the vanilla `.btn`/`.btn-primary` values (padding 5px 20px,
    // 16px/w400, radius 4px, a visible border, `#4043AF` hover) this
    // had been using: `.btn,button,...{border-radius:8px!important;
    // font-weight:600!important;font-size:14px!important;padding:4px
    // 4px!important;border:none!important}`, `.btn-primary:hover{
    // background:var(--primary-dark)!important;box-shadow:var(--
    // shadow-md)!important;transform:translateY(-1px)}` — `--primary-
    // dark`=`#5A3480` (the same `FigmaTokens.purpleHover` token used
    // everywhere else, not a bespoke `#4043AF`/`#3C3FA6`). `.btn
    // .disabled,.btn:disabled{opacity:.65}` (was already correct).
    final bg = _hovering && !disabled ? FigmaTokens.purpleHover : _calPurple;
    return Opacity(
      opacity: disabled ? 0.65 : 1,
      child: MouseRegion(
        cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.translationValues(
            0,
            _hovering && !disabled ? -1 : 0,
            0,
          ),
          decoration: BoxDecoration(
            boxShadow:
                _hovering && !disabled
                    ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : null,
          ),
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: widget.onPressed,
              child: Padding(
                // Padding increased per explicit user request (a
                // deliberate deviation from the real 4px, not a
                // web-match fix).
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 21 / 14,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Event details dialog ───────────────────────────────────────────────────

class _EventDetailsDialog extends ConsumerWidget {
  const _EventDetailsDialog({required this.event});
  final CalendarEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayTitle =
        event.title.isNotEmpty ? event.title : event.courseName;
    final viewDisabled = isViewCourseDisabled(ref, event.courseId);
    // CSS ref, confirmed via live devtools computed styles on the real
    // modal: two `.modal-content` rules exist in `dist/app.css` — an
    // earlier one (padding:15px;margin:auto, no border/radius of its
    // own) and a LATER one that redefines Bootstrap's own base `.modal-
    // content` directly: `border:1px solid #693D94; border-radius:
    // 24px`. The later rule wins for border/radius (untouched by the
    // earlier block) — real radius is **24px**, not the 3px this had
    // been using since Round 29 (an earlier misread of the same
    // cascade). `.modal-header` is forced `display:block!important;
    // text-align:center` by an earlier, more specific `!important` rule
    // in the same stylesheet, which beats the later flex-based
    // Bootstrap default — the title is genuinely centered, matching
    // what this already had.
    //
    // Width ref: the real dialog is `<div class="modal-dialog modal-lg"
    // style="width:80%">` — a fixed 80vw base WIDTH, clamped by
    // whichever breakpoint `max-width` applies: `.modal-lg{max-width:
    // 800px}` at >=992px, plain `.modal-dialog{max-width:500px}` at
    // 576-991px, uncapped below that. Was a flat 480px maxWidth
    // regardless of viewport — much narrower than the real ~800px
    // desktop modal.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final modalCap =
        screenWidth >= 992
            ? 800.0
            : (screenWidth >= 576 ? 500.0 : double.infinity);
    final modalWidth = (screenWidth * 0.8).clamp(0.0, modalCap);
    return Dialog(
      // Shifted upward per explicit user request, flush against the
      // bottom of just the purple top bar (a deliberate deviation, not
      // a web-match fix — Bootstrap's real modal is simply vertically
      // centered). `_desktopTopBarHeight` = 44px — was 90px (which
      // included the white nav bar's own height too, per the user's
      // screenshot showing the modal covering that entirely).
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(
        top: 44,
        left: 40,
        right: 40,
        bottom: 24,
      ),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: _calPurple),
        borderRadius: BorderRadius.circular(24),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: modalWidth, maxHeight: 620),
        child: SingleChildScrollView(
          // CSS ref: `.modal-content{padding:15px}` (all sides — the
          // shared "outer ring" around header/body/footer collectively)
          // wrapping `.modal-body{margin:0 20px; padding:0!important}`
          // (20px horizontal only, own padding zeroed) — 35px horizontal
          // / 15px vertical total for the body content (was a flat 20px
          // on every side).
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // CSS ref, confirmed via live devtools: `.modal-header`
              // (Bootstrap base, its own `display:flex`/`border-bottom`
              // overridden by a later `!important` rule to `display:
              // block;border-bottom:none`, but its `padding:1rem 1rem`
              // (16px all sides — both directions, not just horizontal)
              // is NOT touched by that override and still applies) —
              // real header inset is 15 (content) + 16 (header) = 31px
              // horizontal, and a genuine 16px vertical of its own on
              // top of the shared 15px outer padding, confirmed by the
              // live box model measuring the whole header at exactly
              // 61px tall (16 + 29 title content + 16). Was only ever
              // applying the 31px horizontally, never the 16px
              // vertically — the title/close row had no header-specific
              // top inset, and the header→body gap was patched in as a
              // separate 16px `SizedBox` sibling instead of it being the
              // header's own real bottom padding.
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 31,
                  vertical: 16,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // CSS ref: `.modal-title{font-weight:400; font-size:
                    // 24px; color:#606060}` (was navy/weight800/18px).
                    // CSS ref, confirmed via live devtools: the real
                    // `font-family` is `var(--primary-font)` = 'Inter'
                    // (a LATER, `!important` body rule that wins over an
                    // earlier "Roboto" one) — this whole file never used
                    // `GoogleFonts.inter`, defaulting to Flutter's own
                    // platform font instead.
                    Text(
                      'Event Details',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF606060),
                        fontSize: 24,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: -6,
                      // CSS ref, confirmed via live devtools: the generic
                      // `.close{font-size:1.5rem}` (24px) LOSES to the
                      // page's own `button.close{font-size:18px
                      // !important}` (a more specific selector, also
                      // !important, so it wins over the class-only rule).
                      // Color is `var(--black)`=#2A2A2A (not literal
                      // #000), still at `.close`'s own 50% opacity (not
                      // overridden) — `.close:not(:disabled):not
                      // (.disabled):hover{opacity:.75}`. `button.close`
                      // also carries 4px padding on all sides (from the
                      // generic `.btn,button,...{padding:4px 4px
                      // !important}` rule, which wins over `button.close`
                      // `padding:0` since that has no `!important` of its
                      // own) — confirmed by the live box model (4px
                      // padding, 18px/line-height 21px content). Was 24px
                      // with zero padding and pure black.
                      child: HoverBuilder(
                        cursor: SystemMouseCursors.click,
                        builder:
                            (context, hovering) => IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(
                                Icons.close_rounded,
                                color: const Color(
                                  0xFF2A2A2A,
                                ).withValues(alpha: hovering ? 0.75 : 0.5),
                                size: 18,
                              ),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              // CSS ref: header's own bottom padding (16px, from `1rem
              // 1rem`, now built into the header's own `Padding` above)
              // is what separates it from `.modal-body` below —
              // `.modal-body` itself has no top margin of its own
              // (`margin:0 20px` is horizontal only), so no additional
              // gap belongs here.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 35),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DetailRow(label: 'Title:', value: displayTitle),
                    _DetailRow(
                      label: 'Register Status:',
                      value:
                          event.registrationStatus.isNotEmpty
                              ? event.registrationStatus
                              : 'Unknown',
                    ),
                    // CSS ref: the real event-click modal always shows a
                    // Description line — `event.description || 'No
                    // description available'` — rather than omitting it
                    // outright when empty. Real markup is a plain
                    // `<p><strong>Description:</strong>...</p>` with no
                    // special classes, so both the label and value
                    // inherit the same real body text — `body{font-size:
                    // 14px!important; color:var(--black)=#2A2A2A}` (was
                    // 13px, and a navy-label/muted-value split that isn't
                    // real — both are the same color, differing only by
                    // the label's `<strong>` bold).
                    //
                    // Height ref, confirmed via live devtools: `.modal-
                    // body` measures exactly 148px for this exact content
                    // (Title/Register Status/Description-label/"No
                    // description available"). Reverse-engineered against
                    // the app's real `p{margin-top:0;margin-bottom:1rem}`
                    // rule — 4 lines × (21px content + 16px margin) =
                    // 148px exactly. Was 4px gaps here (and `_DetailRow`'s
                    // own 10px bottom padding, fixed alongside this).
                    const SizedBox(height: 16),
                    Text(
                      'Description:',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF2A2A2A),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      event.description.isNotEmpty
                          ? event.description
                          : 'No description available',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF2A2A2A),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // CSS ref: confirmed against a live screenshot of the
                    // real modal — Close sits flush at the footer's LEFT
                    // edge, View Course at the RIGHT edge, i.e. the real
                    // markup's own `.modal-footer.d-flex{display:flex;
                    // justify-content:space-between}` (from
                    // `_calendarView.php`'s own `<style>` block) DOES win
                    // in practice, contrary to the `!important` cascade
                    // this had previously been traced to (Round 29) —
                    // that cascade reasoning was wrong somewhere; the
                    // live screenshot is the actual ground truth. Was
                    // wrongly centered together.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _BootstrapPrimaryButton(
                          label: 'Close',
                          onPressed: () => Navigator.pop(context),
                        ),
                        _BootstrapPrimaryButton(
                          label: 'View Course',
                          onPressed:
                              viewDisabled
                                  ? null
                                  : () {
                                    Navigator.pop(context);
                                    Modular.to.pushNamed(
                                      CoursesModule.construct(
                                        '${CoursesModule.detail}/${event.courseId}',
                                      ),
                                    );
                                  },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// CSS ref: `<p><strong>Title:</strong> ...</p>` — a plain paragraph, no
// special classes, so both the label and value inherit the same real
// body text (`body{font-size:14px!important; color:var(--black)
// =#2A2A2A}`), differing only by the label's `<strong>` bold (was 13px,
// navy-label/muted-value — neither the real size nor the real color
// split).
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    // CSS ref: real `<p>` margin-bottom is 16px (`1rem`, from the app's
    // real `p{margin-top:0;margin-bottom:1rem}` rule) — was 10px.
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: GoogleFonts.inter(
                color: const Color(0xFF2A2A2A),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.inter(
                color: const Color(0xFF2A2A2A),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
