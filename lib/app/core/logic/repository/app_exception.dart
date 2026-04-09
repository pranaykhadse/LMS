///
///
/// App Exception is used to make the error handling Uniform across multiple Types Repositories.
///
///
class AppException implements Exception {
  final String _message;
  final String _prefix;

  AppException([this._message = "", this._prefix = ""]);

  String get message => _message;
  String get title => _prefix;
  @override
  String toString() {
    return "$_prefix: $_message";
  }
}

class InvalidResponseException extends AppException {
  InvalidResponseException([String message = ""])
      : super(message, "Invalid Response");
}

class FetchDataException extends AppException {
  FetchDataException([String message = ""])
      : super(message, "Error During Communication");
}

class TooManyRequestException extends AppException {
  TooManyRequestException([String message = ""])
      : super(message, "Too Many Request");
}

class InternetException extends AppException {
  InternetException([String message = ""]) : super(message, "Connection error");
}

class BadRequestException extends AppException {
  BadRequestException([message]) : super(message, "Invalid Request");
}

class UnauthorizedException extends AppException {
  UnauthorizedException([message]) : super(message, "Unauthorized");
}

class InvalidInputException extends AppException {
  InvalidInputException([String message = ""])
      : super(message, "Invalid Input");
}

class NotFoundException extends AppException {
  NotFoundException([message]) : super(message, "Not Found");
}
