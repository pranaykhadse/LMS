import 'dart:convert';

class Roaster {
  final String? id;
  final String? courseId;
  final String? classId;
  final String? userId;
  final String? status;
  final dynamic cancellationTime;
  final String? isActive;
  final String? elearningLaunch;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final dynamic learningEventClassId;
  final dynamic isSignatureDone;
  final String? signatureImage;
  final dynamic learningEventClass;

  Roaster({
    this.id,
    this.courseId,
    this.classId,
    this.userId,
    this.status,
    this.cancellationTime,
    this.isActive,
    this.elearningLaunch,
    this.createdAt,
    this.updatedAt,
    this.learningEventClassId,
    this.isSignatureDone,
    this.signatureImage,
    this.learningEventClass,
  });

  Roaster copyWith({
    String? id,
    String? courseId,
    String? classId,
    String? userId,
    String? status,
    dynamic cancellationTime,
    String? isActive,
    String? elearningLaunch,
    DateTime? createdAt,
    DateTime? updatedAt,
    dynamic learningEventClassId,
    dynamic isSignatureDone,
    String? signatureImage,
    dynamic learningEventClass,
  }) => Roaster(
    id: id ?? this.id,
    courseId: courseId ?? this.courseId,
    classId: classId ?? this.classId,
    userId: userId ?? this.userId,
    status: status ?? this.status,
    cancellationTime: cancellationTime ?? this.cancellationTime,
    isActive: isActive ?? this.isActive,
    elearningLaunch: elearningLaunch ?? this.elearningLaunch,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    learningEventClassId: learningEventClassId ?? this.learningEventClassId,
    isSignatureDone: isSignatureDone ?? this.isSignatureDone,
    signatureImage: signatureImage ?? this.signatureImage,
    learningEventClass: learningEventClass ?? this.learningEventClass,
  );

  factory Roaster.fromRawJson(String str) => Roaster.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Roaster.fromJson(Map<dynamic, dynamic> json) => Roaster(
    id: json["id"]?.toString(),
    courseId: json["course_id"]?.toString(),
    classId: json["class_id"]?.toString(),
    userId: json["user_id"]?.toString(),
    status: json["status"]?.toString(),
    cancellationTime: json["cancellation_time"],
    isActive: json["is_active"]?.toString(),
    elearningLaunch: json["elearning_launch"]?.toString(),
    createdAt:
        json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
    updatedAt:
        json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
    learningEventClassId: json["learning_event_class_id"]?.toString(),
    isSignatureDone: json["is_signature_done"]?.toString(),
    signatureImage: json["signature_image"]?.toString(),
    learningEventClass: json["learningEventClass"]?.toString(),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "course_id": courseId,
    "class_id": classId,
    "user_id": userId,
    "status": status,
    "cancellation_time": cancellationTime,
    "is_active": isActive,
    "elearning_launch": elearningLaunch,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "learning_event_class_id": learningEventClassId,
    "is_signature_done": isSignatureDone,
    "signature_image": signatureImage,
    "learningEventClass": learningEventClass,
  };
}
