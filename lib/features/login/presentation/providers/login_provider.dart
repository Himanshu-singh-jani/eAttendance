import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/usecases/login_usecase.dart';
import '../../data/models/login_response_model.dart';

enum LoginStatus { idle, loading, success, error }

class LoginProvider extends ChangeNotifier {
  final LoginUseCase loginUseCase;

  LoginProvider(this.loginUseCase);

  LoginStatus status = LoginStatus.idle;
  String? error;

  Future<void> login(String username, String password) async {
    status = LoginStatus.loading;
    error = null;
    notifyListeners();

    try {
      final LoginResponseModel result = await loginUseCase(username, password);

      // 🔒 Safety check (backend bug protection)
      if (result.token.isEmpty) {
        throw Exception('Invalid token');
      }

      final prefs = await SharedPreferences.getInstance();

      // ================= AUTH STATE =================
      await prefs.setBool('isLoggedIn', true); // 🔥 REQUIRED

      // ================= TOKEN =================
      await prefs.setString('token', result.token);
      await prefs.setString('expiresAt', result.expiresAt.toIso8601String());

      // ================= USER =================
      await prefs.setInt('userId', result.user.userId);
      await prefs.setString('userName', result.user.userName);
      await prefs.setString('role', result.user.role);

      // ================= ORGANIZATION =================
      await prefs.setInt('orgId', result.user.orgId);
      await prefs.setString('orgName', result.user.orgName);

      // ================= OFFICE =================
      await prefs.setInt('officeId', result.user.officeId);
      await prefs.setString('officeName', result.user.officeName);

      // ================= OPTIONAL =================
      await prefs.setString('fullName', result.user.fullName ?? '');
      await prefs.setString('email', result.user.email ?? '');
      await prefs.setString('mobileNo', result.user.mobileNo ?? '');

      status = LoginStatus.success;
    } catch (e) {
      error = 'Your username or password is incorrect';
      status = LoginStatus.error;
    }

    notifyListeners();
  }

  /// Clear error after snackbar
  void clearError() {
    error = null;
    status = LoginStatus.idle;
    notifyListeners();
  }

  /// Logout (used by profile widget / future API)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    // 🔥 Clear auth state
    await prefs.clear();

    status = LoginStatus.idle;
    notifyListeners();
  }
}
