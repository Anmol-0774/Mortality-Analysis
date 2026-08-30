import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _T {
  static const bg = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const surface2 = Color(0xFF243044);
  static const border = Color(0xFF334155);
  static const muted = Color(0xFF94A3B8);
  static const sub = Color(0xFFCBD5E1);
  static const text = Color(0xFFF1F5F9);
  static const accent = Color(0xFF38BDF8);
  static const green = Color(0xFF34D399);
  static const purple = Color(0xFF818CF8);
  static const orange = Color(0xFFFB923C);
  static const red = Color(0xFFF87171);
  // ignore: unused_field
  static const pink = Color(0xFFF472B6);
}

// ═══════════════════════════════════════════════════════
//  MAIN PAGE — REPORTS ONLY (no AI / chatbot code)
// ═══════════════════════════════════════════════════════

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      appBar: null,
      body: SafeArea(
        child: Column(
          children: [
            // ── Back button (same top-left navigation style as other pages)
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: _T.text,
                    size: 18,
                  ),
                ),
              ),
            ),
            const Expanded(
              child: _ReportsTab(),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  REPORTS
// ═══════════════════════════════════════════════════════

class _ReportsTab extends StatefulWidget {
  const _ReportsTab();

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  final _sb = Supabase.instance.client;

  // ── Stats loaded from DB
  int _total = 0;
  int _valid = 0;
  int _flagged = 0;

  String _topCause = '—';
  String _topDistrict = '—';
  String _topLocality = '—';

  double _avgAge = 0;

  int _maleCount = 0;
  int _femaleCount = 0;

  Map<String, int> _causeMap = {};
  Map<String, int> _districtMap = {};
  Map<String, int> _monthlyMap = {};
  Map<String, int> _yearlyMap = {};

  bool _loading = true;
  String? _error;

  int? _selYear;
  int? _selMonth;

  final List<int> _years = [];
  final List<int> _months = List.generate(12, (i) => i + 1);

  static const _monthNames = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ═══════════════════════════════════════════════════════
  // LOAD DATA FROM SUPABASE
  // ═══════════════════════════════════════════════════════

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _sb
          .from('mortality_records_clean')
          .select(
            'age,gender,district,specific_locality,cause_of_death,'
            'date_of_death,quality_score',
          )
          .gte('quality_score', 60)
          .limit(10000);

      final data = List<Map<String, dynamic>>.from(res as List);

      // ── Basic counts
      _total = data.length;

      _maleCount = data.where((r) => r['gender']?.toString() == 'Male').length;

      _femaleCount =
          data.where((r) => r['gender']?.toString() == 'Female').length;

      // ── Quality tiers. Both are already inside the >= 60 filter above —
      // this just splits records into higher- vs lower-confidence buckets.
      _valid = data.where((r) {
        final q = r['quality_score'];
        return q is num && q >= 80;
      }).length;

      _flagged = data.where((r) {
        final q = r['quality_score'];
        return q is num && q < 80;
      }).length;

      // ── Average age
      final ages = data
          .map((r) {
            final value = r['age'];

            if (value is int) {
              return value;
            }

            return int.tryParse(value?.toString() ?? '');
          })
          .whereType<int>()
          .where((a) => a > 0 && a < 120)
          .toList();

      _avgAge = ages.isEmpty ? 0 : ages.reduce((a, b) => a + b) / ages.length;

      // ═══════════════════════════════════════════════════
      // CAUSE MAP
      // ═══════════════════════════════════════════════════

      _causeMap = {};

      for (final r in data) {
        final c = r['cause_of_death']?.toString() ?? '';

        if (c.isNotEmpty && c != 'Unspecified' && c != 'Unknown') {
          _causeMap[c] = (_causeMap[c] ?? 0) + 1;
        }
      }

      if (_causeMap.isNotEmpty) {
        _topCause = (_causeMap.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;
      }

      // ═══════════════════════════════════════════════════
      // DISTRICT MAP
      // ═══════════════════════════════════════════════════

      _districtMap = {};

      for (final r in data) {
        final d = r['district']?.toString() ?? '';

        if (d.isNotEmpty && d != 'Unknown') {
          _districtMap[d] = (_districtMap[d] ?? 0) + 1;
        }
      }

      if (_districtMap.isNotEmpty) {
        _topDistrict = (_districtMap.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;
      }

      // ═══════════════════════════════════════════════════
      // LOCALITY MAP
      // ═══════════════════════════════════════════════════

      final locMap = <String, int>{};

      for (final r in data) {
        final l = r['specific_locality']?.toString() ?? '';

        if (l.isNotEmpty && l != 'Not Specified') {
          locMap[l] = (locMap[l] ?? 0) + 1;
        }
      }

      if (locMap.isNotEmpty) {
        _topLocality = (locMap.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;
      }

      // ═══════════════════════════════════════════════════
      // MONTHLY + YEARLY MAPS
      // ═══════════════════════════════════════════════════

      _monthlyMap = {};
      _yearlyMap = {};

      final yearSet = <int>{};

      for (final r in data) {
        final dateStr = r['date_of_death']?.toString() ?? '';

        if (dateStr.length >= 7) {
          final year = int.tryParse(dateStr.substring(0, 4));
          final month = int.tryParse(dateStr.substring(5, 7));

          if (year != null) {
            yearSet.add(year);

            _yearlyMap[year.toString()] = (_yearlyMap[year.toString()] ?? 0) + 1;
          }

          if (year != null && month != null) {
            final key = '$year-${month.toString().padLeft(2, '0')}';

            _monthlyMap[key] = (_monthlyMap[key] ?? 0) + 1;
          }
        }
      }

      _years.clear();

      _years.addAll(yearSet.toList()..sort());

      if (_selYear == null && _years.isNotEmpty) {
        _selYear = _years.last;
      }

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ═══════════════════════════════════════════════════════
  // BUILD REPORT TEXT
  // ═══════════════════════════════════════════════════════

  String _buildReportText({required String type}) {
    final now = DateTime.now();

    final buffer = StringBuffer();

    buffer.writeln('═══════════════════════════════════════════════');
    buffer.writeln('       MORTALITY ANALYSIS SYSTEM');
    buffer.writeln('       $type');
    buffer.writeln(
      '       Generated: ${now.day}/${now.month}/${now.year}  '
      '${now.hour}:${now.minute.toString().padLeft(2, '0')}',
    );
    buffer.writeln('═══════════════════════════════════════════════');

    buffer.writeln();

    // ═══════════════════════════════════════════════════
    // MONTHLY REPORT
    // ═══════════════════════════════════════════════════

    if (type.contains('Monthly') && _selYear != null && _selMonth != null) {
      buffer.writeln('PERIOD: ${_monthNames[_selMonth!]} $_selYear');

      final key = '$_selYear-${_selMonth.toString().padLeft(2, '0')}';

      final monthDeaths = _monthlyMap[key] ?? 0;

      buffer.writeln('Total Deaths This Month: $monthDeaths');

      buffer.writeln();

      buffer.writeln('MONTHLY BREAKDOWN (all months of $_selYear):');

      for (int m = 1; m <= 12; m++) {
        final k = '$_selYear-${m.toString().padLeft(2, '0')}';

        final v = _monthlyMap[k] ?? 0;

        buffer.writeln('  ${_monthNames[m].padRight(12)}: $v deaths');
      }
    }
    // ═══════════════════════════════════════════════════
    // YEARLY REPORT
    // ═══════════════════════════════════════════════════
    else if (type.contains('Yearly') && _selYear != null) {
      buffer.writeln('PERIOD: $_selYear');

      buffer.writeln(
        'Total Deaths in $_selYear: '
        '${_yearlyMap[_selYear.toString()] ?? 0}',
      );

      buffer.writeln();

      buffer.writeln('YEARLY COMPARISON:');

      for (final e
          in (_yearlyMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))) {
        buffer.writeln('  ${e.key}: ${e.value} deaths');
      }
    }
    // ═══════════════════════════════════════════════════
    // OVERVIEW REPORT
    // ═══════════════════════════════════════════════════
    else {
      buffer.writeln('OVERVIEW STATISTICS:');

      buffer.writeln('  Total Records   : $_total');

      buffer.writeln('  Valid Records   : $_valid');

      buffer.writeln('  Flagged Records : $_flagged');

      buffer.writeln('  Average Age     : ${_avgAge.toStringAsFixed(1)} years');

      buffer.writeln('  Male Deaths     : $_maleCount');

      buffer.writeln('  Female Deaths   : $_femaleCount');

      buffer.writeln();

      buffer.writeln('TOP CAUSE OF DEATH: $_topCause');

      buffer.writeln('TOP DISTRICT      : $_topDistrict');

      buffer.writeln('TOP LOCALITY      : $_topLocality');
    }

    // ═══════════════════════════════════════════════════
    // TOP CAUSES
    // ═══════════════════════════════════════════════════

    buffer.writeln();

    buffer.writeln('TOP 10 CAUSES OF DEATH:');

    final sortedCauses =
        (_causeMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .take(10);

    for (final e in sortedCauses) {
      buffer.writeln('  ${e.key.padRight(28)}: ${e.value}');
    }

    // ═══════════════════════════════════════════════════
    // DISTRICT BREAKDOWN
    // ═══════════════════════════════════════════════════

    buffer.writeln();

    buffer.writeln('DEATHS BY DISTRICT:');

    final sortedDistricts = (_districtMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)));

    for (final e in sortedDistricts) {
      buffer.writeln('  ${e.key.padRight(20)}: ${e.value}');
    }

    buffer.writeln();

    buffer.writeln('═══════════════════════════════════════════════');

    buffer.writeln('END OF REPORT — Mortality Analysis System');

    buffer.writeln('═══════════════════════════════════════════════');

    return buffer.toString();
  }

  // ═══════════════════════════════════════════════════════
  // SHOW REPORT
  // ═══════════════════════════════════════════════════════

  void _showReport(String type) {
    final content = _buildReportText(type: type);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _T.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          width: 640,
          height: MediaQuery.of(context).size.height * 0.82,
          child: Column(
            children: [
              // ── Dialog header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: _T.border),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _T.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.description_rounded,
                        color: _T.accent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type,
                            style: const TextStyle(
                              color: _T.text,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const Text(
                            'Generated from live database',
                            style: TextStyle(
                              color: _T.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: _T.muted,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // ── Report content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    content,
                    style: const TextStyle(
                      color: _T.sub,
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.7,
                    ),
                  ),
                ),
              ),

              // ── Bottom actions
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: _T.border),
                  ),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Report generated from mortality_records_clean.',
                        style: TextStyle(
                          color: _T.muted,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.check_rounded,
                        size: 15,
                      ),
                      label: const Text('Done'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _T.accent,
                        foregroundColor: _T.bg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // PDF EXPORT
  // ═══════════════════════════════════════════════════════

  Future<void> exportToPdf() async {
    try {
      final pdf = pw.Document();

      final reportText = _buildReportText(type: 'Mortality Analysis Report');

      pdf.addPage(
        pw.MultiPage(
          build: (pwContext) => [
            pw.Text(
              'MORTALITY ANALYSIS SYSTEM',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Generated: '
              '${DateTime.now().day}/'
              '${DateTime.now().month}/'
              '${DateTime.now().year}',
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              reportText,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();

      final file = XFile.fromData(
        Uint8List.fromList(bytes),
        name: 'mortality_report.pdf',
        mimeType: 'application/pdf',
      );

      await Share.shareXFiles(
        [file],
        text: 'Mortality Analysis PDF Report',
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $e'),
          backgroundColor: _T.red,
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: _T.accent,
          strokeWidth: 2,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: _T.red,
              size: 48,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _T.muted,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: _T.accent,
                foregroundColor: _T.bg,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ═══════════════════════════════════════════════
          // SUMMARY BANNER
          // ═══════════════════════════════════════════════
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _T.accent.withValues(alpha: 0.12),
                  _T.purple.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _T.accent.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reports & Export',
                        style: TextStyle(
                          color: _T.text,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Generate detailed mortality reports '
                        'from your live Supabase database.',
                        style: TextStyle(
                          color: _T.muted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 10,
                        children: [
                          _stat('Total Records', '$_total', _T.accent),
                          _stat('Top Cause', _topCause, _T.orange),
                          _stat('Top District', _topDistrict, _T.purple),
                          _stat(
                            'Avg Age',
                            '${_avgAge.toStringAsFixed(1)} yrs',
                            _T.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.summarize_rounded,
                  size: 60,
                  color: _T.accent.withValues(alpha: 0.25),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ═══════════════════════════════════════════════
          // QUICK EXPORT
          // ═══════════════════════════════════════════════
          _secLabel('Quick Export'),

          LayoutBuilder(
            builder: (ctx, box) {
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _exportBtn(
                    Icons.picture_as_pdf_rounded,
                    'Download PDF Report',
                    'Generate mortality report as PDF',
                    _T.purple,
                    () async {
                      await exportToPdf();
                    },
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // ═══════════════════════════════════════════════
          // MONTHLY REPORT
          // ═══════════════════════════════════════════════
          _secLabel('Monthly Report'),

          _card(
            'Generate Monthly Report',
            Icons.calendar_month_rounded,
            _T.purple,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select year and month to generate a focused '
                  'monthly mortality report.',
                  style: TextStyle(color: _T.muted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _dropField<int>(
                        'Year',
                        _years,
                        _selYear,
                        (v) => setState(() => _selYear = v),
                        itemLabel: (v) => v.toString(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dropField<int>(
                        'Month',
                        _months,
                        _selMonth,
                        (v) => setState(() => _selMonth = v),
                        itemLabel: (v) => _monthNames[v],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _selYear != null && _selMonth != null
                          ? () => _showReport(
                                'Monthly Report — '
                                '${_monthNames[_selMonth!]} '
                                '$_selYear',
                              )
                          : null,
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text(
                        'Generate',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _T.purple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_selYear != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'MONTHLY DEATHS THIS YEAR',
                    style: TextStyle(
                      color: _T.muted,
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(12, (i) {
                      final m = i + 1;

                      final key = '$_selYear-${m.toString().padLeft(2, '0')}';

                      final count = _monthlyMap[key] ?? 0;

                      final isSelected = _selMonth == m;

                      return GestureDetector(
                        onTap: () => setState(() => _selMonth = m),
                        child: Container(
                          width: 70,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _T.purple.withValues(alpha: 0.2)
                                : _T.bg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? _T.purple : _T.border,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _monthNames[m].substring(0, 3),
                                style: TextStyle(
                                  color: isSelected ? _T.purple : _T.muted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$count',
                                style: TextStyle(
                                  color: isSelected
                                      ? _T.purple
                                      : count > 0
                                          ? _T.text
                                          : _T.muted,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ═══════════════════════════════════════════════
          // YEARLY REPORT
          // ═══════════════════════════════════════════════
          _secLabel('Yearly Report'),

          _card(
            'Generate Yearly Report',
            Icons.bar_chart_rounded,
            _T.orange,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select a year to generate a comprehensive '
                  'annual mortality report.',
                  style: TextStyle(color: _T.muted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    SizedBox(
                      width: 160,
                      child: _dropField<int>(
                        'Year',
                        _years,
                        _selYear,
                        (v) => setState(() => _selYear = v),
                        itemLabel: (v) => v.toString(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _selYear != null
                          ? () => _showReport('Yearly Report — $_selYear')
                          : null,
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text(
                        'Generate',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _T.orange,
                        foregroundColor: _T.bg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'YEAR-BY-YEAR DEATHS',
                  style: TextStyle(
                    color: _T.muted,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                ...((_yearlyMap.entries.toList()
                      ..sort((a, b) => a.key.compareTo(b.key)))
                    .map((e) {
                  final maxVal = _yearlyMap.values.fold(
                    0,
                    (a, b) => a > b ? a : b,
                  );

                  final pct = maxVal > 0 ? e.value / maxVal : 0.0;

                  final isSel = e.key == _selYear?.toString();

                  return GestureDetector(
                    onTap: () => setState(() => _selYear = int.tryParse(e.key)),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSel
                            ? _T.orange.withValues(alpha: 0.08)
                            : _T.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSel ? _T.orange : _T.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 50,
                            child: Text(
                              e.key,
                              style: TextStyle(
                                color: isSel ? _T.orange : _T.sub,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 8,
                                backgroundColor: _T.border,
                                valueColor: AlwaysStoppedAnimation(
                                  isSel ? _T.orange : _T.accent,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${e.value} deaths',
                            style: TextStyle(
                              color: isSel ? _T.orange : _T.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                })),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // STAT WIDGET
  // ═══════════════════════════════════════════════════════

  Widget _stat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: _T.muted, fontSize: 10),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // SECTION LABEL
  // ═══════════════════════════════════════════════════════

  Widget _secLabel(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: _T.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            t.toUpperCase(),
            style: const TextStyle(
              color: _T.muted,
              fontSize: 10,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // EXPORT BUTTON
  // ═══════════════════════════════════════════════════════

  Widget _exportBtn(
    IconData icon,
    String label,
    String sub,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: _T.text,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sub,
                    style: const TextStyle(color: _T.muted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // CARD
  // ═══════════════════════════════════════════════════════

  Widget _card(String title, IconData icon, Color color, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _T.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _T.border)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: _T.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: child,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // DROPDOWN
  // ═══════════════════════════════════════════════════════

  Widget _dropField<T>(
    String hint,
    List<T> items,
    T? val,
    void Function(T?) onChange, {
    required String Function(T) itemLabel,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: val,
      dropdownColor: _T.surface,
      style: const TextStyle(color: _T.text, fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _T.muted, fontSize: 12),
        filled: true,
        fillColor: _T.bg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _T.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: _T.accent),
        ),
      ),
      isExpanded: true,
      items: items
          .map(
            (v) => DropdownMenuItem<T>(
              value: v,
              child: Text(itemLabel(v)),
            ),
          )
          .toList(),
      onChanged: onChange,
    );
  }
}