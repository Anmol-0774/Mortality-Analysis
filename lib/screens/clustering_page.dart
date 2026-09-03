import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

// ═══════════════════════════════════════════════════════
//  THEME
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
  static const yellow  = Color(0xFFFBBF24);
  static const orange  = Color(0xFFFB923C);
  static const red     = Color(0xFFF87171);
  static const purple  = Color(0xFF818CF8);
}

// ═══════════════════════════════════════════════════════
//  MODELS
// ═══════════════════════════════════════════════════════

/// One data point per locality, with computed features
class _LocalityPoint {
  final String locality;
  final String district;
  final double mortalityRate;   // deaths per locality (normalized 0-1)
  final double avgAge;          // average age of deceased (normalized 0-1)
  final double waterScore;      // water quality score (0-1, higher = better)
  final double comorbidityRate; // proportion with prior conditions
  final int    totalDeaths;     // raw death count
  final Map<String, int> causeCounts; // cause_of_death -> count, for this locality
  int    cluster = -1;          // assigned cluster (0=Low, 1=Med, 2=High)

  _LocalityPoint({
    required this.locality,
    required this.district,
    required this.mortalityRate,
    required this.avgAge,
    required this.waterScore,
    required this.comorbidityRate,
    required this.totalDeaths,
    required this.causeCounts,
  });

  // Feature vector for K-Means distance calculation
  List<double> get features => [mortalityRate, avgAge, 1 - waterScore, comorbidityRate];

  // The single most common cause of death recorded in this locality
  String get topDisease {
    if (causeCounts.isEmpty) return 'Unknown';
    return (causeCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }
}

class _ScatterPoint {
  final double x; // mortality rate
  final double y; // water score (inverted = risk)
  final String label;
  _ScatterPoint(this.x, this.y, this.label);
}

class _CD {
  final String label;
  final double value;
  _CD(this.label, this.value);
}

// ═══════════════════════════════════════════════════════
//  CLUSTERING PAGE
// ═══════════════════════════════════════════════════════
class ClusteringPage extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  ClusteringPage({super.key});
  @override
  State<ClusteringPage> createState() => _ClusteringPageState();
}

class _ClusteringPageState extends State<ClusteringPage> {
  final _sb = Supabase.instance.client;

  List<_LocalityPoint> _points = [];
  List<_LocalityPoint> _filtered = [];

  // Filters
  String? _selDistrict;
  String? _selCluster;
  List<String> _districts = [];

  bool _loading = true;
  bool _clustering = false;
  String? _error;
  int _iterations = 0;

  // Cluster labels & colors
  static const _clusterNames  = ['Low Risk', 'Medium Risk', 'High Risk'];
  static const _clusterColors = [_T.green, _T.yellow, _T.red];
  static const _clusterIcons  = [
    Icons.check_circle_rounded,
    Icons.warning_amber_rounded,
    Icons.dangerous_rounded,
  ];

  @override
  void initState() { super.initState(); _fetchAndCluster(); }

  // ─────────────────────────────────────────────
  //  FETCH + BUILD FEATURES
  // ─────────────────────────────────────────────
  Future<void> _fetchAndCluster() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _sb
          .from('mortality_records_clean')
          .select('specific_locality, district, age, water_source, '
              'prior_medical_conditions, cause_of_death, quality_score')
          .gte('quality_score', 60)
          .limit(10000);

      final data = List<Map<String, dynamic>>.from(res as List);

      // Group by locality
      final Map<String, Map<String, dynamic>> grouped = {};
      for (final r in data) {
        final loc  = r['specific_locality']?.toString() ?? '';
        final dist = r['district']?.toString() ?? '';
        if (loc.isEmpty || loc == 'Not Specified') continue;

        final key = '$loc|$dist';
        if (!grouped.containsKey(key)) {
          grouped[key] = {
            'locality': loc, 'district': dist,
            'deaths': 0, 'ages': <int>[],
            'waterScores': <double>[], 'comorbidCount': 0,
            'causeCounts': <String, int>{},
          };
        }
        grouped[key]!['deaths'] = (grouped[key]!['deaths'] as int) + 1;

        final age = r['age'];
        if (age is int && age > 0 && age < 120) {
          (grouped[key]!['ages'] as List<int>).add(age);
        }

        // Water quality score: Filtered=1.0, Tap=0.8, Well=0.5, River=0.2, Other=0.4
        final water = r['water_source']?.toString() ?? '';
        final ws = {'Filtered': 1.0, 'Tap': 0.8, 'Well': 0.5, 'River': 0.2}[water] ?? 0.4;
        (grouped[key]!['waterScores'] as List<double>).add(ws);

        final conds = r['prior_medical_conditions'];
        if (conds is List && conds.isNotEmpty &&
            !(conds.length == 1 && (conds.first?.toString().toLowerCase() ?? '') == 'none')) {
          grouped[key]!['comorbidCount'] = (grouped[key]!['comorbidCount'] as int) + 1;
        }

        // Cause of death tally per locality
        final cause = r['cause_of_death']?.toString() ?? '';
        if (cause.isNotEmpty && cause != 'Unspecified' && cause != 'Unknown') {
          final causeCounts = grouped[key]!['causeCounts'] as Map<String, int>;
          causeCounts[cause] = (causeCounts[cause] ?? 0) + 1;
        }
      }

