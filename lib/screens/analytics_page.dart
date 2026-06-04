// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

// ═══════════════════════════════════════════════════════
//  MODELS
// ═══════════════════════════════════════════════════════
class _CD { final String label; final double value; _CD(this.label, this.value); }
class _GD { final String cause; final double male; final double female; _GD(this.cause, this.male, this.female); }
class _TD { final String year; final double count; _TD(this.year, this.count); }

// ═══════════════════════════════════════════════════════
//  THEME
// ═══════════════════════════════════════════════════════
class _T {
  static const bg      = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  // ignore: unused_field
  static const card    = Color(0xFF1E293B);
  static const border  = Color(0xFF334155);
  static const muted   = Color(0xFF94A3B8);
  static const text    = Color(0xFFF1F5F9);
  static const sub     = Color(0xFFCBD5E1);
  static const accent  = Color(0xFF38BDF8);
  static const green   = Color(0xFF34D399);
  static const purple  = Color(0xFF818CF8);
  static const orange  = Color(0xFFFB923C);
  static const red     = Color(0xFFF87171);
  static const pink    = Color(0xFFF472B6);
  static const palette = [
    Color(0xFF38BDF8), Color(0xFF818CF8), Color(0xFF34D399),
    Color(0xFFFB923C), Color(0xFFF87171), Color(0xFFA78BFA),
    Color(0xFF22D3EE), Color(0xFFFBBF24), Color(0xFF4ADE80),
    Color(0xFFF472B6), Color(0xFF6EE7B7), Color(0xFFFCA5A5),
  ];
}

