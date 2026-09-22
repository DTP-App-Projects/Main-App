import 'package:bloc/bloc.dart';
import 'package:digital_trade_portal/features/auth/presentation/view_models/auth/auth_states.dart';

class AuthCubit extends Cubit<AuthStates>{
  AuthCubit():super(AuthInitState());

  int loginPhoneLength=0;

  checkLoginPhoneLength({required int length}){
    loginPhoneLength=length;
    emit(CheckLoginPhoneLengthState());
  }

  int registerPhoneLength=0;

  checkRegisterPhoneLength({required int length}){
    registerPhoneLength=length;
    emit(CheckRegisterPhoneLengthState());
  }

  enableVerifyButton(){
    emit(EnableVerifyButtonState());
  }
}