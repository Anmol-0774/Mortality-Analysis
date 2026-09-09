import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mortality_analysis/screens/dashboard_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mortality_analysis/screens/splash_screen.dart';
import 'package:mortality_analysis/screens/dashboard_screen.dart';
import 'package:mortality_analysis/screens/data_form_screen.dart';
import 'package:mortality_analysis/screens/login_screen.dart';
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

  // UPDATE: now async, because it looks up the user's role from the
  // `profiles` table instead of matching a hardcoded email. This means
  // a worker account and an admin account both go through the SAME
  // login screen, and this function figures out where to send them —
  // no separate secret URL required for admin access to work.
  //
  // IMPORTANT: since this is now a Future<Widget>, whatever calls
  // getHomeScreen() (your SplashScreen) must `await` it. Paste
  // splash_screen.dart and I'll update that too.
  static Future<Widget> getHomeScreen() async {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      return const LoginScreen();
    }

    final userId = session.user.id;

    // Check role from the profiles table
    String? role;
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();
      role = profile['role'] as String?;
    } catch (e) {
      // Table/column missing or no profile row found for this user.
      role = null;
    }

    if (role == 'admin') {
      if (kIsWeb) {
        return DashboardScreen();
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
      // 3. No separate admin route needed anymore — admin access now goes
      // through the same LoginScreen, and getHomeScreen() above sends
      // admins to the right dashboard based on their `role`.
    );
  }
}