// ═══════════════════════════════════════════════════════
//  ANALYTICS PAGE
// ═══════════════════════════════════════════════════════
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final _sb = Supabase.instance.client;
  static const _table = 'mortality_records_clean';

  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _filtered = [];

  // Global filters
  String? _selDistrict;
  final _localityCtrl = TextEditingController();
  String? _selYear;

  // Disease-by-city trend filters (independent)
  String? _trendDisease;
  final _trendLocalityCtrl = TextEditingController();

  List<String> _districts = [];
  List<String> _years = [];
  List<String> _allDiseases = [];   // ALL diseases from DB
  List<String> _topDiseases = [];   // top 6 for global trend

  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _fetchData(); }

  @override
  void dispose() {
    _localityCtrl.dispose();
    _trendLocalityCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────
  //  FETCH  (real Supabase data, no dummy)
  // ─────────────────────────────────────────────────
  Future<void> _fetchData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _sb
          .from(_table)
          .select('age,gender,district,specific_locality,cause_of_death,'
              'prior_medical_conditions,place_of_death,water_source,'
              'income_bracket,date_of_death,is_valid,quality_score')
          .eq('is_valid', true)
          .gte('quality_score', 60)
          .limit(10000);

      _allData = List<Map<String, dynamic>>.from(res as List);

      _districts = _allData
          .map((r) => r['district']?.toString() ?? '')
          .where((d) => d.isNotEmpty && d != 'Unknown')
          .toSet().toList()..sort();

      _years = _allData
          .map((r) => (r['date_of_death']?.toString() ?? '').length >= 4
              ? r['date_of_death'].toString().substring(0, 4) : '')
          .where((y) => y.length == 4)
          .toSet().toList()..sort();

      // ALL diseases from DB
      _allDiseases = _allData
          .map((r) => r['cause_of_death']?.toString() ?? '')
          .where((d) => d.isNotEmpty && d != 'Unknown' && d != 'Unspecified')
          .toSet().toList()..sort();

      _applyFilters();
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ─────────────────────────────────────────────────
  //  FILTER  (applied to all charts except disease-by-city)
  // ─────────────────────────────────────────────────
  void _applyFilters() {
    final loc = _localityCtrl.text.trim().toLowerCase();
    _filtered = _allData.where((r) {
      if (_selDistrict != null && _selDistrict!.isNotEmpty &&
          r['district'] != _selDistrict) {
        return false;
      }
      if (loc.isNotEmpty &&
          !(r['specific_locality']?.toString().toLowerCase() ?? '').contains(loc)) {
        return false;
      }
      if (_selYear != null && _selYear!.isNotEmpty &&
          !(r['date_of_death']?.toString() ?? '').startsWith(_selYear!)) {
        return false;
      }
      return true;
    }).toList();

    final counts = _countBy(_filtered, 'cause_of_death');
    _topDiseases = (counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(6).map((e) => e.key).toList();

    if (_trendDisease == null || !_allDiseases.contains(_trendDisease)) {
      _trendDisease = _allDiseases.isNotEmpty ? _allDiseases.first : null;
    }
    setState(() { _loading = false; });
  }

  void _clearFilters() {
    _selDistrict = null;
    _localityCtrl.clear();
    _selYear = null;
    _applyFilters();
  }

  // ─────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────
  Map<String, int> _countBy(List<Map<String, dynamic>> data, String key) {
    final m = <String, int>{};
    for (final r in data) {
      final v = r[key]?.toString() ?? 'Unknown';
      if (v.isEmpty || v == 'Unknown' || v == 'Unspecified') continue;
      m[v] = (m[v] ?? 0) + 1;
    }
    return m;
  }

  String get _avgAge {
    final ages = _filtered.map((r) => r['age']).whereType<int>()
        .where((a) => a > 0 && a < 120).toList();
    if (ages.isEmpty) return '—';
    return (ages.reduce((a, b) => a + b) / ages.length).toStringAsFixed(1);
  }

  String get _topCause {
    final c = _countBy(_filtered, 'cause_of_death');
    if (c.isEmpty) return '—';
    return (c.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
  }

  String get _filterLabel {
    final p = <String>[];
    if (_selDistrict != null) p.add(_selDistrict!);
    if (_localityCtrl.text.trim().isNotEmpty) p.add(_localityCtrl.text.trim());
    if (_selYear != null) p.add(_selYear!);
    return p.isEmpty ? 'All Areas · All Years' : p.join(' · ');
  }

  // ─────────────────────────────────────────────────
  //  CHART DATA
  // ─────────────────────────────────────────────────
  List<_CD> get _causesData {
    final s = (_countBy(_filtered, 'cause_of_death').entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(10);
    return s.map((e) => _CD(e.key, e.value.toDouble())).toList();
  }

  List<_CD> get _ageData {
    final bins = {'0–17': 0, '18–34': 0, '35–49': 0, '50–64': 0, '65+': 0};
    for (final r in _filtered) {
      final a = r['age']; if (a == null || a <= 0) continue;
      if (a < 18) {
        bins['0–17'] = bins['0–17']! + 1;
      } else if (a < 35) bins['18–34'] = bins['18–34']! + 1;
      else if (a < 50) bins['35–49'] = bins['35–49']! + 1;
      else if (a < 65) bins['50–64'] = bins['50–64']! + 1;
      else bins['65+'] = bins['65+']! + 1;
    }
    return bins.entries.map((e) => _CD(e.key, e.value.toDouble())).toList();
  }

  List<_CD> get _genderData {
    final c = _countBy(_filtered, 'gender');
    return c.entries.map((e) => _CD(e.key, e.value.toDouble())).toList();
  }

  List<_GD> get _genderByCause {
    return _causesData.take(6).map((cd) {
      final m = _filtered.where((r) =>
          r['cause_of_death'] == cd.label && r['gender'] == 'Male').length.toDouble();
      final f = _filtered.where((r) =>
          r['cause_of_death'] == cd.label && r['gender'] == 'Female').length.toDouble();
      final s = cd.label.length > 12 ? '${cd.label.substring(0, 10)}…' : cd.label;
      return _GD(s, m, f);
    }).toList();
  }

  List<_CD> get _comorbidData {
    final counts = <String, int>{};
    for (final r in _filtered) {
      final c = r['prior_medical_conditions'];
      if (c is List) {
        for (final x in c) {
          final s = x?.toString() ?? '';
          if (s.isNotEmpty && s.toLowerCase() != 'none') counts[s] = (counts[s] ?? 0) + 1;
        }
      }
    }
    final s = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return s.take(8).map((e) => _CD(e.key, e.value.toDouble())).toList();
  }

  List<_CD> get _placeData {
    final c = _countBy(_filtered, 'place_of_death');
    return c.entries.map((e) => _CD(e.key, e.value.toDouble())).toList();
  }

  List<_CD> get _waterData {
    final c = _countBy(_filtered, 'water_source');
    return c.entries.map((e) => _CD(e.key, e.value.toDouble())).toList();
  }

  List<_CD> get _ageDiseaseData {
    return _causesData.take(8).map((cd) {
      final ages = _filtered
          .where((r) => r['cause_of_death'] == cd.label && r['age'] != null && r['age'] > 0 && r['age'] < 120)
          .map((r) => r['age'] as int).toList();
      final avg = ages.isEmpty ? 0.0 : ages.reduce((a, b) => a + b) / ages.length;
      final s = cd.label.length > 12 ? '${cd.label.substring(0, 10)}…' : cd.label;
      return _CD(s, double.parse(avg.toStringAsFixed(1)));
    }).toList();
  }

  // Global trend (top diseases, filtered data, all years)
  List<_TD> _trendFor(String disease) {
    return _years.map((y) {
      final count = _filtered.where((r) =>
          r['cause_of_death'] == disease &&
          (r['date_of_death']?.toString() ?? '').startsWith(y)).length;
      return _TD(y, count.toDouble());
    }).toList();
  }

  // Disease-by-city trend (independent: uses trendLocality + trendDisease across ALL years)
  List<_TD> get _cityDiseaseTrend {
    if (_trendDisease == null) return [];
    final loc = _trendLocalityCtrl.text.trim().toLowerCase();
    return _years.map((y) {
      final count = _allData.where((r) {
        if (r['cause_of_death'] != _trendDisease) return false;
        if (!(r['date_of_death']?.toString() ?? '').startsWith(y)) return false;
        if (loc.isNotEmpty &&
            !(r['specific_locality']?.toString().toLowerCase() ?? '').contains(loc)) {
          return false;
        }
        return true;
      }).length;
      return _TD(y, count.toDouble());
    }).toList();
  }

  String _cityTrendRatio(List<_TD> td) {
    if (td.length < 2) return '';
    final first = td.first.count; final last = td.last.count;
    if (first == 0 && last == 0) return 'No data';
    if (first == 0) return '↑ New cases';
    final pct = ((last - first) / first * 100);
    final dir = last > first ? '↑' : last < first ? '↓' : '→';
    return '$dir ${pct.abs().toStringAsFixed(1)}%  (${td.first.year}→${td.last.year})';
  }

  // ─────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────
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
            color: _T.accent, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: _T.accent.withOpacity(0.5), blurRadius: 8)])),
          const SizedBox(width: 10),
          const Text('Descriptive Analytics',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _fetchData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? _buildLoader()
          : _error != null
              ? _buildError()
              : Column(children: [
                  _buildFilterBar(),
                  Expanded(child: RefreshIndicator(
                    color: _T.accent,
                    onRefresh: _fetchData,
                    child: _buildBody(),
                  )),
                ]),
    );
  }

  Widget _buildLoader() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const CircularProgressIndicator(color: _T.accent, strokeWidth: 2),
      const SizedBox(height: 16),
      Text('Loading data from database…', style: TextStyle(color: _T.muted, fontSize: 13)),
    ],
  ));

  Widget _buildError() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.error_outline_rounded, color: _T.red, size: 48),
      const SizedBox(height: 12),
      Text('Failed to load data', style: TextStyle(color: _T.text, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text(_error ?? '', style: TextStyle(color: _T.muted, fontSize: 11), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: _fetchData,
        icon: const Icon(Icons.refresh),
        label: const Text('Retry'),
        style: ElevatedButton.styleFrom(backgroundColor: _T.accent, foregroundColor: _T.bg),
      ),
    ],
  ));

  // ─────────────────────────────────────────────────
  //  FILTER BAR
  // ─────────────────────────────────────────────────
  Widget _buildFilterBar() {
    return Container(
      decoration: BoxDecoration(
        color: _T.surface,
        border: Border(bottom: BorderSide(color: _T.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.tune_rounded, size: 14, color: _T.muted),
          const SizedBox(width: 6),
          Text('FILTER ALL CHARTS', style: TextStyle(
              color: _T.muted, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (ctx, box) {
          final wide = box.maxWidth > 600;
          final fields = [
            _filterDrop('District', _districts, _selDistrict, (v) {
              setState(() => _selDistrict = v);
              _applyFilters();
            }),
            _filterInput('City / Village…', _localityCtrl, () => _applyFilters()),
            _filterDrop('Year', _years, _selYear, (v) {
              setState(() => _selYear = v);
              _applyFilters();
            }),
            _clearBtn(),
          ];
          return wide
              ? Row(children: fields.map((f) => Expanded(child: Padding(
                    padding: const EdgeInsets.only(right: 10), child: f))).toList())
              : Wrap(spacing: 10, runSpacing: 10,
                  children: fields.map((f) => SizedBox(width: (box.maxWidth - 10) / 2, child: f)).toList());
        }),
        if (_selDistrict != null || _localityCtrl.text.isNotEmpty || _selYear != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  // ignore: duplicate_ignore
                  // ignore: deprecated_member_use
                  color: _T.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _T.accent.withOpacity(0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.location_on_rounded, size: 11, color: _T.accent),
                  const SizedBox(width: 5),
                  Text(_filterLabel, style: TextStyle(color: _T.accent, fontSize: 11)),
                ]),
              ),
              const SizedBox(width: 8),
              Text('${_filtered.length} records', style: TextStyle(color: _T.muted, fontSize: 11)),
            ]),
          ),
      ]),
    );
  }

  Widget _filterDrop(String hint, List<String> options, String? val, void Function(String?) onChange) {
    return DropdownButtonFormField<String>(
      initialValue: val,
      dropdownColor: _T.surface,
      style: const TextStyle(color: _T.text, fontSize: 12),
      decoration: _deco(hint),
      isExpanded: true,
      items: [
        DropdownMenuItem(value: null, child: Text('All $hint', style: TextStyle(color: _T.muted))),
        ...options.map((o) => DropdownMenuItem(value: o, child: Text(o))),
      ],
      onChanged: onChange,
    );
  }

  Widget _filterInput(String hint, TextEditingController ctrl, VoidCallback onChange) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(color: _T.text, fontSize: 12),
      decoration: _deco(hint),
      onChanged: (_) => onChange(),
    );
  }

  Widget _clearBtn() => SizedBox(
    height: 44,
    child: OutlinedButton.icon(
      onPressed: _clearFilters,
      icon: const Icon(Icons.close_rounded, size: 14),
      label: const Text('Clear', style: TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: _T.muted,
        side: BorderSide(color: _T.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _T.muted, fontSize: 12),
    filled: true, fillColor: _T.bg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _T.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _T.accent)),
  );

  // ─────────────────────────────────────────────────
  //  BODY
  // ─────────────────────────────────────────────────
  Widget _buildBody() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Summary
        _buildSummary(),
        const SizedBox(height: 24),

        _sec('Top Causes of Death'),
        _responsiveRow([_buildCausesChart(), _buildAgeChart()]),
        const SizedBox(height: 16),

        _sec('Gender Analysis'),
        _responsiveRow([_buildGenderPie(), _buildGenderByCause()]),
        const SizedBox(height: 16),

        _sec('Comorbidities & Place'),
        _responsiveRow([_buildComorbid(), _buildPlace()]),
        const SizedBox(height: 16),

        _sec('Age by Disease'),
        _buildAgeDiseaseChart(),
        const SizedBox(height: 16),

        _sec('Water Source — Lifestyle Factor'),
        _buildWaterChart(),
        const SizedBox(height: 24),

        _sec('Disease Trend by City / Year  ·  Localized Analysis'),
        _buildCityDiseaseTrend(),
        const SizedBox(height: 24),

        _sec('Year-by-Year Global Trend (Top Diseases)'),
        _buildGlobalTrend(),
        const SizedBox(height: 40),
      ]),
    );
  }

  // ─────────────────────────────────────────────────
  //  SUMMARY CARDS
  // ─────────────────────────────────────────────────
  Widget _buildSummary() {
    final male = _filtered.where((r) => r['gender'] == 'Male').length;
    final female = _filtered.where((r) => r['gender'] == 'Female').length;
    final locs = _filtered.map((r) => r['specific_locality']?.toString() ?? '')
        .where((l) => l.isNotEmpty).toSet().length;

    final stats = [
      ('Total Records', '${_filtered.length}', _T.accent, Icons.people_rounded),
      ('Top Cause', _topCause, _T.orange, Icons.coronavirus_rounded),
      ('Avg Age', _avgAge, _T.purple, Icons.cake_rounded),
      ('Male / Female', '$male / $female', _T.green, Icons.wc_rounded),
      ('Localities', '$locs', _T.pink, Icons.location_city_rounded),
    ];

    return LayoutBuilder(builder: (ctx, box) {
      final cols = box.maxWidth > 800 ? 5 : box.maxWidth > 500 ? 3 : 2;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.2,
        children: stats.map((s) => Container(
          decoration: BoxDecoration(
            color: _T.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _T.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: s.$3.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(s.$4, color: s.$3, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(s.$1, style: const TextStyle(color: _T.muted, fontSize: 10)),
                const SizedBox(height: 2),
                Text(s.$2, style: TextStyle(color: s.$3,
                    fontSize: 14, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ],
            )),
          ]),
        )).toList(),
      );
    });
  }

  // ─────────────────────────────────────────────────
  //  LAYOUT HELPERS
  // ─────────────────────────────────────────────────
  Widget _sec(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Container(width: 3, height: 16,
          decoration: BoxDecoration(
              color: _T.accent, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(t.toUpperCase(), style: const TextStyle(
          color: _T.muted, fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _responsiveRow(List<Widget> children) => LayoutBuilder(
    builder: (ctx, box) => box.maxWidth > 700
        ? Row(crossAxisAlignment: CrossAxisAlignment.start,
            children: children.map((c) => Expanded(
              child: Padding(padding: const EdgeInsets.only(right: 14), child: c))).toList())
        : Column(children: children.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 14), child: c)).toList()),
  );

  Widget _card({required String title, required String badge,
      required Color badgeColor, required Widget child, String? subtitle}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _T.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Card header
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _T.border)),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: _T.text,
                    fontWeight: FontWeight.bold, fontSize: 14)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: _T.muted, fontSize: 11)),
                ],
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: badgeColor.withOpacity(0.3)),
                ),
                child: Text(badge, style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ]),
      );

  // Chart axis styles
  CategoryAxis get _catAxis => CategoryAxis(
    labelStyle: const TextStyle(color: _T.muted, fontSize: 10),
    axisLine: AxisLine(color: _T.border),
    majorGridLines: const MajorGridLines(width: 0),
    majorTickLines: const MajorTickLines(size: 0),
  );

  NumericAxis get _numAxis => NumericAxis(
    labelStyle: const TextStyle(color: _T.muted, fontSize: 10),
    axisLine: AxisLine(color: _T.border),
    majorGridLines: MajorGridLines(color: _T.border.withOpacity(0.5), width: 0.5, dashArray: [4,4]),
    majorTickLines: const MajorTickLines(size: 0),
  );

  TooltipBehavior get _tip => TooltipBehavior(
    enable: true,
    color: _T.surface,
    textStyle: const TextStyle(color: _T.text, fontSize: 11),
    borderColor: _T.border,
    borderWidth: 1,
  );

  // ─────────────────────────────────────────────────
  //  1. TOP CAUSES
  // ─────────────────────────────────────────────────
  Widget _buildCausesChart() => _card(
    title: 'Top Causes of Death',
    badge: 'Descriptive',
    badgeColor: _T.orange,
    subtitle: 'Top 10 causes ranked by frequency',
    child: SfCartesianChart(
      backgroundColor: Colors.transparent,
      plotAreaBackgroundColor: Colors.transparent,
      margin: EdgeInsets.zero,
      primaryXAxis: CategoryAxis(
        labelStyle: const TextStyle(color: _T.muted, fontSize: 9),
        axisLine: AxisLine(color: _T.border),
        majorGridLines: const MajorGridLines(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
      ),
      primaryYAxis: _numAxis,
      tooltipBehavior: _tip,
      series: [
        BarSeries<_CD, String>(
          dataSource: _causesData,
          xValueMapper: (d, _) => d.label,
          yValueMapper: (d, _) => d.value,
          pointColorMapper: (d, i) => _T.palette[i % _T.palette.length],
          borderRadius: BorderRadius.circular(4),
          width: 0.6,
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelAlignment: ChartDataLabelAlignment.outer,
            textStyle: TextStyle(color: _T.sub, fontSize: 9),
          ),
        ),
      ],
    ),
  );

  // ─────────────────────────────────────────────────
  //  2. AGE DISTRIBUTION
  // ─────────────────────────────────────────────────
  Widget _buildAgeChart() => _card(
    title: 'Age Distribution',
    badge: 'Distribution',
    badgeColor: _T.purple,
    subtitle: 'Deaths grouped by age range',
    child: SfCartesianChart(
      backgroundColor: Colors.transparent,
      plotAreaBackgroundColor: Colors.transparent,
      margin: EdgeInsets.zero,
      primaryXAxis: _catAxis,
      primaryYAxis: _numAxis,
      tooltipBehavior: _tip,
      series: [
        ColumnSeries<_CD, String>(
          dataSource: _ageData,
          xValueMapper: (d, _) => d.label,
          yValueMapper: (d, _) => d.value,
          pointColorMapper: (d, i) => _T.palette[i % _T.palette.length],
          borderRadius: BorderRadius.circular(5),
          width: 0.6,
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            textStyle: TextStyle(color: _T.sub, fontSize: 10),
          ),
        ),
      ],
    ),
  );

  // ─────────────────────────────────────────────────
  //  3. GENDER PIE
  // ─────────────────────────────────────────────────
  Widget _buildGenderPie() => _card(
    title: 'Gender Distribution',
    badge: 'Overview',
    badgeColor: _T.accent,
    subtitle: 'Overall male vs female split',
    child: SfCircularChart(
      backgroundColor: Colors.transparent,
      legend: Legend(isVisible: true,
          textStyle: const TextStyle(color: _T.sub, fontSize: 11),
          position: LegendPosition.bottom),
      tooltipBehavior: _tip,
      series: [
        DoughnutSeries<_CD, String>(
          dataSource: _genderData,
          xValueMapper: (d, _) => d.label,
          yValueMapper: (d, _) => d.value,
          pointColorMapper: (d, i) => [_T.accent, _T.pink, _T.green][i % 3],
          innerRadius: '55%',
          radius: '80%',
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            textStyle: TextStyle(color: _T.text, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  // ─────────────────────────────────────────────────
  //  4. GENDER BY CAUSE
  // ─────────────────────────────────────────────────
  Widget _buildGenderByCause() => _card(
    title: 'Gender by Disease',
    badge: 'Breakdown',
    badgeColor: _T.green,
    subtitle: 'Male vs Female per top cause',
    child: SfCartesianChart(
      backgroundColor: Colors.transparent,
      plotAreaBackgroundColor: Colors.transparent,
      margin: EdgeInsets.zero,
      primaryXAxis: CategoryAxis(
        labelStyle: const TextStyle(color: _T.muted, fontSize: 8),
        axisLine: AxisLine(color: _T.border),
        majorGridLines: const MajorGridLines(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        labelRotation: -20,
      ),
      primaryYAxis: _numAxis,
      legend: Legend(isVisible: true,
          textStyle: const TextStyle(color: _T.sub, fontSize: 10)),
      tooltipBehavior: _tip,
      series: [
        StackedColumnSeries<_GD, String>(
          dataSource: _genderByCause,
          xValueMapper: (d, _) => d.cause,
          yValueMapper: (d, _) => d.male,
          name: 'Male',
          color: _T.accent,
          borderRadius: BorderRadius.circular(3),
        ),
        StackedColumnSeries<_GD, String>(
          dataSource: _genderByCause,
          xValueMapper: (d, _) => d.cause,
          yValueMapper: (d, _) => d.female,
          name: 'Female',
          color: _T.pink,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    ),
  );

  // ─────────────────────────────────────────────────
  //  5. COMORBIDITY
  // ─────────────────────────────────────────────────
  Widget _buildComorbid() => _card(
    title: 'Comorbidity Analysis',
    badge: 'Comorbidity',
    badgeColor: _T.red,
    subtitle: 'Prior conditions among deceased',
    child: _comorbidData.isEmpty
        ? _empty('No comorbidity data available')
        : SfCircularChart(
            backgroundColor: Colors.transparent,
            legend: Legend(isVisible: true,
                textStyle: const TextStyle(color: _T.sub, fontSize: 10),
                overflowMode: LegendItemOverflowMode.wrap,
                position: LegendPosition.bottom),
            tooltipBehavior: _tip,
            series: [
              PieSeries<_CD, String>(
                dataSource: _comorbidData,
                xValueMapper: (d, _) => d.label,
                yValueMapper: (d, _) => d.value,
                pointColorMapper: (d, i) => _T.palette[i % _T.palette.length],
                explode: true,
                explodeIndex: 0,
                dataLabelSettings: const DataLabelSettings(
                  isVisible: true,
                  textStyle: TextStyle(color: _T.text, fontSize: 9),
                  labelPosition: ChartDataLabelPosition.outside,
                ),
              ),
            ],
          ),
  );

  // ─────────────────────────────────────────────────
  //  6. PLACE OF DEATH
  // ─────────────────────────────────────────────────
  Widget _buildPlace() => _card(
    title: 'Place of Death',
    badge: 'Location',
    badgeColor: _T.purple,
    subtitle: 'Where deaths occurred',
    child: SfCartesianChart(
      backgroundColor: Colors.transparent,
      plotAreaBackgroundColor: Colors.transparent,
      margin: EdgeInsets.zero,
      primaryXAxis: _catAxis,
      primaryYAxis: _numAxis,
      tooltipBehavior: _tip,
      series: [
        ColumnSeries<_CD, String>(
          dataSource: _placeData,
          xValueMapper: (d, _) => d.label,
          yValueMapper: (d, _) => d.value,
          pointColorMapper: (d, i) => _T.palette[i % _T.palette.length],
          borderRadius: BorderRadius.circular(5),
          width: 0.5,
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            textStyle: TextStyle(color: _T.sub, fontSize: 10),
          ),
        ),
      ],
    ),
  );

  // ─────────────────────────────────────────────────
  //  7. AGE BY DISEASE
  // ─────────────────────────────────────────────────
  Widget _buildAgeDiseaseChart() => _card(
    title: 'Average Age at Death by Disease',
    badge: 'Age Analysis',
    badgeColor: _T.accent,
    subtitle: 'Which diseases affect which age groups most',
    child: SfCartesianChart(
      backgroundColor: Colors.transparent,
      plotAreaBackgroundColor: Colors.transparent,
      margin: EdgeInsets.zero,
      primaryXAxis: CategoryAxis(
        labelStyle: const TextStyle(color: _T.muted, fontSize: 9),
        axisLine: AxisLine(color: _T.border),
        majorGridLines: const MajorGridLines(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        labelRotation: -20,
      ),
      primaryYAxis: NumericAxis(
        labelStyle: const TextStyle(color: _T.muted, fontSize: 10),
        axisLine: AxisLine(color: _T.border),
        majorGridLines: MajorGridLines(color: _T.border.withOpacity(0.5), width: 0.5, dashArray: [4,4]),
        majorTickLines: const MajorTickLines(size: 0),
        minimum: 0, maximum: 90,
        title: AxisTitle(text: 'Average Age (years)',
            textStyle: const TextStyle(color: _T.muted, fontSize: 10)),
      ),
      tooltipBehavior: _tip,
      series: [
        BarSeries<_CD, String>(
          dataSource: _ageDiseaseData,
          xValueMapper: (d, _) => d.label,
          yValueMapper: (d, _) => d.value,
          pointColorMapper: (d, i) => _T.palette[i % _T.palette.length],
          borderRadius: BorderRadius.circular(4),
          width: 0.6,
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelAlignment: ChartDataLabelAlignment.outer,
            textStyle: TextStyle(color: _T.sub, fontSize: 9),
          ),
        ),
      ],
    ),
  );

  // ─────────────────────────────────────────────────
  //  8. WATER SOURCE
  // ─────────────────────────────────────────────────
  Widget _buildWaterChart() => _card(
    title: 'Water Source Distribution',
    badge: 'Lifestyle',
    badgeColor: _T.green,
    subtitle: 'Primary water source of deceased — lifestyle factor analysis',
    child: LayoutBuilder(builder: (ctx, box) {
      final wide = box.maxWidth > 500;
      return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          flex: wide ? 3 : 5,
          child: SfCircularChart(
            backgroundColor: Colors.transparent,
            tooltipBehavior: _tip,
            series: [
              DoughnutSeries<_CD, String>(
                dataSource: _waterData,
                xValueMapper: (d, _) => d.label,
                yValueMapper: (d, _) => d.value,
                pointColorMapper: (d, i) => _T.palette[i % _T.palette.length],
                innerRadius: '50%',
                explode: true,
                explodeIndex: 0,
                dataLabelSettings: const DataLabelSettings(
                  isVisible: true,
                  textStyle: TextStyle(color: _T.text, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: wide ? 2 : 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _waterData.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(
                  color: _T.palette[e.key % _T.palette.length],
                  borderRadius: BorderRadius.circular(2),
                )),
                const SizedBox(width: 8),
                Expanded(child: Text(e.value.label,
                    style: const TextStyle(color: _T.sub, fontSize: 11))),
                Text('${e.value.value.toInt()}',
                    style: TextStyle(color: _T.palette[e.key % _T.palette.length],
                        fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
            )).toList(),
          ),
        ),
      ]);
    }),
  );

  // ─────────────────────────────────────────────────
  //  9. DISEASE TREND BY CITY/YEAR (NEW CHART)
  // ─────────────────────────────────────────────────
  Widget _buildCityDiseaseTrend() {
    final td = _cityDiseaseTrend;
    final ratio = _cityTrendRatio(td);
    final loc = _trendLocalityCtrl.text.trim();
    final hasData = td.any((t) => t.count > 0);
    final isUp = td.length >= 2 && td.last.count > td.first.count;

    return _card(
      title: 'Disease Trend by City / Year',
      badge: 'Localized Trend',
      badgeColor: _T.orange,
      subtitle: 'Select a disease + enter a specific city to see year-by-year change',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Controls row
        LayoutBuilder(builder: (ctx, box) {
          final wide = box.maxWidth > 500;
          final diseaseField = DropdownButtonFormField<String>(
            initialValue: _trendDisease,
            dropdownColor: _T.surface,
            style: const TextStyle(color: _T.text, fontSize: 12),
            decoration: _deco('Select Disease'),
            isExpanded: true,
            items: _allDiseases.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
            onChanged: (v) => setState(() => _trendDisease = v),
          );
          final cityField = TextFormField(
            controller: _trendLocalityCtrl,
            style: const TextStyle(color: _T.text, fontSize: 12),
            decoration: _deco('Enter City / Village name…'),
            onChanged: (_) => setState(() {}),
          );
          return wide
              ? Row(children: [
                  Expanded(child: diseaseField),
                  const SizedBox(width: 12),
                  Expanded(child: cityField),
                ])
              : Column(children: [
                  diseaseField,
                  const SizedBox(height: 10),
                  cityField,
                ]);
        }),
        const SizedBox(height: 16),

        // Trend stats
        if (td.length >= 2 && hasData) ...[
          Row(children: [
            _statPill('Change', ratio, isUp ? _T.red : _T.green),
            const SizedBox(width: 10),
            _statPill('Peak Year',
                td.isEmpty ? '—' : td.reduce((a, b) => a.count > b.count ? a : b).year,
                _T.accent),
            const SizedBox(width: 10),
            _statPill('Latest (${_years.isNotEmpty ? _years.last : "—"})',
                '${td.isEmpty ? 0 : td.last.count.toInt()} deaths',
                isUp ? _T.red : _T.green),
          ]),
          const SizedBox(height: 14),
        ],

        // Context label
        if (loc.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Icon(Icons.place_rounded, size: 13, color: _T.orange),
              const SizedBox(width: 5),
              Text('Showing: ${_trendDisease ?? "—"} in "$loc"',
                  style: const TextStyle(color: _T.orange, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Showing all localities for ${_trendDisease ?? "—"}  ·  enter a city name above to localize',
                style: const TextStyle(color: _T.muted, fontSize: 11)),
          ),

        // Chart
        !hasData && loc.isNotEmpty
            ? _empty('No data for "$_trendDisease" in "$loc"')
            : SfCartesianChart(
                backgroundColor: Colors.transparent,
                plotAreaBackgroundColor: Colors.transparent,
                margin: EdgeInsets.zero,
                primaryXAxis: _catAxis,
                primaryYAxis: NumericAxis(
                  labelStyle: const TextStyle(color: _T.muted, fontSize: 10),
                  axisLine: AxisLine(color: _T.border),
                  majorGridLines: MajorGridLines(color: _T.border.withOpacity(0.5), width: 0.5, dashArray: [4,4]),
                  majorTickLines: const MajorTickLines(size: 0),
                  title: AxisTitle(text: 'Deaths per year',
                      textStyle: const TextStyle(color: _T.muted, fontSize: 10)),
                ),
                tooltipBehavior: TooltipBehavior(
                  enable: true, header: _trendDisease ?? '',
                  color: _T.surface,
                  textStyle: const TextStyle(color: _T.text, fontSize: 11),
                  borderColor: _T.border, borderWidth: 1,
                ),
                series: [
                  SplineAreaSeries<_TD, String>(
                    dataSource: td,
                    xValueMapper: (d, _) => d.year,
                    yValueMapper: (d, _) => d.count,
                    color: _T.orange.withOpacity(0.12),
                    borderColor: _T.orange,
                    borderWidth: 2.5,
                    splineType: SplineType.cardinal,
                    markerSettings: MarkerSettings(
                      isVisible: true,
                      color: _T.orange,
                      borderColor: _T.surface,
                      borderWidth: 2,
                      height: 8, width: 8,
                    ),
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      textStyle: TextStyle(color: _T.sub, fontSize: 10),
                    ),
                  ),
                ],
              ),
      ]),
    );
  }

  Widget _statPill(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: _T.muted, fontSize: 10)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 13,
            fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
      ]),
    ),
  );

  // ─────────────────────────────────────────────────
  //  10. GLOBAL TREND (top diseases, filtered)
  // ─────────────────────────────────────────────────
  Widget _buildGlobalTrend() {
    if (_topDiseases.isEmpty || _years.isEmpty) return _empty('Not enough data');

    final datasets = _topDiseases.asMap().entries.map((e) =>
        SplineSeries<_TD, String>(
          dataSource: _trendFor(e.value),
          xValueMapper: (d, _) => d.year,
          yValueMapper: (d, _) => d.count,
          name: e.value,
          color: _T.palette[e.key % _T.palette.length],
          width: 2,
          markerSettings: MarkerSettings(
            isVisible: true,
            color: _T.palette[e.key % _T.palette.length],
            borderColor: _T.surface,
            borderWidth: 2,
            height: 6, width: 6,
          ),
        )).toList();

    return _card(
      title: 'Year-by-Year Global Trend',
      badge: 'Multi-Disease',
      badgeColor: _T.purple,
      subtitle: 'Top ${_topDiseases.length} diseases over time · filtered by $_filterLabel',
      child: SfCartesianChart(
        backgroundColor: Colors.transparent,
        plotAreaBackgroundColor: Colors.transparent,
        margin: EdgeInsets.zero,
        legend: Legend(
          isVisible: true,
          textStyle: const TextStyle(color: _T.sub, fontSize: 10),
          overflowMode: LegendItemOverflowMode.wrap,
          position: LegendPosition.bottom,
        ),
        primaryXAxis: _catAxis,
        primaryYAxis: _numAxis,
        tooltipBehavior: TooltipBehavior(
          enable: true, shared: true,
          color: _T.surface,
          textStyle: const TextStyle(color: _T.text, fontSize: 11),
          borderColor: _T.border, borderWidth: 1,
        ),
        series: datasets,
      ),
    );
  }

  Widget _empty(String msg) => Container(
    height: 120,
    alignment: Alignment.center,
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.bar_chart_rounded, color: _T.border, size: 36),
      const SizedBox(height: 8),
      Text(msg, style: const TextStyle(color: _T.muted, fontSize: 12)),
    ]),
  );
}