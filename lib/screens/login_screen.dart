import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signup_screen.dart';
import 'data_form_screen.dart';
import 'admin_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // فیلڈ ورکر کے کنٹرولرز
  final _workerEmailController = TextEditingController();
  final _workerPasswordController = TextEditingController();
  
  // ایڈمن کے کنٹرولرز
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();

  bool _isLoading = false;

  // 1. فیلڈ ورکر لاگ ان لاجک (بغیر کسی ایڈمن رسائی کے)
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
        final loggedInEmail = response.user!.email!.toLowerCase();

        // اگر ایڈمن غلطی سے یہاں سے لاگ ان کرنے کی کوشش کرے تو اسے بلاک کریں
        if (loggedInEmail == 'admin@mortality.com') {
          await Supabase.instance.client.auth.signOut();
          _showSnackBar("Access Denied: Admin must log in through the Dedicated Admin Panel!", Colors.red);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DataFormScreen())
          );
        }
      }
    } on AuthException catch (e) {
      _showSnackBar(e.message, Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. ڈیڈیکیٹڈ ایڈمن لاگ ان لاجک (سخت سیکیورٹی چیک کے ساتھ)
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
            MaterialPageRoute(builder: (context) => const AdminDashboardScreen())
          );
        } else {
          // اگر کوئی عام فیلڈ ورکر ایڈمن پینل ہیک کرنے یا لاگ ان کرنے کی کوشش کرے
          await Supabase.instance.client.auth.signOut();
          _showSnackBar("Access Denied: You are not authorized as an Admin!", Colors.red);
        }
      }
    } on AuthException catch (e) {
      _showSnackBar(e.message, Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color)
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // دو بالکل الگ پینلز کے لیے ٹیبز
      child: Scaffold(
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
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    // پروفیشنل پینل ٹیب بار (بغیر کسی ٹوگل بٹن کے)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        indicatorColor: Colors.white,
                        indicatorWeight: 3,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        tabs: const [
                          Tab(icon: Icon(Icons.assignment_ind), text: "Field Worker"),
                          Tab(icon: Icon(Icons.admin_panel_settings), text: "Admin Panel"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // پینل کے مواد کا سائز فکس کرنے کے لیے ہائٹ کنٹینر
                    SizedBox(
                      height: 440, 
                      child: TabBarView(
                        physics: const NeverScrollableScrollPhysics(), // سیکیورٹی کے لیے سوائپ بند
                        children: [
                          _buildWorkerPanel(),
                          _buildAdminPanel(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- 👷 پینل 1: فیلڈ ورکر لاگ ان ویو ---
  Widget _buildWorkerPanel() {
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const Text(
              "Worker Authentication",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)
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
                    child: const Text("SIGN IN AS WORKER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
            const SizedBox(height: 15),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SignupScreen())
              ),
              child: const Text("Create a Worker Account? Sign Up", style: TextStyle(color: Colors.deepPurple)),
            )
          ],
        ),
      ),
    );
  }

  // --- 🔑 پینل 2: ڈیڈیکیٹڈ ایڈمن لاگ ان ویو ---
  Widget _buildAdminPanel() {
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const Text(
              "Administrative Secure Access",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)
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
                    child: const Text("AUTHORIZE & ENTER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.enhanced_encryption, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 5),
                Text("Encrypted FYP Administrator Session", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ],
            )
          ],
        ),
      ),
    );
  }
}