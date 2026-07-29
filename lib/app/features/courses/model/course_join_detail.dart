import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:lms/app/core/core.dart';

class CourseJoinDetail {
  const CourseJoinDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.objective,
    required this.logo,
    required this.participantGuide,
    required this.learningPath,
    required this.launchStatus,
    required this.launchDate,
    required this.nextVirtualClassEvent,
    required this.progressPercentage,
    required this.primaryAction,
    required this.isEnrolled,
    required this.allowRating,
    required this.skills,
    required this.structures,
  });

  final int id;
  final String title;
  final String description;
  final String objective;
  final String? logo;
  final String? participantGuide;
  final String? learningPath;
  final String launchStatus;
  final DateTime? launchDate;
  // The single source of truth for "does this course have an upcoming
  // Virtual Class session, and when": both the LAUNCHES IN countdown
  // (launchDate) and the Register -> Confirm dialog in the view layer read
  // from this same field, so they can never disagree about whether a real
  // session exists.
  final LearningEvent? nextVirtualClassEvent;
  final double progressPercentage; // 0.0 to 1.0
  final String primaryAction;
  final bool isEnrolled;
  final bool allowRating;
  final List<String> skills;
  final List<CourseStructureItem> structures;

  /// classId -> learningEventClassId for every Virtual Class (typeCode '3')
  /// or In Person (typeCode '2') class that has an upcoming session -
  /// POST lms-screen/register-course rejects whole-course enrollment
  /// ("some classes require a session selection") unless this is supplied
  /// for every such class. Auto-selects each class's own earliest upcoming
  /// session.
  Map<int, int> get classLearningEventSelections {
    final selections = <int, int>{};
    for (final item in structures) {
      if (item.classId == null) continue;
      if (item.typeCode != '2' && item.typeCode != '3') continue;
      final event = _earliestUpcomingEventOf(item.learningEvents);
      final eventId = event?.learningEventClassId;
      if (eventId != null) selections[item.classId!] = eventId;
    }
    return selections;
  }

  /// Every Virtual Class / In Person class that has at least one upcoming
  /// session - each one needs its own session picked before whole-course
  /// enrollment can succeed, matching the website's step-through-each-class
  /// Register wizard (Next per class, Register on the last, then a final
  /// Confirm summarizing every selection).
  List<CourseStructureItem> get classesRequiringSessionSelection => structures
      .where((item) =>
          item.classId != null &&
          (item.typeCode == '2' || item.typeCode == '3') &&
          _earliestUpcomingEventOf(item.learningEvents) != null)
      .toList();

  factory CourseJoinDetail.fromJson(Map<String, dynamic> json) {
    final root = _payloadMap(json);
    final course = _courseMap(root);
    final classes = _firstList(root, const [
      'course_classes',
      'courseClasses',
      'classes',
      'events',
      'course_structure',
      'courseStructure',
      'learning_events',
      'learningEvents',
    ]);
    final actionLabel = _actionLabel(root, course);
    final rootRegistered = _isRegistered(root);
    final courseRegistered = _isRegistered(course);
    final actionCancel = _actionMeansCancel(actionLabel);
    final isEnrolled = rootRegistered || courseRegistered || actionCancel;
    if (kDebugMode) {
      debugPrint(
        '[CourseJoinDetail] course_id=${_firstValue(root, course, const ['course_id', 'courseId', 'id'])} '
        'actionLabel="$actionLabel" '
        'isRegistered(root)=$rootRegistered '
        'isRegistered(course)=$courseRegistered '
        'actionMeansCancel=$actionCancel '
        '=> isEnrolled=$isEnrolled',
      );
      debugPrint('[CourseJoinDetail] root enrollment-related keys: ${_enrollmentKeySnapshot(root)}');
      debugPrint('[CourseJoinDetail] course enrollment-related keys: ${_enrollmentKeySnapshot(course)}');
    }
    final structures = classes
        .whereType<Map>()
        .map((value) => CourseStructureItem.fromJson(Map<String, dynamic>.from(value)))
        .toList();
    final nextVirtualClassEvent = _earliestUpcomingVirtualClassEvent(structures);
    if (kDebugMode) {
      debugPrint(
        '[CourseJoinDetail] nextVirtualClassEvent start='
        '${nextVirtualClassEvent?.startDateTime}',
      );
    }
    return CourseJoinDetail(
      id: _asInt(
        _firstValue(root, course, const ['course_id', 'courseId', 'id']),
      ),
      title:
          _clean(
            _firstValue(root, course, const [
              'course_name',
              'courseName',
              'name',
              'title',
            ]),
          ) ??
          'Course Details',
      description:
          _clean(
            _firstValue(root, course, const [
              'description',
              'course_description',
              'courseDescription',
            ]),
          ) ??
          '',
      objective:
          _clean(
            _firstValue(root, course, const [
              'objective',
              'objectives',
              'learning_objectives',
              'learningObjectives',
            ]),
          ) ??
          '',
      logo: _url(
        _firstValue(root, course, const [
          'logo_link',
          'logoLink',
          'logo',
          'image',
          'image_url',
          'banner',
          'thumbnail',
        ]),
      ),
      participantGuide: _url(
        _firstValue(root, course, const [
          'participant_guide_file',
          'participantGuideFile',
          'participant_guide_link',
          'participantGuideLink',
        ]),
      ),
      learningPath: _learningPath(root, course),
      launchStatus:
          _clean(
            _firstValue(root, course, const [
              'launch_status',
              'launchStatus',
              'course_status',
              'courseStatus',
              'status_label',
              'statusLabel',
            ]),
          ) ??
          (_asBool(
                    _firstValue(root, course, const ['is_closed', 'isClosed']),
                  ) ||
                  _isBookingClosed(root)
              ? 'Closed'
              : 'Open'),
      // Deliberately not sourced from generic top-level date fields
      // (course_date, available_at, etc.) - those matched unrelated course
      // metadata for courses with no actual scheduled session, producing a
      // bogus countdown. Only a real upcoming Virtual Class session counts,
      // same as nextVirtualClassEvent below.
      launchDate: nextVirtualClassEvent?.startDateTime,
      nextVirtualClassEvent: nextVirtualClassEvent,
      progressPercentage: _progressPercent(root, course),
      primaryAction:
          actionLabel ?? (isEnrolled ? 'Cancel Registration' : 'Enroll Now'),
      isEnrolled: isEnrolled,
      allowRating: _asBool(
        _firstValue(root, course, const ['allow_rating', 'allowRating']),
      ),
      skills: _skillNames(root, course),
      structures: structures,
    );
  }
}

