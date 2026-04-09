import 'dart:convert';

class ClassInfo {
  final String? id;
  final String? name;
  final String? customTypeName;
  final String? type;
  final String? objective;
  final String? agreementSigned;
  final String? description;
  final String? checklist;
  final String? supervisorApproval;
  final dynamic classPath;
  final dynamic classLink;
  final dynamic s3ClassLink;
  final String? storyLineFile;
  final dynamic instructionalHours;
  final dynamic startDate;
  final dynamic endDate;
  final dynamic startTime;
  final dynamic endTime;
  final dynamic location;
  final dynamic instructor;
  final dynamic maxRegistrations;
  final String? uuid;
  final dynamic cost;
  final dynamic amount;
  final dynamic cancellationCost;
  final String? isAccessPeriod;
  final String? accessPeriod;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;
  final String? isLaunch;
  final String? isRise;
  final String? isPayment;
  final String? instruction;
  final String? videoUploadUrl;
  final String? readWebpageLink;
  final String? articleFile;
  final dynamic discussionForumLink;
  final String? readWebpageText;
  final String? watchVideoLink;
  final String? readArticleLink;
  final String? isCertificate;
  final String? learningCertificateId;
  final String? isPreRequisite;
  final String? order;
  final String? courseName;
  final String? issuingOrganization;
  final String? postCompletionMessage;
  final String? points;
  final String? supervisorPostCompletionMessage;
  final String? discussionGuruLink;
  final String? peerCoachingLink;
  final String? peerCoachingFile;
  final String? isOptional;
  final String? isSignature;
  final dynamic readArticleFilename;
  final dynamic watchVideoFilename;
  final String? isMultigroup;
  final String? multiGroup;
  final String? shrm;
  final String? hrci;
  final String? courseNumber;
  final String? courseHours;
  final String? mentorPostCompletionMessage;
  final String? onePagerPro;
  final String? virtualClassLink;
  final dynamic virtualClassFile;
  final dynamic virtualClassFilename;
  final String? customPrompt;
  final String? alternativeLearningEvent;
  final String? isCourseExclude;
  final String? excludeGroup;

  ClassInfo({
    this.id,
    this.name,
    this.customTypeName,
    this.type,
    this.objective,
    this.agreementSigned,
    this.description,
    this.checklist,
    this.supervisorApproval,
    this.classPath,
    this.classLink,
    this.s3ClassLink,
    this.storyLineFile,
    this.instructionalHours,
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.location,
    this.instructor,
    this.maxRegistrations,
    this.uuid,
    this.cost,
    this.amount,
    this.cancellationCost,
    this.isAccessPeriod,
    this.accessPeriod,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
    this.isLaunch,
    this.isRise,
    this.isPayment,
    this.instruction,
    this.videoUploadUrl,
    this.readWebpageLink,
    this.articleFile,
    this.discussionForumLink,
    this.readWebpageText,
    this.watchVideoLink,
    this.readArticleLink,
    this.isCertificate,
    this.learningCertificateId,
    this.isPreRequisite,
    this.order,
    this.courseName,
    this.issuingOrganization,
    this.postCompletionMessage,
    this.points,
    this.supervisorPostCompletionMessage,
    this.discussionGuruLink,
    this.peerCoachingLink,
    this.peerCoachingFile,
    this.isOptional,
    this.isSignature,
    this.readArticleFilename,
    this.watchVideoFilename,
    this.isMultigroup,
    this.multiGroup,
    this.shrm,
    this.hrci,
    this.courseNumber,
    this.courseHours,
    this.mentorPostCompletionMessage,
    this.onePagerPro,
    this.virtualClassLink,
    this.virtualClassFile,
    this.virtualClassFilename,
    this.customPrompt,
    this.alternativeLearningEvent,
    this.isCourseExclude,
    this.excludeGroup,
  });

