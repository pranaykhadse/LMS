import 'dart:convert';

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String? _asString(dynamic value) => value?.toString();

class AuthState {
  final User? user;
  final Role? role;
  final String? token;
  final UserProfile? userProfile;
  final int? jobRoleId;
  final String? jobRole;
  final List<Group>? group;
  final List<dynamic>? supervisor;

  AuthState({
    this.user,
    this.role,
    this.token,
    this.userProfile,
    this.jobRoleId,
    this.jobRole,
    this.group,
    this.supervisor,
  });

  AuthState copyWith({
    User? user,
    Role? role,
    String? token,
    UserProfile? userProfile,
    int? jobRoleId,
    String? jobRole,
    List<Group>? group,
    List<dynamic>? supervisor,
  }) => AuthState(
    user: user ?? this.user,
    role: role ?? this.role,
    token: token ?? this.token,
    userProfile: userProfile ?? this.userProfile,
    jobRoleId: jobRoleId ?? this.jobRoleId,
    jobRole: jobRole ?? this.jobRole,
    group: group ?? this.group,
    supervisor: supervisor ?? this.supervisor,
  );

  factory AuthState.fromRawJson(String str) =>
      AuthState.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory AuthState.fromJson(Map<String, dynamic> json) {
    final rawProfile =
        json["userProfile"] ??
        json["user_profile"] ??
        json["profile"] ??
        json["user_profile_data"];
    return AuthState(
      user: json["user"] == null ? null : User.fromJson(json["user"]),
      role: json["role"] == null ? null : Role.fromJson(json["role"]),
      token: _asString(json["token"]),
      userProfile:
          rawProfile is Map
              ? UserProfile.fromJson(Map<String, dynamic>.from(rawProfile))
              : null,
      jobRoleId: _asInt(json["job_role_id"]),
      jobRole: _asString(json["job_role"]),
      group:
          json["group"] == null
              ? []
              : List<Group>.from(json["group"]!.map((x) => Group.fromJson(x))),
      // supervisor: json["supervisor"] == null ? [] : List<dynamic>.from(json["supervisor"]!.map((x) => x)),
    );
  }

  Map<String, dynamic> toJson() => {
    "user": user?.toJson(),
    "role": role?.toJson(),
    "token": token,
    "userProfile": userProfile?.toJson(),
    "job_role_id": jobRoleId,
    "job_role": jobRole,
    "group":
        group == null ? [] : List<dynamic>.from(group!.map((x) => x.toJson())),
    // "supervisor": supervisor == null ? [] : List<dynamic>.from(supervisor!.map((x) => x)),
  };
}

class Group {
  final int? id;
  final String? name;

  Group({this.id, this.name});

  Group copyWith({int? id, String? name}) =>
      Group(id: id ?? this.id, name: name ?? this.name);

  factory Group.fromRawJson(String str) => Group.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Group.fromJson(Map<String, dynamic> json) =>
      Group(id: _asInt(json["id"]), name: _asString(json["name"]));

  Map<String, dynamic> toJson() => {"id": id, "name": name};
}

class Role {
  final String? itemName;

  Role({this.itemName});

  Role copyWith({String? itemName}) =>
      Role(itemName: itemName ?? this.itemName);

  factory Role.fromRawJson(String str) => Role.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Role.fromJson(Map<String, dynamic> json) =>
      Role(itemName: _asString(json["item_name"]));

  Map<String, dynamic> toJson() => {"item_name": itemName};
}

class User {
  final int? id;
  final String? commonUserId;
  final String? username;
  final String? authKey;
  final dynamic authKeyExpiry;
  final String? passwordHash;
  final dynamic passwordResetToken;
  final dynamic oauthClient;
  final dynamic oauthClientUserId;
  final String? email;
  final int? status;
  final int? lmsStatus;
  final int? courseStatus;
  final int? isDeleted;
  final String? costCode;
  final dynamic groupId;
  final int? createdAt;
  final int? updatedAt;
  final dynamic loggedAt;
  final int? createdBy;
  final int? timezoneId;
  final int? enableTwoFactorAuth;
  final String? twoFactorAuthGoogleToken;
  final String? subtitleLanguage;
  final int? checkAuthLogin;
  final dynamic onePagerProStatus;
  final int? enableSubs;
  final int? primaryGroup;
  final String? jobRole;
  final String? autoLoginToken;
  final String? failedAttempts;
  final dynamic lockedUntil;
  final int? leadershipSystems;
  final int? virtualDevelopmentProStatus;
  final dynamic organisation;
  final dynamic flsaStatus;
  final dynamic employeeId;
  final String? primaryGroupLabel;