class CourseStructureItem {
  const CourseStructureItem({
    required this.title,
    required this.subtitle,
    required this.nextSession,
    required this.status,
    required this.actionLabel,
    required this.icon,
    required this.showDetails,
    required this.showAction,
    required this.description,
    required this.learningEvents,
    required this.typeCode,
    required this.isEnrolledInClass,
    required this.recordingUrls,
    this.classId,
    this.contentUrl,
    this.downloadUrl,
  });

  final String title;
  final String subtitle;
  final String nextSession;
  final String status;
  final String actionLabel;
  final CourseStructureIcon icon;
  final bool showDetails;
  final bool showAction;
  final String description;
  final List<LearningEvent> learningEvents;
  final String typeCode;
  final bool isEnrolledInClass;
  final List<String> recordingUrls;
  final int? classId;
  final String? contentUrl;
  final String? downloadUrl;

  factory CourseStructureItem.fromJson(Map<String, dynamic> json) {
    final classMap =
        json['class'] is Map
            ? Map<String, dynamic>.from(json['class'])
            : json['class_info'] is Map
            ? Map<String, dynamic>.from(json['class_info'])
            : json;
    final typeCode =
        _firstValue(json, classMap, const [
          'type',
          'class_type',
          'classType',
        ])?.toString();
    final type =
        _clean(
          _firstValue(json, classMap, const [
            'type_name',
            'typeName',
            'class_type_name',
            'classTypeName',
            'type_label',
            'typeLabel',
          ]),
        ) ??
        _typeDisplayName(typeCode);
    final actionLabel =
        _clean(
          _firstValue(json, classMap, const [
            'button_text',
            'buttonText',
            'action_label',
            'actionLabel',
            'launch_button',
            'launchButton',
          ]),
        ) ??
        _typeActionLabel(typeCode);
    final enrollmentMap = json['enrollment'] is Map
        ? Map<String, dynamic>.from(json['enrollment'] as Map)
        : null;
    final enrollmentStatus = enrollmentMap != null ? _asInt(enrollmentMap['status']) : 0;
    final isEnrolledInClass = enrollmentStatus > 0;
    final classStatus = enrollmentStatus == 3
        ? 'Completed'
        : enrollmentStatus == 1
        ? 'Registered'
        : _clean(_firstValue(json, classMap, const [
            'status', 'status_label', 'statusLabel', 'completion_status', 'completionStatus',
          ])) ?? '';
    final effectiveActionLabel = isEnrolledInClass && typeCode == '1'
        ? 'Launch'
        : isEnrolledInClass && typeCode == '20'
        ? 'Launch Assessment'
        : isEnrolledInClass && typeCode == '3'
        ? 'Attend Class'
        : actionLabel;
    // Parse recording URLs from all learning events (e.g. Virtual Class recordings)
    final rawEventsAll = (json['learning_events'] ?? json['learningEvents'] ?? const []) as List? ?? const [];
    final recordingUrls = rawEventsAll
        .whereType<Map>()
        .expand<String>((event) {
          final recs = (event['recordings'] as List? ?? []);
          return recs.whereType<Map>()
              .map((r) => _url(r['recording_local_url']?.toString()))
              .whereType<String>();
        })
        .toList();

    // Parse content URLs from the `content` field
    final contentObj = json['content'];
    final contentMap = contentObj is Map
        ? Map<String, dynamic>.from(contentObj)
        : <String, dynamic>{};
    String? contentUrl;
    String? downloadUrl;
    switch (typeCode) {
      case '4': // Watch Video — videoUploadUrl lives in classMap, not contentMap
        contentUrl = _url(classMap['video_upload_url'])
            ?? _url(contentMap['video_upload_url'])
            ?? _url(json['video_upload_url']);
        downloadUrl = contentUrl;
        break;
      case '5': // Read Article
        contentUrl = _url(contentMap['article_file']);
        downloadUrl = contentUrl;
        break;
      case '6': // Read Webpage
        contentUrl = _url(contentMap['read_webpage_link']);
        break;
      case '7': // Discussion Board
        contentUrl = _url(contentMap['discussion_forum_link']);
        break;
      case '13': // LinkedIn Certification
        contentUrl = _url(contentMap['read_webpage_link']);
        break;
      case '14': // Discussion Guru
        contentUrl = _url(contentMap['discussion_guru_link']);
        break;
      case '15': // Peer Coaching (PDF)
        contentUrl = _url(contentMap['peer_coaching_file']);
        downloadUrl = contentUrl;
        break;
      case '17': // OnePage Pro
        contentUrl = _url(contentMap['read_webpage_link']);
        break;
      case '18': // Simulation / Custom Prompt
        contentUrl = _url(contentMap['bridgework_link']);
        break;
      case '19': // Agreement (PDF)
        contentUrl = _url(contentMap['article_file']);
        downloadUrl = contentUrl;
        break;
      case '3': // Virtual Class — session link from first learning event
        final rawEvents = (json['learning_events'] as List? ?? []);
        for (final e in rawEvents) {
          if (e is Map) {
            final link = _url(e['training_session_link']?.toString());
            if (link != null) { contentUrl = link; break; }
          }
        }
        break;
    }

    // Parsed once so a missing top-level next-session field can fall back
    // to the first learning event's own start date/time - the website's
    // "Next Session" for a class often only lives nested there, not as a
    // direct field on the class itself.
    final learningEvents = ((json['learning_events'] ?? json['learningEvents'] ?? const []) as List? ?? const [])
        .whereType<Map>()
        .map((e) => LearningEvent.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final directNextSession = _clean(
      _firstValue(json, classMap, const [
        'next_session',
        'nextSession',
        'start_date',
        'startDate',
        'session_date',
        'sessionDate',
      ]),
    );
    // Was `learningEvents.first` - the raw, unfiltered, unconverted first
    // entry in whatever order the API happens to return the class's
    // sessions in. A class with old/past sessions mixed in with a real
    // upcoming one (e.g. test data spanning 2021-2026) could show a
    // years-stale "Next Session" while Register correctly picked the
    // actual upcoming session underneath - two different displays for
    // what should be the same answer. Use the same still-open (start
    // through end) selection as registration, formatted from the already
    // UTC->local-corrected DateTime rather than pasting the raw strings.
    if (kDebugMode) {
      final itemTitle = _firstValue(json, classMap, const ['name', 'title', 'class_name', 'className']);
      debugPrint('[CourseStructureItem] "$itemTitle" typeCode=$typeCode learningEvents=${learningEvents.length}');
      for (final e in learningEvents) {
        debugPrint('[CourseStructureItem]   raw start=${e.startDate} ${e.startTime} '
            'end=${e.endDate} ${e.endTime} => startDateTime=${e.startDateTime} '
            'endDateTime=${e.endDateTime} learningEventClassId=${e.learningEventClassId}');
      }
    }
    final upcomingEvent = _earliestUpcomingEventOf(learningEvents);
    final eventNextSession = upcomingEvent?.startDateTime != null
        ? _formatNextSessionMoment(upcomingEvent!.startDateTime!)
        : null;

    return CourseStructureItem(
      title:
          _clean(
            _firstValue(json, classMap, const [
              'name',
              'title',
              'class_name',
              'className',
            ]),
          ) ??
          'Course Item',
      subtitle: type.isEmpty ? '' : '($type)',
      nextSession: directNextSession ?? eventNextSession ?? '',
      status: classStatus,
      actionLabel: effectiveActionLabel,
      icon: _structureIcon(typeCode),
      showDetails: _typeShowDetails(typeCode),
      showAction: effectiveActionLabel.isNotEmpty,
      description: _clean(_firstValue(json, classMap, const ['description', 'class_description', 'classDescription'])) ?? '',
      learningEvents: learningEvents,
      typeCode: typeCode ?? '',
      isEnrolledInClass: isEnrolledInClass,
      recordingUrls: recordingUrls,
      classId: _asIntOrNull(
        _firstValue(json, classMap, const ['class_id', 'classId', 'id']),
      ),
      contentUrl: contentUrl,
      downloadUrl: downloadUrl,
    );
  }
}

enum CourseStructureIcon {
  register,
  video,
  article,
  webpage,
  discussionBoard,
  tasks,
  coaches,
  insights,
  certification,
  discussionGuru,
  link,
  agreement,
  details,
}

class LearningEvent {
  const LearningEvent({
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.instructor,
    required this.location,
    required this.instructions,
    this.sessionLink,
    this.learningEventClassId,
  });

