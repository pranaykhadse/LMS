import 'dart:convert';

import 'package:lms/app/features/courses/model/class_info.dart';

class CourseClass {
  final String? id;
  final String? courseId;
  final String? classId;
  final String? scannedPdf;
  final String? order;
  final ClassInfo? classInfo;
  // All LEC-level fields from allcourse/events (training links, dates, etc.).
  // Used as fallback when fetch-user-roaster doesn't populate learningEventClass.
  final Map<dynamic, dynamic>? rawLec;

  CourseClass({
    this.id,
    this.courseId,
    this.classId,
    this.scannedPdf,
    this.order,
    this.classInfo,
    this.rawLec,
  });

  CourseClass copyWith({
    String? id,
    String? courseId,
    String? classId,
    String? scannedPdf,
    String? order,
    ClassInfo? classInfo,
    Map<dynamic, dynamic>? rawLec,
  }) {
    return CourseClass(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      classId: classId ?? this.classId,
      scannedPdf: scannedPdf ?? this.scannedPdf,
      order: order ?? this.order,
      classInfo: classInfo ?? this.classInfo,
      rawLec: rawLec ?? this.rawLec,
    );
  }

  static const _standardKeys = {'id', 'course_id', 'class_id', 'scanned_pdf', 'order', 'class'};

  Map<String, dynamic> toJson() {
    // Spread extra LEC fields (training links, dates, etc.) so they survive
    // Hive offline storage and can be read back via fromJson.
    final extraLec = rawLec?.entries
        .where((e) => !_standardKeys.contains(e.key.toString()))
        .map((e) => MapEntry(e.key.toString(), e.value));
    return {
      'id': id,
      'course_id': courseId,
      'class_id': classId,
      'scanned_pdf': scannedPdf,
      'order': order,
      'class': classInfo?.toJson(),
      if (extraLec != null) ...Map.fromEntries(extraLec),
    };
  }

  factory CourseClass.fromJson(Map<dynamic, dynamic> map) {
    // Capture every top-level field except 'class' as raw LEC data.
    final raw = Map<dynamic, dynamic>.from(map)..remove('class');
    return CourseClass(
      id: map['id']?.toString(),
      courseId: map['course_id']?.toString(),
      classId: map['class_id']?.toString(),
      scannedPdf: map['scanned_pdf']?.toString(),
      order: map['order']?.toString(),
      classInfo: map['class'] != null ? ClassInfo.fromJson(map['class']) : null,
      rawLec: raw,
    );
  }

  /// Recording URLs for Virtual Class (type '3') events.
  /// Priority: rawLec['recording_links'] list →
  ///           rawLec['training_session_recording_link'] →
  ///           classInfo.alternativeLearningEvent →
  ///           dummy URL (temporary, until backend returns the field)
  List<String> get recordingUrls {
    if (classInfo?.type != '3') return const [];
    final urls = <String>[];

    if (rawLec != null) {
      final links = rawLec!['recording_links'];
      if (links is List) {
        for (final l in links) {
          final u = _cleanRecUrl(l?.toString());
          if (u != null) urls.add(u);
        }
      }
      if (urls.isEmpty) {
        final u = _cleanRecUrl(
            rawLec!['training_session_recording_link']?.toString());
        if (u != null) urls.add(u);
      }
    }

    if (urls.isEmpty) {
      final u = _cleanRecUrl(classInfo?.alternativeLearningEvent);
      if (u != null) urls.add(u);
    }

    // TODO: remove once backend reliably returns training_session_recording_link
    if (urls.isEmpty) {
      urls.add('https://dwpfuyia3u2j6.cloudfront.net/fdNb996MNYiX2CK.m3u8');
    }

    return urls;
  }

  static String? _cleanRecUrl(String? url) {
    if (url == null || url.trim().isEmpty || url.trim() == '0') return null;
    return url.trim();
  }

  String toRawJson() => json.encode(toJson());

  factory CourseClass.fromRawJson(String source) =>
      CourseClass.fromJson(json.decode(source));

  @override
  String toString() {
    return 'CourseClass(id: $id, courseId: $courseId, classId: $classId, scannedPdf: $scannedPdf, order: $order, classInfo: $classInfo)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CourseClass &&
        other.id == id &&
        other.courseId == courseId &&
        other.classId == classId &&
        other.scannedPdf == scannedPdf &&
        other.order == order &&
        other.classInfo == classInfo;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      courseId.hashCode ^
      classId.hashCode ^
      scannedPdf.hashCode ^
      order.hashCode ^
      classInfo.hashCode;
}
