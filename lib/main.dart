import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mortality_analysis/screens/login_screen.dart';
import 'package:mortality_analysis/screens/data_form_screen.dart'; // Ensure path is correct

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Hive for Offline Storage
  await Hive.initFlutter();
  await Hive.openBox('offline_records');

  // 2. Initialize Supabase
  await Supabase.initialize(
    url: 'https://qhgjwjrdlclksmddpijk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFoZ2p3anJkbGNsa3NtZGRwaWprIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyNTU2NjQsImV4cCI6MjA5MTgzMTY2NH0.muDLOM5SE_lHlWICzGCqyGgnahFOs-SjJIIqzVy5hSw',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 3. Check if a user is already logged in
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mortality Analysis App',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo, // Matching your new professional UI
      ),
      // Agar session exist karta hai toh Data Form dikhao, warna Login
      home: session != null ? const DataFormScreen() : const LoginScreen(),
    );
  }
}