  User({
    this.id,
    this.commonUserId,
    this.username,
    this.authKey,
    this.authKeyExpiry,
    this.passwordHash,
    this.passwordResetToken,
    this.oauthClient,
    this.oauthClientUserId,
    this.email,
    this.status,
    this.lmsStatus,
    this.courseStatus,
    this.isDeleted,
    this.costCode,
    this.groupId,
    this.createdAt,
    this.updatedAt,
    this.loggedAt,
    this.createdBy,
    this.timezoneId,
    this.enableTwoFactorAuth,
    this.twoFactorAuthGoogleToken,
    this.subtitleLanguage,
    this.checkAuthLogin,
    this.onePagerProStatus,
    this.enableSubs,
    this.primaryGroup,
    this.jobRole,
    this.autoLoginToken,
    this.failedAttempts,
    this.lockedUntil,
    this.leadershipSystems,
    this.virtualDevelopmentProStatus,
    this.organisation,
    this.flsaStatus,
    this.employeeId,
    this.primaryGroupLabel,
  });

  User copyWith({
    int? id,
    String? commonUserId,
    String? username,
    String? authKey,
    dynamic authKeyExpiry,
    String? passwordHash,
    dynamic passwordResetToken,
    dynamic oauthClient,
    dynamic oauthClientUserId,
    String? email,
    int? status,
    int? lmsStatus,
    int? courseStatus,
    int? isDeleted,
    String? costCode,
    dynamic groupId,
    int? createdAt,
    int? updatedAt,
    dynamic loggedAt,
    int? createdBy,
    int? timezoneId,
    int? enableTwoFactorAuth,
    String? twoFactorAuthGoogleToken,
    String? subtitleLanguage,
    int? checkAuthLogin,
    dynamic onePagerProStatus,
    int? enableSubs,
    int? primaryGroup,
    String? jobRole,
    String? autoLoginToken,
    String? failedAttempts,
    dynamic lockedUntil,
    int? leadershipSystems,
    int? virtualDevelopmentProStatus,
    dynamic organisation,
    dynamic flsaStatus,
    dynamic employeeId,
    String? primaryGroupLabel,
  }) => User(
    id: id ?? this.id,
    commonUserId: commonUserId ?? this.commonUserId,
    username: username ?? this.username,
    authKey: authKey ?? this.authKey,
    authKeyExpiry: authKeyExpiry ?? this.authKeyExpiry,
    passwordHash: passwordHash ?? this.passwordHash,
    passwordResetToken: passwordResetToken ?? this.passwordResetToken,
    oauthClient: oauthClient ?? this.oauthClient,
    oauthClientUserId: oauthClientUserId ?? this.oauthClientUserId,
    email: email ?? this.email,
    status: status ?? this.status,
    lmsStatus: lmsStatus ?? this.lmsStatus,
    courseStatus: courseStatus ?? this.courseStatus,
    isDeleted: isDeleted ?? this.isDeleted,
    costCode: costCode ?? this.costCode,
    groupId: groupId ?? this.groupId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    loggedAt: loggedAt ?? this.loggedAt,
    createdBy: createdBy ?? this.createdBy,
    timezoneId: timezoneId ?? this.timezoneId,
    enableTwoFactorAuth: enableTwoFactorAuth ?? this.enableTwoFactorAuth,
    twoFactorAuthGoogleToken:
        twoFactorAuthGoogleToken ?? this.twoFactorAuthGoogleToken,
    subtitleLanguage: subtitleLanguage ?? this.subtitleLanguage,
    checkAuthLogin: checkAuthLogin ?? this.checkAuthLogin,
    onePagerProStatus: onePagerProStatus ?? this.onePagerProStatus,
    enableSubs: enableSubs ?? this.enableSubs,
    primaryGroup: primaryGroup ?? this.primaryGroup,
    jobRole: jobRole ?? this.jobRole,
    autoLoginToken: autoLoginToken ?? this.autoLoginToken,
    failedAttempts: failedAttempts ?? this.failedAttempts,
    lockedUntil: lockedUntil ?? this.lockedUntil,
    leadershipSystems: leadershipSystems ?? this.leadershipSystems,
    virtualDevelopmentProStatus:
        virtualDevelopmentProStatus ?? this.virtualDevelopmentProStatus,
    organisation: organisation ?? this.organisation,
    flsaStatus: flsaStatus ?? this.flsaStatus,
    employeeId: employeeId ?? this.employeeId,
    primaryGroupLabel: primaryGroupLabel ?? this.primaryGroupLabel,
  );

