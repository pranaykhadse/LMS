class CalendarViewResult {
  const CalendarViewResult({required this.totalEvents, required this.events});

  final int totalEvents;
  final List<CalendarEvent> events;

  factory CalendarViewResult.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['payload'] is List ? json['payload'] as List : const [];
    return CalendarViewResult(
      totalEvents: _asInt(json['total_events']),
      events: rawEvents
          .whereType<Map>()
          .map((m) => CalendarEvent.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}

class CalendarEvent {
  const CalendarEvent({
    required this.courseId,
    required this.courseName,
    required this.classId,
    required this.className,
    required this.learningEventClassId,
    required this.title,
    required this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    required this.registrationStatus,
    required this.description,
    this.calendarDetailApi,
  });

  final int courseId;
  final String courseName;
  final int classId;
  final String className;
  final int learningEventClassId;
  final String title;
  final DateTime startDate;
  final DateTime? endDate;
  final String? startTime;
  final String? endTime;
  final String registrationStatus;
  final String description;
  final String? calendarDetailApi;

  DateTime get startDateTime => _combine(startDate, startTime);
  DateTime? get endDateTime =>
      endDate == null ? null : _combine(endDate!, endTime);

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      courseId: _asInt(json['course_id']),
      courseName: json['course_name']?.toString() ?? '',
      classId: _asInt(json['class_id']),
      className: json['class_name']?.toString() ?? '',
      learningEventClassId: _asInt(json['learning_event_class_id']),
      title: json['title']?.toString() ?? '',
      startDate:
          DateTime.tryParse(json['start_date']?.toString() ?? '') ??
              DateTime.now(),
      endDate: json['end_date'] == null
          ? null
          : DateTime.tryParse(json['end_date'].toString()),
      startTime: _nullableString(json['start_time']),
      endTime: _nullableString(json['end_time']),
      registrationStatus: json['registration_status']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      calendarDetailApi: _nullableString(json['calendar_detail_api']),
    );
  }
}

// The API sends dates/times in UTC with no timezone marker, so the
// combined value is built as UTC and converted to the device's local time
// (matching course_join_detail.dart's _combineDateAndTime) - otherwise
// events show up shifted by the local UTC offset (+5:30 on an IST device).
DateTime _combine(DateTime date, String? time) {
  if (time == null || time.isEmpty) return DateTime.utc(date.year, date.month, date.day).toLocal();
  final parts = time.split(':');
  if (parts.isEmpty) return DateTime.utc(date.year, date.month, date.day).toLocal();
  final h = int.tryParse(parts[0]) ?? 0;
  final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  final s = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
  return DateTime.utc(date.year, date.month, date.day, h, m, s).toLocal();
}

String? _nullableString(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