  final String startDate;
  final String endDate;
  final String startTime;
  final String endTime;
  final String instructor;
  final String location;
  final String instructions;
  final String? sessionLink;
  // Required by POST lms-screen/register-course to select this specific
  // session when registering for a class that has one (virtual/in-person).
  final int? learningEventClassId;

  DateTime? get startDateTime => _combineDateAndTime(startDate, startTime);
  DateTime? get endDateTime => _combineDateAndTime(endDate, endTime);

  factory LearningEvent.fromJson(Map<String, dynamic> json) {
    return LearningEvent(
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
      instructor: json['instructor']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      instructions: json['instructions']?.toString() ?? '',
      sessionLink: _clean(json['training_session_link']?.toString()),
      learningEventClassId: _asIntOrNull(json['learning_event_class_id'] ?? json['id']),
    );
  }
}

/// The earliest still-upcoming Virtual Class (typeCode '3') session across
/// the course's classes - and nothing else. Scoped to Virtual Class only:
/// other content types (video/PDF/article/...) can also carry a
/// `learning_events` array in the API response, and picking up a date from
/// one of those produced a bogus countdown on courses with no real session
/// at all.
LearningEvent? _earliestUpcomingVirtualClassEvent(List<CourseStructureItem> structures) {
  LearningEvent? earliest;
  for (final item in structures) {
    if (item.typeCode != '3') continue;
    final candidate = _earliestUpcomingEventOf(item.learningEvents);
    if (candidate == null) continue;
    if (earliest == null || candidate.startDateTime!.isBefore(earliest.startDateTime!)) {
      earliest = candidate;
    }
  }
  return earliest;
}

/// The earliest still-registerable event within a single class's own
/// learningEvents list. A session stays registerable for its whole
/// duration - from start through end, not just before it starts - matching
/// the website, which keeps a class's status "Available" until its end
/// datetime rather than closing registration the moment it starts.
LearningEvent? _earliestUpcomingEventOf(List<LearningEvent> events) {
  final now = DateTime.now();
  LearningEvent? earliest;
  for (final event in events) {
    final start = event.startDateTime;
    if (start == null) continue;
    final end = event.endDateTime;
    final stillOpen = end == null ? !start.isBefore(now) : now.isBefore(end);
    if (!stillOpen) continue;
    if (earliest == null || start.isBefore(earliest.startDateTime!)) earliest = event;
  }
  return earliest;
}

String _formatNextSessionMoment(DateTime dt) {
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${pad(dt.month)}-${pad(dt.day)} ${pad(dt.hour)}:${pad(dt.minute)}:${pad(dt.second)}';
}

/// The API sends session dates/times in UTC with no timezone marker (plain
/// "2026-07-30" + "11:45:00"), so they're parsed as UTC and converted to
/// the device's local time here - on an IST device that's +5:30, which is
/// what makes the countdown/START-END times match what the learner should
/// actually see the session start locally, not the raw UTC values.
DateTime? _combineDateAndTime(String dateStr, String timeStr) {
  final date = DateTime.tryParse(dateStr);
  if (date == null) return null;
  if (timeStr.isEmpty) return DateTime.utc(date.year, date.month, date.day).toLocal();
  final parts = timeStr.split(':');
  final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  final second = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
  return DateTime.utc(date.year, date.month, date.day, hour, minute, second).toLocal();
}

double _progressPercent(
  Map<String, dynamic> root,
  Map<String, dynamic> course,
) {
  final direct = _firstValue(root, course, const [
    'course_progress_percentage',
    'courseProgressPercentage',
    'progress_percentage',
    'progressPercentage',
  ]);
  if (direct != null) return _asPercent(direct);
  for (final map in [root, course]) {
    final ab = map['action_buttons'];
    if (ab is Map) {
      final val =
          ab['course_progress_percentage'] ??
          ab['progress_percentage'] ??
          ab['progress'];
      if (val != null) return _asPercent(val);
    }
  }
  return 0.0;
}

double _asPercent(dynamic value) {
  final str = value?.toString().replaceAll('%', '').trim() ?? '';
  final parsed = double.tryParse(str) ?? 0.0;
  return parsed > 1.0 ? parsed / 100.0 : parsed;
}

Map<String, dynamic> _payloadMap(Map<String, dynamic> json) {
  final payload = json['payload'] ?? json['data'] ?? json['course'];
  if (payload is Map) return Map<String, dynamic>.from(payload);
  if (payload is List && payload.isNotEmpty && payload.first is Map) {
    return Map<String, dynamic>.from(payload.first);
  }
  return json;
}

Map<String, dynamic> _courseMap(Map<String, dynamic> json) {
  for (final key in const [
    'course',
    'course_detail',
    'courseDetail',
    'course_info',
    'courseInfo',
    'details',
  ]) {
    final value = json[key];
    if (value is Map) return Map<String, dynamic>.from(value);
  }
  return json;
}

dynamic _firstValue(
  Map<String, dynamic> primary,
  Map<String, dynamic> secondary,
  List<String> keys,
) {
  for (final key in keys) {
    if (primary.containsKey(key) && primary[key] != null) return primary[key];
    if (secondary.containsKey(key) && secondary[key] != null) {
      return secondary[key];
    }
  }
  return null;
}

List<dynamic> _firstList(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is List) return value;
    if (value is Map) return value.values.toList();
  }
  return const [];
}