  factory User.fromRawJson(String str) => User.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: _asInt(json["id"]),
    commonUserId: _asString(json["common_user_id"]),
    username: _asString(json["username"]),
    authKey: _asString(json["auth_key"]),
    authKeyExpiry: json["auth_key_expiry"],
    passwordHash: _asString(json["password_hash"]),
    passwordResetToken: json["password_reset_token"],
    oauthClient: json["oauth_client"],
    oauthClientUserId: json["oauth_client_user_id"],
    email: _asString(json["email"]),
    status: _asInt(json["status"]),
    lmsStatus: _asInt(json["lms_status"]),
    courseStatus: _asInt(json["course_status"]),
    isDeleted: _asInt(json["is_deleted"]),
    costCode: _asString(json["cost_code"]),
    groupId: json["group_id"],
    createdAt: _asInt(json["created_at"]),
    updatedAt: _asInt(json["updated_at"]),
    loggedAt: json["logged_at"],
    createdBy: _asInt(json["created_by"]),
    timezoneId: _asInt(json["timezone_id"]),
    enableTwoFactorAuth: _asInt(json["enable_two_factor_auth"]),
    twoFactorAuthGoogleToken: _asString(json["two_factor_auth_google_token"]),
    subtitleLanguage: _asString(json["subtitle_language"]),
    checkAuthLogin: _asInt(json["check_auth_login"]),
    onePagerProStatus: json["one_pager_pro_status"],
    enableSubs: _asInt(json["enable_subs"]),
    primaryGroup: _asInt(json["primary_group"]),
    jobRole: _asString(json["job_role"]),
    autoLoginToken: _asString(json["auto_login_token"]),
    failedAttempts: _asString(json["failed_attempts"]),
    lockedUntil: json["locked_until"],
    leadershipSystems: _asInt(json["leadership_systems"]),
    virtualDevelopmentProStatus: _asInt(json["virtual_development_pro_status"]),
    organisation: json["organisation"],
    flsaStatus: json["flsa_status"],
    employeeId: json["employee_id"],
    primaryGroupLabel: _asString(json["primary_group_label"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "common_user_id": commonUserId,
    "username": username,
    "auth_key": authKey,
    "auth_key_expiry": authKeyExpiry,
    "password_hash": passwordHash,
    "password_reset_token": passwordResetToken,
    "oauth_client": oauthClient,
    "oauth_client_user_id": oauthClientUserId,
    "email": email,
    "status": status,
    "lms_status": lmsStatus,
    "course_status": courseStatus,
    "is_deleted": isDeleted,
    "cost_code": costCode,
    "group_id": groupId,
    "created_at": createdAt,
    "updated_at": updatedAt,
    "logged_at": loggedAt,
    "created_by": createdBy,
    "timezone_id": timezoneId,
    "enable_two_factor_auth": enableTwoFactorAuth,
    "two_factor_auth_google_token": twoFactorAuthGoogleToken,
    "subtitle_language": subtitleLanguage,
    "check_auth_login": checkAuthLogin,
    "one_pager_pro_status": onePagerProStatus,
    "enable_subs": enableSubs,
    "primary_group": primaryGroup,
    "job_role": jobRole,
    "auto_login_token": autoLoginToken,
    "failed_attempts": failedAttempts,
    "locked_until": lockedUntil,
    "leadership_systems": leadershipSystems,
    "virtual_development_pro_status": virtualDevelopmentProStatus,
    "organisation": organisation,
    "flsa_status": flsaStatus,
    "employee_id": employeeId,
    "primary_group_label": primaryGroupLabel,
  };
}

class UserProfile {
  final int? userId;
  final String? firstname;
  final dynamic middlename;
  final String? lastname;
  final dynamic avatarPath;
  final dynamic avatarBaseUrl;
  final String? locale;
  final dynamic gender;
  final String? division;
  final String? department;
  final String? location;
  final int? points;
  final dynamic website;
  final dynamic linkedIn;
  final dynamic supervisorPopupMonth;
  final int? mentorPopupMonth;
  final dynamic notificationType;
  final dynamic countryCode;
  final dynamic textPhoneNumber;
  final dynamic emailOptions;
  final dynamic whatsappPhoneNumber;
  final dynamic slackEmail;
  final dynamic teamsEmail;
  final DateTime? requestDate;
  final int? requestCount;
  final int? virtualDevelopmentProStatus;
  final String? recommendedCourses;
  final String? requiredCourses;

  // Admin-managed access-restriction fields. Not editable from the app's
  // Account Settings screen, but PUT /user-profile/{id} replaces the whole
  // profile, so these must be round-tripped unchanged rather than dropped.
  final dynamic meteredAccess;
  final dynamic restrictedGroupId;
  final dynamic restrictionType;
  final dynamic restrictedCourseLimit;
  final dynamic restrictedDate;

