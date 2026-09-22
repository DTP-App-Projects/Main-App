class LoginModel {
  String? message;
  String? requestId;

  LoginModel.fromJson(Map<String, dynamic> json) {
    message = json['message'];
    requestId = json['request_id'];
  }
}
