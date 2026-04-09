import 'dart:convert';

import 'package:lms/app/features/courses/model/class_info.dart';

class CourseClass {
  final String? id;
  final String? courseId;
  final String? classId;
  final String? scannedPdf;
  final String? order;
  final ClassInfo? classInfo;
  CourseClass({
    this.id,
    this.courseId,
    this.classId,
    this.scannedPdf,
    this.order,
    this.classInfo,
  });

  CourseClass copyWith({
    String? id,
    String? courseId,
    String? classId,
    String? scannedPdf,
    String? order,
    ClassInfo? classInfo,
  }) {
    return CourseClass(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      classId: classId ?? this.classId,
      scannedPdf: scannedPdf ?? this.scannedPdf,
      order: order ?? this.order,
      classInfo: classInfo ?? this.classInfo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_id': courseId,
      'class_id': classId,
      'scanned_pdf': scannedPdf,
      'order': order,
      'class': classInfo?.toJson(),
    };
  }

  factory CourseClass.fromJson(Map<dynamic, dynamic> map) {
    return CourseClass(
      id: map['id'],
      courseId: map['course_id'],
      classId: map['class_id'],
      scannedPdf: map['scanned_pdf'],
      order: map['order'],
      classInfo: map['class'] != null ? ClassInfo.fromJson(map['class']) : null,
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
  int get hashCode {
    return id.hashCode ^
        courseId.hashCode ^
        classId.hashCode ^
        scannedPdf.hashCode ^
        order.hashCode ^
        classInfo.hashCode;
  }
}
