import 'package:lms/app/core/model/page_info.dart';

class DataResponse<T> {
  final List<T> data;
  final PageInfo pageInfo;

  DataResponse({required this.data, required this.pageInfo});

  static DataResponse<T> parse<T>(dynamic response, T Function(Map) fromMap) {
    if (response['success'] == 'false') throw response['message'];
    final pageInfo = PageInfo.fromJson(response);

    final payload = response['payload'];
    if (payload is! List) throw "Invalid response from server";

    List<T> courses = [];
    for (var element in payload) {
      if (element['roasters'] != null) {
        if (element['roasters'] is List && element['roasters'].length > 0) {
          print(element);
        } else if (element['roasters'] is Map &&
            element['roasters'].length > 0) {
          print(element);
        }
      }
      courses.add(fromMap(element));
    }
    return DataResponse(data: courses, pageInfo: pageInfo);
  }
}
