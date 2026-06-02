import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mortality_analysis/screens/web_dashboard_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mortality_analysis/screens/dashboard_screen.dart';
import 'package:mortality_analysis/screens/data_form_screen.dart';
import 'package:mortality_analysis/screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('offline_records');

  await Supabase.initialize(
    url: 'https://qhgjwjrdlclksmddpijk.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFoZ2p3anJkbGNsa3NtZGRwaWprIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyNTU2NjQsImV4cCI6MjA5MTgzMTY2NH0.muDLOM5SE_lHlWICzGCqyGgnahFOs-SjJIIqzVy5hSw',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Widget _getHomeScreen() {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      return const LoginScreen();
    }

    final userEmail = session.user.email;

    final isAdmin =
        userEmail != null &&
        userEmail.toLowerCase() == 'admin@mortality.com';

    if (isAdmin) {
      // Web (Edge/Chrome) → use web-safe dashboard
      if (kIsWeb) {
        return WebDashboardScreen();
      }
      // Android / iOS → WebView dashboard works fine
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
      home: _getHomeScreen(),
    );
  }
}