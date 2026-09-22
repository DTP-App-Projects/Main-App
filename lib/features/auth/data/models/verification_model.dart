class VerificationModel {
  String? message;
  Data? data;
  bool? ok;

  VerificationModel.fromJson(Map<String, dynamic> json) {
    message = json['message'];
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
    ok = json['ok'];
  }
}

class Data {
  UserData? userData;
  String? token;

  Data.fromJson(Map<String, dynamic> json) {
    userData = json['data'] != null ? UserData.fromJson(json['data']) : null;
    token = json['token'];
  }
}

class UserData {
  int? id;
  String? name;
  String? email;
  String? phone;
  String? avatar;
  String? gender;
  String? birthday;
  String? status;
  int? nationalityId;
  bool? acceptConditions;


  UserData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    email = json['email'];
    phone = json['phone'];
    avatar = json['avatar'];
    gender = json['gender'];
    birthday = json['birthday'];
    status = json['status'];
    nationalityId = json['nationality_id'];
    acceptConditions = json['accept_conditions'];
  }
}
