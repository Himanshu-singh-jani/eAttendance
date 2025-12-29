import 'package:barcode_generator/core/routes/app_router.dart';
import 'package:barcode_generator/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/login_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscurePassword = true;
  bool _agreed = false;
  LoginStatus? _lastStatus;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool get _canLogin =>
      _usernameController.text.isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      _agreed;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LoginProvider>(
      builder: (context, provider, _) {
        // ================= SIDE EFFECTS =================
        if (_lastStatus != provider.status) {
          _lastStatus = provider.status;

          if (provider.status == LoginStatus.error) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Your username or password is incorrect'),
                  backgroundColor: Colors.red,
                ),
              );
              provider.clearError();
            });
          }

          if (provider.status == LoginStatus.success) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go(AppRoutes.home);
            });
          }
        }

        return Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // ===== LOGIN IMAGE =====
                  Container(
                    height: 260,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: AppColors.lightPrimary.withOpacity(0.15),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/login_illustration.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    'eAttendance',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Easy way to Record & Track Attendance',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),

                  const SizedBox(height: 32),

                  // ===== USERNAME =====
                  _inputField(
                    controller: _usernameController,
                    hint: 'Username',
                  ),

                  const SizedBox(height: 16),

                  // ===== PASSWORD =====
                  _inputField(
                    controller: _passwordController,
                    hint: 'Password',
                    obscure: _obscurePassword,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ===== AGREEMENT =====
                  Row(
                    children: [
                      Checkbox(
                        value: _agreed,
                        onChanged: (v) =>
                            setState(() => _agreed = v ?? false),
                      ),
                      const Expanded(
                        child: Text(
                          "I've read and agreed to User Agreement & Privacy Policy",
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // ===== LOGIN BUTTON =====
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed:
                          (_canLogin && provider.status != LoginStatus.loading)
                              ? () {
                                  context.read<LoginProvider>().login(
                                        _usernameController.text.trim(),
                                        _passwordController.text.trim(),
                                      );
                                }
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: provider.status == LoginStatus.loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===== INPUT FIELD =====
  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