List<String> _skillNames(
  Map<String, dynamic> root,
  Map<String, dynamic> course,
) {
  final values = _firstList(root, const [
    'skills',
    'skill',
    'behaviors',
    'behaviours',
    'skills_behaviors',
    'skillsBehaviors',
    'available_skills',
  ]);
  return values
      .map((value) {
        if (value is Map) {
          return _clean(
            value['name'] ??
                value['skill_name'] ??
                value['skillName'] ??
                value['behavior_name'] ??
                value['behaviour_name'],
          );
        }
        return _clean(value);
      })
      .whereType<String>()
      .toList();
}

String? _actionLabel(Map<String, dynamic> root, Map<String, dynamic> course) {
  final direct = _clean(
    _firstValue(root, course, const [
      'button_text',
      'buttonText',
      'primary_action',
      'primaryAction',
      'registration_button',
      'registrationButton',
      'registration_button_text',
      'registrationButtonText',
      'enrollment_button',
      'enrollmentButton',
      'enroll_button_text',
      'enrollButtonText',
      'action_label',
      'actionLabel',
      'label',
    ]),
  );
  return direct ?? _findActionLabel(root) ?? _findActionLabel(course);
}

String? _learningPath(Map<String, dynamic> root, Map<String, dynamic> course) {
  final direct = _clean(
    _firstValue(root, course, const [
      'learning_path',
      'learningPath',
      'learning_path_name',
      'learningPathName',
    ]),
  );
  if (direct != null) return direct;
  final values = _firstList(root, const ['learning_paths', 'learningPaths']);
  if (values.isEmpty) return null;
  return values.map(_clean).whereType<String>().join(', ');
}

