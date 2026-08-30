// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

// ═══════════════════════════════════════════════════════
//  MODELS
// ═══════════════════════════════════════════════════════

class _CD {
  final String label;
  final double value;
  _CD(this.label, this.value);
}

class _GD {
  final String cause;
  final double male;
  final double female;
  _GD(this.cause, this.male, this.female);
}

class _TD {
  final String year;
  final double count;
  _TD(this.year, this.count);
}

/// Disease + Comorbidity relationship
class _DC {
  final String disease;
  final String comorbidity;
  final double count;
  _DC(this.disease, this.comorbidity, this.count);
}

/// Disease + Water relationship
class _DW {
  final String disease;
  final String water;
  final double count;
  _DW(this.disease, this.water, this.count);
}

/// Disease + Place relationship
class _DP {
  final String disease;
  final String place;
  final double count;
  _DP(this.disease, this.place, this.count);
}

/// Disease + Age group
class _DA {
  final String disease;
  final String ageGroup;
  final double count;
  _DA(this.disease, this.ageGroup, this.count);
}

/// Disease + Gender
class _DG {
  final String disease;
  final String gender;
  final double count;
  _DG(this.disease, this.gender, this.count);
}

/// Disease + Comorbidity combination
class _Combo {
  final String disease;
  final String combination;
  final double count;
  final double percentage;
  _Combo(this.disease, this.combination, this.count, this.percentage);
}

/// Comorbidity + Comorbidity combination
class _CC {
  final String combination;
  final double count;
  final double percentage;
  _CC(this.combination, this.count, this.percentage);
}

/// Risk/association insight model
class _Insight {
  final String title;
  final String description;
  final Color color;
  final IconData icon;
  _Insight(this.title, this.description, this.color, this.icon);
}

// ═══════════════════════════════════════════════════════
//  THEME
// ═══════════════════════════════════════════════════════

class _T {
  static const bg = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const surfaceAlt = Color(0xFF25324A);
  static const border = Color(0xFF334155);
  static const muted = Color(0xFF94A3B8);
  static const text = Color(0xFFF1F5F9);
  static const sub = Color(0xFFCBD5E1);

  static const accent = Color(0xFF38BDF8);
  static const green = Color(0xFF34D399);
  static const purple = Color(0xFF818CF8);
  static const orange = Color(0xFFFB923C);
  static const red = Color(0xFFF87171);
  static const pink = Color(0xFFF472B6);

  // Dedicated, consistent gender colors used everywhere a
  // male/female breakdown is shown so users can read charts
  // at a glance without checking a legend each time.
  static const male = Color(0xFF38BDF8);
  static const female = Color(0xFFF472B6);
  static const otherGender = Color(0xFFA78BFA);

  static const palette = [
    Color(0xFF38BDF8),
    Color(0xFF818CF8),
    Color(0xFF34D399),
    Color(0xFFFB923C),
    Color(0xFFF87171),
    Color(0xFFA78BFA),
    Color(0xFF22D3EE),
    Color(0xFFFBBF24),
    Color(0xFF4ADE80),
    Color(0xFFF472B6),
    Color(0xFF6EE7B7),
    Color(0xFFFCA5A5),
  ];

  static Color genderColor(String gender) {
    final g = gender.toLowerCase();
    if (g == 'male') return male;
    if (g == 'female') return female;
    return otherGender;
  }
}

// ═══════════════════════════════════════════════════════
//  RESPONSIVE HELPERS
// ═══════════════════════════════════════════════════════

/// Small helper so every widget in this page uses the same
/// breakpoints instead of scattering magic numbers around.
class _Break {
  static const mobile = 600.0;
  static const tablet = 1000.0;

  static bool isMobile(double w) => w < mobile;
  static bool isTablet(double w) => w >= mobile && w < tablet;
  static bool isDesktop(double w) => w >= tablet;

  static double pagePadding(double w) =>
      isMobile(w) ? 12 : (isTablet(w) ? 16 : 20);

  static double chartHeight(double w) =>
      isMobile(w) ? 300 : (isTablet(w) ? 340 : 390);

  static double axisLabelSize(double w) => isMobile(w) ? 8 : 9.5;

  static double rotation(double w) => isMobile(w) ? -55 : -35;
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
  // Disease-by-city trend filters (independent)
String? _trendDisease;
String? _trendLocality;
final _trendOtherDiseaseCtrl = TextEditingController();

  List<String> _districts = [];
  List<String> _years = [];

  List<String> _allDiseases = [];
  List<String> _topDiseases = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }
@override
void dispose() {
  _localityCtrl.dispose();
  _trendOtherDiseaseCtrl.dispose();
  super.dispose();
}
  // ═══════════════════════════════════════════════════════
  // FETCH
  // ═══════════════════════════════════════════════════════
