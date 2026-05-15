import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/services/supabase_service.dart';
import 'core/services/server_time_service.dart';
import 'core/services/session_service.dart';
import 'core/utils/app_version.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/login/login_screen.dart';

// Global navigator key untuk session callbacks
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

  // Setup session callbacks untuk auto-logout
  _setupSessionCallbacks();

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

/// Setup callbacks untuk session management
void _setupSessionCallbacks() {
  // Callback ketika session expired
  SessionService.onSessionExpired = () {
    final context = navigatorKey.currentContext;
    if (context != null) {
      // Auto logout dan redirect ke login
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      
      // Show notification
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please login again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  };
  
  // Callback ketika session akan expired (warning)
  SessionService.onSessionWarning = () {
    final context = navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Session Warning'),
          content: const Text(
            'Your session will expire in 5 minutes. '
            'Do you want to continue working?'
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                SessionService.updateActivity(); // Extend session
              },
              child: const Text('Continue'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Manual logout
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      );
    }
  };
}

class JamsAbsenApp extends StatelessWidget {
  const JamsAbsenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jams Attendance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      navigatorKey: navigatorKey, // Untuk session callbacks
      home: const SplashScreen(),
    );
  }
}
