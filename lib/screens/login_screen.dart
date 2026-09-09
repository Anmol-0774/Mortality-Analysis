// ignore_for_file: use_super_parameters
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'data_form_screen.dart';
import 'signup_screen.dart';
import 'dashboard_screen.dart';
import 'web_dashboard_screen.dart';

// ═══════════════════════════════════════════════════════
//  FIELD WORKER LOGIN — this is the ONLY login shown when
//  the app opens normally. Admin login lives on its own
//  separate route (see admin_login_screen.dart) and is
//  never linked from here.
//
//  UPDATE: this screen now also supports admins logging in
//  through the SAME form. After Supabase authenticates the
//  user, we check their `role` in the `profiles` table and
//  redirect accordingly. This is the professional pattern —
//  no hidden URL needed, and it works identically on web
//  and mobile.
// ═══════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _workerEmailController = TextEditingController();
  final _workerPasswordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _loginAsWorker() async {
    final email = _workerEmailController.text.trim();
    final password = _workerPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar("Please fill in all fields", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (response.session != null) {
        final userId = response.user!.id;

        // Fetch role from the profiles table
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

        if (!mounted) return;

        if (role == 'admin') {
          // Role says admin -> go straight to admin dashboard
          // (matches the same web/mobile split used in main.dart's getHomeScreen)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  kIsWeb ? WebDashboardScreen() : const DashboardScreen(),
            ),
          );
        } else {
          // Normal worker path (unchanged)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DataFormScreen()),
          );
        }
      }
    } on AuthException catch (e) {
      _showSnackBar(e.message, Colors.red);
    } catch (e) {
      _showSnackBar(e.toString(), Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade900, Colors.indigo.shade800],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.health_and_safety, size: 80, color: Colors.white),
                  const SizedBox(height: 10),
                  const Text(
                    "Mortality Records Gateway",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Card(
                    elevation: 10,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    child: Padding(
                      padding: const EdgeInsets.all(25),
                      child: Column(
                        children: [
                          const Text(
                            "Worker Authentication",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(height: 25),
                          TextField(
                            controller: _workerEmailController,
                            decoration: InputDecoration(
                              labelText: "Worker Email",
                              prefixIcon: const Icon(Icons.email, color: Colors.deepPurple),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _workerPasswordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: "Password",
                              prefixIcon: const Icon(Icons.lock, color: Colors.deepPurple),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 30),
                          _isLoading
                              ? const CircularProgressIndicator()
                              : ElevatedButton(
                                  onPressed: _loginAsWorker,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    minimumSize: const Size(double.infinity, 55),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text(
                                    "SIGN IN AS WORKER",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                          const SizedBox(height: 15),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SignupScreen()),
                            ),
                            child: const Text(
                              "Create a Worker Account? Sign Up",
                              style: TextStyle(color: Colors.deepPurple),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  WEBVIEW DASHBOARD (unchanged, kept from original file)
// ═══════════════════════════════════════════════════════
class DashboardWebViewScreen extends StatefulWidget {
  const DashboardWebViewScreen({super.key});

  @override
  State<DashboardWebViewScreen> createState() => _DashboardWebViewScreenState();
}

class _DashboardWebViewScreenState extends State<DashboardWebViewScreen> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadFlutterAsset('assets/dashboard.html');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mortality Analytics Dashboard'),
        backgroundColor: Colors.indigo,
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}