List<String> get _trendLocalities {
  final unique = <String, String>{};

  for (final r in _allData) {
    final locality = r['specific_locality']?.toString().trim() ?? '';

    if (locality.isEmpty ||
        locality.toLowerCase() == 'unknown' ||
        locality.toLowerCase() == 'unspecified') {
      continue;
    }

    // Case-insensitive uniqueness.
    // Keeps the first original spelling for display.
    unique.putIfAbsent(locality.toLowerCase(), () => locality);
  }

  final result = unique.values.toList();

  result.sort(
    (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
  );

  return result;
}
 
 String _normalizeTrendValue(String value) {
  return value.trim().toLowerCase();
}
 
  Future<void> _fetchData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final res = await _sb
          .from(_table)
          .select(
            'age,gender,district,specific_locality,cause_of_death,'
            'prior_medical_conditions,place_of_death,water_source,'
            'income_bracket,date_of_death,is_valid,quality_score',
          )
          .eq('is_valid', true)
          .gte('quality_score', 60)
          .limit(10000);

      _allData = List<Map<String, dynamic>>.from(res as List);

      _districts = _allData
          .map((r) => r['district']?.toString() ?? '')
          .where((d) => d.isNotEmpty && d != 'Unknown')
          .toSet()
          .toList()
        ..sort();

      _years = _allData
          .map((r) => (r['date_of_death']?.toString() ?? '').length >= 4
              ? r['date_of_death'].toString().substring(0, 4)
              : '')
          .where((y) => y.length == 4)
          .toSet()
          .toList()
        ..sort();

      _allDiseases = _allData
          .map((r) => r['cause_of_death']?.toString().trim() ?? '')
          .where((d) =>
              d.isNotEmpty &&
              d.toLowerCase() != 'unknown' &&
              d.toLowerCase() != 'unspecified')
          .toSet()
          .toList()
        ..sort();

      _applyFilters();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════
  // FILTER
  // ═══════════════════════════════════════════════════════

  void _applyFilters() {
    final loc = _localityCtrl.text.trim().toLowerCase();

    _filtered = _allData.where((r) {
      if (_selDistrict != null &&
          _selDistrict!.isNotEmpty &&
          r['district']?.toString() != _selDistrict) {
        return false;
      }

      if (loc.isNotEmpty &&
          !(r['specific_locality']?.toString().toLowerCase() ?? '')
              .contains(loc)) {
        return false;
      }

      if (_selYear != null &&
          _selYear!.isNotEmpty &&
          !(r['date_of_death']?.toString() ?? '').startsWith(_selYear!)) {
        return false;
      }

      return true;
    }).toList();

    final counts = _countBy(_filtered, 'cause_of_death');

    _topDiseases = (counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(6)
        .map((e) => e.key)
        .toList();

    if (_trendDisease == null || !_allDiseases.contains(_trendDisease)) {
      _trendDisease = _allDiseases.isNotEmpty ? _allDiseases.first : null;
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  void _clearFilters() {
    _selDistrict = null;
    _localityCtrl.clear();
    _selYear = null;
    _applyFilters();
  }

  // ═══════════════════════════════════════════════════════
  // BASIC HELPERS
  // ═══════════════════════════════════════════════════════

  Map<String, int> _countBy(List<Map<String, dynamic>> data, String key) {
    final m = <String, int>{};

    for (final r in data) {
      final v = r[key]?.toString().trim() ?? 'Unknown';

      if (v.isEmpty ||
          v.toLowerCase() == 'unknown' ||
          v.toLowerCase() == 'unspecified') {
        continue;
      }

      m[v] = (m[v] ?? 0) + 1;
    }

    return m;
  }

  List<String> _extractComorbidities(Map<String, dynamic> record) {
    final raw = record['prior_medical_conditions'];

    if (raw == null) return [];

    if (raw is List) {
      return raw
          .map((x) => x?.toString().trim() ?? '')
          .where((x) =>
              x.isNotEmpty &&
              x.toLowerCase() != 'none' &&
              x.toLowerCase() != 'unknown' &&
              x.toLowerCase() != 'unspecified')
          .toSet()
          .toList();
    }

    final value = raw.toString().trim();

    if (value.isEmpty ||
        value.toLowerCase() == 'none' ||
        value.toLowerCase() == 'unknown' ||
        value.toLowerCase() == 'unspecified') {
      return [];
    }

    return value
        .replaceAll('{', '')
        .replaceAll('}', '')
        .split(',')
        .map((x) => x.trim())
        .where((x) =>
            x.isNotEmpty &&
            x.toLowerCase() != 'none' &&
            x.toLowerCase() != 'unknown' &&
            x.toLowerCase() != 'unspecified')
        .toSet()
        .toList();
  }

  int _getAge(Map<String, dynamic> r) {
    final value = r['age'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _ageGroup(int age) {
    if (age <= 0) return 'Unknown';
    if (age < 18) return '0–17';
    if (age < 35) return '18–34';
    if (age < 50) return '35–49';
    if (age < 65) return '50–64';
    return '65+';
  }

  String _shorten(String value, [int max = 18]) {
    if (value.length <= max) return value;
    return '${value.substring(0, max - 1)}…';
  }

  // ═══════════════════════════════════════════════════════
  // SUMMARY METRICS
  // ═══════════════════════════════════════════════════════

  String get _avgAge {
    final ages =
        _filtered.map(_getAge).where((a) => a > 0 && a < 120).toList();
    if (ages.isEmpty) return '—';
    return (ages.reduce((a, b) => a + b) / ages.length).toStringAsFixed(1);
  }

  String get _topCause {
    final c = _countBy(_filtered, 'cause_of_death');
    if (c.isEmpty) return '—';
    return (c.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }

  String get _filterLabel {
    final p = <String>[];
    if (_selDistrict != null) p.add(_selDistrict!);
    if (_localityCtrl.text.trim().isNotEmpty) p.add(_localityCtrl.text.trim());
    if (_selYear != null) p.add(_selYear!);
    return p.isEmpty ? 'All Areas · All Years' : p.join(' · ');
  }

  double _percentage(int value, int total) {
    if (total <= 0) return 0;
    return value / total * 100;
  }

  // ═══════════════════════════════════════════════════════
  // ORIGINAL CHART DATA
  // ═══════════════════════════════════════════════════════

  List<_CD> get _causesData {
    final s = (_countBy(_filtered, 'cause_of_death').entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(10);
    return s.map((e) => _CD(e.key, e.value.toDouble())).toList();
  }

  List<_CD> get _ageData {
    final bins = {
      '0–17': 0,
      '18–34': 0,
      '35–49': 0,
      '50–64': 0,
      '65+': 0,
    };

    for (final r in _filtered) {
      final a = _getAge(r);
      if (a <= 0) continue;
      if (a < 18) {
        bins['0–17'] = bins['0–17']! + 1;
      } else if (a < 35) {
        bins['18–34'] = bins['18–34']! + 1;
      } else if (a < 50) {
        bins['35–49'] = bins['35–49']! + 1;
      } else if (a < 65) {
        bins['50–64'] = bins['50–64']! + 1;
      } else {
        bins['65+'] = bins['65+']! + 1;
      }
    }

    return bins.entries.map((e) => _CD(e.key, e.value.toDouble())).toList();
  }

  List<_CD> get _genderData {
    final c = _countBy(_filtered, 'gender');
    return c.entries.map((e) => _CD(e.key, e.value.toDouble())).toList();
  }

  /// Full disease name is preserved here — only the chart's
  /// x-axis mapper shortens it for display, so tooltips can
  /// always show the complete cause of death.
  List<_GD> get _genderByCause {
    final causeCounts = _countBy(_filtered, 'cause_of_death');
    final topCauses = causeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return topCauses.take(6).map((entry) {
      final cause = entry.key;
      double male = 0;
      double female = 0;

      for (final r in _filtered) {
        final recordCause = r['cause_of_death']?.toString().trim() ?? '';
        final gender = r['gender']?.toString().trim().toLowerCase() ?? '';
        if (recordCause != cause) continue;
        if (gender == 'male') {
          male++;
        } else if (gender == 'female') {
          female++;
        }
      }

      return _GD(cause, male, female);
    }).toList();
  }

  List<_CD> get _comorbidData {
    final counts = <String, int>{};
    for (final r in _filtered) {
      for (final c in _extractComorbidities(r)) {
        counts[c] = (counts[c] ?? 0) + 1;
      }
    }
    final s = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
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

  /// Full disease name preserved; the chart shortens only for
  /// the visible axis label, tooltip shows the full text.
  List<_CD> get _ageDiseaseData {
    return _causesData.take(8).map((cd) {
      final ages = _filtered
          .where((r) =>
              r['cause_of_death']?.toString() == cd.label &&
              _getAge(r) > 0 &&
              _getAge(r) < 120)
          .map(_getAge)
          .toList();

      final avg =
          ages.isEmpty ? 0.0 : ages.reduce((a, b) => a + b) / ages.length;

      return _CD(cd.label, double.parse(avg.toStringAsFixed(1)));
    }).toList();
  }

  // ═══════════════════════════════════════════════════════
  // GLOBAL TREND
  // ═══════════════════════════════════════════════════════

  List<_TD> _trendFor(String disease) {
    return _years.map((y) {
      final count = _filtered.where((r) {
        return r['cause_of_death']?.toString() == disease &&
            (r['date_of_death']?.toString() ?? '').startsWith(y);
      }).length;
      return _TD(y, count.toDouble());
    }).toList();
  }

  // ═══════════════════════════════════════════════════════
  // CITY DISEASE TREND
  // ═══════════════════════════════════════════════════════
List<_TD> get _cityDiseaseTrend {
  if (_trendDisease == null) return [];

  final selectedDisease = _trendDisease == 'Other'
      ? _trendOtherDiseaseCtrl.text.trim()
      : (_trendDisease ?? '').trim();

  if (selectedDisease.isEmpty) return [];

  final selectedDiseaseNormalized =
      _normalizeTrendValue(selectedDisease);

  final selectedLocality =
      (_trendLocality ?? '').trim().toLowerCase();

  return _years.map((y) {
    final count = _allData.where((r) {
      // -----------------------------
      // Disease matching
      // -----------------------------
      final recordDisease =
          r['cause_of_death']?.toString().trim() ?? '';

      if (recordDisease.isEmpty) return false;

      if (_normalizeTrendValue(recordDisease) !=
          selectedDiseaseNormalized) {
        return false;
      }

      // -----------------------------
      // Year matching
      // -----------------------------
      final date =
          r['date_of_death']?.toString() ?? '';

      if (!date.startsWith(y)) {
        return false;
      }

      // -----------------------------
      // Locality matching
      // -----------------------------
      if (selectedLocality.isNotEmpty) {
        final recordLocality =
            r['specific_locality']?.toString().trim().toLowerCase() ?? '';

        if (recordLocality != selectedLocality) {
          return false;
        }
      }

      return true;
    }).length;

    return _TD(y, count.toDouble());
  }).toList();
}



  String _cityTrendRatio(List<_TD> td) {
    if (td.length < 2) return '';
    final first = td.first.count;
    final last = td.last.count;

    if (first == 0 && last == 0) return 'No data';
    if (first == 0) return '↑ New cases';

    final pct = ((last - first) / first * 100);
    final dir = last > first ? '↑' : (last < first ? '↓' : '→');

    return '$dir ${pct.abs().toStringAsFixed(1)}%  '
        '(${td.first.year}→${td.last.year})';
  }

  // ═══════════════════════════════════════════════════════
  // DEEP ANALYSIS
  // ═══════════════════════════════════════════════════════

  List<_DC> get _diseaseComorbidityData {
    final map = <String, int>{};

    for (final r in _filtered) {
      final disease = r['cause_of_death']?.toString().trim() ?? '';
      if (disease.isEmpty ||
          disease.toLowerCase() == 'unknown' ||
          disease.toLowerCase() == 'unspecified') {
        continue;
      }

      for (final c in _extractComorbidities(r)) {
        final key = '$disease|||$c';
        map[key] = (map[key] ?? 0) + 1;
      }
    }

    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(30).map((e) {
      final parts = e.key.split('|||');
      return _DC(parts.first, parts.length > 1 ? parts[1] : '',
          e.value.toDouble());
    }).toList();
  }

  List<String> get _heatmapDiseases =>
      _diseaseComorbidityData.map((e) => e.disease).toSet().take(8).toList();

  List<String> get _heatmapComorbidities => _diseaseComorbidityData
      .map((e) => e.comorbidity)
      .toSet()
      .take(8)
      .toList();

  int _diseaseComorbidityCount(String disease, String comorbidity) {
    int count = 0;
    for (final r in _filtered) {
      final recordDisease = r['cause_of_death']?.toString().trim() ?? '';
      if (recordDisease != disease) continue;
      if (_extractComorbidities(r).contains(comorbidity)) count++;
    }
    return count;
  }

  List<_Combo> get _diseaseCombinationData {
    final map = <String, int>{};

    for (final r in _filtered) {
      final disease = r['cause_of_death']?.toString().trim() ?? '';
      if (disease.isEmpty ||
          disease.toLowerCase() == 'unknown' ||
          disease.toLowerCase() == 'unspecified') {
        continue;
      }

      final conditions = _extractComorbidities(r);
      if (conditions.isEmpty) continue;

      conditions.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      final combination = '$disease + ${conditions.join(' + ')}';
      map[combination] = (map[combination] ?? 0) + 1;
    }

    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = _filtered.length;

    return sorted.take(15).map((e) {
      final splitIndex = e.key.indexOf(' + ');
      final disease =
          splitIndex > 0 ? e.key.substring(0, splitIndex) : e.key;
      final combo = splitIndex > 0 ? e.key.substring(splitIndex + 3) : '';
      return _Combo(disease, combo, e.value.toDouble(),
          _percentage(e.value, total));
    }).toList();
  }

  List<_CC> get _comorbidityCombinationData {
    final map = <String, int>{};

    for (final r in _filtered) {
      final conditions = _extractComorbidities(r);
      if (conditions.length < 2) continue;

      conditions.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      for (int i = 0; i < conditions.length; i++) {
        for (int j = i + 1; j < conditions.length; j++) {
          final combo = '${conditions[i]} + ${conditions[j]}';
          map[combo] = (map[combo] ?? 0) + 1;
        }
      }
    }

    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = _filtered.length;

    return sorted
        .take(15)
        .map((e) => _CC(e.key, e.value.toDouble(), _percentage(e.value, total)))
        .toList();
  }

  List<_DW> get _diseaseWaterData {
    final map = <String, int>{};

    for (final r in _filtered) {
      final disease = r['cause_of_death']?.toString().trim() ?? '';
      final water = r['water_source']?.toString().trim() ?? '';

      if (disease.isEmpty ||
          water.isEmpty ||
          disease.toLowerCase() == 'unknown' ||
          water.toLowerCase() == 'unknown' ||
          water.toLowerCase() == 'unspecified') {
        continue;
      }

      final key = '$disease|||$water';
      map[key] = (map[key] ?? 0) + 1;
    }

    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(30).map((e) {
      final parts = e.key.split('|||');
      return _DW(parts.first, parts.length > 1 ? parts[1] : '',
          e.value.toDouble());
    }).toList();
  }

  List<_DP> get _diseasePlaceData {
    final map = <String, int>{};

    for (final r in _filtered) {
      final disease = r['cause_of_death']?.toString().trim() ?? '';
      final place = r['place_of_death']?.toString().trim() ?? '';

      if (disease.isEmpty ||
          place.isEmpty ||
          disease.toLowerCase() == 'unknown' ||
          place.toLowerCase() == 'unknown' ||
          place.toLowerCase() == 'unspecified') {
        continue;
      }

      final key = '$disease|||$place';
      map[key] = (map[key] ?? 0) + 1;
    }

    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(30).map((e) {
      final parts = e.key.split('|||');
      return _DP(parts.first, parts.length > 1 ? parts[1] : '',
          e.value.toDouble());
    }).toList();
  }

  List<_DA> get _diseaseAgeData {
    final map = <String, int>{};

    for (final r in _filtered) {
      final disease = r['cause_of_death']?.toString().trim() ?? '';
      final age = _getAge(r);
      if (disease.isEmpty || age <= 0 || age >= 120) continue;

      final group = _ageGroup(age);
      final key = '$disease|||$group';
      map[key] = (map[key] ?? 0) + 1;
    }

    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(30).map((e) {
      final parts = e.key.split('|||');
      return _DA(parts.first, parts.length > 1 ? parts[1] : '',
          e.value.toDouble());
    }).toList();
  }

  List<_DG> get _diseaseGenderData {
    final map = <String, int>{};

    for (final r in _filtered) {
      final disease = r['cause_of_death']?.toString().trim() ?? '';
      final gender = r['gender']?.toString().trim() ?? '';
      if (disease.isEmpty || gender.isEmpty) continue;

      final key = '$disease|||$gender';
      map[key] = (map[key] ?? 0) + 1;
    }

    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(30).map((e) {
      final parts = e.key.split('|||');
      return _DG(parts.first, parts.length > 1 ? parts[1] : '',
          e.value.toDouble());
    }).toList();
  }

  // ═══════════════════════════════════════════════════════
  // ANALYTICAL INSIGHTS
  // ═══════════════════════════════════════════════════════

  List<_Insight> get _insights {
    final result = <_Insight>[];

    if (_filtered.isEmpty) {
      return [
        _Insight(
          'No records',
          'No mortality records match the current filters.',
          _T.muted,
          Icons.info_outline_rounded,
        ),
      ];
    }

    final causeCounts = _countBy(_filtered, 'cause_of_death');

    if (causeCounts.isNotEmpty) {
      final top = causeCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final e = top.first;
      final pct = _percentage(e.value, _filtered.length);

      result.add(_Insight(
        'Leading Cause',
        '${e.key} accounts for ${e.value} records '
            '(${pct.toStringAsFixed(1)}% of filtered mortality records).',
        _T.orange,
        Icons.coronavirus_rounded,
      ));
    }

    if (_diseaseComorbidityData.isNotEmpty) {
      final e = _diseaseComorbidityData.first;
      result.add(_Insight(
        'Strongest Observed Combination',
        '${e.disease} appears with ${e.comorbidity} '
            'in ${e.count.toInt()} mortality records. '
            'This is a high-frequency observed association '
            'in the current dataset.',
        _T.red,
        Icons.warning_amber_rounded,
      ));
    }

    if (_diseaseWaterData.isNotEmpty) {
      final e = _diseaseWaterData.first;
      result.add(_Insight(
        'Water–Disease Pattern',
        '${e.disease} has the highest observed '
            'record count associated with ${e.water} '
            'among the available water-source data.',
        _T.accent,
        Icons.water_drop_rounded,
      ));
    }

    if (_diseasePlaceData.isNotEmpty) {
      final e = _diseasePlaceData.first;
      result.add(_Insight(
        'Place–Disease Pattern',
        '${e.disease} has ${e.count.toInt()} records '
            'associated with ${e.place} as the place of death.',
        _T.purple,
        Icons.local_hospital_rounded,
      ));
    }

    final ages = _filtered.map(_getAge).where((a) => a > 0 && a < 120).toList();

    if (ages.isNotEmpty) {
      final groups = <String, int>{
        '0–17': 0,
        '18–34': 0,
        '35–49': 0,
        '50–64': 0,
        '65+': 0,
      };

      for (final a in ages) {
        groups[_ageGroup(a)] = groups[_ageGroup(a)]! + 1;
      }

      final topAge = groups.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final e = topAge.first;

      result.add(_Insight(
        'Dominant Age Group',
        '${e.key} contains ${e.value} of the '
            '${ages.length} records with valid age data '
            '(${_percentage(e.value, ages.length).toStringAsFixed(1)}%).',
        _T.green,
        Icons.groups_rounded,
      ));
    }

    if (_comorbidityCombinationData.isNotEmpty) {
      final e = _comorbidityCombinationData.first;
      result.add(_Insight(
        'Frequent Comorbidity Pair',
        '${e.combination} occurs together in '
            '${e.count.toInt()} records '
            '(${e.percentage.toStringAsFixed(1)}% of filtered records).',
        _T.pink,
        Icons.link_rounded,
      ));
    }

    return result.take(6).toList();
  }

  // ═══════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      appBar: AppBar(
        backgroundColor: _T.surface,
        foregroundColor: _T.text,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _T.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: _T.accent.withOpacity(0.5), blurRadius: 8),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Descriptive Analytics',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
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
              : Column(
                  children: [
                    _buildFilterBar(),
                    Expanded(
                      child: RefreshIndicator(
                        color: _T.accent,
                        onRefresh: _fetchData,
                        child: _buildBody(),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildLoader() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: _T.accent, strokeWidth: 2),
            const SizedBox(height: 16),
            Text('Loading data from database…',
                style: TextStyle(color: _T.muted, fontSize: 13)),
          ],
        ),
      );

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: _T.red, size: 48),
              const SizedBox(height: 12),
              const Text('Failed to load data',
                  style: TextStyle(
                      color: _T.text, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(_error ?? '',
                  style: const TextStyle(color: _T.muted, fontSize: 11),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _T.accent, foregroundColor: _T.bg),
              ),
            ],
          ),
        ),
      );

  // ═══════════════════════════════════════════════════════
  // FILTER BAR
  // ═══════════════════════════════════════════════════════

  Widget _buildFilterBar() {
    return Container(
      decoration: const BoxDecoration(
        color: _T.surface,
        border: Border(bottom: BorderSide(color: _T.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 14, color: _T.muted),
              const SizedBox(width: 6),
              Text('FILTER ALL CHARTS',
                  style: TextStyle(
                      color: _T.muted,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (ctx, box) {
              final wide = box.maxWidth > _Break.mobile;

              final fields = [
                _filterDrop('District', _districts, _selDistrict, (v) {
                  setState(() => _selDistrict = v);
                  _applyFilters();
                }),
                _filterInput(
                    'City / Village…', _localityCtrl, () => _applyFilters()),
                _filterDrop('Year', _years, _selYear, (v) {
                  setState(() => _selYear = v);
                  _applyFilters();
                }),
                _clearBtn(),
              ];

              if (wide) {
                return Row(
                  children: fields
                      .map((f) => Expanded(
                          child: Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: f)))
                      .toList(),
                );
              }

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: fields
                    .map((f) =>
                        SizedBox(width: (box.maxWidth - 10) / 2, child: f))
                    .toList(),
              );
            },
          ),
          if (_selDistrict != null ||
              _localityCtrl.text.isNotEmpty ||
              _selYear != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _T.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _T.accent.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 11, color: _T.accent),
                        const SizedBox(width: 5),
                        Text(_filterLabel,
                            style:
                                const TextStyle(color: _T.accent, fontSize: 11)),
                      ],
                    ),
                  ),
                  Text('${_filtered.length} records',
                      style: const TextStyle(color: _T.muted, fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterDrop(String hint, List<String> options, String? val,
      void Function(String?) onChange) {
    return DropdownButtonFormField<String>(
      initialValue: val,
      dropdownColor: _T.surface,
      style: const TextStyle(color: _T.text, fontSize: 12),
      decoration: _deco(hint),
      isExpanded: true,
      items: [
        DropdownMenuItem(
          value: null,
          child:
              Text('All $hint', style: const TextStyle(color: _T.muted)),
        ),
        ...options.map((o) => DropdownMenuItem(value: o, child: Text(o))),
      ],
      onChanged: onChange,
    );
  }

  Widget _filterInput(
      String hint, TextEditingController ctrl, VoidCallback onChange) {
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
            side: const BorderSide(color: _T.border),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _T.muted, fontSize: 12),
        filled: true,
        fillColor: _T.bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _T.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _T.accent),
        ),
      );

  // ═══════════════════════════════════════════════════════
  // BODY
  // ═══════════════════════════════════════════════════════

  Widget _buildBody() {
    final w = MediaQuery.sizeOf(context).width;
    final pad = _Break.pagePadding(w);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummary(),
          const SizedBox(height: 24),
          _sec('Mortality Analysis & Key Findings'),
          _buildInsights(),
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
          _sec('Disease × Comorbidity Analysis'),
          _buildDiseaseComorbidityChart(),
          const SizedBox(height: 16),
          _buildDiseaseComorbidityHeatmap(),
          const SizedBox(height: 16),
          _buildDiseaseCombinationTable(),
          const SizedBox(height: 16),
          _buildComorbidityPairChart(),
          const SizedBox(height: 16),
          _sec('Age by Disease'),
          _buildAgeDiseaseChart(),
          const SizedBox(height: 16),
          _buildDiseaseAgeChart(),
          const SizedBox(height: 16),
          _sec('Water Source — Lifestyle Factor'),
          _buildWaterChart(),
          const SizedBox(height: 16),
          _buildWaterDiseaseChart(),
          const SizedBox(height: 16),
          _buildPlaceDiseaseChart(),
          const SizedBox(height: 16),
          _buildGenderDiseaseAnalysis(),
          const SizedBox(height: 24),
          _sec('Disease Trend by City / Year  ·  Localized Analysis'),
          _buildCityDiseaseTrend(),
          const SizedBox(height: 24),
          _sec('Year-by-Year Global Trend (Top Diseases)'),
          _buildGlobalTrend(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // SUMMARY CARDS
  // ═══════════════════════════════════════════════════════

  Widget _buildSummary() {
    final male = _filtered
        .where((r) => r['gender']?.toString().toLowerCase() == 'male')
        .length;
    final female = _filtered
        .where((r) => r['gender']?.toString().toLowerCase() == 'female')
        .length;

    final locs = _filtered
        .map((r) => r['specific_locality']?.toString() ?? '')
        .where((l) => l.isNotEmpty)
        .toSet()
        .length;

    final stats = [
      ('Total Records', '${_filtered.length}', _T.accent, Icons.people_rounded),
      ('Top Cause', _topCause, _T.orange, Icons.coronavirus_rounded),
      ('Avg Age', _avgAge, _T.purple, Icons.cake_rounded),
      ('Male / Female', '$male / $female', _T.green, Icons.wc_rounded),
      ('Localities', '$locs', _T.pink, Icons.location_city_rounded),
    ];

    return LayoutBuilder(
      builder: (ctx, box) {
        final w = box.maxWidth;
        final cols = w > 900 ? 5 : (w > 650 ? 3 : 2);
        final aspect = w > 900 ? 2.2 : (w > 650 ? 1.9 : 1.55);

        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: aspect,
          children: stats
              .map((s) => Container(
                    decoration: BoxDecoration(
                      color: _T.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _T.border),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: s.$3.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(s.$4, color: s.$3, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(s.$1,
                                  style: const TextStyle(
                                      color: _T.muted, fontSize: 10)),
                              const SizedBox(height: 2),
                              Text(
                                s.$2,
                                style: TextStyle(
                                    color: s.$3,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // INSIGHTS
  // ═══════════════════════════════════════════════════════

  Widget _buildInsights() {
    final insights = _insights;
    if (insights.isEmpty) {
      return _empty('Not enough information for analytical insights');
    }

    return LayoutBuilder(
      builder: (ctx, box) {
        final wide = box.maxWidth > 750;

        final cards = insights
            .map((i) => Container(
                  width: wide ? (box.maxWidth - 12) / 2 : double.infinity,
                  margin: EdgeInsets.only(
                      bottom: 12, right: wide ? 6 : 0, left: wide ? 6 : 0),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: _T.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: i.color.withOpacity(0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: i.color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(i.icon, color: i.color, size: 19),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i.title,
                                style: TextStyle(
                                    color: i.color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            Text(i.description,
                                style: const TextStyle(
                                    color: _T.sub, fontSize: 11, height: 1.45)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ))
            .toList();

        return wide ? Wrap(children: cards) : Column(children: cards);
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // LAYOUT HELPERS
  // ═══════════════════════════════════════════════════════

  Widget _sec(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                  color: _T.accent, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t.toUpperCase(),
                style: const TextStyle(
                    color: _T.muted,
                    fontSize: 10,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

  Widget _responsiveRow(List<Widget> children) => LayoutBuilder(
        builder: (ctx, box) => box.maxWidth > 700
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children
                    .map((c) => Expanded(
                        child:
                            Padding(padding: const EdgeInsets.only(right: 14), child: c)))
                    .toList(),
              )
            : Column(
                children: children
                    .map((c) =>
                        Padding(padding: const EdgeInsets.only(bottom: 14), child: c))
                    .toList(),
              ),
      );

  /// Shared card chrome for every chart. `trailing` is used to show a
  /// compact Male/Female (or other) legend next to the badge whenever a
  /// chart encodes gender via point colors instead of a Syncfusion legend.
  Widget _card({
    required String title,
    required String badge,
    required Color badgeColor,
    required Widget child,
    String? subtitle,
    Widget? trailing,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _T.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _T.border)),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 8,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 160),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: _T.text,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle,
                              style:
                                  const TextStyle(color: _T.muted, fontSize: 11)),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (trailing != null) ...[trailing, const SizedBox(width: 10)],
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: badgeColor.withOpacity(0.3)),
                        ),
                        child: Text(badge,
                            style: TextStyle(
                                color: badgeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(padding: const EdgeInsets.all(16), child: child),
          ],
        ),
      );

  // ═══════════════════════════════════════════════════════
  // GENDER LEGEND
  // ═══════════════════════════════════════════════════════

  Widget _legendDot(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: _T.sub, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      );

  Widget _genderLegend({bool includeOther = false}) => Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          _legendDot(_T.male, 'Male'),
          _legendDot(_T.female, 'Female'),
          if (includeOther) _legendDot(_T.otherGender, 'Other'),
        ],
      );

  // ═══════════════════════════════════════════════════════
  // TOOLTIP HELPERS — used so charts can show the FULL,
  // untruncated names when a bar is tapped, even though the
  // x-axis label itself is shortened to keep charts readable.
  // ═══════════════════════════════════════════════════════

  Widget _tooltipCard(List<Widget> children) => Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _T.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _T.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 14),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  Widget _tooltipTitle(String text, {Color color = _T.text}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          softWrap: true,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      );

  Widget _tooltipRow(String label, String value, {Color? valueColor}) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                  text: '$label: ',
                  style: const TextStyle(color: _T.muted, fontSize: 11)),
              TextSpan(
                text: value,
                style: TextStyle(
                    color: valueColor ?? _T.sub,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );

  // ═══════════════════════════════════════════════════════
  // AXIS / TOOLTIP
  // ═══════════════════════════════════════════════════════

  CategoryAxis get _catAxis => CategoryAxis(
        labelStyle: const TextStyle(color: _T.muted, fontSize: 10),
        axisLine: const AxisLine(color: _T.border),
        majorGridLines: const MajorGridLines(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
      );

  NumericAxis get _numAxis => NumericAxis(
        labelStyle: const TextStyle(color: _T.muted, fontSize: 10),
        axisLine: const AxisLine(color: _T.border),
        majorGridLines: MajorGridLines(
          color: _T.border.withOpacity(0.5),
          width: 0.5,
          dashArray: const [4, 4],
        ),
        majorTickLines: const MajorTickLines(size: 0),
      );

  TooltipBehavior get _tip => TooltipBehavior(
        enable: true,
        color: _T.surface,
        textStyle: const TextStyle(color: _T.text, fontSize: 11),
        borderColor: _T.border,
        borderWidth: 1,
      );

  // ═══════════════════════════════════════════════════════
  // 1. TOP CAUSES
  // ═══════════════════════════════════════════════════════

  Widget _buildCausesChart() {
    final w = MediaQuery.sizeOf(context).width;

    return _card(
      title: 'Top Causes of Death',
      badge: 'Descriptive',
      badgeColor: _T.orange,
      subtitle: 'Top 10 causes ranked by frequency · tap a bar for details',
      child: SfCartesianChart(
        backgroundColor: Colors.transparent,
        plotAreaBackgroundColor: Colors.transparent,
        margin: EdgeInsets.zero,
        primaryXAxis: CategoryAxis(
          labelStyle: TextStyle(color: _T.muted, fontSize: _Break.axisLabelSize(w)),
          axisLine: const AxisLine(color: _T.border),
          majorGridLines: const MajorGridLines(width: 0),
          majorTickLines: const MajorTickLines(size: 0),
          labelRotation: _Break.rotation(w).round(),
        ),
        primaryYAxis: _numAxis,
        tooltipBehavior: TooltipBehavior(
          enable: true,
          builder: (data, point, series, pointIndex, seriesIndex) {
            final d = data as _CD;
            return _tooltipCard([
              _tooltipTitle(d.label, color: _T.orange),
              _tooltipRow('Records', d.value.toInt().toString()),
              _tooltipRow('Share of filtered data',
                  '${_percentage(d.value.toInt(), _filtered.length).toStringAsFixed(1)}%'),
            ]);
          },
        ),
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
  }

  // ═══════════════════════════════════════════════════════
  // 2. AGE DISTRIBUTION
  // ═══════════════════════════════════════════════════════

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
          tooltipBehavior: TooltipBehavior(
            enable: true,
            builder: (data, point, series, pointIndex, seriesIndex) {
              final d = data as _CD;
              return _tooltipCard([
                _tooltipTitle('Age group ${d.label}', color: _T.purple),
                _tooltipRow('Records', d.value.toInt().toString()),
              ]);
            },
          ),
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

  // ═══════════════════════════════════════════════════════
  // 3. GENDER PIE
  // ═══════════════════════════════════════════════════════

  Widget _buildGenderPie() => _card(
        title: 'Gender Distribution',
        badge: 'Overview',
        badgeColor: _T.accent,
        subtitle: 'Overall male vs female split',
        child: SfCircularChart(
          backgroundColor: Colors.transparent,
          legend: Legend(
            isVisible: true,
            textStyle: const TextStyle(color: _T.sub, fontSize: 11),
            position: LegendPosition.bottom,
          ),
          tooltipBehavior: TooltipBehavior(
            enable: true,
            builder: (data, point, series, pointIndex, seriesIndex) {
              final d = data as _CD;
              return _tooltipCard([
                _tooltipTitle(d.label, color: _T.genderColor(d.label)),
                _tooltipRow('Records', d.value.toInt().toString()),
                _tooltipRow('Share',
                    '${_percentage(d.value.toInt(), _filtered.length).toStringAsFixed(1)}%'),
              ]);
            },
          ),
          series: [
            DoughnutSeries<_CD, String>(
              dataSource: _genderData,
              xValueMapper: (d, _) => d.label,
              yValueMapper: (d, _) => d.value,
              pointColorMapper: (d, _) => _T.genderColor(d.label),
              innerRadius: '55%',
              radius: '80%',
              dataLabelSettings: const DataLabelSettings(
                isVisible: true,
                textStyle:
                    TextStyle(color: _T.text, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

  // ═══════════════════════════════════════════════════════
  // 4. GENDER BY CAUSE
  // ═══════════════════════════════════════════════════════

  Widget _buildGenderByCause() {
    final w = MediaQuery.sizeOf(context).width;

    return _card(
      title: 'Gender by Disease',
      badge: 'Breakdown',
      badgeColor: _T.green,
      subtitle: 'Male vs Female per top cause · tap a bar for the full name',
      trailing: _genderLegend(),
      child: SfCartesianChart(
        backgroundColor: Colors.transparent,
        plotAreaBackgroundColor: Colors.transparent,
        margin: EdgeInsets.zero,
        primaryXAxis: CategoryAxis(
          labelStyle: TextStyle(color: _T.muted, fontSize: _Break.axisLabelSize(w)),
          axisLine: const AxisLine(color: _T.border),
          majorGridLines: const MajorGridLines(width: 0),
          majorTickLines: const MajorTickLines(size: 0),
          labelRotation: _Break.rotation(w).round(),
        ),
        primaryYAxis: _numAxis,
        legend: Legend(
          isVisible: true,
          textStyle: const TextStyle(color: _T.sub, fontSize: 10),
        ),
        tooltipBehavior: TooltipBehavior(
          enable: true,
          builder: (data, point, series, pointIndex, seriesIndex) {
            final d = data as _GD;
            return _tooltipCard([
              _tooltipTitle(d.cause),
              _tooltipRow('Male', d.male.toInt().toString(), valueColor: _T.male),
              _tooltipRow('Female', d.female.toInt().toString(), valueColor: _T.female),
              _tooltipRow('Total', (d.male + d.female).toInt().toString()),
            ]);
          },
        ),
        series: [
          StackedColumnSeries<_GD, String>(
            dataSource: _genderByCause,
            xValueMapper: (d, _) => _shorten(d.cause, 12),
            yValueMapper: (d, _) => d.male,
            name: 'Male',
            color: _T.male,
            borderRadius: BorderRadius.circular(3),
          ),
          StackedColumnSeries<_GD, String>(
            dataSource: _genderByCause,
            xValueMapper: (d, _) => _shorten(d.cause, 12),
            yValueMapper: (d, _) => d.female,
            name: 'Female',
            color: _T.female,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 5. COMORBIDITY
  // ═══════════════════════════════════════════════════════

  Widget _buildComorbid() => _card(
        title: 'Comorbidity Analysis',
        badge: 'Comorbidity',
        badgeColor: _T.red,
        subtitle: 'Prior conditions among deceased',
        child: _comorbidData.isEmpty
            ? _empty('No comorbidity data available')
            : SfCircularChart(
                backgroundColor: Colors.transparent,
                legend: Legend(
                  isVisible: true,
                  textStyle: const TextStyle(color: _T.sub, fontSize: 10),
                  overflowMode: LegendItemOverflowMode.wrap,
                  position: LegendPosition.bottom,
                ),
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  builder: (data, point, series, pointIndex, seriesIndex) {
                    final d = data as _CD;
                    return _tooltipCard([
                      _tooltipTitle(d.label),
                      _tooltipRow('Records', d.value.toInt().toString()),
                      _tooltipRow('Share',
                          '${_percentage(d.value.toInt(), _filtered.length).toStringAsFixed(1)}%'),
                    ]);
                  },
                ),
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

  // ═══════════════════════════════════════════════════════
  // 6. PLACE OF DEATH
  // ═══════════════════════════════════════════════════════

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
          tooltipBehavior: TooltipBehavior(
            enable: true,
            builder: (data, point, series, pointIndex, seriesIndex) {
              final d = data as _CD;
              return _tooltipCard([
                _tooltipTitle(d.label),
                _tooltipRow('Records', d.value.toInt().toString()),
              ]);
            },
          ),
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

  // ═══════════════════════════════════════════════════════
  // 7. AGE BY DISEASE (average)
  // ═══════════════════════════════════════════════════════

  Widget _buildAgeDiseaseChart() {
    final w = MediaQuery.sizeOf(context).width;

    return _card(
      title: 'Average Age at Death by Disease',
      badge: 'Age Analysis',
      badgeColor: _T.accent,
      subtitle:
          'Which diseases affect which age groups most · tap a bar for the full name',
      child: SfCartesianChart(
        backgroundColor: Colors.transparent,
        plotAreaBackgroundColor: Colors.transparent,
        margin: EdgeInsets.zero,
        primaryXAxis: CategoryAxis(
          labelStyle: TextStyle(color: _T.muted, fontSize: _Break.axisLabelSize(w)),
          axisLine: const AxisLine(color: _T.border),
          majorGridLines: const MajorGridLines(width: 0),
          majorTickLines: const MajorTickLines(size: 0),
          labelRotation: _Break.rotation(w).round(),
        ),
        primaryYAxis: NumericAxis(
          labelStyle: const TextStyle(color: _T.muted, fontSize: 10),
          axisLine: const AxisLine(color: _T.border),
          majorGridLines: MajorGridLines(
              color: _T.border.withOpacity(0.5), width: 0.5, dashArray: const [4, 4]),
          majorTickLines: const MajorTickLines(size: 0),
          minimum: 0,
          maximum: 90,
          title: AxisTitle(
              text: 'Average Age (years)',
              textStyle: const TextStyle(color: _T.muted, fontSize: 10)),
        ),
        tooltipBehavior: TooltipBehavior(
          enable: true,
          builder: (data, point, series, pointIndex, seriesIndex) {
            final d = data as _CD;
            return _tooltipCard([
              _tooltipTitle(d.label, color: _T.accent),
              _tooltipRow('Average age', '${d.value} years'),
            ]);
          },
        ),
        series: [
          BarSeries<_CD, String>(
            dataSource: _ageDiseaseData,
            xValueMapper: (d, _) => _shorten(d.label, 12),
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
  }

  // ═══════════════════════════════════════════════════════
  // 8. WATER SOURCE
  // ═══════════════════════════════════════════════════════

  Widget _buildWaterChart() => _card(
        title: 'Water Source Distribution',
        badge: 'Lifestyle',
        badgeColor: _T.green,
        subtitle:
            'Primary water source of deceased — lifestyle factor analysis',
        child: LayoutBuilder(
          builder: (ctx, box) {
            final wide = box.maxWidth > 500;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: wide ? 3 : 5,
                  child: SfCircularChart(
                    backgroundColor: Colors.transparent,
                    tooltipBehavior: TooltipBehavior(
                      enable: true,
                      builder: (data, point, series, pointIndex, seriesIndex) {
                        final d = data as _CD;
                        return _tooltipCard([
                          _tooltipTitle(d.label, color: _T.green),
                          _tooltipRow('Records', d.value.toInt().toString()),
                        ]);
                      },
                    ),
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
                          textStyle: TextStyle(
                              color: _T.text, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: wide ? 2 : 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _waterData
                        .asMap()
                        .entries
                        .map((e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _T.palette[e.key % _T.palette.length],
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(e.value.label,
                                        style: const TextStyle(color: _T.sub, fontSize: 11)),
                                  ),
                                  Text('${e.value.value.toInt()}',
                                      style: TextStyle(
                                          color: _T.palette[e.key % _T.palette.length],
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            );
          },
        ),
      );

  // ═══════════════════════════════════════════════════════
  // 9. DISEASE × COMORBIDITY BAR
  // ═══════════════════════════════════════════════════════

  Widget _buildDiseaseComorbidityChart() {
    final data = _diseaseComorbidityData.take(12).toList();
    final w = MediaQuery.sizeOf(context).width;

    if (data.isEmpty) {
      return _card(
        title: 'Disease × Comorbidity Association',
        badge: 'Deep Analysis',
        badgeColor: _T.red,
        subtitle: 'Which prior conditions are observed with each cause of death',
        child: _empty('No disease-comorbidity relationships available'),
      );
    }

    return _card(
      title: 'Disease × Comorbidity Association',
      badge: 'Deep Analysis',
      badgeColor: _T.red,
      subtitle:
          'Top observed disease + comorbidity relationships · tap a bar for full names',
      child: SizedBox(
        height: _Break.chartHeight(w),
        child: SfCartesianChart(
          backgroundColor: Colors.transparent,
          plotAreaBackgroundColor: Colors.transparent,
          margin: EdgeInsets.zero,
          primaryXAxis: CategoryAxis(
            labelStyle: TextStyle(color: _T.muted, fontSize: _Break.axisLabelSize(w)),
            labelRotation: _Break.rotation(w).round(),
            axisLine: const AxisLine(color: _T.border),
            majorGridLines: const MajorGridLines(width: 0),
            majorTickLines: const MajorTickLines(size: 0),
          ),
          primaryYAxis: _numAxis,
          tooltipBehavior: TooltipBehavior(
            enable: true,
            builder: (data, point, series, pointIndex, seriesIndex) {
              final d = data as _DC;
              return _tooltipCard([
                _tooltipTitle(d.disease, color: _T.red),
                _tooltipRow('Comorbidity', d.comorbidity),
                _tooltipRow('Records', d.count.toInt().toString()),
              ]);
            },
          ),
          series: [
            ColumnSeries<_DC, String>(
              dataSource: data,
              xValueMapper: (d, _) => _shorten('${d.disease} + ${d.comorbidity}', 22),
              yValueMapper: (d, _) => d.count,
              pointColorMapper: (d, i) => _T.palette[i % _T.palette.length],
              borderRadius: BorderRadius.circular(4),
              width: 0.65,
              dataLabelSettings: const DataLabelSettings(
                isVisible: true,
                textStyle: TextStyle(color: _T.sub, fontSize: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 10. DISEASE × COMORBIDITY HEATMAP
  // ═══════════════════════════════════════════════════════

  Widget _buildDiseaseComorbidityHeatmap() {
    final diseases = _heatmapDiseases;
    final conditions = _heatmapComorbidities;

    if (diseases.isEmpty || conditions.isEmpty) {
      return _card(
        title: 'Disease × Comorbidity Matrix',
        badge: 'Relationship',
        badgeColor: _T.pink,
        subtitle: 'Frequency of each comorbidity within each disease group',
        child: _empty('Not enough comorbidity information'),
      );
    }

    int maxValue = 1;
    for (final d in diseases) {
      for (final c in conditions) {
        final value = _diseaseComorbidityCount(d, c);
        if (value > maxValue) maxValue = value;
      }
    }

    return _card(
      title: 'Disease × Comorbidity Matrix',
      badge: 'Relationship',
      badgeColor: _T.pink,
      subtitle:
          'Darker cells = more mortality records with that disease + comorbidity together. Tap any cell or label for the full name.',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _matrixCell('Disease', width: 145, header: true),
                ...conditions.map((c) =>
                    _matrixCell(_shorten(c, 12), width: 88, header: true, fullText: c)),
              ],
            ),
            const SizedBox(height: 3),
            ...diseases.map((disease) {
              return Row(
                children: [
                  _matrixCell(_shorten(disease, 22),
                      width: 145, align: TextAlign.left, fullText: disease),
                  ...conditions.map((condition) {
                    final value = _diseaseComorbidityCount(disease, condition);
                    return _matrixValueCell(value, maxValue, disease, condition);
                  }),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _matrixCell(
    String text, {
    required double width,
    bool header = false,
    TextAlign align = TextAlign.center,
    String? fullText,
  }) {
    final cell = Container(
      width: width,
      height: 42,
      margin: const EdgeInsets.all(2),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: header ? _T.bg : _T.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _T.border),
      ),
      child: Text(
        text,
        textAlign: align,
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
        style: TextStyle(
          color: header ? _T.accent : _T.sub,
          fontSize: header ? 9 : 10,
          fontWeight: header ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );

    if (fullText == null || fullText == text) return cell;

    return Tooltip(
      message: fullText,
      triggerMode: TooltipTriggerMode.tap,
      preferBelow: false,
      textStyle: const TextStyle(color: _T.text, fontSize: 12),
      decoration: BoxDecoration(
        color: _T.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _T.border),
      ),
      child: cell,
    );
  }

  Widget _matrixValueCell(int value, int maxValue, String disease, String comorbidity) {
    final ratio = maxValue == 0 ? 0.0 : value / maxValue;

    final cell = Container(
      width: 88,
      height: 42,
      margin: const EdgeInsets.all(2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: value == 0 ? _T.bg : Color.lerp(_T.bg, _T.red, ratio.clamp(0.0, 1.0)),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _T.border),
      ),
      child: Text(
        '$value',
        style: TextStyle(
          color: value == 0 ? _T.border : _T.text,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    return Tooltip(
      message: '$disease + $comorbidity: $value records',
      triggerMode: TooltipTriggerMode.tap,
      preferBelow: false,
      textStyle: const TextStyle(color: _T.text, fontSize: 12),
      decoration: BoxDecoration(
        color: _T.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _T.border),
      ),
      child: cell,
    );
  }

  // ═══════════════════════════════════════════════════════
  // 11. DISEASE + COMORBIDITY COMBINATIONS
  // ═══════════════════════════════════════════════════════

  Widget _buildDiseaseCombinationTable() {
    final data = _diseaseCombinationData;

    return _card(
      title: 'High-Frequency Disease + Comorbidity Combinations',
      badge: 'Combination Analysis',
      badgeColor: _T.red,
      subtitle: 'Observed combinations appearing together in mortality records',
      child: data.isEmpty
          ? _empty('No disease-comorbidity combinations found')
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: _T.bg, borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      SizedBox(
                          width: 34,
                          child: Text('#',
                              style: TextStyle(
                                  color: _T.muted, fontSize: 10, fontWeight: FontWeight.bold))),
                      Expanded(
                          child: Text('Disease',
                              style: TextStyle(
                                  color: _T.muted, fontSize: 10, fontWeight: FontWeight.bold))),
                      Expanded(
                          flex: 2,
                          child: Text('Comorbidity / Combination',
                              style: TextStyle(
                                  color: _T.muted, fontSize: 10, fontWeight: FontWeight.bold))),
                      SizedBox(
                          width: 65,
                          child: Text('Records',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  color: _T.muted, fontSize: 10, fontWeight: FontWeight.bold))),
                      SizedBox(
                          width: 70,
                          child: Text('%',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  color: _T.muted, fontSize: 10, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                ...data.asMap().entries.map((entry) {
                  final index = entry.key;
                  final d = entry.value;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: _T.border.withOpacity(0.6))),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 34,
                          child: Text('${index + 1}',
                              style: TextStyle(
                                  color: index < 3 ? _T.red : _T.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          child: Text(_shorten(d.disease, 24),
                              style: const TextStyle(
                                  color: _T.text, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(d.combination,
                              style: const TextStyle(color: _T.sub, fontSize: 11)),
                        ),
                        SizedBox(
                          width: 65,
                          child: Text('${d.count.toInt()}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  color: _T.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        SizedBox(
                          width: 70,
                          child: Text('${d.percentage.toStringAsFixed(1)}%',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  color: _T.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Interpretation: these are high-frequency combinations in the mortality dataset; they should not be interpreted as causal risk without population-at-risk or comparison data.',
                    style: TextStyle(color: _T.muted, fontSize: 10, height: 1.4),
                  ),
                ),
              ],
            ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 12. COMORBIDITY PAIRS
  // ═══════════════════════════════════════════════════════

  Widget _buildComorbidityPairChart() {
    final data = _comorbidityCombinationData.take(10).toList();
    final w = MediaQuery.sizeOf(context).width;

    return _card(
      title: 'Comorbidity–Comorbidity Combinations',
      badge: 'Interaction',
      badgeColor: _T.pink,
      subtitle:
          'Which prior conditions frequently occur together · tap a bar for the full pair',
      child: data.isEmpty
          ? _empty('No multiple-comorbidity combinations available')
          : SizedBox(
              height: _Break.chartHeight(w),
              child: SfCartesianChart(
                backgroundColor: Colors.transparent,
                plotAreaBackgroundColor: Colors.transparent,
                margin: EdgeInsets.zero,
                primaryXAxis: CategoryAxis(
                  labelStyle: TextStyle(color: _T.muted, fontSize: _Break.axisLabelSize(w)),
                  labelRotation: _Break.rotation(w).round(),
                  axisLine: const AxisLine(color: _T.border),
                  majorGridLines: const MajorGridLines(width: 0),
                  majorTickLines: const MajorTickLines(size: 0),
                ),
                primaryYAxis: _numAxis,
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  builder: (data, point, series, pointIndex, seriesIndex) {
                    final d = data as _CC;
                    return _tooltipCard([
                      _tooltipTitle(d.combination, color: _T.pink),
                      _tooltipRow('Records', d.count.toInt().toString()),
                      _tooltipRow('Share of filtered records',
                          '${d.percentage.toStringAsFixed(1)}%'),
                    ]);
                  },
                ),
                series: [
                  ColumnSeries<_CC, String>(
                    dataSource: data,
                    xValueMapper: (d, _) => _shorten(d.combination, 22),
                    yValueMapper: (d, _) => d.count,
                    pointColorMapper: (d, i) => _T.palette[i % _T.palette.length],
                    borderRadius: BorderRadius.circular(4),
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      textStyle: TextStyle(color: _T.sub, fontSize: 8),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 13. DISEASE × AGE
  // ═══════════════════════════════════════════════════════

  Widget _buildDiseaseAgeChart() {
    final data = _diseaseAgeData.take(15).toList();
    final w = MediaQuery.sizeOf(context).width;

    if (data.isEmpty) {
      return _card(
        title: 'Disease × Age Group',
        badge: 'Age Relationship',
        badgeColor: _T.purple,
        subtitle: 'Age groups where each disease appears most often',
        child: _empty('No valid age/disease relationship available'),
      );
    }

    return _card(
      title: 'Disease × Age Group',
      badge: 'Age Relationship',
      badgeColor: _T.purple,
      subtitle:
          'Observed mortality records by disease and age group · tap a bar for details',
      child: SizedBox(
        height: _Break.chartHeight(w),
        child: SfCartesianChart(
          backgroundColor: Colors.transparent,
          plotAreaBackgroundColor: Colors.transparent,
          margin: EdgeInsets.zero,
          primaryXAxis: CategoryAxis(
            labelStyle: TextStyle(color: _T.muted, fontSize: _Break.axisLabelSize(w)),
            labelRotation: _Break.rotation(w).round(),
            axisLine: const AxisLine(color: _T.border),
            majorGridLines: const MajorGridLines(width: 0),
            majorTickLines: const MajorTickLines(size: 0),
          ),
          primaryYAxis: _numAxis,
          tooltipBehavior: TooltipBehavior(
            enable: true,
            builder: (data, point, series, pointIndex, seriesIndex) {
              final d = data as _DA;
              return _tooltipCard([
                _tooltipTitle(d.disease, color: _T.purple),
                _tooltipRow('Age group', d.ageGroup),
                _tooltipRow('Records', d.count.toInt().toString()),
              ]);
            },
          ),
          series: [
            ColumnSeries<_DA, String>(
              dataSource: data,
              xValueMapper: (d, _) => _shorten('${d.disease} / ${d.ageGroup}', 22),
              yValueMapper: (d, _) => d.count,
              pointColorMapper: (d, i) => _T.palette[i % _T.palette.length],
              borderRadius: BorderRadius.circular(4),
              dataLabelSettings: const DataLabelSettings(
                isVisible: true,
                textStyle: TextStyle(color: _T.sub, fontSize: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 14. WATER × DISEASE
  // ═══════════════════════════════════════════════════════

  Widget _buildWaterDiseaseChart() {
    final data = _diseaseWaterData.take(15).toList();
    final w = MediaQuery.sizeOf(context).width;

    return _card(
      title: 'Disease × Water Source',
      badge: 'Environmental',
      badgeColor: _T.accent,
      subtitle:
          'Observed relationship between causes of death and recorded water sources · tap for details',
      child: data.isEmpty
          ? _empty('No water-source/disease relationship available')
          : SizedBox(
              height: _Break.chartHeight(w),
              child: SfCartesianChart(
                backgroundColor: Colors.transparent,
                plotAreaBackgroundColor: Colors.transparent,
                margin: EdgeInsets.zero,
                primaryXAxis: CategoryAxis(
                  labelStyle: TextStyle(color: _T.muted, fontSize: _Break.axisLabelSize(w)),
                  labelRotation: _Break.rotation(w).round(),
                  axisLine: const AxisLine(color: _T.border),
                  majorGridLines: const MajorGridLines(width: 0),
                  majorTickLines: const MajorTickLines(size: 0),
                ),
                primaryYAxis: _numAxis,
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  builder: (data, point, series, pointIndex, seriesIndex) {
                    final d = data as _DW;
                    return _tooltipCard([
                      _tooltipTitle(d.disease, color: _T.accent),
                      _tooltipRow('Water source', d.water),
                      _tooltipRow('Records', d.count.toInt().toString()),
                    ]);
                  },
                ),
                series: [
                  ColumnSeries<_DW, String>(
                    dataSource: data,
                    xValueMapper: (d, _) => _shorten('${d.disease} / ${d.water}', 22),
                    yValueMapper: (d, _) => d.count,
                    pointColorMapper: (d, i) => _T.palette[i % _T.palette.length],
                    borderRadius: BorderRadius.circular(4),
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      textStyle: TextStyle(color: _T.sub, fontSize: 8),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 15. PLACE × DISEASE
  // ═══════════════════════════════════════════════════════

  Widget _buildPlaceDiseaseChart() {
    final data = _diseasePlaceData.take(15).toList();
    final w = MediaQuery.sizeOf(context).width;

    return _card(
      title: 'Disease × Place of Death',
      badge: 'Location Analysis',
      badgeColor: _T.orange,
      subtitle:
          'Where specific causes of death are most frequently recorded · tap for details',
      child: data.isEmpty
          ? _empty('No disease/place relationship available')
          : SizedBox(
              height: _Break.chartHeight(w),
              child: SfCartesianChart(
                backgroundColor: Colors.transparent,
                plotAreaBackgroundColor: Colors.transparent,
                margin: EdgeInsets.zero,
                primaryXAxis: CategoryAxis(
                  labelStyle: TextStyle(color: _T.muted, fontSize: _Break.axisLabelSize(w)),
                  labelRotation: _Break.rotation(w).round(),
                  axisLine: const AxisLine(color: _T.border),
                  majorGridLines: const MajorGridLines(width: 0),
                  majorTickLines: const MajorTickLines(size: 0),
                ),
                primaryYAxis: _numAxis,
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  builder: (data, point, series, pointIndex, seriesIndex) {
                    final d = data as _DP;
                    return _tooltipCard([
                      _tooltipTitle(d.disease, color: _T.orange),
                      _tooltipRow('Place of death', d.place),
                      _tooltipRow('Records', d.count.toInt().toString()),
                    ]);
                  },
                ),
                series: [
                  ColumnSeries<_DP, String>(
                    dataSource: data,
                    xValueMapper: (d, _) => _shorten('${d.disease} / ${d.place}', 22),
                    yValueMapper: (d, _) => d.count,
                    pointColorMapper: (d, i) => _T.palette[i % _T.palette.length],
                    borderRadius: BorderRadius.circular(4),
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      textStyle: TextStyle(color: _T.sub, fontSize: 8),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 16. DISEASE × GENDER
  // ═══════════════════════════════════════════════════════

  Widget _buildGenderDiseaseAnalysis() {
    final data = _diseaseGenderData.take(15).toList();
    final w = MediaQuery.sizeOf(context).width;

    return _card(
      title: 'Disease × Gender Association',
      badge: 'Demographic',
      badgeColor: _T.green,
      subtitle:
          'Observed mortality records by disease and gender · tap a bar for details',
      trailing: _genderLegend(includeOther: true),
      child: data.isEmpty
          ? _empty('No disease/gender relationship available')
          : SizedBox(
              height: _Break.chartHeight(w),
              child: SfCartesianChart(
                backgroundColor: Colors.transparent,
                plotAreaBackgroundColor: Colors.transparent,
                margin: EdgeInsets.zero,
                primaryXAxis: CategoryAxis(
                  labelStyle: TextStyle(color: _T.muted, fontSize: _Break.axisLabelSize(w)),
                  labelRotation: _Break.rotation(w).round(),
                  axisLine: const AxisLine(color: _T.border),
                  majorGridLines: const MajorGridLines(width: 0),
                  majorTickLines: const MajorTickLines(size: 0),
                ),
                primaryYAxis: _numAxis,
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  builder: (data, point, series, pointIndex, seriesIndex) {
                    final d = data as _DG;
                    return _tooltipCard([
                      _tooltipTitle(d.disease, color: _T.genderColor(d.gender)),
                      _tooltipRow('Gender', d.gender,
                          valueColor: _T.genderColor(d.gender)),
                      _tooltipRow('Records', d.count.toInt().toString()),
                    ]);
                  },
                ),
                series: [
                  ColumnSeries<_DG, String>(
                    dataSource: data,
                    xValueMapper: (d, _) => _shorten('${d.disease} / ${d.gender}', 22),
                    yValueMapper: (d, _) => d.count,
                    pointColorMapper: (d, i) => _T.genderColor(d.gender),
                    borderRadius: BorderRadius.circular(4),
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      textStyle: TextStyle(color: _T.sub, fontSize: 8),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 17. CITY DISEASE TREND
  // ═══════════════════════════════════════════════════════
Widget _buildCityDiseaseTrend() {
  final td = _cityDiseaseTrend;
  final ratio = _cityTrendRatio(td);

  final loc = (_trendLocality ?? '').trim();

  final selectedDisease = _trendDisease == 'Other'
      ? _trendOtherDiseaseCtrl.text.trim()
      : (_trendDisease ?? '').trim();

  final hasData = td.any((t) => t.count > 0);

  final isUp =
      td.length >= 2 && td.last.count > td.first.count;

  final diseaseOptions = [
    ..._allDiseases.where(
      (d) => d.trim().toLowerCase() != 'other',
    ),
    'Other',
  ];

  return _card(
    title: 'Disease Trend by City / Year',
    badge: 'Localized Trend',
    badgeColor: _T.orange,
    subtitle:
        'Select a disease and specific locality to see year-by-year change',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (ctx, box) {
            final wide = box.maxWidth > _Break.mobile;

            // ---------------------------------------------
            // Disease dropdown
            // ---------------------------------------------
            final diseaseField =
                DropdownButtonFormField<String>(
              value: _trendDisease,
              dropdownColor: _T.surface,
              style: const TextStyle(
                color: _T.text,
                fontSize: 12,
              ),
              decoration: _deco('Select Disease'),
              isExpanded: true,
              items: diseaseOptions
                  .map(
                    (d) => DropdownMenuItem<String>(
                      value: d,
                      child: Text(
                        d,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _trendDisease = v;

                  // Clear custom disease whenever
                  // a normal disease is selected.
                  if (v != 'Other') {
                    _trendOtherDiseaseCtrl.clear();
                  }
                });
              },
            );

            // ---------------------------------------------
            // Other disease text field
            // ---------------------------------------------
            final otherDiseaseField =
                _trendDisease == 'Other'
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: TextFormField(
                          controller: _trendOtherDiseaseCtrl,
                          style: const TextStyle(
                            color: _T.text,
                            fontSize: 12,
                          ),
                          decoration:
                              _deco('Enter disease name…'),
                          textInputAction:
                              TextInputAction.done,
                          onChanged: (_) {
                            setState(() {});
                          },
                        ),
                      )
                    : const SizedBox.shrink();

            // ---------------------------------------------
            // Specific locality dropdown
            // ---------------------------------------------
            final localityField =
                DropdownButtonFormField<String>(
              value: _trendLocality,
              dropdownColor: _T.surface,
              style: const TextStyle(
                color: _T.text,
                fontSize: 12,
              ),
              decoration:
                  _deco('Select City / Village'),
              isExpanded: true,
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text(
                    'All Localities',
                    style: TextStyle(
                      color: _T.muted,
                    ),
                  ),
                ),
                ..._trendLocalities.map(
                  (locality) =>
                      DropdownMenuItem<String>(
                    value: locality,
                    child: Text(
                      locality,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _trendLocality = value;
                });
              },
            );

            // ---------------------------------------------
            // Responsive layout
            // ---------------------------------------------
            if (wide) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: diseaseField,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: localityField,
                      ),
                    ],
                  ),
                  otherDiseaseField,
                ],
              );
            }

            return Column(
              children: [
                diseaseField,
                const SizedBox(height: 10),
                localityField,
                otherDiseaseField,
              ],
            );
          },
        ),

        const SizedBox(height: 16),

        // -----------------------------------------------
        // Statistics
        // -----------------------------------------------
        if (td.length >= 2 && hasData) ...[
          LayoutBuilder(
            builder: (ctx, box) {
              final narrow = box.maxWidth < 480;

              final pills = [
                _statPill(
                  'Change',
                  ratio,
                  isUp ? _T.red : _T.green,
                ),
                _statPill(
                  'Peak Year',
                  td
                      .reduce(
                        (a, b) =>
                            a.count > b.count ? a : b,
                      )
                      .year,
                  _T.accent,
                ),
                _statPill(
                  'Latest (${_years.isNotEmpty ? _years.last : "—"})',
                  '${td.isEmpty ? 0 : td.last.count.toInt()} deaths',
                  isUp ? _T.red : _T.green,
                ),
              ];

              if (narrow) {
                return Column(
                  children: pills
                      .map(
                        (p) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: 8),
                          child: p,
                        ),
                      )
                      .toList(),
                );
              }

              return Row(
                children: [
                  for (int i = 0;
                      i < pills.length;
                      i++) ...[
                    pills[i],
                    if (i != pills.length - 1)
                      const SizedBox(width: 10),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 14),
        ],

        // -----------------------------------------------
        // Current selection label
        // -----------------------------------------------
        if (selectedDisease.isNotEmpty &&
            loc.isNotEmpty)
          Padding(
            padding:
                const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.place_rounded,
                  size: 13,
                  color: _T.orange,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Showing: $selectedDisease in "$loc"',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _T.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (selectedDisease.isNotEmpty)
          Padding(
            padding:
                const EdgeInsets.only(bottom: 10),
            child: Text(
              'Showing all localities for $selectedDisease · select a city / village above to localize',
              style: const TextStyle(
                color: _T.muted,
                fontSize: 11,
              ),
            ),
          ),

        // -----------------------------------------------
        // Empty state
        // -----------------------------------------------
        !hasData &&
                selectedDisease.isNotEmpty
            ? _empty(
                loc.isNotEmpty
                    ? 'No data for "$selectedDisease" in "$loc"'
                    : 'No data found for "$selectedDisease"',
              )
            : SfCartesianChart(
                backgroundColor: Colors.transparent,
                plotAreaBackgroundColor:
                    Colors.transparent,
                margin: EdgeInsets.zero,
                primaryXAxis: _catAxis,
                primaryYAxis: NumericAxis(
                  labelStyle:
                      const TextStyle(
                    color: _T.muted,
                    fontSize: 10,
                  ),
                  axisLine:
                      const AxisLine(
                    color: _T.border,
                  ),
                  majorGridLines:
                      MajorGridLines(
                    color:
                        _T.border.withOpacity(0.5),
                    width: 0.5,
                    dashArray: const [4, 4],
                  ),
                  majorTickLines:
                      const MajorTickLines(size: 0),
                  title: AxisTitle(
                    text: 'Deaths per year',
                    textStyle:
                        const TextStyle(
                      color: _T.muted,
                      fontSize: 10,
                    ),
                  ),
                ),
                tooltipBehavior:
                    TooltipBehavior(
                  enable: true,
                  header: selectedDisease,
                  color: _T.surface,
                  textStyle:
                      const TextStyle(
                    color: _T.text,
                    fontSize: 11,
                  ),
                  borderColor: _T.border,
                  borderWidth: 1,
                ),
                series: [
                  SplineAreaSeries<_TD, String>(
                    dataSource: td,
                    xValueMapper: (d, _) =>
                        d.year,
                    yValueMapper: (d, _) =>
                        d.count,
                    color: _T.orange
                        .withOpacity(0.12),
                    borderColor: _T.orange,
                    borderWidth: 2.5,
                    splineType:
                        SplineType.cardinal,
                    markerSettings:
                        const MarkerSettings(
                      isVisible: true,
                      color: _T.orange,
                      borderColor:
                          _T.surface,
                      borderWidth: 2,
                      height: 8,
                      width: 8,
                    ),
                    dataLabelSettings:
                        const DataLabelSettings(
                      isVisible: true,
                      textStyle:
                          TextStyle(
                        color: _T.sub,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
      ],
    ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(color: _T.muted, fontSize: 10)),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );

  // ═══════════════════════════════════════════════════════
  // 18. GLOBAL TREND
  // ═══════════════════════════════════════════════════════

  Widget _buildGlobalTrend() {
    if (_topDiseases.isEmpty || _years.isEmpty) {
      return _empty('Not enough data');
    }

    final datasets = _topDiseases
        .asMap()
        .entries
        .map((e) => SplineSeries<_TD, String>(
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
                height: 6,
                width: 6,
              ),
            ))
        .toList();

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
          enable: true,
          shared: true,
          color: _T.surface,
          textStyle: const TextStyle(color: _T.text, fontSize: 11),
          borderColor: _T.border,
          borderWidth: 1,
        ),
        series: datasets,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // EMPTY
  // ═══════════════════════════════════════════════════════

  Widget _empty(String msg) => Container(
        height: 120,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart_rounded, color: _T.border, size: 36),
            const SizedBox(height: 8),
            Text(msg,
                style: const TextStyle(color: _T.muted, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
      );
}