part of 'complete_profile_cubit.dart';

sealed class CompleteProfileState {}

final class CompleteProfileInitial extends CompleteProfileState {}

final class CompleteProfileLoadingState extends CompleteProfileState {}

final class CompleteProfileSuccessState extends CompleteProfileState {
  final String message;

  CompleteProfileSuccessState({required this.message});
}

final class CompleteProfileErrorState extends CompleteProfileState {
  final String errMessage;

  CompleteProfileErrorState({required this.errMessage});
}
