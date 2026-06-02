import 'dart:convert';

import 'package:lms/app/features/courses/model/roaster.dart';

class Course {
  final int? id;
  final int? groupId;
  final String? name;
  final dynamic amount;
  final String? objective;
  final String? description;
  final String? checklist;
  final int? supervisorApproval;
  final int? createdBy;
  final int? isPayment;
  final String? logoLink;
  final int? maxRegistrations;
  final dynamic participantGuideFile;
  final dynamic participantGuideLink;
  final dynamic wrapMethodologyFile;
  final dynamic wrapMethodologyLink;
  final int? isRequired;
  final int? reminderFrequency;
  final int? recurrenceTime;
  final dynamic dueDate;
  final dynamic oldDueDate;
  final dynamic requiredTrainingMessage;
  final dynamic lastReminderEmailDate;
  final int? enrollDeadlineRequired;
  final int? enrollDeadlineType;
  final int? enrollDeadlineTime;
  final dynamic fakePeopleGroup;
  final int? customTimeLimit;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? isActive;
  final int? allowRating;
  final int? displayRating;
  final dynamic averageRating;
  final int? ratingCount;
  final dynamic duration;
  final dynamic clientItemId;
  final dynamic clientItemType;
  final List<Roaster>? roasters;
  Course({
    this.id,
    this.groupId,
    this.name,
    this.amount,
    this.objective,
    this.description,
    this.checklist,
    this.supervisorApproval,
    this.createdBy,
    this.isPayment,
    this.logoLink,
    this.maxRegistrations,
    this.participantGuideFile,
    this.participantGuideLink,
    this.wrapMethodologyFile,
    this.wrapMethodologyLink,
    this.isRequired,
    this.reminderFrequency,
    this.recurrenceTime,
    this.dueDate,
    this.oldDueDate,
    this.requiredTrainingMessage,
    this.lastReminderEmailDate,
    this.enrollDeadlineRequired,
    this.enrollDeadlineType,
    this.enrollDeadlineTime,
    this.fakePeopleGroup,
    this.customTimeLimit,
    this.createdAt,
    this.updatedAt,
    this.isActive,
    this.allowRating,
    this.displayRating,
    this.averageRating,
    this.ratingCount,
    this.duration,
    this.clientItemId,
    this.clientItemType,
    this.roasters,
  });

  Course copyWith({
    int? id,
    int? groupId,
    String? name,
    dynamic amount,
    String? objective,
    String? description,
    String? checklist,
    int? supervisorApproval,
    int? createdBy,
    int? isPayment,
    String? logoLink,
    int? maxRegistrations,
    dynamic participantGuideFile,
    dynamic participantGuideLink,
    dynamic wrapMethodologyFile,
    dynamic wrapMethodologyLink,
    int? isRequired,
    int? reminderFrequency,
    int? recurrenceTime,
    dynamic dueDate,
    dynamic oldDueDate,
    dynamic requiredTrainingMessage,
    dynamic lastReminderEmailDate,
    int? enrollDeadlineRequired,
    int? enrollDeadlineType,
    int? enrollDeadlineTime,
    dynamic fakePeopleGroup,
    int? customTimeLimit,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? isActive,
    int? allowRating,
    int? displayRating,
    dynamic averageRating,
    int? ratingCount,
    dynamic duration,
    dynamic clientItemId,
    dynamic clientItemType,
    List<Roaster>? roasters,
  }) => Course(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    objective: objective ?? this.objective,
    description: description ?? this.description,
    checklist: checklist ?? this.checklist,
    supervisorApproval: supervisorApproval ?? this.supervisorApproval,
    createdBy: createdBy ?? this.createdBy,
    isPayment: isPayment ?? this.isPayment,
    logoLink: logoLink ?? this.logoLink,
    maxRegistrations: maxRegistrations ?? this.maxRegistrations,
    participantGuideFile: participantGuideFile ?? this.participantGuideFile,
    participantGuideLink: participantGuideLink ?? this.participantGuideLink,
    wrapMethodologyFile: wrapMethodologyFile ?? this.wrapMethodologyFile,
    wrapMethodologyLink: wrapMethodologyLink ?? this.wrapMethodologyLink,
    isRequired: isRequired ?? this.isRequired,
    reminderFrequency: reminderFrequency ?? this.reminderFrequency,
    recurrenceTime: recurrenceTime ?? this.recurrenceTime,
    dueDate: dueDate ?? this.dueDate,
    oldDueDate: oldDueDate ?? this.oldDueDate,
    requiredTrainingMessage:
        requiredTrainingMessage ?? this.requiredTrainingMessage,
    lastReminderEmailDate: lastReminderEmailDate ?? this.lastReminderEmailDate,
    enrollDeadlineRequired:
        enrollDeadlineRequired ?? this.enrollDeadlineRequired,
    enrollDeadlineType: enrollDeadlineType ?? this.enrollDeadlineType,
    enrollDeadlineTime: enrollDeadlineTime ?? this.enrollDeadlineTime,
    fakePeopleGroup: fakePeopleGroup ?? this.fakePeopleGroup,
    customTimeLimit: customTimeLimit ?? this.customTimeLimit,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isActive: isActive ?? this.isActive,
    allowRating: allowRating ?? this.allowRating,
    displayRating: displayRating ?? this.displayRating,
    averageRating: averageRating ?? this.averageRating,
    ratingCount: ratingCount ?? this.ratingCount,
    duration: duration ?? this.duration,
    clientItemId: clientItemId ?? this.clientItemId,
    clientItemType: clientItemType ?? this.clientItemType,
    roasters: roasters ?? this.roasters,
  );

