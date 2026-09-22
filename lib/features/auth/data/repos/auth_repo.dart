import 'package:dartz/dartz.dart';
import 'package:digital_trade_portal/core/errors/failure.dart';
import 'package:digital_trade_portal/features/auth/data/models/login_model.dart';
import 'package:digital_trade_portal/features/auth/data/models/verification_model.dart';

abstract class AuthRepo {
  Future<Either<Failure, LoginModel>> login({required Map<String, dynamic> data});
  Future<Either<Failure, VerificationModel>> loginVerification({required Map<String, dynamic> data});
  Future<Either<Failure, String>> completeProfile({required Map<String, dynamic> data});
}
