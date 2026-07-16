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
  final String primaryAction;
  final bool isEnrolled;
  final bool allowRating;
  final List<String> skills;
  final List<CourseStructureItem> structures;

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
    final isEnrolled =
        _isRegistered(root) ||
        _isRegistered(course) ||
        _actionMeansCancel(actionLabel);
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
      primaryAction:
          actionLabel ?? (isEnrolled ? 'Cancel Registration' : 'Enroll Now'),
      isEnrolled: isEnrolled,
      allowRating: _asBool(
        _firstValue(root, course, const ['allow_rating', 'allowRating']),
      ),
      skills: _skillNames(root, course),
      structures:
          classes
              .whereType<Map>()
              .map(
                (value) => CourseStructureItem.fromJson(
                  Map<String, dynamic>.from(value),
                ),
              )
              .toList(),
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
        : actionLabel;
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
      nextSession:
          _clean(
            _firstValue(json, classMap, const [
              'next_session',
              'nextSession',
              'start_date',
              'startDate',
              'session_date',
              'sessionDate',
            ]),
          ) ??
          '',
      status: classStatus,
      actionLabel: effectiveActionLabel,
      icon: _structureIcon(typeCode),
      showDetails: _typeShowDetails(typeCode),
      showAction: effectiveActionLabel.isNotEmpty,
      description: _clean(_firstValue(json, classMap, const ['description', 'class_description', 'classDescription'])) ?? '',
      learningEvents: ((json['learning_events'] ?? json['learningEvents'] ?? const []) as List? ?? const [])
          .whereType<Map>()
          .map((e) => LearningEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
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
  });

  final String startDate;
  final String endDate;
  final String startTime;
  final String endTime;
  final String instructor;
  final String location;
  final String instructions;
  final String? sessionLink;

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
    );
  }
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