bool _isBookingClosed(Map<String, dynamic> root) {
  final booking = root['booking_status'];
  if (booking is! Map) return false;
  final max = _asInt(booking['max_registrations']);
  final registered = _asInt(booking['registered_users']);
  return max > 0 && registered >= max;
}

String? _findActionLabel(dynamic value) {
  if (value is Map) {
    for (final entry in value.entries) {
      if (entry.value is Map || entry.value is List) continue;
      final key = entry.key.toString().toLowerCase();
      final text = _clean(entry.value);
      if (text != null &&
          (key.contains('button') ||
              key.contains('action') ||
              key.contains('registration') ||
              key.contains('enroll')) &&
          _looksLikeAction(text)) {
        return text;
      }
    }
    for (final entry in value.entries) {
      final nested = _findActionLabel(entry.value);
      if (nested != null) return nested;
    }
  }
  if (value is Iterable) {
    for (final item in value) {
      final nested = _findActionLabel(item);
      if (nested != null) return nested;
    }
  }
  return null;
}

bool _looksLikeAction(String text) {
  final value = text.toLowerCase();
  return value.contains('enroll') ||
      value.contains('register') ||
      value.contains('cancel') ||
      value.contains('join');
}

/// Debug-only diagnostic dump of whichever registration/enrollment-shaped
/// keys are actually present at the top level of [map], so a mismatch
/// between what the API sends and the key names `_isRegistered` looks for
/// can be spotted directly from a device/console log capture.
Map<String, dynamic> _enrollmentKeySnapshot(Map<String, dynamic> map) {
  const candidateKeys = [
    'is_enrolled', 'isEnrolled', 'is_registered', 'isRegistered', 'registered',
    'enrolled', 'is_joined', 'isJoined', 'joined', 'is_enroll', 'isEnroll',
    'is_user_enrolled', 'isUserEnrolled', 'is_user_registered', 'isUserRegistered',
    'user_registered', 'userRegistered', 'course_enrolled', 'courseEnrolled',
    'course_registered', 'courseRegistered', 'already_enrolled', 'alreadyEnrolled',
    'already_registered', 'alreadyRegistered',
    'registration_status', 'registrationStatus', 'enrollment_status', 'enrollmentStatus',
    'roster_status', 'rosterStatus', 'roaster_status', 'roasterStatus',
    'user_course_status', 'userCourseStatus',
    'registration', 'registration_detail', 'registrationDetail', 'enrollment',
    'enrollment_detail', 'enrollmentDetail', 'roster', 'roster_detail', 'rosterDetail',
    'roaster', 'rosters', 'roasters', 'user_roster', 'userRoster', 'user_rosters',
    'userRosters', 'user_roaster', 'userRoaster', 'user_roasters', 'userRoasters',
    'user_course', 'userCourse',
  ];
  final found = <String, dynamic>{};
  for (final key in candidateKeys) {
    if (map.containsKey(key)) found[key] = map[key];
  }
  return found;
}

