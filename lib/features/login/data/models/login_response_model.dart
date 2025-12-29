import 'user_model.dart';

class LoginResponseModel {
  final String token;
  final UserModel user;
  final DateTime expiresAt;

  LoginResponseModel({
    required this.token,
    required this.user,
    required this.expiresAt,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      token: json['token'],
      user: UserModel.fromJson(json['user']),
      expiresAt: DateTime.parse(json['expiresAt']),
    );
  }
}
