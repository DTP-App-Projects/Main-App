import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:digital_trade_portal/features/auth/data/repos/auth_repo.dart';

part 'complete_profile_state.dart';

class CompleteProfileCubit extends Cubit<CompleteProfileState> {
  CompleteProfileCubit(this.repo) : super(CompleteProfileInitial());
  final AuthRepo repo;

  Future<void> completeProfile({
    required String name,
    required String gender,
    required String birthday,
    required String phone,
    File? avatar,
    String? email,
  }) async {
    emit(CompleteProfileLoadingState());
    var result = await repo.completeProfile(data: {
      "name": name,
      "gender": gender,
      "birthday": birthday,
      "phone": "+966$phone",
      if (avatar != null) "avatar": await MultipartFile.fromFile(avatar.path),
      if (email != null&&email!="") "email": email,
      // if(nationalityId!=null) "nationality_id": nationalityId,
      "accept_conditions":1,
    });
    return result.fold((failure) {
      emit(CompleteProfileErrorState(errMessage: failure.errMessage));
    }, (data) {
      emit(CompleteProfileSuccessState(message: data));
    });
  }
}
