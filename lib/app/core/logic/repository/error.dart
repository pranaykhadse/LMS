import 'dart:io';

import 'package:dio/dio.dart';

import 'app_exception.dart';

/// The server doesn't always return a JSON object on error (sometimes a
/// plain string, a list of validation messages, or nothing at all), so
/// pulling a "message" key out of it must not assume it's a Map — doing
/// that with dynamic typing throws (List's [] operator wants an int index,
/// not a String key), turning a normal HTTP error into a confusing crash.
String? _messageFrom(dynamic data) {
  if (data is Map) return data["message"]?.toString();
  if (data is List && data.isNotEmpty) return data.join("\n");
  if (data is String && data.isNotEmpty) return data;
  return null;
}

void handelException(e) {
  if (e is! DioException) {
    if (e is SocketException) {
      throw InternetException();
    }
    throw FetchDataException(e.toString());
  }
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
      throw AppException(
          "Connection Timeout while reaching server", "Connection Timeout : ");
    case DioExceptionType.sendTimeout:
      throw AppException(
          "Connection Timeout while Sending data to server", "Send Timeout : ");

    case DioExceptionType.receiveTimeout:
      throw AppException("Connection Timeout while recieving data from server",
          "Recieve Timeout : ");

    case DioExceptionType.badResponse:
      switch (e.response?.statusCode) {
        case 400:
          throw BadRequestException(_messageFrom(e.response?.data) ??
              e.response?.statusMessage.toString() ??
              "");
        case 401:
        case 403:
          throw UnauthorizedException(_messageFrom(e.response?.data) ??
              e.response?.statusMessage.toString() ??
              "No Permission");
        case 404:
          throw NotFoundException(
              _messageFrom(e.response?.data) ?? "Requested Data Not Found");

        case 413:
          throw AppException(
              "File is too large to upload", "File is too large : ");

        case 422:
          String data2 = "";
          final responseData = e.response?.data;
          final errors = responseData is Map ? responseData["errors"] : null;
          if (errors is Map) {
            for (var item in errors.values) {
              data2 += (item is List ? item.join("\n") : item.toString()) + "\n";
            }
          } else if (errors is List) {
            data2 = errors.join("\n");
          }
          throw InvalidInputException(
              data2.isEmpty ? (_messageFrom(responseData) ?? "Invalid input.") : data2);
        // throw UnauthorisedException(e.response.statusMessage.toString());
        case 429:
          throw TooManyRequestException();
        case 500:
        default:
          throw FetchDataException(
              'Error occured while Communication with Server: ${e.message}');
      }

    case DioExceptionType.cancel:
      throw AppException("Request was cancelled", "Cancel:");

    case DioExceptionType.unknown:
      if (e.error is SocketException) {
        throw InternetException();
      }
      throw FetchDataException(
          e.error?.toString() ?? "Unknown Error occured while Requesting");
    case DioExceptionType.badCertificate:
      throw AppException(
          "Certification Verification Failed.", "Bad Certificate");
    case DioExceptionType.connectionError:
      throw InternetException();
  }
}

void removeNullFromMap(Map data) {
  data.removeWhere((key, value) => value == null);
  data.forEach((key, value) {
    if (value is Map) {
      removeNullFromMap(value);
    }
    if (value is List) {
      for (var e in value) {
        if (e is Map) {
          removeNullFromMap(e);
        }
      }
    }
  });
}
