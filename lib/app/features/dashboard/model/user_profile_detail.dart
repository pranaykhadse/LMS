import 'package:lms/app/features/authentication/model/auth_state.dart';

class UserProfileDetail {
  const UserProfileDetail({
    required this.profile,
    required this.user,
    this.phoneNumber,
    this.enableTextMessages = false,
  });

  final UserProfile profile;
  final User user;
  final String? phoneNumber;
  final bool enableTextMessages;

  factory UserProfileDetail.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    return UserProfileDetail(
      profile: UserProfile.fromJson(json),
      user: rawUser is Map
          ? User.fromJson(Map<String, dynamic>.from(rawUser))
          : User(),
      // The confirmed GET /user-profile/{id} schema returns this under
      // "text_phone_number", not "phone_number" — try both, preferring
      // whichever one is actually present.
      phoneNumber:
          json['text_phone_number']?.toString() ?? json['phone_number']?.toString(),
      enableTextMessages: json['enable_text_messages'] == 1 ||
          json['enable_text_messages']?.toString() == '1' ||
          json['enable_text_messages'] == true,
    );
  }
}
