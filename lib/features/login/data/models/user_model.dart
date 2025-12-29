class UserModel {
  final int userId;
  final int orgId;
  final String orgName;
  final int officeId;
  final String officeName;
  final String userName;
  final String? fullName;
  final String? email;
  final String? mobileNo;
  final String role;

  UserModel({
    required this.userId,
    required this.orgId,
    required this.orgName,
    required this.officeId,
    required this.officeName,
    required this.userName,
    required this.role,
    this.fullName,
    this.email,
    this.mobileNo,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'],
      orgId: json['orgId'],
      orgName: json['orgName'],
      officeId: json['officeId'],
      officeName: json['officeName'],
      userName: json['userName'],
      role: json['role'],
      fullName: json['fullName'],
      email: json['email'],
      mobileNo: json['mobileNo'],
    );
  }
}
