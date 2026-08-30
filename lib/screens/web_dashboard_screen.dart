import 'package:flutter/material.dart';
import 'package:mortality_analysis/screens/analytics_page.dart';

class WebDashboardScreen extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  WebDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0b0f1a),
      appBar: AppBar(
        title: const Text('Mortality Admin Panel'),
        backgroundColor: const Color(0xFF111827),
        foregroundColor: const Color(0xFF38bdf8),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnalyticsPage()),
            ),
            icon: const Icon(Icons.bar_chart, color: Color(0xFF38bdf8)),
            label: const Text(
              'Analytics',
              style: TextStyle(color: Color(0xFF38bdf8)),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: const _WebDashboardBody(),
    );
  }
}

class _WebDashboardBody extends StatelessWidget {
  const _WebDashboardBody();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Welcome
          const Text(
            'Admin Dashboard',
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Mortality Analysis System',
            style: TextStyle(color: Color(0xFF64748b), fontSize: 13),
          ),
          const SizedBox(height: 28),

          // ── Quick nav cards
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.2,
            children: [
              _NavCard(
                icon: Icons.bar_chart,
                label: 'Descriptive Analytics',
                sub: 'Causes · Age · Gender · Trends',
                color: const Color(0xFF38bdf8),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnalyticsPage()),
                ),
              ),
              _NavCard(
                icon: Icons.people,
                label: 'Records',
                sub: 'View all mortality records',
                color: const Color(0xFF818cf8),
                onTap: () {}, // hook up your records screen here
              ),
              _NavCard(
                icon: Icons.add_circle_outline,
                label: 'Add Record',
                sub: 'Enter new mortality data',
                color: const Color(0xFF34d399),
                onTap: () {}, // hook up your form screen here
              ),
              _NavCard(
                icon: Icons.settings,
                label: 'Settings',
                sub: 'System configuration',
                color: const Color(0xFFfb923c),
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1e2d45)),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(sub,
                      style: const TextStyle(
                          color: Color(0xFF64748b), fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 14),
          ],
        ),
      ),
    );
  }
}