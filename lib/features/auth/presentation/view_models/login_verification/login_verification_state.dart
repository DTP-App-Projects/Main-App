part of 'login_verification_cubit.dart';

sealed class LoginVerificationState {}

final class LoginVerificationInitial extends LoginVerificationState {}

final class LoginVerificationLoadingState extends LoginVerificationState {}

final class LoginVerificationSuccessState extends LoginVerificationState {
  final VerificationModel verificationModel;

  LoginVerificationSuccessState({required this.verificationModel});
}

final class LoginVerificationErrorState extends LoginVerificationState {
  final String errMessage;

  LoginVerificationErrorState({required this.errMessage});
}