  UserProfile({
    this.userId,
    this.firstname,
    this.middlename,
    this.lastname,
    this.avatarPath,
    this.avatarBaseUrl,
    this.locale,
    this.gender,
    this.division,
    this.department,
    this.location,
    this.points,
    this.website,
    this.linkedIn,
    this.supervisorPopupMonth,
    this.mentorPopupMonth,
    this.notificationType,
    this.countryCode,
    this.textPhoneNumber,
    this.emailOptions,
    this.whatsappPhoneNumber,
    this.slackEmail,
    this.teamsEmail,
    this.requestDate,
    this.requestCount,
    this.virtualDevelopmentProStatus,
    this.recommendedCourses,
    this.requiredCourses,
    this.meteredAccess,
    this.restrictedGroupId,
    this.restrictionType,
    this.restrictedCourseLimit,
    this.restrictedDate,
  });

  /// Joins avatar_base_url + avatar_path into a full URL, ensuring exactly
  /// one "/" between them - the API returns avatar_base_url without a
  /// trailing slash and avatar_path without a leading slash (e.g.
  /// ".../storage/web/source" + "1/x.jpg"), so naive '$base$path'
  /// concatenation silently drops the separator, producing
  /// ".../source1/x.jpg" instead of ".../source/1/x.jpg" and 404ing.
  String get avatarUrl {
    final path = avatarPath?.toString() ?? '';
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = avatarBaseUrl?.toString() ?? '';
    if (base.isEmpty) return '';
    final needsSlash = !base.endsWith('/') && !path.startsWith('/');
    return needsSlash ? '$base/$path' : '$base$path';
  }

  UserProfile copyWith({
    int? userId,
    String? firstname,
    dynamic middlename,
    String? lastname,
    dynamic avatarPath,
    dynamic avatarBaseUrl,
    String? locale,
    dynamic gender,
    String? division,
    String? department,
    String? location,
    int? points,
    dynamic website,
    dynamic linkedIn,
    dynamic supervisorPopupMonth,
    int? mentorPopupMonth,
    dynamic notificationType,
    dynamic countryCode,
    dynamic textPhoneNumber,
    dynamic emailOptions,
    dynamic whatsappPhoneNumber,
    dynamic slackEmail,
    dynamic teamsEmail,
    DateTime? requestDate,
    int? requestCount,
    int? virtualDevelopmentProStatus,
    String? recommendedCourses,
    String? requiredCourses,
    dynamic meteredAccess,
    dynamic restrictedGroupId,
    dynamic restrictionType,
    dynamic restrictedCourseLimit,
    dynamic restrictedDate,
  }) => UserProfile(
    userId: userId ?? this.userId,
    firstname: firstname ?? this.firstname,
    middlename: middlename ?? this.middlename,
    lastname: lastname ?? this.lastname,
    avatarPath: avatarPath ?? this.avatarPath,
    avatarBaseUrl: avatarBaseUrl ?? this.avatarBaseUrl,
    locale: locale ?? this.locale,
    gender: gender ?? this.gender,
    division: division ?? this.division,
    department: department ?? this.department,
    location: location ?? this.location,
    points: points ?? this.points,
    website: website ?? this.website,
    linkedIn: linkedIn ?? this.linkedIn,
    supervisorPopupMonth: supervisorPopupMonth ?? this.supervisorPopupMonth,
    mentorPopupMonth: mentorPopupMonth ?? this.mentorPopupMonth,
    notificationType: notificationType ?? this.notificationType,
    countryCode: countryCode ?? this.countryCode,
    textPhoneNumber: textPhoneNumber ?? this.textPhoneNumber,
    emailOptions: emailOptions ?? this.emailOptions,
    whatsappPhoneNumber: whatsappPhoneNumber ?? this.whatsappPhoneNumber,
    slackEmail: slackEmail ?? this.slackEmail,
    teamsEmail: teamsEmail ?? this.teamsEmail,
    requestDate: requestDate ?? this.requestDate,
    requestCount: requestCount ?? this.requestCount,
    virtualDevelopmentProStatus:
        virtualDevelopmentProStatus ?? this.virtualDevelopmentProStatus,
    recommendedCourses: recommendedCourses ?? this.recommendedCourses,
    requiredCourses: requiredCourses ?? this.requiredCourses,
    meteredAccess: meteredAccess ?? this.meteredAccess,
    restrictedGroupId: restrictedGroupId ?? this.restrictedGroupId,
    restrictionType: restrictionType ?? this.restrictionType,
    restrictedCourseLimit: restrictedCourseLimit ?? this.restrictedCourseLimit,
    restrictedDate: restrictedDate ?? this.restrictedDate,
  );

