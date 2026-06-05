import 'dart:io';

import 'package:dio/dio.dart';

import 'app_exception.dart';

void handelException(e) {
  if (e is! DioException) {
    if (e is SocketException) {
      throw InternetException();
    }
    throw FetchDataException(e.toString());
  }
  // log(e.message);
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
          throw BadRequestException(e.response?.data?["message"] ??
              e.response?.statusMessage.toString() ??
              "");
        case 401:
        case 403:
          throw UnauthorizedException(e.response?.data?["message"] ??
              e.response?.statusMessage.toString() ??
              "No Permission");
        case 404:
          throw NotFoundException(
              e.response?.data?['message'] ?? "Requested Data Not Found");

        case 413:
          throw AppException(
              "File is too large to upload", "File is too large : ");

        case 422:
          String data2 = "";
          var data3 = e.response?.data?["errors"];
          if (data3 is Map) {
            for (var item in data3.values) {
              data2 += (item.join("\n") ?? "") + "\n";
            }
          }
          throw InvalidInputException(
              (data2.isEmpty ? e.response?.data["message"] : data2).toString());
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
