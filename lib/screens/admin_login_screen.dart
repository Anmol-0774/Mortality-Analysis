import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mortality_analysis/screens/dashboard_screen.dart';

// ═══════════════════════════════════════════════════════
//  ADMIN LOGIN — NOT linked from the main LoginScreen.
//  Reach this only through its own route (e.g. a named
//  route like '/admin-panel'), which on Flutter web means
//  typing the URL directly, e.g.:
//    https://yourapp.com/#/admin-panel
//  See the routing notes below for how to wire this up.
// ═══════════════════════════════════════════════════════
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _loginAsAdmin() async {
    final email = _adminEmailController.text.trim();
    final password = _adminPasswordController.text.trim();

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
        final loggedInEmail = response.user!.email!.toLowerCase();

        // سخت چیک: صرف مخصوص ایڈمن ای میل کو ہی ڈیش بورڈ کی اجازت ہوگی
        if (loggedInEmail == 'admin@mortality.com') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => DashboardScreen()),
          );
        } else {
          // اگر کوئی عام فیلڈ ورکر ایڈمن پینل ہیک کرنے یا لاگ ان کرنے کی کوشش کرے
          await Supabase.instance.client.auth.signOut();
          _showSnackBar("Access Denied: You are not authorized as an Admin!", Colors.red);
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
            colors: [Colors.indigo.shade900, Colors.deepPurple.shade900],
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
                  const Icon(Icons.admin_panel_settings, size: 80, color: Colors.white),
                  const SizedBox(height: 10),
                  const Text(
                    "Admin Panel Access",
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
                            "Administrative Secure Access",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                          const SizedBox(height: 25),
                          TextField(
                            controller: _adminEmailController,
                            decoration: InputDecoration(
                              labelText: "Admin Email",
                              prefixIcon: const Icon(Icons.security, color: Colors.indigo),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _adminPasswordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: "Secret Password",
                              prefixIcon: const Icon(Icons.lock_person, color: Colors.indigo),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 30),
                          _isLoading
                              ? const CircularProgressIndicator()
                              : ElevatedButton(
                                  onPressed: _loginAsAdmin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    minimumSize: const Size(double.infinity, 55),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text(
                                    "AUTHORIZE & ENTER",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.enhanced_encryption, size: 16, color: Colors.grey.shade500),
                              const SizedBox(width: 5),
                              Text(
                                "Encrypted FYP Administrator Session",
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                              ),
                            ],
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