  factory UserProfile.fromRawJson(String str) =>
      UserProfile.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    userId: _asInt(json["user_id"]),
    firstname: _asString(json["firstname"]),
    middlename: json["middlename"],
    lastname: _asString(json["lastname"]),
    avatarPath: json["avatar_path"],
    avatarBaseUrl: json["avatar_base_url"],
    locale: _asString(json["locale"]),
    gender: json["gender"],
    division: _asString(json["division"]),
    department: _asString(json["department"]),
    location: _asString(json["location"]),
    points: _asInt(json["points"]),
    website: json["website"],
    linkedIn: json["linked_in"],
    supervisorPopupMonth: json["supervisor_popup_month"],
    mentorPopupMonth: _asInt(json["mentor_popup_month"]),
    notificationType: json["notification_type"],
    countryCode: json["country_code"],
    textPhoneNumber: json["text_phone_number"],
    emailOptions: json["email_options"],
    whatsappPhoneNumber: json["whatsapp_phone_number"],
    slackEmail: json["slack_email"],
    teamsEmail: json["teams_email"],
    requestDate:
        json["request_date"] == null
            ? null
            : DateTime.tryParse(json["request_date"].toString()),
    requestCount: _asInt(json["request_count"]),
    virtualDevelopmentProStatus: _asInt(json["virtual_development_pro_status"]),
    recommendedCourses: _asString(json["recommended_courses"]),
    requiredCourses: _asString(json["required_courses"]),
    meteredAccess: json["metered_access"],
    restrictedGroupId: json["restricted_group_id"],
    restrictionType: json["restriction_type"],
    restrictedCourseLimit: json["restricted_course_limit"],
    restrictedDate: json["restricted_date"],
  );

  Map<String, dynamic> toJson() => {
    "user_id": userId,
    "firstname": firstname,
    "middlename": middlename,
    "lastname": lastname,
    "avatar_path": avatarPath,
    "avatar_base_url": avatarBaseUrl,
    "locale": locale,
    "gender": gender,
    "division": division,
    "department": department,
    "location": location,
    "points": points,
    "website": website,
    "linked_in": linkedIn,
    "supervisor_popup_month": supervisorPopupMonth,
    "mentor_popup_month": mentorPopupMonth,
    "notification_type": notificationType,
    "country_code": countryCode,
    "text_phone_number": textPhoneNumber,
    "email_options": emailOptions,
    "whatsapp_phone_number": whatsappPhoneNumber,
    "slack_email": slackEmail,
    "teams_email": teamsEmail,
    "request_date":
        requestDate == null
            ? null
            : "${requestDate!.year.toString().padLeft(4, '0')}-${requestDate!.month.toString().padLeft(2, '0')}-${requestDate!.day.toString().padLeft(2, '0')}",
    "request_count": requestCount,
    "virtual_development_pro_status": virtualDevelopmentProStatus,
    "recommended_courses": recommendedCourses,
    "required_courses": requiredCourses,
    "metered_access": meteredAccess,
    "restricted_group_id": restrictedGroupId,
    "restriction_type": restrictionType,
    "restricted_course_limit": restrictedCourseLimit,
    "restricted_date": restrictedDate,
  };

  /// Exactly the field set PUT /user-profile/{id} expects — a subset of
  /// [toJson] (that one also carries fields this endpoint doesn't take,
  /// like notification/popup bookkeeping) with the given overrides applied.
  Map<String, dynamic> toUpdateJson({
    String? firstname,
    String? lastname,
    String? location,
    dynamic website,
    dynamic linkedIn,
    String? division,
    String? department,
    dynamic avatarPath,
    dynamic countryCode,
  }) => {
    "firstname": firstname ?? this.firstname,
    "middlename": middlename,
    "lastname": lastname ?? this.lastname,
    "avatar_path": avatarPath ?? this.avatarPath,
    "avatar_base_url": avatarBaseUrl,
    "locale": locale,
    "gender": gender,
    "division": division ?? this.division,
    "department": department ?? this.department,
    "location": location ?? this.location,
    "points": points,
    "website": website ?? this.website,
    "linked_in": linkedIn ?? this.linkedIn,
    "country_code": countryCode ?? this.countryCode,
    "metered_access": meteredAccess,
    "restricted_group_id": restrictedGroupId,
    "restriction_type": restrictionType,
    "restricted_course_limit": restrictedCourseLimit,
    "restricted_date": restrictedDate,
  };
}
