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