      if (grouped.isEmpty) {
        setState(() { _error = 'No locality data found in the database.'; _loading = false; });
        return;
      }

      // Find max deaths for normalization
      final maxDeaths = grouped.values.map((g) => g['deaths'] as int).reduce(max).toDouble();

      // Build feature points
      _points = grouped.values.map((g) {
        final deaths    = g['deaths'] as int;
        final ages      = g['ages'] as List<int>;
        final wScores   = g['waterScores'] as List<double>;
        final comorbid  = g['comorbidCount'] as int;
        final causes    = g['causeCounts'] as Map<String, int>;
        final avgAge    = ages.isEmpty ? 0.5 : (ages.reduce((a, b) => a + b) / ages.length) / 90.0;
        final avgWater  = wScores.isEmpty ? 0.5 : wScores.reduce((a, b) => a + b) / wScores.length;
        final comorbRate= deaths > 0 ? comorbid / deaths : 0.0;
        return _LocalityPoint(
          locality: g['locality'] as String,
          district: g['district'] as String,
          mortalityRate: maxDeaths > 0 ? deaths / maxDeaths : 0.0,
          avgAge: avgAge.clamp(0.0, 1.0),
          waterScore: avgWater.clamp(0.0, 1.0),
          comorbidityRate: comorbRate.clamp(0.0, 1.0),
          totalDeaths: deaths,
          causeCounts: causes,
        );
      }).toList();

      _districts = _points.map((p) => p.district)
          .where((d) => d.isNotEmpty && d != 'Unknown').toSet().toList()..sort();

      // Run K-Means
      await _runKMeans();
      _applyFilters();
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ─────────────────────────────────────────────
  //  K-MEANS ALGORITHM
  // ─────────────────────────────────────────────
  Future<void> _runKMeans({int k = 3, int maxIter = 100}) async {
    setState(() => _clustering = true);

    if (_points.length < k) {
      // Not enough data: assign manually by deaths
      final sorted = List<_LocalityPoint>.from(_points)
        ..sort((a, b) => a.totalDeaths.compareTo(b.totalDeaths));
      final third = sorted.length ~/ 3;
      for (int i = 0; i < sorted.length; i++) {
        sorted[i].cluster = i < third ? 0 : i < third * 2 ? 1 : 2;
      }
      setState(() { _clustering = false; _iterations = 1; });
      return;
    }

  final rng = Random(42); // fixed seed for reproducibility

// Initialize centroids: pick k points spread across mortality range
final sorted = List<_LocalityPoint>.from(_points)
  ..sort((a, b) => a.mortalityRate.compareTo(b.mortalityRate));

final step = sorted.length ~/ k;

List<List<double>> centroids = List.generate(k, (i) {
  final p = sorted[(i * step).clamp(0, sorted.length - 1)];
  return List<double>.from(p.features);
});

    int iter = 0;
    bool changed = true;

    while (changed && iter < maxIter) {
      changed = false;
      iter++;

      // Assign each point to nearest centroid
      for (final p in _points) {
        double minDist = double.infinity;
        int best = 0;
        for (int c = 0; c < k; c++) {
          final d = _euclidean(p.features, centroids[c]);
          if (d < minDist) { minDist = d; best = c; }
        }
        if (p.cluster != best) { p.cluster = best; changed = true; }
      }

      // Recompute centroids
      for (int c = 0; c < k; c++) {
        final members = _points.where((p) => p.cluster == c).toList();
        if (members.isEmpty) continue;
        for (int f = 0; f < 4; f++) {
          centroids[c][f] = members.map((p) => p.features[f]).reduce((a, b) => a + b) / members.length;
        }
      }
    }

    // Relabel clusters: sort by avg mortality so 0=low, 1=med, 2=high
    final clusterAvgMortality = List.generate(k, (c) {
      final m = _points.where((p) => p.cluster == c).toList();
      return m.isEmpty ? 0.0 : m.map((p) => p.mortalityRate).reduce((a, b) => a + b) / m.length;
    });
    final order = List.generate(k, (i) => i)
      ..sort((a, b) => clusterAvgMortality[a].compareTo(clusterAvgMortality[b]));
    final remap = {for (int i = 0; i < k; i++) order[i]: i};
    for (final p in _points) { p.cluster = remap[p.cluster] ?? p.cluster; }

    setState(() { _clustering = false; _iterations = iter; });
  }