  factory Course.fromRawJson(String str) => Course.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Course.fromJson(Map json) => Course(
    id: json["id"],
    groupId: json["group_id"],
    name: json["name"],
    amount: json["amount"],
    objective: json["objective"],
    description: json["description"],
    checklist: json["checklist"],
    supervisorApproval: json["supervisor_approval"],
    createdBy: json["created_by"],
    isPayment: json["is_payment"],
    logoLink: json["logo_link"],
    maxRegistrations: json["max_registrations"],
    participantGuideFile: json["participant_guide_file"],
    participantGuideLink: json["participant_guide_link"],
    wrapMethodologyFile: json["wrap_methodology_file"],
    wrapMethodologyLink: json["wrap_methodology_link"],
    isRequired: json["is_required"],
    reminderFrequency: json["reminder_frequency"],
    recurrenceTime: json["recurrence_time"],
    dueDate: json["due_date"],
    oldDueDate: json["old_due_date"],
    requiredTrainingMessage: json["required_training_message"],
    lastReminderEmailDate: json["last_reminder_email_date"],
    enrollDeadlineRequired: json["enroll_deadline_required"],
    enrollDeadlineType: json["enroll_deadline_type"],
    enrollDeadlineTime: json["enroll_deadline_time"],
    fakePeopleGroup: json["fake_people_group"],
    customTimeLimit: json["custom_time_limit"],
    createdAt:
        json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
    updatedAt:
        json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
    isActive: json["is_active"],
    allowRating: json["allow_rating"],
    displayRating: json["display_rating"],
    averageRating: json["average_rating"],
    ratingCount: json["rating_count"],
    duration: json["duration"],
    clientItemId: json["client_item_id"],
    clientItemType: json["client_item_type"],
    roasters:
        json["roasters"] == null
            ? null
            : List<Roaster>.from(
              (json["roasters"] is List
                      ? json["roasters"]
                      : json["roasters"] is Map
                      ? json["roasters"]!.values
                      : [])
                  .map((x) => Roaster.fromJson(x)),
            ),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "group_id": groupId,
    "name": name,
    "amount": amount,
    "objective": objective,
    "description": description,
    "checklist": checklist,
    "supervisor_approval": supervisorApproval,
    "created_by": createdBy,
    "is_payment": isPayment,
    "logo_link": logoLink,
    "max_registrations": maxRegistrations,
    "participant_guide_file": participantGuideFile,
    "participant_guide_link": participantGuideLink,
    "wrap_methodology_file": wrapMethodologyFile,
    "wrap_methodology_link": wrapMethodologyLink,
    "is_required": isRequired,
    "reminder_frequency": reminderFrequency,
    "recurrence_time": recurrenceTime,
    "due_date": dueDate,
    "old_due_date": oldDueDate,
    "required_training_message": requiredTrainingMessage,
    "last_reminder_email_date": lastReminderEmailDate,
    "enroll_deadline_required": enrollDeadlineRequired,
    "enroll_deadline_type": enrollDeadlineType,
    "enroll_deadline_time": enrollDeadlineTime,
    "fake_people_group": fakePeopleGroup,
    "custom_time_limit": customTimeLimit,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "is_active": isActive,
    "allow_rating": allowRating,
    "display_rating": displayRating,
    "average_rating": averageRating,
    "rating_count": ratingCount,
    "duration": duration,
    "client_item_id": clientItemId,
    "client_item_type": clientItemType,
    "roasters":
        roasters == null
            ? null
            : List<dynamic>.from(roasters!.map((x) => x.toJson())),
  };

  double get percentage {
    if (roasters?.isEmpty ?? true) return 0.0;
    return roasters!.where((element) => element.status == "3").length /
        roasters!.length;
  }
}