  ClassInfo copyWith({
    String? id,
    String? name,
    String? customTypeName,
    String? type,
    String? objective,
    String? agreementSigned,
    String? description,
    String? checklist,
    String? supervisorApproval,
    dynamic classPath,
    dynamic classLink,
    dynamic s3ClassLink,
    String? storyLineFile,
    dynamic instructionalHours,
    dynamic startDate,
    dynamic endDate,
    dynamic startTime,
    dynamic endTime,
    dynamic location,
    dynamic instructor,
    dynamic maxRegistrations,
    String? uuid,
    dynamic cost,
    dynamic amount,
    dynamic cancellationCost,
    String? isAccessPeriod,
    String? accessPeriod,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
    String? updatedBy,
    String? isLaunch,
    String? isRise,
    String? isPayment,
    String? instruction,
    String? videoUploadUrl,
    String? readWebpageLink,
    String? articleFile,
    dynamic discussionForumLink,
    String? readWebpageText,
    String? watchVideoLink,
    String? readArticleLink,
    String? isCertificate,
    String? learningCertificateId,
    String? isPreRequisite,
    String? order,
    String? courseName,
    String? issuingOrganization,
    String? postCompletionMessage,
    String? points,
    String? supervisorPostCompletionMessage,
    String? discussionGuruLink,
    String? peerCoachingLink,
    String? peerCoachingFile,
    String? isOptional,
    String? isSignature,
    dynamic readArticleFilename,
    dynamic watchVideoFilename,
    String? isMultigroup,
    String? multiGroup,
    String? shrm,
    String? hrci,
    String? courseNumber,
    String? courseHours,
    String? mentorPostCompletionMessage,
    String? onePagerPro,
    String? virtualClassLink,
    dynamic virtualClassFile,
    dynamic virtualClassFilename,
    String? customPrompt,
    String? alternativeLearningEvent,
    String? isCourseExclude,
    String? excludeGroup,
  }) => ClassInfo(
    id: id ?? this.id,
    name: name ?? this.name,
    customTypeName: customTypeName ?? this.customTypeName,
    type: type ?? this.type,
    objective: objective ?? this.objective,
    agreementSigned: agreementSigned ?? this.agreementSigned,
    description: description ?? this.description,
    checklist: checklist ?? this.checklist,
    supervisorApproval: supervisorApproval ?? this.supervisorApproval,
    classPath: classPath ?? this.classPath,
    classLink: classLink ?? this.classLink,
    s3ClassLink: s3ClassLink ?? this.s3ClassLink,
    storyLineFile: storyLineFile ?? this.storyLineFile,
    instructionalHours: instructionalHours ?? this.instructionalHours,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    location: location ?? this.location,
    instructor: instructor ?? this.instructor,
    maxRegistrations: maxRegistrations ?? this.maxRegistrations,
    uuid: uuid ?? this.uuid,
    cost: cost ?? this.cost,
    amount: amount ?? this.amount,
    cancellationCost: cancellationCost ?? this.cancellationCost,
    isAccessPeriod: isAccessPeriod ?? this.isAccessPeriod,
    accessPeriod: accessPeriod ?? this.accessPeriod,
    createdAt: createdAt ?? this.createdAt,
    createdBy: createdBy ?? this.createdBy,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedBy: updatedBy ?? this.updatedBy,
    isLaunch: isLaunch ?? this.isLaunch,
    isRise: isRise ?? this.isRise,
    isPayment: isPayment ?? this.isPayment,
    instruction: instruction ?? this.instruction,
    videoUploadUrl: videoUploadUrl ?? this.videoUploadUrl,
    readWebpageLink: readWebpageLink ?? this.readWebpageLink,
    articleFile: articleFile ?? this.articleFile,
    discussionForumLink: discussionForumLink ?? this.discussionForumLink,
    readWebpageText: readWebpageText ?? this.readWebpageText,
    watchVideoLink: watchVideoLink ?? this.watchVideoLink,
    readArticleLink: readArticleLink ?? this.readArticleLink,
    isCertificate: isCertificate ?? this.isCertificate,
    learningCertificateId: learningCertificateId ?? this.learningCertificateId,
    isPreRequisite: isPreRequisite ?? this.isPreRequisite,
    order: order ?? this.order,
    courseName: courseName ?? this.courseName,
    issuingOrganization: issuingOrganization ?? this.issuingOrganization,
    postCompletionMessage: postCompletionMessage ?? this.postCompletionMessage,
    points: points ?? this.points,
    supervisorPostCompletionMessage:
        supervisorPostCompletionMessage ?? this.supervisorPostCompletionMessage,
    discussionGuruLink: discussionGuruLink ?? this.discussionGuruLink,
    peerCoachingLink: peerCoachingLink ?? this.peerCoachingLink,
    peerCoachingFile: peerCoachingFile ?? this.peerCoachingFile,
    isOptional: isOptional ?? this.isOptional,
    isSignature: isSignature ?? this.isSignature,
    readArticleFilename: readArticleFilename ?? this.readArticleFilename,
    watchVideoFilename: watchVideoFilename ?? this.watchVideoFilename,
    isMultigroup: isMultigroup ?? this.isMultigroup,
    multiGroup: multiGroup ?? this.multiGroup,
    shrm: shrm ?? this.shrm,
    hrci: hrci ?? this.hrci,
    courseNumber: courseNumber ?? this.courseNumber,
    courseHours: courseHours ?? this.courseHours,
    mentorPostCompletionMessage:
        mentorPostCompletionMessage ?? this.mentorPostCompletionMessage,
    onePagerPro: onePagerPro ?? this.onePagerPro,
    virtualClassLink: virtualClassLink ?? this.virtualClassLink,
    virtualClassFile: virtualClassFile ?? this.virtualClassFile,
    virtualClassFilename: virtualClassFilename ?? this.virtualClassFilename,
    customPrompt: customPrompt ?? this.customPrompt,
    alternativeLearningEvent:
        alternativeLearningEvent ?? this.alternativeLearningEvent,
    isCourseExclude: isCourseExclude ?? this.isCourseExclude,
    excludeGroup: excludeGroup ?? this.excludeGroup,
  );

