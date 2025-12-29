import 'package:barcode_generator/features/qr/presentation/pages/qr_page.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/login/presentation/pages/login_page.dart';
import '../../features/home/presentation/pages/home_page.dart';

class AppRoutes {
  static const login = '/login';
  static const home = '/home';
  static const qrPage = '/qrPage';
}

/// 🔐 AUTH CHECK
Future<bool> _isLoggedIn() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('isLoggedIn') ?? false;
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.login,

  redirect: (context, state) async {
    final loggedIn = await _isLoggedIn();
    final isOnLogin = state.matchedLocation == AppRoutes.login;

    // ❌ Not logged in → force login
    if (!loggedIn && !isOnLogin) {
      return AppRoutes.login;
    }

    // ✅ Logged in → skip login
    if (loggedIn && isOnLogin) {
      return AppRoutes.home;
    }

    return null;
  },

  routes: [
    GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginPage()),
    GoRoute(path: AppRoutes.home, builder: (_, __) => const HomePage()),
    // GoRoute(
    //   path: AppRoutes.qrPage,
    //   builder: (_, __) => const QrPage(),
    // ),
  ],
);
