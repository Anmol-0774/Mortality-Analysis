import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mortality_analysis/screens/clustering_page.dart';
import 'package:mortality_analysis/screens/reports_and_chatbot_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:mortality_analysis/screens/analytics_page.dart';
import 'package:mortality_analysis/screens/login_screen.dart';

// ═══════════════════════════════════════════════════════
//  THEME CONSTANTS
// ═══════════════════════════════════════════════════════
class _T {
  static const bg      = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const border  = Color(0xFF334155);
  static const muted   = Color(0xFF94A3B8);
  static const sub     = Color(0xFFCBD5E1);
  static const text    = Color(0xFFF1F5F9);
  static const accent  = Color(0xFF38BDF8);
  static const green   = Color(0xFF34D399);
  static const purple  = Color(0xFF818CF8);
  static const orange  = Color(0xFFFB923C);
  static const red     = Color(0xFFF87171);
  static const pink    = Color(0xFFF472B6);
}

// ═══════════════════════════════════════════════════════
//  DASHBOARD SCREEN
// ═══════════════════════════════════════════════════════
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _sb = Supabase.instance.client;
  WebViewController? _controller;
  bool _webViewLoading = true;

  // Stats
  int    _totalRecords  = 0;
  int    _validRecords  = 0;
  int    _flaggedRecords = 0;
  double _avgQuality    = 0;
  bool   _statsLoading  = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
    if (!kIsWeb) _loadHtml();
  }

  // ─────────────────────────────────────────────
  //  LOAD STATS
  // ─────────────────────────────────────────────
