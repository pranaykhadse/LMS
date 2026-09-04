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
      user:
          rawUser is Map
              ? User.fromJson(Map<String, dynamic>.from(rawUser))
              : User(),
      // The API sometimes returns this pre-formatted for display
      // ("(201) 552-1423") rather than as bare digits - saving that
      // straight back (e.g. an edit to some OTHER field, with the phone
      // number left untouched) fails the backend's phone_number schema,
      // which only accepts digits. Stripped here at parse time, once,
      // rather than at every save-site that touches this field, so the
      // edit field itself always starts clean and there's no way for the
      // formatted form to round-trip back to the server.
      phoneNumber: _digitsOnly(json['phone_number']?.toString()),
      enableTextMessages:
          json['enable_text_messages'] == 1 ||
          json['enable_text_messages']?.toString() == '1' ||
          json['enable_text_messages'] == true,
    );
  }
}

/// Strips everything except 0-9 - drops spaces, dashes, parentheses, plus
/// signs, etc. `country_code`/`country_iso` are already separate fields
/// from this one, so a bare local-number digit string is always what's
/// wanted here, never any of that formatting.
String? _digitsOnly(String? value) {
  if (value == null) return null;
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? null : digits;
}
