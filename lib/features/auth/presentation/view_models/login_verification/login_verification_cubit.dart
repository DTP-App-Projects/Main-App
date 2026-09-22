import 'package:bloc/bloc.dart';
import 'package:digital_trade_portal/core/utils/services/local_services/cache_helper.dart';
import 'package:digital_trade_portal/features/auth/data/models/verification_model.dart';
import 'package:digital_trade_portal/features/auth/data/repos/auth_repo.dart';
part 'login_verification_state.dart';

class LoginVerificationCubit extends Cubit<LoginVerificationState> {
  LoginVerificationCubit(this.repo) : super(LoginVerificationInitial());
  final AuthRepo repo;

  Future<void> loginVerification({required String phone,required String requestId, required String otp}) async {
    emit(LoginVerificationLoadingState());
    var result = await repo.loginVerification(
      data: {
        "field": "phone",
        "value": "+966$phone",
        "otp": otp,
        "request_id":requestId,
        "fcm_token": await CacheHelper.getData(key: "deviceToken"),
      },
    );
    return result.fold(
      (failure) {
        emit(LoginVerificationErrorState(errMessage: failure.errMessage));
      },
      (data) {
        emit(LoginVerificationSuccessState(verificationModel: data));
      },
    );
  }
}