Future<void> _loadStats() async {
  setState(() => _statsLoading = true);

  try {
    final res = await _sb
        .from('mortality_records_clean')
        .select('quality_score'); // ❌ removed is_valid

    final data = List<Map<String, dynamic>>.from(res as List);

    final scores = data
        .map((r) => r['quality_score'])
        .whereType<num>() // safer than int
        .toList();

    final avg = scores.isEmpty
        ? 0.0
        : scores.reduce((a, b) => a + b) / scores.length;

    setState(() {
      _totalRecords = data.length;

      _validRecords = 0;     // ❌ removed is_valid logic
      _flaggedRecords = 0;   // ❌ removed is_valid logic

      _avgQuality = avg;
      _statsLoading = false;
    });
  } catch (e) {
    setState(() => _statsLoading = false);
    debugPrint('Stats error: $e');
  }
}
  // ─────────────────────────────────────────────
  //  LOAD HTML (mobile only)
  // ─────────────────────────────────────────────
  Future<void> _loadHtml() async {
    try {
      final html = await rootBundle.loadString('assets/dashboard.html');
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) => setState(() => _webViewLoading = false),
        ))
        ..loadHtmlString(html);
      setState(() {});
    } catch (e) {
      debugPrint('WebView error: $e');
    }
  }

  // ─────────────────────────────────────────────
  //  NAVIGATION HELPERS
  // ─────────────────────────────────────────────
  void _go(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  // ─────────────────────────────────────────────
  //  LOGOUT
  // ─────────────────────────────────────────────
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Sign Out',
        message: 'Are you sure you want to log out?',
        confirmLabel: 'Sign Out',
        confirmColor: _T.red,
        icon: Icons.logout_rounded,
      ),
    );
    if (confirmed != true) return;
    await _sb.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ─────────────────────────────────────────────
  //  CHANGE PASSWORD
  // ─────────────────────────────────────────────
  void _showChangePassword() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ChangePasswordDialog(),
    );
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final email = _sb.auth.currentUser?.email ?? 'Admin';
    return Scaffold(
      backgroundColor: _T.bg,
      body: Column(children: [
        _buildTopBar(email),
        Expanded(child: kIsWeb ? _buildWebBody() : _buildMobileBody()),
      ]),
    );
  }

  // ─────────────────────────────────────────────
  //  TOP BAR
  // ─────────────────────────────────────────────
  Widget _buildTopBar(String email) {
    return Container(
      decoration: BoxDecoration(
        color: _T.surface,
        border: Border(bottom: BorderSide(color: _T.border)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(children: [
        // Logo
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: _T.accent.withOpacity(0.3), blurRadius: 12)],
          ),
          child: const Icon(Icons.monitor_heart_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Mortality Analysis', style: TextStyle(color: _T.text, fontWeight: FontWeight.bold, fontSize: 16)),
          const Text('Admin Panel', style: TextStyle(color: _T.muted, fontSize: 11)),
        ]),
        const Spacer(),
        // Admin chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _T.bg, borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _T.border),
          ),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: _T.accent.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.person_rounded, color: _T.accent, size: 16),
            ),
            const SizedBox(width: 8),
            Text(email, style: const TextStyle(color: _T.sub, fontSize: 12), overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: 10),
        _topBtn(icon: Icons.lock_reset_rounded, label: 'Password', color: _T.purple, onTap: _showChangePassword),
        const SizedBox(width: 8),
        _topBtn(icon: Icons.logout_rounded, label: 'Logout', color: _T.red, onTap: _logout),
      ]),
    );
  }

  Widget _topBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) =>
      TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        style: TextButton.styleFrom(
          backgroundColor: color.withOpacity(0.08),
          side: BorderSide(color: color.withOpacity(0.2)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      );

  // ─────────────────────────────────────────────
  //  WEB BODY
  // ─────────────────────────────────────────────
  Widget _buildWebBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Welcome Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_T.accent.withOpacity(0.15), _T.purple.withOpacity(0.10)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _T.accent.withOpacity(0.2)),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Welcome back, Admin 👋',
                  style: TextStyle(color: _T.text, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Mortality Analysis System — Admin Control Panel',
                  style: TextStyle(color: _T.muted, fontSize: 13)),
              const SizedBox(height: 16),
              Wrap(spacing: 10, runSpacing: 10, children: [
                _bannerBtn(Icons.bar_chart_rounded,      'Analytics',    _T.accent,  () => _go(const AnalyticsPage())),
                _bannerBtn(Icons.hub_rounded,            'Clustering',   _T.purple,  () => _go(ClusteringPage())),
                _bannerBtn(Icons.summarize_rounded,      'Reports & AI', _T.orange,  () => _go(const ReportsAndChatbotPage())),
              ]),
            ])),
            const SizedBox(width: 20),
            Icon(Icons.analytics_rounded, size: 72, color: _T.accent.withOpacity(0.25)),
          ]),
        ),
        const SizedBox(height: 24),

        // ── Stats Row
        _buildStatsRow(),
        const SizedBox(height: 24),

        // ── Menu Grid
        const Text('Quick Actions', style: TextStyle(color: _T.muted, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _buildMenuGrid(),
      ]),
    );
  }

  Widget _bannerBtn(IconData icon, String label, Color color, VoidCallback onTap) =>
      ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: _T.bg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
      );

  // ─────────────────────────────────────────────
  //  MOBILE BODY
  // ─────────────────────────────────────────────
  Widget _buildMobileBody() {
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator(color: _T.accent));
    }
    return Stack(children: [
      WebViewWidget(controller: _controller!),
      if (_webViewLoading)
        Container(color: _T.bg, child: const Center(child: CircularProgressIndicator(color: _T.accent))),
      // Mobile FAB menu
      Positioned(
        bottom: 24, right: 24,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          _mobileFab(Icons.summarize_rounded,   'Reports & AI', _T.orange,  () => _go(const ReportsAndChatbotPage())),
          const SizedBox(height: 10),
          _mobileFab(Icons.hub_rounded,          'Clustering',   _T.purple,  () => _go(ClusteringPage())),
          const SizedBox(height: 10),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'analytics',
            onPressed: () => _go(const AnalyticsPage()),
            backgroundColor: _T.accent,
            foregroundColor: _T.bg,
            icon: const Icon(Icons.bar_chart_rounded),
            label: const Text('Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
            elevation: 6,
          ),
        ]),
      ),
    ]);
  }

  Widget _mobileFab(IconData icon, String label, Color color, VoidCallback onTap) =>
      FloatingActionButton.extended(
        heroTag: label,
        onPressed: onTap,
        backgroundColor: color.withOpacity(0.9),
        foregroundColor: _T.bg,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        elevation: 4,
      );

  // ─────────────────────────────────────────────
  //  STATS ROW
  // ─────────────────────────────────────────────
  Widget _buildStatsRow() {
    final stats = [
      ('Total Records', _statsLoading ? '…' : '$_totalRecords',                      _T.accent,  Icons.storage_rounded),
      ('Valid Records', _statsLoading ? '…' : '$_validRecords',                      _T.green,   Icons.verified_rounded),
      ('Flagged',       _statsLoading ? '…' : '$_flaggedRecords',                    _T.red,     Icons.flag_rounded),
      ('Avg Quality',   _statsLoading ? '…' : '${_avgQuality.toStringAsFixed(0)}%',  _T.orange,  Icons.star_rounded),
    ];
    return LayoutBuilder(builder: (ctx, box) {
      final cols = box.maxWidth > 700 ? 4 : box.maxWidth > 400 ? 2 : 1;
      return GridView.count(
        crossAxisCount: cols, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 2.4,
        children: stats.map((s) => Container(
          decoration: BoxDecoration(
            color: _T.surface, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _T.border),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: s.$3.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(s.$4, color: s.$3, size: 22),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(s.$1, style: const TextStyle(color: _T.muted, fontSize: 11)),
              const SizedBox(height: 3),
              Text(s.$2, style: TextStyle(color: s.$3, fontSize: 22, fontWeight: FontWeight.bold)),
            ]),
          ]),
        )).toList(),
      );
    });
  }

  // ─────────────────────────────────────────────
  //  MENU GRID — ALL 6 CARDS
  // ─────────────────────────────────────────────
  Widget _buildMenuGrid() {
    final items = [
      _MenuItem(
        Icons.bar_chart_rounded,
        'Descriptive Analytics',
        'Causes · Age · Gender · Year Trends',
        _T.accent,
        () => _go(const AnalyticsPage()),
      ),
      _MenuItem(
        Icons.hub_rounded,
        'Clustering (K-Means ML)',
        'Risk clusters · Scatter plot · Stats',
        _T.purple,
        () => _go(ClusteringPage()),
      ),
      _MenuItem(
        Icons.summarize_rounded,
        'Reports & AI Assistant',
        'Export reports · Chat with your data',
        _T.orange,
        () => _go(const ReportsAndChatbotPage()),
      ),
      _MenuItem(
        Icons.lock_reset_rounded,
        'Change Password',
        'Update your admin password',
        _T.pink,
        _showChangePassword,
      ),
      _MenuItem(
        Icons.logout_rounded,
        'Sign Out',
        'Securely log out of the system',
        _T.red,
        _logout,
      ),
    ];

    return LayoutBuilder(builder: (ctx, box) {
      final cols = box.maxWidth > 900 ? 3 : box.maxWidth > 600 ? 2 : 1;
      return GridView.count(
        crossAxisCount: cols, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 14, mainAxisSpacing: 14,
        childAspectRatio: box.maxWidth > 900 ? 2.2 : 2.4,
        children: items.map(_buildMenuCard).toList(),
      );
    });
  }

  Widget _buildMenuCard(_MenuItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: item.color.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(item.title, style: const TextStyle(color: _T.text, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(item.subtitle, style: const TextStyle(color: _T.muted, fontSize: 11)),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, color: item.color.withOpacity(0.5), size: 14),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  MENU ITEM MODEL
// ═══════════════════════════════════════════════════════
class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _MenuItem(this.icon, this.title, this.subtitle, this.color, this.onTap);
}

// ═══════════════════════════════════════════════════════
//  CONFIRM DIALOG
// ═══════════════════════════════════════════════════════
class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final IconData icon;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: confirmColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: confirmColor, size: 20),
        ),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(color: Color(0xFFF1F5F9), fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
      content: Text(message, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
//  CHANGE PASSWORD DIALOG
// ═══════════════════════════════════════════════════════
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey    = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool   _showCurrent = false;
  bool   _showNew     = false;
  bool   _showConfirm = false;
  bool   _loading     = false;
  String? _errorMsg;
  String? _successMsg;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _errorMsg = null; _successMsg = null; });
    try {
      final sb    = Supabase.instance.client;
      final email = sb.auth.currentUser?.email ?? '';
      final auth  = await sb.auth.signInWithPassword(email: email, password: _currentCtrl.text.trim());
      if (auth.user == null) {
        setState(() { _errorMsg = 'Current password is incorrect.'; _loading = false; });
        return;
      }
      await sb.auth.updateUser(UserAttributes(password: _newCtrl.text.trim()));
      setState(() { _successMsg = 'Password updated successfully!'; _loading = false; });
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _errorMsg = 'Error: ${e.toString().replaceAll('AuthException:', '').trim()}';
        _loading  = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF818CF8).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.lock_reset_rounded, color: Color(0xFF818CF8), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Change Password', style: TextStyle(color: Color(0xFFF1F5F9), fontWeight: FontWeight.bold, fontSize: 17)),
                Text('Update your admin password', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ])),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),
            ]),
            const SizedBox(height: 24),
            const Divider(color: Color(0xFF334155)),
            const SizedBox(height: 20),

            if (_errorMsg   != null) _banner(_errorMsg!,   const Color(0xFFF87171), Icons.error_outline_rounded),
            if (_successMsg != null) _banner(_successMsg!, const Color(0xFF34D399), Icons.check_circle_outline_rounded),

            _fieldLabel('Current Password'),
            _pwField(_currentCtrl, 'Enter current password', _showCurrent,
                () => setState(() => _showCurrent = !_showCurrent),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
            const SizedBox(height: 16),

            _fieldLabel('New Password'),
            _pwField(_newCtrl, 'Min. 8 characters', _showNew,
                () => setState(() => _showNew = !_showNew),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 8) return 'Minimum 8 characters';
                  return null;
                }),
            const SizedBox(height: 16),

            _fieldLabel('Confirm New Password'),
            _pwField(_confirmCtrl, 'Re-enter new password', _showConfirm,
                () => setState(() => _showConfirm = !_showConfirm),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v != _newCtrl.text) return 'Passwords do not match';
                  return null;
                }),
            const SizedBox(height: 24),

            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF94A3B8),
                  side: const BorderSide(color: Color(0xFF334155)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cancel'),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF818CF8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  disabledBackgroundColor: const Color(0xFF334155),
                ),
                child: _loading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold)),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(label, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600)),
  );

  Widget _pwField(TextEditingController ctrl, String hint, bool visible,
      VoidCallback toggleVis, {String? Function(String?)? validator}) =>
      TextFormField(
        controller: ctrl,
        obscureText: !visible,
        style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 13),
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          filled: true, fillColor: const Color(0xFF0F172A),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          suffixIcon: IconButton(
            icon: Icon(visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: const Color(0xFF64748B), size: 18),
            onPressed: toggleVis,
          ),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF334155))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF818CF8))),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF87171))),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF87171))),
          errorStyle: const TextStyle(color: Color(0xFFF87171), fontSize: 11),
        ),
      );

  Widget _banner(String msg, Color color, IconData icon) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(msg, style: TextStyle(color: color, fontSize: 12))),
    ]),
  );
}