bool _isRegistered(Map<String, dynamic> map) {
  for (final key in const [
    'is_enrolled',
    'isEnrolled',
    'is_registered',
    'isRegistered',
    'registered',
    'enrolled',
    'is_joined',
    'isJoined',
    'joined',
    'is_enroll',
    'isEnroll',
    'is_user_enrolled',
    'isUserEnrolled',
    'is_user_registered',
    'isUserRegistered',
    'user_registered',
    'userRegistered',
    'course_enrolled',
    'courseEnrolled',
    'course_registered',
    'courseRegistered',
    'already_enrolled',
    'alreadyEnrolled',
    'already_registered',
    'alreadyRegistered',
  ]) {
    if (_asBool(map[key])) return true;
  }

  for (final key in const [
    'registration_status',
    'registrationStatus',
    'enrollment_status',
    'enrollmentStatus',
    'roster_status',
    'rosterStatus',
    'roaster_status',
    'roasterStatus',
    'user_course_status',
    'userCourseStatus',
  ]) {
    if (_statusMeansRegistered(map[key])) return true;
  }

  for (final key in const [
    'registration',
    'registration_detail',
    'registrationDetail',
    'enrollment',
    'enrollment_detail',
    'enrollmentDetail',
    'roster',
    'roster_detail',
    'rosterDetail',
    'roaster',
    'rosters',
    'roasters',
    'user_roster',
    'userRoster',
    'user_rosters',
    'userRosters',
    'user_roaster',
    'userRoaster',
    'user_roasters',
    'userRoasters',
    'roaster_detail',
    'roasterDetail',
    'user_course',
    'userCourse',
  ]) {
    final value = map[key];
    if (value is Map && value.isNotEmpty && !_recordLooksCancelled(value)) {
      return true;
    }
    if (value is List && value.isNotEmpty) return true;
  }

  return false;
}

