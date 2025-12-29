import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/routes/app_router.dart';

// ================= LOGIN FEATURE =================
import 'features/login/data/datasources/login_remote_datasource.dart';
import 'features/login/data/repositories/login_repository_impl.dart';
import 'features/login/domain/usecases/login_usecase.dart';
import 'features/login/presentation/providers/login_provider.dart';

// ================= QR FEATURE =================
import 'features/qr/data/datasources/qr_remote_data_source.dart';
import 'features/qr/domain/usecases/generate_qr_usecase.dart';
import 'features/qr/presentation/providers/qr_provider.dart';

Future<void> main() async {
  // 🔥 REQUIRED for SharedPreferences + async router redirects
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const AppRoot());
}

/// Root widget where all providers are injected
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ================= LOGIN PROVIDER =================
        ChangeNotifierProvider(
          create: (_) => LoginProvider(
            LoginUseCase(
              LoginRepositoryImpl(
                LoginRemoteDataSource(),
              ),
            ),
          ),
        ),

        // ================= QR PROVIDER =================
        ChangeNotifierProvider(
          create: (_) => QrProvider(
            GenerateQrUseCase(
              QrRemoteDataSource(),
            ),
          ),
        ),
      ],
      child: const MyApp(),
    );
  }
}

/// Actual App widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
    );
  }
}

