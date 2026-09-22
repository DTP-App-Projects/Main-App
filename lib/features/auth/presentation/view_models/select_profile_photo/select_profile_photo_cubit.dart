import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:digital_trade_portal/features/auth/data/repos/auth_repo.dart';

part 'select_profile_photo_state.dart';

class SelectProfilePhotoCubit extends Cubit<SelectProfilePhotoState> {
  SelectProfilePhotoCubit(this.repo) : super(SelectProfilePhotoInitial());
  final AuthRepo repo;

  File? profilePhotoFile;
  ImagePicker picker = ImagePicker();

  selectProfilePhoto() async {
    await picker.pickImage(source: ImageSource.gallery).then((image) {
      if (image != null) {
        profilePhotoFile = File(image.path);
        emit(SelectProfilePhotoSuccessState());
      }
    });
  }
}
