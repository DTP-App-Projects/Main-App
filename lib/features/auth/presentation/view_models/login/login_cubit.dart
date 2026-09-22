import 'package:bloc/bloc.dart';
import 'package:digital_trade_portal/features/auth/data/models/login_model.dart';
import 'package:digital_trade_portal/features/auth/data/repos/auth_repo.dart';
part 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this.repo) : super(LoginInitial());
  final AuthRepo repo;

  Future<void> login({required String phone}) async {
    emit(LoginLoadingState());
    var result = await repo.login(data: {
      "action_by": "phone",
      "phone": "+966$phone",
      "role": "customer",
    });
    return result.fold((failure) {
      emit(LoginErrorState(errMessage: failure.errMessage));
    }, (data) {
      emit(LoginSuccessState(model: data));
    });
  }
}
