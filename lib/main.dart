import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/services/supabase_service.dart';
import 'core/services/server_time_service.dart';
import 'core/utils/app_version.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait([
    initializeDateFormatting('id_ID'),
    SupabaseService.initialize(),
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
  ]);

  // Inisialisasi waktu server setelah Supabase siap
  // untuk cache offset waktu sedini mungkin
  ServerTimeService.initialize();

  // Load versi dari pubspec.yaml (1x, tersedia di mana saja)
  await AppVersion.init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const JamsAbsenApp());
}

class JamsAbsenApp extends StatelessWidget {
  const JamsAbsenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jams Attendance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}