  double _euclidean(List<double> a, List<double> b) {
    double sum = 0;
    for (int i = 0; i < a.length; i++) {
      sum += pow(a[i] - b[i], 2);
    }
    return sqrt(sum);
  }

  // ─────────────────────────────────────────────
  //  FILTERS
  // ─────────────────────────────────────────────
  void _applyFilters() {
    _filtered = _points.where((p) {
      if (_selDistrict != null && _selDistrict!.isNotEmpty && p.district != _selDistrict) return false;
      if (_selCluster != null && _selCluster!.isNotEmpty &&
          _clusterNames[p.cluster] != _selCluster) {
        return false;
      }
      return true;
    }).toList();
    setState(() => _loading = false);
  }

  void _clearFilters() {
    setState(() { _selDistrict = null; _selCluster = null; });
    _applyFilters();
  }

  // ─────────────────────────────────────────────
  //  COMPUTED STATS
  // ─────────────────────────────────────────────
  List<_LocalityPoint> _clusterMembers(int c) => _filtered.where((p) => p.cluster == c).toList();

  double _avgDeaths(int c) {
    final m = _clusterMembers(c);
    if (m.isEmpty) return 0;
    return m.map((p) => p.totalDeaths).reduce((a, b) => a + b) / m.length;
  }

  double _avgWater(int c) {
    final m = _clusterMembers(c);
    if (m.isEmpty) return 0;
    return m.map((p) => p.waterScore).reduce((a, b) => a + b) / m.length;
  }

  double _avgComorbid(int c) {
    final m = _clusterMembers(c);
    if (m.isEmpty) return 0;
    return m.map((p) => p.comorbidityRate).reduce((a, b) => a + b) / m.length;
  }

