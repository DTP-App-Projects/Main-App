import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:digital_trade_portal/core/errors/failure.dart';
import 'package:digital_trade_portal/core/utils/services/remote_services/endpoints.dart';
import 'package:digital_trade_portal/features/auth/data/models/login_model.dart';
import 'package:digital_trade_portal/features/auth/data/models/verification_model.dart';
import 'package:digital_trade_portal/features/auth/data/repos/auth_repo.dart';
import '../../../../core/utils/services/remote_services/api_service.dart';

class AuthRepoImpl implements AuthRepo {
  final ApiService? apiService;

  AuthRepoImpl(this.apiService);

  @override
  Future<Either<Failure, LoginModel>> login({required Map<String, dynamic> data}) async {
    try {
      var response = await apiService!.postData(endPoint: EndPoints.login, data: data);
      return right(LoginModel.fromJson(response.data));
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      } else {
        return left(ServerFailure(e.toString()));
      }
    }
  }

  @override
  Future<Either<Failure, VerificationModel>> loginVerification({required Map<String, dynamic> data}) async {
    try {
      var response = await apiService!.postData(endPoint: EndPoints.loginVerification, data: data);
      var result = VerificationModel.fromJson(response.data);
      return right(result);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      } else {
        return left(ServerFailure(e.toString()));
      }
    }
  }

  @override
  Future<Either<Failure, String>> completeProfile({required Map<String, dynamic> data}) async {
    try {
      var response = await apiService!.postData(
        endPoint: "customer/profile/complete",
        data: FormData.fromMap(data),
        sendToken: true,
      );
      return right(response.data["message"]);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      } else {
        return left(ServerFailure(e.toString()));
      }
    }
  }
}
