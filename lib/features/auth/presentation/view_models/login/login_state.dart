part of 'login_cubit.dart';

sealed class LoginState {}

final class LoginInitial extends LoginState {}

final class LoginLoadingState extends LoginState {}

final class LoginSuccessState extends LoginState {
  final LoginModel model;

  LoginSuccessState({required this.model});
}

final class LoginErrorState extends LoginState {
  final String errMessage;

  LoginErrorState({required this.errMessage});
}