  /// Most common cause of death across ALL localities in this cluster,
  /// computed by summing each locality's own cause tally.
  String _clusterTopDisease(int c) {
    final members = _clusterMembers(c);
    final Map<String, int> combined = {};
    for (final p in members) {
      p.causeCounts.forEach((cause, count) {
        combined[cause] = (combined[cause] ?? 0) + count;
      });
    }
    if (combined.isEmpty) return 'Unknown';
    return (combined.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
  }

  // ─────────────────────────────────────────────
  //  AREAS LIST POPUP
  // ─────────────────────────────────────────────
  void _showAreasDialog(int cluster) {
    final color = _clusterColors[cluster];
    final members = List<_LocalityPoint>.from(_clusterMembers(cluster))
      ..sort((a, b) => b.totalDeaths.compareTo(a.totalDeaths));

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _T.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 560,
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _T.border))),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_clusterIcons[cluster], color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${_clusterNames[cluster]} — ${members.length} Areas',
                      style: const TextStyle(color: _T.text, fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('Sorted by total deaths, highest first',
                      style: const TextStyle(color: _T.muted, fontSize: 11)),
                ])),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: _T.muted),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            // List
            Expanded(
              child: members.isEmpty
                  ? const Center(child: Text('No areas in this cluster',
                      style: TextStyle(color: _T.muted, fontSize: 12)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: members.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final p = members[i];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: color.withValues(alpha: 0.2)),
                          ),
                          child: Row(children: [
                            Container(
                              width: 26, height: 26,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              alignment: Alignment.center,
                              child: Text('${i + 1}',
                                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(p.locality,
                                    style: const TextStyle(color: _T.text, fontSize: 13, fontWeight: FontWeight.w600)),
                                Text(p.district, style: const TextStyle(color: _T.muted, fontSize: 11)),
                                const SizedBox(height: 4),
                                Row(children: [
                                  const Icon(Icons.coronavirus_rounded, size: 12, color: _T.muted),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text('Top cause: ${p.topDisease}',
                                        style: const TextStyle(color: _T.sub, fontSize: 11),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ]),
                              ]),
                            ),
                            const SizedBox(width: 8),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text('${p.totalDeaths} deaths',
                                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                              Text('Water: ${(p.waterScore * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(color: _T.muted, fontSize: 10)),
                            ]),
                          ]),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      appBar: AppBar(
        backgroundColor: _T.surface,
        foregroundColor: _T.text,
        elevation: 0,
        title: Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(
            color: _T.purple, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: _T.purple.withValues(alpha: 0.5), blurRadius: 8)])),
          const SizedBox(width: 10),
          const Text('K-Means Clustering', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        ]),
        actions: [
          if (!_loading && !_clustering)
            TextButton.icon(
              onPressed: _fetchAndCluster,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Re-cluster', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: _T.purple),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading || _clustering
          ? _loader()
          : _error != null
              ? _errView()
              : Column(children: [
                  _filterBar(),
                  Expanded(child: RefreshIndicator(
                    color: _T.accent,
                    onRefresh: _fetchAndCluster,
                    child: _body(),
                  )),
                ]),
    );
  }

  Widget _loader() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const CircularProgressIndicator(color: _T.purple, strokeWidth: 2),
    const SizedBox(height: 16),
    Text(_clustering ? 'Running K-Means algorithm…' : 'Loading data from database…',
        style: const TextStyle(color: _T.muted, fontSize: 13)),
    if (_clustering) ...[
      const SizedBox(height: 8),
      const Text('Grouping localities into 3 risk clusters',
          style: TextStyle(color: _T.muted, fontSize: 11)),
    ],
  ]));

  Widget _errView() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.error_outline_rounded, color: _T.red, size: 48),
    const SizedBox(height: 12),
    const Text('Failed to cluster', style: TextStyle(color: _T.text, fontSize: 16, fontWeight: FontWeight.bold)),
    const SizedBox(height: 6),
    Text(_error ?? '', style: const TextStyle(color: _T.muted, fontSize: 11)),
    const SizedBox(height: 20),
    ElevatedButton.icon(
      onPressed: _fetchAndCluster,
      icon: const Icon(Icons.refresh),
      label: const Text('Retry'),
      style: ElevatedButton.styleFrom(backgroundColor: _T.purple, foregroundColor: Colors.white),
    ),
  ]));

  // ─────────────────────────────────────────────
  //  FILTER BAR
  // ─────────────────────────────────────────────
  Widget _filterBar() => Container(
    decoration: BoxDecoration(color: _T.surface, border: Border(bottom: BorderSide(color: _T.border))),
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.tune_rounded, size: 13, color: _T.muted),
        const SizedBox(width: 6),
        const Text('FILTER CLUSTERS', style: TextStyle(color: _T.muted, fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w600)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: _T.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _T.purple.withValues(alpha: 0.3)),
          ),
          child: Text('K-Means · 3 Clusters · $_iterations iterations',
              style: const TextStyle(color: _T.purple, fontSize: 10, fontWeight: FontWeight.w600)),
        ),
      ]),
      const SizedBox(height: 10),
      LayoutBuilder(builder: (ctx, box) {
        final wide = box.maxWidth > 500;
        final fields = [
          _drop('District', _districts, _selDistrict, (v) { setState(() => _selDistrict = v); _applyFilters(); }),
          _drop('Cluster', _clusterNames, _selCluster, (v) { setState(() => _selCluster = v); _applyFilters(); }),
          SizedBox(height: 44, child: OutlinedButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.close_rounded, size: 14),
            label: const Text('Clear', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(foregroundColor: _T.muted,
                side: BorderSide(color: _T.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          )),
        ];
        return wide
            ? Row(children: fields.map((f) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 10), child: f))).toList())
            : Wrap(spacing: 10, runSpacing: 10, children: fields.map((f) => SizedBox(width: (box.maxWidth - 10) / 2, child: f)).toList());
      }),
      if (_selDistrict != null || _selCluster != null) Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('Showing ${_filtered.length} localities', style: const TextStyle(color: _T.purple, fontSize: 11)),
      ),
    ]),
  );

  Widget _drop(String hint, List<String> opts, String? val, void Function(String?) onChange) =>
      DropdownButtonFormField<String>(
        initialValue: val, dropdownColor: _T.surface,
        style: const TextStyle(color: _T.text, fontSize: 12),
        decoration: InputDecoration(
          hintText: 'All $hint', hintStyle: const TextStyle(color: _T.muted, fontSize: 12),
          filled: true, fillColor: _T.bg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _T.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _T.purple)),
        ),
        isExpanded: true,
        items: [
          DropdownMenuItem(value: null, child: Text('All $hint', style: const TextStyle(color: _T.muted))),
          ...opts.map((o) => DropdownMenuItem(value: o, child: Text(o))),
        ],
        onChanged: onChange,
      );

  // ─────────────────────────────────────────────
  //  BODY
  // ─────────────────────────────────────────────
  Widget _body() => SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ML explanation banner
      _mlBanner(),
      const SizedBox(height: 20),

      // Summary stats
      _summaryRow(),
      const SizedBox(height: 24),

      // Cluster cards
      _sec('Cluster Results — 3 Risk Groups (tap area count for full list)'),
      _clusterCards(),
      const SizedBox(height: 24),

      // Scatter plot
      _sec('Scatter Plot — Mortality Rate vs Healthcare Access'),
      _scatterPlot(),
      const SizedBox(height: 24),

      // Stats table
      _sec('Cluster Statistics Table'),
      _statsTable(),
      const SizedBox(height: 24),

      // Feature comparison
      _sec('Feature Comparison Across Clusters'),
      _featureComparison(),
      const SizedBox(height: 24),

      // Top localities per cluster
      _sec('Top Localities per Cluster'),
      _topLocalitiesPerCluster(),
      const SizedBox(height: 24),

      // Water score chart
      _sec('Water Source Quality by Cluster'),
      _waterByCluster(),
      const SizedBox(height: 40),
    ]),
  );

  // ─────────────────────────────────────────────
  //  ML BANNER
  // ─────────────────────────────────────────────
  Widget _mlBanner() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [_T.purple.withValues(alpha: 0.12), _T.accent.withValues(alpha: 0.06)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _T.purple.withValues(alpha: 0.3)),
    ),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _T.purple.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.psychology_rounded, color: _T.purple, size: 22)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('K-Means Machine Learning', style: TextStyle(color: _T.text, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          'Localities are automatically grouped into 3 clusters using K-Means (k=3). '
          'Features used: mortality rate, average age, water quality, comorbidity rate. '
          'Algorithm converged in $_iterations iterations.',
          style: const TextStyle(color: _T.muted, fontSize: 11, height: 1.5)),
      ])),
    ]),
  );

  // ─────────────────────────────────────────────
  //  SUMMARY ROW
  // ─────────────────────────────────────────────
  Widget _summaryRow() {
    final stats = [
      ('Total Localities', '${_filtered.length}', _T.accent, Icons.location_on_rounded),
      ('High Risk', '${_clusterMembers(2).length}', _T.red, Icons.dangerous_rounded),
      ('Medium Risk', '${_clusterMembers(1).length}', _T.yellow, Icons.warning_amber_rounded),
      ('Low Risk', '${_clusterMembers(0).length}', _T.green, Icons.check_circle_rounded),
      ('Iterations', '$_iterations', _T.purple, Icons.loop_rounded),
    ];
    return LayoutBuilder(builder: (ctx, box) {
      final cols = box.maxWidth > 800 ? 5 : box.maxWidth > 500 ? 3 : 2;
      return GridView.count(
        crossAxisCount: cols, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.2,
        children: stats.map((s) => Container(
          decoration: BoxDecoration(color: _T.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _T.border)),
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: s.$3.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(s.$4, color: s.$3, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(s.$1, style: const TextStyle(color: _T.muted, fontSize: 10)),
              const SizedBox(height: 2),
              Text(s.$2, style: TextStyle(color: s.$3, fontSize: 18, fontWeight: FontWeight.bold)),
            ])),
          ]),
        )).toList(),
      );
    });
  }

  // ─────────────────────────────────────────────
  //  CLUSTER CARDS
  // ─────────────────────────────────────────────
  Widget _clusterCards() => LayoutBuilder(builder: (ctx, box) {
    final wide = box.maxWidth > 700;
    final cards = List.generate(3, (c) => _clusterCard(c));
    return wide
        ? Row(crossAxisAlignment: CrossAxisAlignment.start,
            children: cards.map((card) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 14), child: card))).toList())
        : Column(children: cards.map((card) => Padding(padding: const EdgeInsets.only(bottom: 14), child: card)).toList());
  });

  Widget _clusterCard(int c) {
    final members = _clusterMembers(c);
    final color   = _clusterColors[c];
    final name    = _clusterNames[c];
    final avgD    = _avgDeaths(c);
    final avgW    = (_avgWater(c) * 100).toStringAsFixed(0);
    final avgCo   = (_avgComorbid(c) * 100).toStringAsFixed(0);
    final topDisease = _clusterTopDisease(c);

    final descriptions = [
      'Low mortality · Good water access · Few comorbidities · Safer areas',
      'Moderate mortality · Average water quality · Some prior conditions',
      'High mortality · Poor water access · High comorbidity rate · Priority areas',
    ];

    return Container(
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(_clusterIcons[c], color: color, size: 22)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Cluster ${c + 1}', style: const TextStyle(color: _T.muted, fontSize: 11)),
            Text(name, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
          ])),
          // Tappable "N areas" badge — opens the full list popup
          GestureDetector(
            onTap: () => _showAreasDialog(c),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withValues(alpha: 0.3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${members.length} areas', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Icon(Icons.open_in_new_rounded, size: 12, color: color),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Text(descriptions[c], style: const TextStyle(color: _T.muted, fontSize: 11, height: 1.5)),
        const SizedBox(height: 10),
        // Top disease for this risk group
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(Icons.coronavirus_rounded, size: 14, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text('Leading cause: $topDisease',
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis)),
          ]),
        ),
        const SizedBox(height: 14),
        Divider(color: _T.border),
        const SizedBox(height: 10),
        // Metrics
        _metric('Avg Deaths', avgD.toStringAsFixed(1), color),
        const SizedBox(height: 6),
        _metric('Water Quality', '$avgW%', c == 0 ? _T.green : c == 1 ? _T.yellow : _T.red),
        const SizedBox(height: 6),
        _metric('Comorbidity Rate', '$avgCo%', c == 2 ? _T.red : c == 1 ? _T.yellow : _T.green),
        const SizedBox(height: 12),
        // Progress bar showing proportion
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _filtered.isEmpty ? 0 : members.length / _filtered.length,
            backgroundColor: _T.border,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Text('${_filtered.isEmpty ? 0 : (members.length / _filtered.length * 100).toStringAsFixed(1)}% of localities',
            style: const TextStyle(color: _T.muted, fontSize: 10)),
      ]),
    );
  }

  Widget _metric(String label, String value, Color color) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: _T.muted, fontSize: 11)),
      Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    ],
  );

  // ─────────────────────────────────────────────
  //  SCATTER PLOT
  // ─────────────────────────────────────────────
  Widget _scatterPlot() {
    // Build series per cluster
    final series = List.generate(3, (c) {
      final members = _filtered.where((p) => p.cluster == c).toList();
      final data = members.map((p) => _ScatterPoint(
        p.mortalityRate * 100,       // X: mortality rate %
        (1 - p.waterScore) * 100,    // Y: risk from poor water (inverted)
        p.locality,
      )).toList();

      return ScatterSeries<_ScatterPoint, double>(
        dataSource: data,
        xValueMapper: (d, _) => d.x,
        yValueMapper: (d, _) => d.y,
        name: _clusterNames[c],
        color: _clusterColors[c],
        markerSettings: MarkerSettings(
          isVisible: true,
          height: 10, width: 10,
          shape: DataMarkerType.circle,
          color: _clusterColors[c],
          borderColor: _T.surface,
          borderWidth: 1.5,
        ),
        opacity: 0.85,
      );
    });

    return _card(
      'Scatter Plot — Cluster Visualization',
      'ML Output',
      _T.purple,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Axis explanation
        Row(children: [
          _axisLabel('X-axis', 'Mortality Rate (higher = more deaths)', _T.red),
          const SizedBox(width: 20),
          _axisLabel('Y-axis', 'Water Risk (higher = poorer water access)', _T.orange),
        ]),
        const SizedBox(height: 4),
        Text('Each dot = one locality. Color = assigned cluster. Dots in top-right = highest risk.',
            style: const TextStyle(color: _T.muted, fontSize: 11)),
        const SizedBox(height: 14),
        SfCartesianChart(
          backgroundColor: Colors.transparent,
          plotAreaBackgroundColor: Colors.transparent,
          margin: EdgeInsets.zero,
          legend: Legend(isVisible: true,
              textStyle: const TextStyle(color: _T.sub, fontSize: 11),
              position: LegendPosition.bottom),
          primaryXAxis: NumericAxis(
            title: AxisTitle(text: 'Mortality Rate (normalized %)',
                textStyle: const TextStyle(color: _T.muted, fontSize: 10)),
            labelStyle: const TextStyle(color: _T.muted, fontSize: 9),
            axisLine: AxisLine(color: _T.border),
            majorGridLines: MajorGridLines(color: _T.border.withValues(alpha: 0.4), width: 0.5, dashArray: [4, 4]),
            majorTickLines: const MajorTickLines(size: 0),
          ),
          primaryYAxis: NumericAxis(
            title: AxisTitle(text: 'Water Risk Score (%)',
                textStyle: const TextStyle(color: _T.muted, fontSize: 10)),
            labelStyle: const TextStyle(color: _T.muted, fontSize: 9),
            axisLine: AxisLine(color: _T.border),
            majorGridLines: MajorGridLines(color: _T.border.withValues(alpha: 0.4), width: 0.5, dashArray: [4, 4]),
            majorTickLines: const MajorTickLines(size: 0),
          ),
          tooltipBehavior: TooltipBehavior(
            enable: true,
            color: _T.surface,
            textStyle: const TextStyle(color: _T.text, fontSize: 11),
            borderColor: _T.border, borderWidth: 1,
          ),
          series: series,
        ),
      ]),
      subtitle: 'Mortality rate vs water risk — each point is a locality',
    );
  }

  Widget _axisLabel(String axis, String desc, Color color) => Row(children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 5),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(axis, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      Text(desc, style: const TextStyle(color: _T.muted, fontSize: 10)),
    ]),
  ]);

  // ─────────────────────────────────────────────
  //  STATS TABLE
  // ─────────────────────────────────────────────
  Widget _statsTable() => _card(
    'Cluster Statistics', 'Summary', _T.accent,
    Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: _T.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _T.border)),
        child: Row(children: const [
          Expanded(flex: 2, child: Text('Cluster', style: TextStyle(color: _T.muted, fontSize: 11, fontWeight: FontWeight.w600))),
          Expanded(child: Text('Areas', textAlign: TextAlign.center, style: TextStyle(color: _T.muted, fontSize: 11, fontWeight: FontWeight.w600))),
          Expanded(child: Text('Avg Deaths', textAlign: TextAlign.center, style: TextStyle(color: _T.muted, fontSize: 11, fontWeight: FontWeight.w600))),
          Expanded(child: Text('Water %', textAlign: TextAlign.center, style: TextStyle(color: _T.muted, fontSize: 11, fontWeight: FontWeight.w600))),
          Expanded(child: Text('Comorbid %', textAlign: TextAlign.center, style: TextStyle(color: _T.muted, fontSize: 11, fontWeight: FontWeight.w600))),
        ]),
      ),
      const SizedBox(height: 8),
      ...List.generate(3, (c) {
        final color = _clusterColors[c];
        final members = _clusterMembers(c);
        return GestureDetector(
          onTap: () => _showAreasDialog(c),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              Expanded(flex: 2, child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(_clusterNames[c], style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold))),
              ])),
              Expanded(child: Text('${members.length}', textAlign: TextAlign.center,
                  style: const TextStyle(color: _T.text, fontSize: 13, fontWeight: FontWeight.bold))),
              Expanded(child: Text(_avgDeaths(c).toStringAsFixed(1), textAlign: TextAlign.center,
                  style: TextStyle(color: color, fontSize: 12))),
              Expanded(child: Text('${(_avgWater(c) * 100).toStringAsFixed(0)}%', textAlign: TextAlign.center,
                  style: TextStyle(color: c == 0 ? _T.green : c == 1 ? _T.yellow : _T.red, fontSize: 12))),
              Expanded(child: Text('${(_avgComorbid(c) * 100).toStringAsFixed(0)}%', textAlign: TextAlign.center,
                  style: TextStyle(color: c == 2 ? _T.red : _T.muted, fontSize: 12))),
            ]),
          ),
        );
      }),
    ]),
    subtitle: 'Average feature values per cluster · tap a row to see all its areas',
  );

  // ─────────────────────────────────────────────
  //  FEATURE COMPARISON (Bar chart)
  // ─────────────────────────────────────────────
  Widget _featureComparison() {
    final features = ['Avg Deaths (norm)', 'Avg Age (norm)', 'Water Quality', 'Comorbidity Rate'];
    final series = List.generate(3, (c) {
      final members = _filtered.where((p) => p.cluster == c).toList();
      final List<double> vals;
      if (members.isEmpty) {
        vals = [0, 0, 0, 0];
      } else {
        final avgMort  = members.map((p) => p.mortalityRate).reduce((a, b) => a + b) / members.length;
        final avgAge   = members.map((p) => p.avgAge).reduce((a, b) => a + b) / members.length;
        final avgWater = members.map((p) => p.waterScore).reduce((a, b) => a + b) / members.length;
        final avgCo    = members.map((p) => p.comorbidityRate).reduce((a, b) => a + b) / members.length;
        vals = [avgMort, avgAge, avgWater, avgCo];
      }
      return ColumnSeries<_CD, String>(
        dataSource: features.asMap().entries.map((e) => _CD(e.value, vals[e.key])).toList(),
        xValueMapper: (d, _) => d.label,
        yValueMapper: (d, _) => d.value,
        name: _clusterNames[c],
        color: _clusterColors[c],
        borderRadius: BorderRadius.circular(4),
        width: 0.25,
      );
    });

    return _card('Feature Values per Cluster', 'Comparison', _T.purple,
      SfCartesianChart(
        backgroundColor: Colors.transparent,
        plotAreaBackgroundColor: Colors.transparent,
        margin: EdgeInsets.zero,
        legend: Legend(isVisible: true,
            textStyle: const TextStyle(color: _T.sub, fontSize: 11),
            position: LegendPosition.bottom),
        primaryXAxis: CategoryAxis(
          labelStyle: const TextStyle(color: _T.muted, fontSize: 9),
          axisLine: AxisLine(color: _T.border),
          majorGridLines: const MajorGridLines(width: 0),
          majorTickLines: const MajorTickLines(size: 0),
          labelRotation: -10,
        ),
        primaryYAxis: NumericAxis(
          minimum: 0, maximum: 1,
          labelStyle: const TextStyle(color: _T.muted, fontSize: 10),
          axisLine: AxisLine(color: _T.border),
          majorGridLines: MajorGridLines(color: _T.border.withValues(alpha: 0.4), width: 0.5, dashArray: [4, 4]),
          majorTickLines: const MajorTickLines(size: 0),
          title: AxisTitle(text: 'Normalized value (0–1)',
              textStyle: const TextStyle(color: _T.muted, fontSize: 10)),
        ),
        tooltipBehavior: TooltipBehavior(enable: true,
            color: _T.surface, textStyle: const TextStyle(color: _T.text, fontSize: 11),
            borderColor: _T.border, borderWidth: 1),
        series: series,
      ),
      subtitle: 'How each cluster scores on each feature (0=low, 1=high)',
    );
  }

  // ─────────────────────────────────────────────
  //  TOP LOCALITIES PER CLUSTER
  // ─────────────────────────────────────────────
  Widget _topLocalitiesPerCluster() => LayoutBuilder(builder: (ctx, box) {
    final wide = box.maxWidth > 700;
    final clusterWidgets = List.generate(3, (c) {
      final members = (_clusterMembers(c)..sort((a, b) => b.totalDeaths.compareTo(a.totalDeaths))).take(5).toList();
      final color = _clusterColors[c];
      return _card('${_clusterNames[c]} — Top Areas', 'Cluster ${c + 1}', color,
        members.isEmpty
            ? const Center(child: Text('No localities', style: TextStyle(color: _T.muted, fontSize: 12)))
            : Column(children: members.asMap().entries.map((e) {
                final p = e.value;
                final rank = e.key + 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6)),
                      alignment: Alignment.center,
                      child: Text('$rank', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.locality, style: const TextStyle(color: _T.text, fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(p.district, style: const TextStyle(color: _T.muted, fontSize: 10)),
                      Text('Top cause: ${p.topDisease}',
                          style: const TextStyle(color: _T.muted, fontSize: 10),
                          overflow: TextOverflow.ellipsis),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${p.totalDeaths} deaths', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('Water: ${(p.waterScore * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(color: _T.muted, fontSize: 10)),
                    ]),
                  ]),
                );
              }).toList()),
      );
    });

    return wide
        ? Row(crossAxisAlignment: CrossAxisAlignment.start,
            children: clusterWidgets.map((w) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 14), child: w))).toList())
        : Column(children: clusterWidgets.map((w) => Padding(padding: const EdgeInsets.only(bottom: 14), child: w)).toList());
  });

  // ─────────────────────────────────────────────
  //  WATER BY CLUSTER
  // ─────────────────────────────────────────────
  Widget _waterByCluster() {
    final data = List.generate(3, (c) => _CD(_clusterNames[c], _avgWater(c) * 100));
    return _card('Avg Water Quality Score by Cluster', 'Lifestyle Factor', _T.green,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
          'Water quality score: Filtered=100% · Tap=80% · Well=50% · River=20%\n'
          'Higher % = safer water access = lower mortality risk.',
          style: TextStyle(color: _T.muted, fontSize: 11, height: 1.5)),
        const SizedBox(height: 14),
        SfCartesianChart(
          backgroundColor: Colors.transparent,
          plotAreaBackgroundColor: Colors.transparent,
          margin: EdgeInsets.zero,
          primaryXAxis: CategoryAxis(
            labelStyle: const TextStyle(color: _T.muted, fontSize: 11),
            axisLine: AxisLine(color: _T.border),
            majorGridLines: const MajorGridLines(width: 0),
            majorTickLines: const MajorTickLines(size: 0),
          ),
          primaryYAxis: NumericAxis(
            minimum: 0, maximum: 100,
            labelStyle: const TextStyle(color: _T.muted, fontSize: 10),
            axisLine: AxisLine(color: _T.border),
            majorGridLines: MajorGridLines(color: _T.border.withValues(alpha: 0.4), width: 0.5, dashArray: [4, 4]),
            majorTickLines: const MajorTickLines(size: 0),
            title: AxisTitle(text: 'Water Quality Score (%)',
                textStyle: const TextStyle(color: _T.muted, fontSize: 10)),
          ),
          tooltipBehavior: TooltipBehavior(enable: true,
              color: _T.surface, textStyle: const TextStyle(color: _T.text, fontSize: 11)),
          series: [
            ColumnSeries<_CD, String>(
              dataSource: data,
              xValueMapper: (d, _) => d.label,
              yValueMapper: (d, _) => d.value,
              pointColorMapper: (d, i) => _clusterColors[i],
              borderRadius: BorderRadius.circular(8),
              width: 0.45,
              dataLabelSettings: const DataLabelSettings(
                isVisible: true,
                textStyle: TextStyle(color: _T.sub, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ]),
      subtitle: 'Shows correlation between water quality and cluster risk level',
    );
  }

  // ─────────────────────────────────────────────
  //  LAYOUT HELPERS
  // ─────────────────────────────────────────────
  Widget _sec(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Container(width: 3, height: 16,
          decoration: BoxDecoration(color: _T.purple, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Expanded(child: Text(t.toUpperCase(), style: const TextStyle(
          color: _T.muted, fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w600))),
    ]),
  );

  Widget _card(String title, String badge, Color badgeColor, Widget child, {String? subtitle}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: _T.surface, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _T.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _T.border))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: _T.text, fontWeight: FontWeight.bold, fontSize: 14)),
                if (subtitle != null) ...[const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: _T.muted, fontSize: 11))],
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.3))),
                child: Text(badge, style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ]),
      );
}