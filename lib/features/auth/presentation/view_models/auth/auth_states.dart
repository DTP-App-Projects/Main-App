abstract class AuthStates {}

class AuthInitState extends AuthStates {}

class CheckLoginPhoneLengthState extends AuthStates {}
class CheckRegisterPhoneLengthState extends AuthStates {}
class EnableVerifyButtonState extends AuthStates {}