  factory ClassInfo.fromRawJson(String str) =>
      ClassInfo.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory ClassInfo.fromJson(Map<String, dynamic> json) => ClassInfo(
    id: json["id"],
    name: json["name"],
    customTypeName: json["custom_type_name"],
    type: json["type"],
    objective: json["objective"],
    agreementSigned: json["agreement_signed"],
    description: json["description"],
    checklist: json["checklist"],
    supervisorApproval: json["supervisor_approval"],
    classPath: json["class_path"],
    classLink: json["class_link"],
    s3ClassLink: json["s3_class_link"],
    storyLineFile: json["story_line_file"],
    instructionalHours: json["instructional_hours"],
    startDate: json["start_date"],
    endDate: json["end_date"],
    startTime: json["start_time"],
    endTime: json["end_time"],
    location: json["location"],
    instructor: json["instructor"],
    maxRegistrations: json["max_registrations"],
    uuid: json["uuid"],
    cost: json["cost"],
    amount: json["amount"],
    cancellationCost: json["cancellation_cost"],
    isAccessPeriod: json["is_access_period"],
    accessPeriod: json["access_period"],
    createdAt:
        json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
    createdBy: json["created_by"],
    updatedAt:
        json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
    updatedBy: json["updated_by"],
    isLaunch: json["is_launch"],
    isRise: json["is_rise"],
    isPayment: json["is_payment"],
    instruction: json["instruction"],
    videoUploadUrl: json["video_upload_url"],
    readWebpageLink: json["read_webpage_link"],
    articleFile: json["article_file"],
    discussionForumLink: json["discussion_forum_link"],
    readWebpageText: json["read_webpage_text"],
    watchVideoLink: json["watch_video_link"],
    readArticleLink: json["read_article_link"],
    isCertificate: json["is_certificate"],
    learningCertificateId: json["learning_certificate_id"],
    isPreRequisite: json["is_pre_requisite"],
    order: json["order"],
    courseName: json["course_name"],
    issuingOrganization: json["issuing_organization"],
    postCompletionMessage: json["post_completion_message"],
    points: json["points"],
    supervisorPostCompletionMessage: json["supervisor_post_completion_message"],
    discussionGuruLink: json["discussion_guru_link"],
    peerCoachingLink: json["peer_coaching_link"],
    peerCoachingFile: json["peer_coaching_file"],
    isOptional: json["is_optional"],
    isSignature: json["is_signature"],
    readArticleFilename: json["read_article_filename"],
    watchVideoFilename: json["watch_video_filename"],
    isMultigroup: json["is_multigroup"],
    multiGroup: json["multi_group"],
    shrm: json["SHRM"],
    hrci: json["HRCI"],
    courseNumber: json["course_number"],
    courseHours: json["course_hours"],
    mentorPostCompletionMessage: json["mentor_post_completion_message"],
    onePagerPro: json["one_pager_pro"],
    virtualClassLink: json["virtual_class_link"],
    virtualClassFile: json["virtual_class_file"],
    virtualClassFilename: json["virtual_class_filename"],
    customPrompt: json["custom_prompt"],
    alternativeLearningEvent: json["alternative_learning_event"],
    isCourseExclude: json["is_course_exclude"],
    excludeGroup: json["exclude_group"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "custom_type_name": customTypeName,
    "type": type,
    "objective": objective,
    "agreement_signed": agreementSigned,
    "description": description,
    "checklist": checklist,
    "supervisor_approval": supervisorApproval,
    "class_path": classPath,
    "class_link": classLink,
    "s3_class_link": s3ClassLink,
    "story_line_file": storyLineFile,
    "instructional_hours": instructionalHours,
    "start_date": startDate,
    "end_date": endDate,
    "start_time": startTime,
    "end_time": endTime,
    "location": location,
    "instructor": instructor,
    "max_registrations": maxRegistrations,
    "uuid": uuid,
    "cost": cost,
    "amount": amount,
    "cancellation_cost": cancellationCost,
    "is_access_period": isAccessPeriod,
    "access_period": accessPeriod,
    "created_at": createdAt?.toIso8601String(),
    "created_by": createdBy,
    "updated_at": updatedAt?.toIso8601String(),
    "updated_by": updatedBy,
    "is_launch": isLaunch,
    "is_rise": isRise,
    "is_payment": isPayment,
    "instruction": instruction,
    "video_upload_url": videoUploadUrl,
    "read_webpage_link": readWebpageLink,
    "article_file": articleFile,
    "discussion_forum_link": discussionForumLink,
    "read_webpage_text": readWebpageText,
    "watch_video_link": watchVideoLink,
    "read_article_link": readArticleLink,
    "is_certificate": isCertificate,
    "learning_certificate_id": learningCertificateId,
    "is_pre_requisite": isPreRequisite,
    "order": order,
    "course_name": courseName,
    "issuing_organization": issuingOrganization,
    "post_completion_message": postCompletionMessage,
    "points": points,
    "supervisor_post_completion_message": supervisorPostCompletionMessage,
    "discussion_guru_link": discussionGuruLink,
    "peer_coaching_link": peerCoachingLink,
    "peer_coaching_file": peerCoachingFile,
    "is_optional": isOptional,
    "is_signature": isSignature,
    "read_article_filename": readArticleFilename,
    "watch_video_filename": watchVideoFilename,
    "is_multigroup": isMultigroup,
    "multi_group": multiGroup,
    "SHRM": shrm,
    "HRCI": hrci,
    "course_number": courseNumber,
    "course_hours": courseHours,
    "mentor_post_completion_message": mentorPostCompletionMessage,
    "one_pager_pro": onePagerPro,
    "virtual_class_link": virtualClassLink,
    "virtual_class_file": virtualClassFile,
    "virtual_class_filename": virtualClassFilename,
    "custom_prompt": customPrompt,
    "alternative_learning_event": alternativeLearningEvent,
    "is_course_exclude": isCourseExclude,
    "exclude_group": excludeGroup,
  };
}
