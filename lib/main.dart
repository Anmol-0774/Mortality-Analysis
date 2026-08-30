import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mortality_analysis/screens/web_dashboard_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mortality_analysis/screens/splash_screen.dart';
import 'package:mortality_analysis/screens/dashboard_screen.dart';
import 'package:mortality_analysis/screens/data_form_screen.dart';
import 'package:mortality_analysis/screens/login_screen.dart';
import 'package:mortality_analysis/screens/admin_login_screen.dart';
 // 1. Imported your splash screen file

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('offline_records');

  await Supabase.initialize(
    url: 'https://jpnjovhobwqmhebfydkz.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpwbmpvdmhvYndxbWhlYmZ5ZGt6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA0NjQ1OTIsImV4cCI6MjA5NjA0MDU5Mn0.aiDX2NTNPU7BndHnLlYxmpEi6dNizegMYofQLo5POkU',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Keep this public/accessible so your splash screen can call it to find the next page
  static Widget getHomeScreen() {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      return const LoginScreen();
    }

    final userEmail = session.user.email;

    final isAdmin =
        userEmail != null &&
        userEmail.toLowerCase() == 'admin@mortality.com';

    if (isAdmin) {
      if (kIsWeb) {
        return WebDashboardScreen();
      }
      return const DashboardScreen();
    }

    return const DataFormScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mortality Analysis App',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      // 2. Splash screen is the initial landing screen for the normal '/' route
      home: const SplashScreen(),
      // 3. Separate named route for the Admin Panel — NOT linked from the
      // worker LoginScreen anywhere. Reach it directly:
      //   - Web: https://yourapp.com/#/admin-panel
      //   - In-app: Navigator.pushNamed(context, '/admin-panel')
      routes: {
        '/admin-panel': (context) => const AdminLoginScreen(),
      },
    );
  }
}