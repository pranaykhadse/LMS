class MentorModalData {
  const MentorModalData({
    required this.visible,
    required this.popupMonth,
    required this.shouldShow,
    this.email,
    this.firstname,
    this.lastname,
  });

  final bool visible;
  final int? popupMonth;
  final bool shouldShow;
  final String? email;
  final String? firstname;
  final String? lastname;

  factory MentorModalData.fromJson(Map<String, dynamic> json) => MentorModalData(
        visible: json['visible'] == true || json['visible']?.toString() == '1',
        popupMonth: json['popup_month'] is int ? json['popup_month'] as int : int.tryParse(json['popup_month']?.toString() ?? ''),
        shouldShow: json['should_show'] == true || json['should_show']?.toString() == 'true' || json['should_show']?.toString() == '1',
        email: json['email']?.toString(),
        firstname: json['firstname']?.toString(),
        lastname: json['lastname']?.toString(),
      );
}