bool _statusMeansRegistered(dynamic value) {
  final text = value?.toString().toLowerCase().trim() ?? '';
  return text == '1' ||
      text == 'registered' ||
      text == 'enrolled' ||
      text == 'joined' ||
      text == 'active' ||
      text == 'approved' ||
      text.contains('registered') ||
      text.contains('enrolled');
}

bool _recordLooksCancelled(Map<dynamic, dynamic> value) {
  final status =
      value['status'] ??
      value['registration_status'] ??
      value['enrollment_status'] ??
      value['roster_status'];
  final text = status?.toString().toLowerCase().trim() ?? '';
  return text == '0' ||
      text == 'cancelled' ||
      text == 'canceled' ||
      text.contains('cancel');
}

bool _actionMeansCancel(String? value) {
  final text = value?.toLowerCase() ?? '';
  return text.contains('cancel');
}

String? _clean(dynamic value) {
  final text = value?.toString().stripHtml.trim();
  if (text == null || text.isEmpty || text == 'null' || text == '0') {
    return null;
  }
  return text;
}

String? _url(dynamic value) {
  final text = _clean(value);
  if (text == null) return null;
  return text.startsWith('http://') || text.startsWith('https://')
      ? text
      : null;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  final text = value?.toString().toLowerCase().trim();
  return text == '1' || text == 'true' || text == 'yes' || text == 'enrolled';
}

