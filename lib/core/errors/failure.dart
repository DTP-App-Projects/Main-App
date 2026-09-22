import 'package:dio/dio.dart';

abstract class Failure {
  final String errMessage;

  Failure(this.errMessage);
}

class ServerFailure extends Failure {
  ServerFailure(super.errMessage);

  factory ServerFailure.fromDioError(DioException dioException) {
    switch (dioException.type) {
      case DioExceptionType.connectionTimeout:
        return ServerFailure("connectionTimeOut");
      case DioExceptionType.sendTimeout:
        return ServerFailure("sendTimeOut");
      case DioExceptionType.receiveTimeout:
        return ServerFailure("receiveTimeOut");
      case DioExceptionType.badResponse:
        return ServerFailure.fromResponse(dioException.response!.statusCode!, dioException.response!.data);
      case DioExceptionType.cancel:
        return ServerFailure("requestCanceled");
      case DioExceptionType.unknown:
        if (dioException.error!.toString().contains("SocketException")) {
          return ServerFailure("noInternet");
        } else {
          return ServerFailure("unexpectedError");
        }

      default:
        return ServerFailure("Something went Error Try Again");
    }
  }

  factory ServerFailure.fromResponse(int statusCode, dynamic response) {
    if (statusCode == 400 || statusCode == 401 || statusCode == 403 || statusCode == 422) {
      return ServerFailure(response["message"].toString());
    } else if (statusCode == 500) {
      return ServerFailure("Internal Server Error");
    } else if (statusCode == 404) {
      return ServerFailure("Request Not Found");
    } else {
      return ServerFailure("Something went Error Try Again");
    }
  }
}

class CustomError extends Failure {
  CustomError(super.errMessage);

  static Failure getError(dynamic e) {
    if (e is DioException) {
      return ServerFailure.fromDioError(e);
    } else {
      return CustomError(e.toString());
    }
  }
}
