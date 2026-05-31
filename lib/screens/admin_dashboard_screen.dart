import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _allRecords = [];
  List<Map<String, dynamic>> _filteredRecords = [];
  List<String> _uniqueLocations = [];
  String _selectedLocation = 'All Localities';
  bool _isLoading = true;

  // Real-time KPI Metric Counters
  int _totalRecords = 0;
  int _maleDeaths = 0;
  int _femaleDeaths = 0;
  int _highRiskRegionsCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final response = await _supabase.from('death_data').select();
      setState(() {
        _allRecords = List<Map<String, dynamic>>.from(response);
        _filteredRecords = _allRecords;
        _calculateKPIs();
        
        final locations = _allRecords
            .map((e) => e['locality']?.toString().trim() ?? e['city_village']?.toString().trim() ?? 'Unknown')
            .where((name) => name != 'Unknown' && name.isNotEmpty)
            .toSet()
            .toList();
            
        _uniqueLocations = ['All Localities', ...locations];
        _isLoading = false;
      });
    } catch (e) {
      _showSnackBar('Database connection error: $e', Colors.red);
    }
  }

  void _calculateKPIs() {
    _totalRecords = _filteredRecords.length;
    _maleDeaths = _filteredRecords.where((r) => r['gender'].toString().toLowerCase().startsWith('m')).length;
    _femaleDeaths = _filteredRecords.where((r) => r['gender'].toString().toLowerCase().startsWith('f')).length;
    
    // Logic simulating anomalous clusters (high-risk areas)
    Map<String, int> regionCounts = {};
    for (var r in _filteredRecords) {
      String loc = r['locality'] ?? r['city_village'] ?? 'Unknown';
      regionCounts[loc] = (regionCounts[loc] ?? 0) + 1;
    }
    _highRiskRegionsCount = regionCounts.values.where((count) => count > 50).length; // Regions with over 50 records
  }

  void _applyAdvancedFilter(String query) {
    setState(() {
      _selectedLocation = query;
      if (query == 'All Localities' || query.isEmpty) {
        _filteredRecords = _allRecords;
      } else {
        _filteredRecords = _allRecords.where((r) {
          final recordLoc = (r['locality'] ?? r['city_village'] ?? '').toString().toLowerCase();
          return recordLoc.contains(query.toLowerCase());
        }).toList();
      }
      _calculateKPIs();
    });
  }

  // --- 🔒 High-Security Password Verification Flow ---
  void _openSecurePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool processingCrypto = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.shield_outlined, color: Colors.indigo[900]),
                const SizedBox(width: 10),
                const Text('Secure Password Synchronization'),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "To change the administrator signature, you must authenticate your current session profile.",
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: currentPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Verify Current Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_open),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required field' : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Secret Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_person_rounded),
                        helperText: 'Minimum 6 characters',
                      ),
                      validator: (v) => v!.length < 6 ? 'Password must be at least 6 characters' : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: processingCrypto ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[900], foregroundColor: Colors.white),
                onPressed: processingCrypto ? null : () async {
                  if (!formKey.currentState!.validate()) return;
                  
                  setDialogState(() => processingCrypto = true);
                  try {
                    final adminEmail = _supabase.auth.currentUser?.email;
                    
                    // Step 1: Re-authenticate the session using the current password input
                    await _supabase.auth.signInWithPassword(
                      email: adminEmail!,
                      password: currentPasswordController.text.trim(),
                    );

                    // Step 2: Current password is valid -> commit the update lifecycle
                    await _supabase.auth.updateUser(
                      UserAttributes(password: newPasswordController.text.trim()),
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Admin authorization tokens updated successfully!'), backgroundColor: Colors.green)
                      );
                    }
                  } on AuthException catch (e) {
                    _showSnackBar('Authentication Failed: ${e.message}', Colors.red);
                  } finally {
                    setDialogState(() => processingCrypto = false);
                  }
                },
                child: processingCrypto 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Confirm Identity & Update'),
              )
            ],
          );
        }
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLaptop = screenWidth > 950;

    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        title: const Text('🔬 Digital Mortality System Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.admin_panel_settings_rounded), tooltip: 'Security Panel', onPressed: _openSecurePasswordDialog),
          IconButton(
            icon: const Icon(Icons.exit_to_app_rounded),
            onPressed: () async {
              await _supabase.auth.signOut();
              if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBarSection(),
                  const SizedBox(height: 20),
                  
                  // Component 1: Summary Cards (Top Row)
                  _buildSummaryCardsRow(isLaptop),
                  const SizedBox(height: 20),

                  // Layout Matrix parsing configurations strictly matching the architectural map blueprint
                  if (isLaptop) ...[
                    Row(children: [Expanded(child: _buildAgeChart()), const SizedBox(width: 20), Expanded(child: _buildGenderChart())]),
                    const SizedBox(height: 20),
                    _buildCauseOfDeathChart(),
                    const SizedBox(height: 20),
                    _buildGoogleMapsHeatmapSimulation(),
                    const SizedBox(height: 20),
                    Row(children: [Expanded(child: _buildTrendChart()), const SizedBox(width: 20), Expanded(child: _buildLifestyleFactorsChart())]),
                    const SizedBox(height: 20),
                    Row(children: [Expanded(child: _buildPredictionGaugeMeter()), const SizedBox(width: 20), Expanded(child: _buildForecastChart())]),
                    const SizedBox(height: 20),
                    Row(children: [Expanded(child: _buildKMeansClusterPlot()), const SizedBox(width: 20), Expanded(child: _buildChatbotWidgetPanel())]),
                  ] else ...[
                    _buildAgeChart(), const SizedBox(height: 20),
                    _buildGenderChart(), const SizedBox(height: 20),
                    _buildCauseOfDeathChart(), const SizedBox(height: 20),
                    _buildGoogleMapsHeatmapSimulation(), const SizedBox(height: 20),
                    _buildTrendChart(), const SizedBox(height: 20),
                    _buildLifestyleFactorsChart(), const SizedBox(height: 20),
                    _buildPredictionGaugeMeter(), const SizedBox(height: 20),
                    _buildForecastChart(), const SizedBox(height: 20),
                    _buildKMeansClusterPlot(), const SizedBox(height: 20),
                    _buildChatbotWidgetPanel(),
                  ]
                ],
              ),
            ),
    );
  }

  Widget _buildSearchBarSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Autocomplete<String>(
                optionsBuilder: (TextEditingValue v) => v.text.isEmpty ? const Iterable<String>.empty() : _uniqueLocations.where((o) => o.toLowerCase().contains(v.text.toLowerCase())),
                onSelected: (s) => _applyAdvancedFilter(s),
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(hintText: "Enter specific City or Village query manually...", border: InputBorder.none, prefixIcon: Icon(Icons.search)),
                  );
                },
              ),
            ),
            const VerticalDivider(width: 20),
            DropdownButton<String>(
              value: _uniqueLocations.contains(_selectedLocation) ? _selectedLocation : 'All Localities',
              underline: const SizedBox(),
              items: _uniqueLocations.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
              onChanged: (val) => _applyAdvancedFilter(val!),
            )
          ],
        ),
      ),
    );
  }

  // --- 1. Summary Cards Matrix Row ---
  Widget _buildSummaryCardsRow(bool isLaptop) {
    return GridView.count(
      crossAxisCount: isLaptop ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: isLaptop ? 2.2 : 1.8,
      children: [
        _kpiCard("Total Records", _totalRecords.toString(), Icons.analytics, Colors.blue),
        _kpiCard("Male Deaths", _maleDeaths.toString(), Icons.male, Colors.teal),
        _kpiCard("Female Deaths", _femaleDeaths.toString(), Icons.female, Colors.purple),
        _kpiCard("High-Risk Localities", _highRiskRegionsCount.toString(), Icons.gpp_maybe, Colors.red),
      ],
    );
  }

  Widget _kpiCard(String title, String val, IconData icon, Color col) {
    return Card(
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: col.withOpacity(0.1), child: Icon(icon, color: col)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  // --- 2. Age Distribution Chart ---
  Widget _buildAgeChart() {
    int c1 = 0, c2 = 0, c3 = 0, c4 = 0, c5 = 0;
    for (var r in _filteredRecords) {
      int age = int.tryParse(r['age'].toString()) ?? 0;
      if (age <= 10) c1++;
      else if (age <= 20) c2++;
      else if (age <= 40) c3++;
      else if (age <= 60) c4++;
      else c5++;
    }
    final data = [_DataPoint('0-10', c1.toDouble()), _DataPoint('11-20', c2.toDouble()), _DataPoint('21-40', c3.toDouble()), _DataPoint('41-60', c4.toDouble()), _DataPoint('60+', c5.toDouble())];
    return Card(
      color: Colors.white,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SfCartesianChart(
          title: const ChartTitle(text: 'Age Distribution Matrix', textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          primaryXAxis: const CategoryAxis(),
          series: <CartesianSeries>[ColumnSeries<_DataPoint, String>(dataSource: data, xValueMapper: (d, _) => d.label, yValueMapper: (d, _) => d.value, color: Colors.indigoAccent)],
        ),
      ),
    );
  }

  // --- 3. Gender Comparison Chart ---
  Widget _buildGenderChart() {
    final data = [_DataPoint('Male', _maleDeaths.toDouble()), _DataPoint('Female', _femaleDeaths.toDouble())];
    return Card(
      color: Colors.white,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SfCircularChart(
          title: const ChartTitle(text: 'Gender Ratio Allocation', textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          legend: const Legend(isVisible: true, position: LegendPosition.bottom),
          series: <CircularSeries>[DoughnutSeries<_DataPoint, String>(dataSource: data, xValueMapper: (d, _) => d.label, yValueMapper: (d, _) => d.value, dataLabelSettings: const DataLabelSettings(isVisible: true))],
        ),
      ),
    );
  }

  // --- 4. Cause of Death Analysis ---
  Widget _buildCauseOfDeathChart() {
    Map<String, int> counts = {};
    for (var r in _filteredRecords) {
      String cause = r['cause_of_death'] ?? 'Other';
      counts[cause] = (counts[cause] ?? 0) + 1;
    }
    final data = counts.entries.map((e) => _DataPoint(e.key, e.value.toDouble())).toList();
    return Card(
      color: Colors.white,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SfCartesianChart(
          title: const ChartTitle(text: 'Primary Etiology / Mortality Causes Vectors', textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          primaryXAxis: const CategoryAxis(),
          series: <CartesianSeries>[BarSeries<_DataPoint, String>(dataSource: data, xValueMapper: (d, _) => d.label, yValueMapper: (d, _) => d.value, color: Colors.teal[400], dataLabelSettings: const DataLabelSettings(isVisible: true))],
        ),
      ),
    );
  }

  // --- 5. Regional Mortality Map Simulation ---
  Widget _buildGoogleMapsHeatmapSimulation() {
    return Container(
      width: double.infinity,
      height: 320,
      decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          // Simulated Google Maps Regional Topography Grid Layout Vector Graphics
          Positioned.fill(child: Opacity(opacity: 0.25, child: GridPaper(color: Colors.blue[100]!, interval: 30, divisions: 2))),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.map_rounded, size: 50, color: Colors.white70),
                const SizedBox(height: 10),
                Text("Google Maps API Active Environment Overlay (${_selectedLocation})", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _mapLabel("🔴 High Risk Area", Colors.red),
                    const SizedBox(width: 15),
                    _mapLabel("🟡 Medium Risk Area", Colors.amber),
                    const SizedBox(width: 15),
                    _mapLabel("🟢 Low Risk Area", Colors.green),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _mapLabel(String text, Color col) => Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: col)), const SizedBox(width: 6), Text(text, style: const TextStyle(color: Colors.white, fontSize: 12))]);

  // --- 6. Mortality Trend Over Time ---
  Widget _buildTrendChart() {
    Map<int, int> timeline = {};
    for (var r in _filteredRecords) {
      if (r['date_of_death'] != null) {
        try {
          int yr = DateTime.parse(r['date_of_death'].toString()).year;
          timeline[yr] = (timeline[yr] ?? 0) + 1;
        } catch (_) {}
      }
    }
    final sorted = timeline.keys.toList()..sort();
    final data = sorted.map((y) => _DataPoint(y.toString(), timeline[y]!.toDouble())).toList();
    return Card(
      color: Colors.white,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SfCartesianChart(
          title: const ChartTitle(text: 'Timeline Progression Vector Analytics', textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          primaryXAxis: const CategoryAxis(),
          series: <CartesianSeries>[LineSeries<_DataPoint, String>(dataSource: data, xValueMapper: (d, _) => d.label, yValueMapper: (d, _) => d.value, color: Colors.purple, markerSettings: const MarkerSettings(isVisible: true))],
        ),
      ),
    );
  }

  // --- 7. Lifestyle Risk Factors ---
  Widget _buildLifestyleFactorsChart() {
    final data = [_DataPoint('Smoking', 35), _DataPoint('Obesity', 28), _DataPoint('Sedentary', 22), _DataPoint('Alcohol', 10), _DataPoint('Poor Diet', 45)];
    return Card(
      color: Colors.white,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SfCartesianChart(
          title: const ChartTitle(text: 'Comorbid Lifestyle Risk Modifiers', textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          primaryXAxis: const CategoryAxis(),
          series: <CartesianSeries>[ColumnSeries<_DataPoint, String>(dataSource: data, xValueMapper: (d, _) => d.label, yValueMapper: (d, _) => d.value, color: Colors.deepOrangeAccent)],
        ),
      ),
    );
  }

  // --- 8 & 9. AI Prediction Gauge Meter Simulation ---
  Widget _buildPredictionGaugeMeter() {
    return Card(
      color: Colors.white,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text('XGBoost / Neural Networks Risk Index Metric', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 25),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160, height: 160,
                  child: CircularProgressIndicator(value: 0.85, strokeWidth: 16, backgroundColor: Colors.grey[200], color: Colors.red[700]),
                ),
                Column(
                  children: [
                    Text('85%', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.red[700])),
                    const Text('CRITICAL RISK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                  ],
                )
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text('LOW', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                Text('MEDIUM', style: TextStyle(color: Colors.amber[700], fontWeight: FontWeight.bold, fontSize: 11)),
                Text('HIGH', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
              ],
            )
          ],
        ),
      ),
    );
  }

  // --- 11. Future Mortality Forecast Chart ---
  Widget _buildForecastChart() {
    final historical = [_DataPoint('2023', 450), _DataPoint('2024', 490), _DataPoint('2025', 520), _DataPoint('2026', 580)];
    final projection = [_DataPoint('2026', 580), _DataPoint('2027 (F)', 640), _DataPoint('2028 (F)', 710)];
    return Card(
      color: Colors.white,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SfCartesianChart(
          title: const ChartTitle(text: 'Predictive Horizon Predictive Forecasting Model', textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          primaryXAxis: const CategoryAxis(),
          series: <CartesianSeries>[
            LineSeries<_DataPoint, String>(dataSource: historical, xValueMapper: (d, _) => d.label, yValueMapper: (d, _) => d.value, color: Colors.blue, name: 'Actual Data'),
            LineSeries<_DataPoint, String>(dataSource: projection, xValueMapper: (d, _) => d.label, yValueMapper: (d, _) => d.value, color: Colors.red, dashArray: const <double>[5, 5], name: 'AI Projection')
          ],
        ),
      ),
    );
  }

  // --- 10. Risk Group Clustering (K-Means Scatter Plot) ---
  Widget _buildKMeansClusterPlot() {
    final c1 = [const _ClusterPoint(12, 20), const _ClusterPoint(18, 25), const _ClusterPoint(15, 30)];
    final c2 = [const _ClusterPoint(40, 55), const _ClusterPoint(45, 60), const _ClusterPoint(50, 65)];
    final c3 = [const _ClusterPoint(70, 85), const _ClusterPoint(75, 90), const _ClusterPoint(80, 95)];
    return Card(
      color: Colors.white,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SfCartesianChart(
          title: const ChartTitle(text: 'K-Means Algorithmic Population Density Clusters', textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          series: <ScatterSeries>[
            ScatterSeries<_ClusterPoint, double>(dataSource: c1, xValueMapper: (p, _) => p.x, yValueMapper: (p, _) => p.y, color: Colors.green, name: 'Low Risk Group'),
            ScatterSeries<_ClusterPoint, double>(dataSource: c2, xValueMapper: (p, _) => p.x, yValueMapper: (p, _) => p.y, color: Colors.amber, name: 'Medium Risk Group'),
            ScatterSeries<_ClusterPoint, double>(dataSource: c3, xValueMapper: (p, _) => p.x, yValueMapper: (p, _) => p.y, color: Colors.red, name: 'High Risk Cluster')
          ],
        ),
      ),
    );
  }

  // --- 12. LangChain Natural Language AI Chatbot Interface Panel ---
  Widget _buildChatbotWidgetPanel() {
    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        height: 340,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.indigo[900], borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))),
              child: const Row(
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text('LangChain / GPT Predictive AI Terminal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _chatBubble("Which region has the highest mortality rate?", true),
                  _chatBubble("Analyzing database cluster registers... Cluster analysis shows Alipur has an anomalous spike in cardiovascular cases.", false),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Ask AI (e.g., 'Predict mortality trend for next year')...",
                  suffixIcon: const Icon(Icons.send_rounded, color: Colors.indigo),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _chatBubble(String text, bool isUser) => Align(alignment: isUser ? Alignment.centerRight : Alignment.centerLeft, child: Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.symmetric(vertical: 4), decoration: BoxDecoration(color: isUser ? Colors.indigo[100] : Colors.grey[200], borderRadius: BorderRadius.circular(12)), child: Text(text, style: const TextStyle(fontSize: 12))));
}

class _DataPoint { _DataPoint(this.label, this.value); final String label; final double value; }
class _ClusterPoint { const _ClusterPoint(this.x, this.y); final double x; final double y; }