String _typeDisplayName(String? typeCode) {
  switch (typeCode) {
    case '1':  return 'eLearning Module';
    case '2':  return 'In Person';
    case '3':  return 'Virtual Class';
    case '4':  return 'Watch Video';
    case '5':  return 'Read Article';
    case '6':  return 'Read Webpage';
    case '7':  return 'Discussion Board';
    case '8':  return 'Perform Task With Observation';
    case '9':  return 'Perform Task Without Observation';
    case '10': return 'Receive Coaching';
    case '11': return 'Insight Report';
    case '12': return 'Certificate';
    case '13': return 'LinkedIn Certification';
    case '14': return 'Discussion Guru';
    case '15': return 'Peer Coaching';
    case '17': return 'OnePage Pro';
    case '18': return 'Custom Prompt';
    case '19': return 'Agreement';
    case '20': return 'Test Out Assessment';
    case '22': return 'Text Message';
    case '23': return 'Web Application';
    default:   return '';
  }
}

String _typeActionLabel(String? typeCode) {
  switch (typeCode) {
    case '1':
    case '2':
    case '3':  return 'Register';
    case '4':  return 'Video';
    case '5':  return 'Article';
    case '6':  return 'Webpage';
    case '7':  return 'Discussion Board';
    case '8':
    case '9':  return 'Tasks';
    case '10': return 'Coaches';
    case '11': return 'Insights';
    case '13': return 'Certification';
    case '14': return 'Discussion Guru';
    case '17': return 'OnePage Pro';
    case '18': return 'Bridgework Link';
    case '19': return 'Agreement';
    case '23': return 'Launch Web Application';
    default:   return '';
  }
}

bool _typeShowDetails(String? typeCode) {
  switch (typeCode) {
    case '12': // Certificate - no buttons
    case '14': // Discussion Guru - action only
    case '17': // OnePage Pro - action only
    case '23': // Web Application - action only
      return false;
    default:
      return true;
  }
}

CourseStructureIcon _structureIcon(String? typeCode) {
  switch (typeCode) {
    case '1':
    case '2':
    case '3':  return CourseStructureIcon.register;
    case '4':  return CourseStructureIcon.video;
    case '5':  return CourseStructureIcon.article;
    case '6':  return CourseStructureIcon.webpage;
    case '7':  return CourseStructureIcon.discussionBoard;
    case '8':
    case '9':  return CourseStructureIcon.tasks;
    case '10': return CourseStructureIcon.coaches;
    case '11': return CourseStructureIcon.insights;
    case '13': return CourseStructureIcon.certification;
    case '14': return CourseStructureIcon.discussionGuru;
    case '17':
    case '18':
    case '23': return CourseStructureIcon.link;
    case '19': return CourseStructureIcon.agreement;
    default:   return CourseStructureIcon.details;
  }
}
