import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:excel/excel.dart' as ex;
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
// ═══════════════════════════════════════════════════════
//  ⚠ IMPORTANT: Replace with your actual API key
//  Get it free from: https://console.anthropic.com
// ═══════════════════════════════════════════════════════
final _kGroqKey = dotenv.env['GROQ_API_KEY'] ?? '';
// ═══════════════════════════════════════════════════════
class _T {
  static const bg      = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  // ignore: unused_field
  static const surface2= Color(0xFF243044);
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
//  CHAT MESSAGE MODEL
// ═══════════════════════════════════════════════════════
class _Msg {
  final bool isUser;
  final String text;
  final DateTime time;
  bool isLoading;

  _Msg({
    required this.isUser,
    required this.text,
    required this.time,
    this.isLoading = false,
  });
}

// ═══════════════════════════════════════════════════════
//  MAIN PAGE — Tabs: Reports | AI Chatbot
// ═══════════════════════════════════════════════════════
class ReportsAndChatbotPage extends StatefulWidget {
  const ReportsAndChatbotPage({super.key});
  @override
  State<ReportsAndChatbotPage> createState() => _ReportsAndChatbotPageState();
}

class _ReportsAndChatbotPageState extends State<ReportsAndChatbotPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      appBar: AppBar(
        backgroundColor: _T.surface,
        foregroundColor: _T.text,
        elevation: 0,
        title: Row(children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: _T.accent, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: _T.accent.withOpacity(0.5), blurRadius: 8)],
            ),
          ),
          const SizedBox(width: 10),
          const Text('Reports & AI Assistant',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        ]),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: _T.accent,
          indicatorWeight: 2.5,
          labelColor: _T.accent,
          unselectedLabelColor: _T.muted,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.download_rounded, size: 18), text: 'Reports & Export'),
            Tab(icon: Icon(Icons.smart_toy_rounded, size: 18), text: 'AI Assistant'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _ReportsTab(),
          _ChatbotTab(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  TAB 1 — REPORTS
// ═══════════════════════════════════════════════════════
class _ReportsTab extends StatefulWidget {
  const _ReportsTab();
  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  final _sb = Supabase.instance.client;

  // Stats loaded from DB
  int    _total       = 0;
  final int    _valid       = 0;
  final int    _flagged     = 0;
  String _topCause    = '—';
  String _topDistrict = '—';
  String _topLocality = '—';
  double _avgAge      = 0;
  int    _maleCount   = 0;
  int    _femaleCount = 0;
  Map<String, int> _causeMap     = {};
  Map<String, int> _districtMap  = {};
  Map<String, int> _monthlyMap   = {};
  Map<String, int> _yearlyMap    = {};

  bool   _loading = true;
  String? _error;
  String? _genStatus; // status msg while generating
  int?   _selYear;
  int?   _selMonth;
  final List<int> _years  = [];
  final List<int> _months = List.generate(12, (i) => i + 1);

  static const _monthNames = [
    '', 'January','February','March','April','May','June',
    'July','August','September','October','November','December'
  ];

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _sb
          .from('mortality_records_clean')
          .select('age,gender,district,specific_locality,cause_of_death,'
              'date_of_death,quality_score')
         
          .gte('quality_score', 60)
          .limit(10000);

      final data = List<Map<String, dynamic>>.from(res as List);

      // Basic counts
      _total    = data.length;
      _maleCount   = data.where((r) => r['gender'] == 'Male').length;
      _femaleCount = data.where((r) => r['gender'] == 'Female').length;

      // Avg age
      final ages = data.map((r) => r['age']).whereType<int>()
          .where((a) => a > 0 && a < 120).toList();
      _avgAge = ages.isEmpty ? 0 :
          ages.reduce((a, b) => a + b) / ages.length;

      // Cause map
      _causeMap = {};
      for (final r in data) {
        final c = r['cause_of_death']?.toString() ?? '';
        if (c.isNotEmpty && c != 'Unspecified' && c != 'Unknown') {
          _causeMap[c] = (_causeMap[c] ?? 0) + 1;
        }
      }
      if (_causeMap.isNotEmpty) {
        _topCause = (_causeMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value))).first.key;
      }

      // District map
      _districtMap = {};
      for (final r in data) {
        final d = r['district']?.toString() ?? '';
        if (d.isNotEmpty && d != 'Unknown') _districtMap[d] = (_districtMap[d] ?? 0) + 1;
      }
      if (_districtMap.isNotEmpty) {
        _topDistrict = (_districtMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value))).first.key;
      }

      // Locality
      final locMap = <String, int>{};
      for (final r in data) {
        final l = r['specific_locality']?.toString() ?? '';
        if (l.isNotEmpty && l != 'Not Specified') locMap[l] = (locMap[l] ?? 0) + 1;
      }
      if (locMap.isNotEmpty) {
        _topLocality = (locMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value))).first.key;
      }

      // Monthly & Yearly maps
      _monthlyMap = {};
      _yearlyMap  = {};
      final yearSet = <int>{};
      for (final r in data) {
        final dateStr = r['date_of_death']?.toString() ?? '';
        if (dateStr.length >= 7) {
          final year  = int.tryParse(dateStr.substring(0, 4));
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
      if (_selYear == null && _years.isNotEmpty) _selYear = _years.last;

      setState(() => _loading = false);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Build plain-text report content
  String _buildReportText({required String type}) {
    final now = DateTime.now();
    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════════════════════');
    buffer.writeln('       MORTALITY ANALYSIS SYSTEM');
    buffer.writeln('       $type');
    buffer.writeln('       Generated: ${now.day}/${now.month}/${now.year}  ${now.hour}:${now.minute.toString().padLeft(2,'0')}');
    buffer.writeln('═══════════════════════════════════════════════');
    buffer.writeln();

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
    } else if (type.contains('Yearly') && _selYear != null) {
      buffer.writeln('PERIOD: $_selYear');
      buffer.writeln('Total Deaths in $_selYear: ${_yearlyMap[_selYear.toString()] ?? 0}');
      buffer.writeln();
      buffer.writeln('YEARLY COMPARISON:');
      for (final e in (_yearlyMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))) {
        buffer.writeln('  ${e.key}: ${e.value} deaths');
      }
    } else {
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

    buffer.writeln();
    buffer.writeln('TOP 10 CAUSES OF DEATH:');
    final sortedCauses = (_causeMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))).take(10);
    for (final e in sortedCauses) {
      buffer.writeln('  ${e.key.padRight(28)}: ${e.value}');
    }

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

  void _showReport(String type) {
    final content = _buildReportText(type: type);
    setState(() => _genStatus = null);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _T.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 640,
          height: MediaQuery.of(context).size.height * 0.82,
          padding: const EdgeInsets.all(0),
          child: Column(children: [
            // Dialog header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: _T.border)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _T.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.description_rounded, color: _T.accent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(type, style: const TextStyle(color: _T.text, fontWeight: FontWeight.bold, fontSize: 15)),
                  const Text('Generated from live database', style: TextStyle(color: _T.muted, fontSize: 11)),
                ])),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: _T.muted),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            // Report content
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Text(content,
                style: const TextStyle(
                  color: _T.sub,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.7,
                )),
            )),
            // Copy button
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: _T.border))),
              child: Row(children: [
                Expanded(child: Text(
                  'Note: To export as PDF/Excel, integrate a PDF or Excel package such as pdf or excel_dart.',
                  style: const TextStyle(color: _T.muted, fontSize: 10),
                )),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_rounded, size: 15),
                  label: const Text('Done'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _T.accent, foregroundColor: _T.bg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }



Future<void> exportToExcel() async {
  final excel = ex.Excel.createExcel();
  final sheet = excel['Report'];

  sheet.appendRow([
    ex.TextCellValue("Total"),
    ex.TextCellValue("$_total"),
  ]);

  final bytes = excel.encode();
  if (bytes == null) return;

  final file = XFile.fromData(
    Uint8List.fromList(bytes),
    name: "mortality_report.xlsx",
    mimeType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  );

  await Share.shareXFiles([file], text: "Excel Report");
}

Future<void> exportToPdf() async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      build: (_) => pw.Text("Mortality Report"),
    ),
  );

  final bytes = await pdf.save();

  final file = XFile.fromData(
    bytes,
    name: "mortality_report.pdf",
    mimeType: "application/pdf",
  );

  await Share.shareXFiles([file], text: "PDF Report");
}
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _T.accent, strokeWidth: 2));
    if (_error != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline_rounded, color: _T.red, size: 48),
      const SizedBox(height: 12),
      Text(_error!, style: const TextStyle(color: _T.muted, fontSize: 12)),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: _loadData,
          style: ElevatedButton.styleFrom(backgroundColor: _T.accent, foregroundColor: _T.bg), child: const Text('Retry')),
    ]));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Summary banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_T.accent.withOpacity(0.12), _T.purple.withOpacity(0.08)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border:Border.all(color: _T.accent.withOpacity(0.2)),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Reports & Export',
                  style: TextStyle(color: _T.text, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Generate detailed mortality reports from your live Supabase database.',
                  style: const TextStyle(color: _T.muted, fontSize: 12, height: 1.4)),
              const SizedBox(height: 12),
              Wrap(spacing: 16, children: [
                _stat('Total Records', '$_total', _T.accent),
                _stat('Top Cause', _topCause, _T.orange),
                _stat('Top District', _topDistrict, _T.purple),
                _stat('Avg Age', '${_avgAge.toStringAsFixed(1)} yrs', _T.green),
              ]),
            ])),
            const SizedBox(width: 16),
            Icon(Icons.summarize_rounded, size: 60, color: _T.accent.withOpacity(0.25)),
          ]),
        ),
        const SizedBox(height: 24),

        // ── Quick Export Buttons
        _secLabel('Quick Export'),
       LayoutBuilder(builder: (ctx, box) {
  final wide = box.maxWidth > 600;

  return Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      // 📊 REAL EXCEL EXPORT
 _exportBtn(
  Icons.table_chart_rounded,
  'Download Excel Report',
  'Export mortality data as Excel file',
  _T.green,
  () async {
    await exportToExcel();
  },
),

_exportBtn(
  Icons.description_rounded,
  'Download Word Report',
  'Generate structured report document',
  _T.purple,
  () async {
    await exportToPdf();
  },
),
 
 
    ],
  );
}),
const SizedBox(height: 24),
        const SizedBox(height: 24),

        // ── Monthly Report
        _secLabel('Monthly Report'),
        _card('Generate Monthly Report', Icons.calendar_month_rounded, _T.purple,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Select year and month to generate a focused monthly mortality report.',
                style: TextStyle(color: _T.muted, fontSize: 12)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _dropField<int>(
                'Year', _years, _selYear, (v) => setState(() => _selYear = v),
                itemLabel: (v) => v.toString(),
              )),
              const SizedBox(width: 12),
              Expanded(child: _dropField<int>(
                'Month', _months, _selMonth, (v) => setState(() => _selMonth = v),
                itemLabel: (v) => _monthNames[v],
              )),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _selYear != null && _selMonth != null
                    ? () => _showReport('Monthly Report — ${_monthNames[_selMonth!]} $_selYear')
                    : null,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Generate', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _T.purple, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ]),
            if (_selYear != null) ...[
              const SizedBox(height: 16),
              const Text('MONTHLY DEATHS THIS YEAR',
                  style: TextStyle(color: _T.muted, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: List.generate(12, (i) {
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
                      color: isSelected ? _T.purple.withOpacity(0.2) : _T.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? _T.purple : _T.border),
                    ),
                    child: Column(children: [
                      Text(_monthNames[m].substring(0, 3),
                          style: TextStyle(color: isSelected ? _T.purple : _T.muted, fontSize: 10, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text('$count', style: TextStyle(
                          color: isSelected ? _T.purple : count > 0 ? _T.text : _T.muted,
                          fontSize: 14, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                );
              })),
            ],
          ]),
        ),
        const SizedBox(height: 16),

        // ── Yearly Report
        _secLabel('Yearly Report'),
        _card('Generate Yearly Report', Icons.bar_chart_rounded, _T.orange,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Select a year to generate a comprehensive annual mortality report.',
                style: TextStyle(color: _T.muted, fontSize: 12)),
            const SizedBox(height: 14),
            Row(children: [
              SizedBox(width: 160, child: _dropField<int>(
                'Year', _years, _selYear, (v) => setState(() => _selYear = v),
                itemLabel: (v) => v.toString(),
              )),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _selYear != null
                    ? () => _showReport('Yearly Report — $_selYear')
                    : null,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Generate', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _T.orange, foregroundColor: _T.bg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            const Text('YEAR-BY-YEAR DEATHS',
                style: TextStyle(color: _T.muted, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...((_yearlyMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key))).map((e) {
              final maxVal = _yearlyMap.values.fold(0, (a, b) => a > b ? a : b);
              final pct = maxVal > 0 ? e.value / maxVal : 0.0;
              final isSel = e.key == _selYear?.toString();
              return GestureDetector(
                onTap: () => setState(() => _selYear = int.tryParse(e.key)),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSel ? _T.orange.withOpacity(0.08) : _T.bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSel ? _T.orange : _T.border),
                  ),
                  child: Row(children: [
                    SizedBox(width: 50, child: Text(e.key,
                        style: TextStyle(color: isSel ? _T.orange : _T.sub,
                            fontSize: 12, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 12),
                    Expanded(child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct, minHeight: 8,
                        backgroundColor: _T.border,
                        valueColor: AlwaysStoppedAnimation(isSel ? _T.orange : _T.accent),
                      ),
                    )),
                    const SizedBox(width: 12),
                    Text('${e.value} deaths', style: TextStyle(
                        color: isSel ? _T.orange : _T.muted, fontSize: 11)),
                  ]),
                ),
              );
            })),
          ]),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _stat(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _T.muted, fontSize: 10)),
      Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis),
    ],
  );

  Widget _secLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Container(width: 3, height: 16,
          decoration: BoxDecoration(color: _T.accent, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(t.toUpperCase(), style: const TextStyle(
          color: _T.muted, fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _exportBtn(IconData icon, String label, String sub, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 240,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _T.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.35)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: _T.text, fontWeight: FontWeight.bold, fontSize: 12)),
              Text(sub, style: const TextStyle(color: _T.muted, fontSize: 10)),
            ])),
          ]),
        ),
      );

  Widget _card(String title, IconData icon, Color color, Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: _T.surface, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _T.border),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 3))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _T.border))),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: _T.text, fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
      ),
      Padding(padding: const EdgeInsets.all(18), child: child),
    ]),
  );

  Widget _dropField<T>(String hint, List<T> items, T? val, void Function(T?) onChange,
      {required String Function(T) itemLabel}) =>
      DropdownButtonFormField<T>(
        initialValue: val, dropdownColor: _T.surface,
        style: const TextStyle(color: _T.text, fontSize: 12),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: _T.muted, fontSize: 12),
          filled: true, fillColor: _T.bg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _T.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _T.accent)),
        ),
        isExpanded: true,
        items: items.map((v) => DropdownMenuItem<T>(value: v, child: Text(itemLabel(v)))).toList(),
        onChanged: onChange,
      );
}

// ═══════════════════════════════════════════════════════
//  TAB 2 — AI CHATBOT
// ═══════════════════════════════════════════════════════
class _ChatbotTab extends StatefulWidget {
  const _ChatbotTab();
  @override
  State<_ChatbotTab> createState() => _ChatbotTabState();
}

class _ChatbotTabState extends State<_ChatbotTab> {
  final _sb      = Supabase.instance.client;
  final _scroll  = ScrollController();
  final _input   = TextEditingController();
  final List<_Msg> _msgs = [];

  bool   _dbLoaded  = false;
  bool   _responding = false;
  String _dbSummary  = '';

  // Suggested questions
  static const _suggestions = [
    'Which village has the highest mortality rate?',
    'What is the most common cause of death?',
    'Show diabetes-related deaths by district.',
    'Which age group has the most deaths?',
    'Compare male vs female mortality rates.',
    'Which year had the most deaths?',
    'What percentage died at home vs hospital?',
    'Which district needs most urgent attention?',
  ];

  @override
  void initState() {
    super.initState();
    _loadDbContext();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  // ── Load database summary for AI context
  Future<void> _loadDbContext() async {
    try {
      final res = await _sb
          .from('mortality_records_clean')
          .select('age,gender,district,specific_locality,cause_of_death,'
              'date_of_death,place_of_death,water_source,income_bracket,'
              'prior_medical_conditions,quality_score')
          .gte('quality_score', 60)
          .limit(5000);

      final data = List<Map<String, dynamic>>.from(res as List);

      // Build compact summary for AI context
      final total = data.length;
      final male  = data.where((r) => r['gender'] == 'Male').length;
      final fem   = data.where((r) => r['gender'] == 'Female').length;

      final ages = data.map((r) => r['age']).whereType<int>()
          .where((a) => a > 0 && a < 120).toList();
      final avgAge = ages.isEmpty ? 0.0 : ages.reduce((a, b) => a + b) / ages.length;

      // Top 10 causes
      final causeMap = <String, int>{};
      for (final r in data) {
        final c = r['cause_of_death']?.toString() ?? '';
        if (c.isNotEmpty && c != 'Unspecified') causeMap[c] = (causeMap[c] ?? 0) + 1;
      }
      final topCauses = (causeMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(10);

      // Top districts
      final distMap = <String, int>{};
      for (final r in data) {
        final d = r['district']?.toString() ?? '';
        if (d.isNotEmpty && d != 'Unknown') distMap[d] = (distMap[d] ?? 0) + 1;
      }
      final topDistricts = (distMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(10);

      // Top localities
      final locMap = <String, int>{};
      for (final r in data) {
        final l = r['specific_locality']?.toString() ?? '';
        if (l.isNotEmpty && l != 'Not Specified') locMap[l] = (locMap[l] ?? 0) + 1;
      }
      final topLocalities = (locMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(15);

      // Year breakdown
      final yearMap = <String, int>{};
      for (final r in data) {
        final d = r['date_of_death']?.toString() ?? '';
        if (d.length >= 4) {
          final y = d.substring(0, 4);
          yearMap[y] = (yearMap[y] ?? 0) + 1;
        }
      }

      // Place breakdown
      final placeMap = <String, int>{};
      for (final r in data) {
        final p = r['place_of_death']?.toString() ?? '';
        if (p.isNotEmpty) placeMap[p] = (placeMap[p] ?? 0) + 1;
      }

      // Water source
      final waterMap = <String, int>{};
      for (final r in data) {
        final w = r['water_source']?.toString() ?? '';
        if (w.isNotEmpty) waterMap[w] = (waterMap[w] ?? 0) + 1;
      }

      // Income breakdown
      final incomeMap = <String, int>{};
      for (final r in data) {
        final i = r['income_bracket']?.toString() ?? '';
        if (i.isNotEmpty) incomeMap[i] = (incomeMap[i] ?? 0) + 1;
      }

      // Disease by district (top 5)
      final diseaseDist = <String, Map<String, int>>{};
      for (final r in data) {
        final dist  = r['district']?.toString() ?? '';
        final cause = r['cause_of_death']?.toString() ?? '';
        if (dist.isEmpty || cause.isEmpty || cause == 'Unspecified') continue;
        diseaseDist.putIfAbsent(dist, () => {});
        diseaseDist[dist]![cause] = (diseaseDist[dist]![cause] ?? 0) + 1;
      }

      final buf = StringBuffer();
      buf.writeln('DATABASE SUMMARY FOR MORTALITY ANALYSIS SYSTEM:');
      buf.writeln('Total valid mortality records: $total');
      buf.writeln('Male deaths: $male | Female deaths: $fem');
      buf.writeln('Average age at death: ${avgAge.toStringAsFixed(1)} years');
      buf.writeln();
      buf.writeln('TOP 10 CAUSES OF DEATH:');
      for (final e in topCauses) {
        buf.writeln('  ${e.key}: ${e.value} deaths');
      }
      buf.writeln();
      buf.writeln('TOP 10 DISTRICTS BY DEATHS:');
      for (final e in topDistricts) {
        buf.writeln('  ${e.key}: ${e.value} deaths');
      }
      buf.writeln();
      buf.writeln('TOP 15 LOCALITIES BY DEATHS:');
      for (final e in topLocalities) {
        buf.writeln('  ${e.key}: ${e.value} deaths');
      }
      buf.writeln();
      buf.writeln('DEATHS BY YEAR:');
      for (final e in (yearMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))) {
        buf.writeln('  ${e.key}: ${e.value} deaths');
      }
      buf.writeln();
      buf.writeln('PLACE OF DEATH:');
      for (final e in placeMap.entries) {
        buf.writeln('  ${e.key}: ${e.value}');
      }
      buf.writeln();
      buf.writeln('WATER SOURCE:');
      for (final e in waterMap.entries) {
        buf.writeln('  ${e.key}: ${e.value}');
      }
      buf.writeln();
      buf.writeln('INCOME BRACKET:');
      for (final e in incomeMap.entries) {
        buf.writeln('  ${e.key}: ${e.value}');
      }
      buf.writeln();
      buf.writeln('TOP DISEASE PER DISTRICT (top 5 districts):');
      int dCount = 0;
      for (final dist in topDistricts.take(5)) {
        final causes = diseaseDist[dist.key];
        if (causes == null) continue;
        final top = (causes.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(3);
        buf.writeln('  ${dist.key}: ${top.map((e) => "${e.key}(${e.value})").join(", ")}');
        dCount++;
      }

      _dbSummary = buf.toString();
      _dbLoaded  = true;

      // Add welcome message
      setState(() {
        _msgs.add(_Msg(
          isUser: false,
          text: '👋 Hello! I\'m your AI mortality data assistant.\n\n'
              'I have loaded **$total records** from your database and I can answer questions about:\n'
              '• Causes of death and trends\n'
              '• District and village comparisons\n'
              '• Age and gender analysis\n'
              '• Year-by-year mortality trends\n'
              '• Risk factors and lifestyle data\n\n'
              'Ask me anything about your mortality data!',
          time: DateTime.now(),
        ));
      });
    } catch (e) {
      setState(() {
        _msgs.add(_Msg(
          isUser: false,
          text: '⚠️ Could not load database context: $e\n\nPlease check your Supabase connection.',
          time: DateTime.now(),
        ));
      });
    }
  }

  // ── Send message to Claude AI with DB context
  Future<void> _send([String? override]) async {
    final text = (override ?? _input.text).trim();
    if (text.isEmpty || _responding) return;

    _input.clear();
    setState(() {
      _msgs.add(_Msg(isUser: true, text: text, time: DateTime.now()));
      _msgs.add(_Msg(isUser: false, text: '', time: DateTime.now(), isLoading: true));
      _responding = true;
    });
    _scrollToBottom();

    try {
      final systemPrompt =
          'You are an expert public health data analyst AI assistant for a Mortality Analysis System in Pakistan/AJK region. '
          'You have access to the following real database summary. Use ONLY this data to answer questions accurately. '
          'Be concise, helpful, and specific. Format your answers clearly with numbers and percentages where relevant. '
          'If asked about a specific village or disease not in the data, say so clearly.\n\n'
          '$_dbSummary';
 final response = await http.post(
  Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_kGroqKey',
  },
  body: jsonEncode({
    // Updated to a highly optimized, active Groq model
    'model': 'openai/gpt-oss-20b', 
    'messages': [
      {
        'role': 'system',
        // ignore: dead_null_aware_expression
        'content': systemPrompt ?? "You are a helpful assistant",
      },
      {
        'role': 'user',
        'content': text,
      }
    ],
    'temperature': 0.3,
    'max_tokens': 1024,
  })
).timeout(
  const Duration(seconds: 30),);
if (response.statusCode == 200) {
  final data = jsonDecode(response.body);
  final result = data['choices'][0]['message']['content'];
  print(result);
} else {
  print("Error: ${response.statusCode}");
  print(response.body);
}
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['choices']?[0]?['message']?['content'] ?? 'No response received.';
        setState(() {
          _msgs.last.isLoading = false;
          _msgs[_msgs.length - 1] = _Msg(
            isUser: false, text: reply, time: DateTime.now());
        });
      } else {
        final errBody = jsonDecode(response.body);
        final errMsg  = errBody['error']?['message'] ?? 'API error ${response.statusCode}';
        setState(() {
          _msgs[_msgs.length - 1] = _Msg(
            isUser: false,
            text: '❌ API Error: $errMsg\n\nMake sure your Anthropic API key is set correctly in the code.',
            time: DateTime.now(),
          );
        });
      }
    } catch (e) {
      setState(() {
        _msgs[_msgs.length - 1] = _Msg(
          isUser: false,
          text: '❌ Connection error: $e\n\nPlease check your internet connection and API key.',
          time: DateTime.now(),
        );
      });
    } finally {
      setState(() => _responding = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _clearChat() {
    setState(() => _msgs.clear());
    _loadDbContext();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Top bar
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _T.surface,
          border: Border(bottom: BorderSide(color: _T.border)),
        ),
        child: Row(children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              color: _dbLoaded ? _T.green : _T.orange,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: (_dbLoaded ? _T.green : _T.orange).withOpacity(0.5), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _dbLoaded ? 'Connected to database · AI ready' : 'Loading database…',
            style: TextStyle(color: _dbLoaded ? _T.green : _T.orange, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _clearChat,
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: const Text('Clear Chat', style: TextStyle(fontSize: 11)),
            style: TextButton.styleFrom(foregroundColor: _T.muted),
          ),
        ]),
      ),

      // ── Suggestions (shown when chat is empty / just welcome)
      if (_msgs.length <= 1) Container(
        color: _T.bg,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SUGGESTED QUESTIONS',
              style: TextStyle(color: _T.muted, fontSize: 10, letterSpacing: 1.3, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: _suggestions.map((q) =>
            GestureDetector(
              onTap: () => _send(q),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _T.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _T.border),
                ),
                child: Text(q, style: const TextStyle(color: _T.sub, fontSize: 11)),
              ),
            ),
          ).toList()),
        ]),
      ),

      // ── Messages
      Expanded(child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        itemCount: _msgs.length,
        itemBuilder: (ctx, i) => _buildMessage(_msgs[i]),
      )),

      // ── Input bar
      Container(
        decoration: BoxDecoration(
          color: _T.surface,
          border: Border(top: BorderSide(color: _T.border)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Row(children: [
          Expanded(child: TextField(
            controller: _input,
            style: const TextStyle(color: _T.text, fontSize: 13),
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(
              hintText: 'Ask about mortality data, trends, villages…',
              hintStyle: const TextStyle(color: _T.muted, fontSize: 12),
              filled: true, fillColor: _T.bg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _T.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _T.accent)),
            ),
          )),
          const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Material(
              color: _responding ? _T.border : _T.accent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _responding ? null : () => _send(),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: _responding
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _T.muted))
                      : const Icon(Icons.send_rounded, color: _T.bg, size: 20),
                ),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildMessage(_Msg msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isUser ? _T.accent.withOpacity(0.15) : _T.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isUser ? 14 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 14),
              ),
              border: Border.all(color: isUser ? _T.accent.withOpacity(0.3) : _T.border),
            ),
            child: msg.isLoading
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: _T.accent)),
                    const SizedBox(width: 10),
                    const Text('Analyzing your data…',
                        style: TextStyle(color: _T.muted, fontSize: 12, fontStyle: FontStyle.italic)),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Render **bold** markdown manually
                    _renderText(msg.text),
                    const SizedBox(height: 6),
                    Text(
                      '${msg.time.hour.toString().padLeft(2,'0')}:${msg.time.minute.toString().padLeft(2,'0')}',
                      style: const TextStyle(color: _T.muted, fontSize: 9),
                    ),
                  ]),
          )),
          if (isUser) ...[
            const SizedBox(width: 10),
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _T.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _T.accent.withOpacity(0.3)),
              ),
              child: const Icon(Icons.person_rounded, color: _T.accent, size: 17),
            ),
          ],
        ],
      ),
    );
  }

  // Simple bold + newline renderer for AI responses
  Widget _renderText(String text) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        // Bold: **text**
        final boldRegex = RegExp(r'\*\*(.*?)\*\*');
        if (!boldRegex.hasMatch(line)) {
          return Text(line, style: const TextStyle(color: _T.sub, fontSize: 13, height: 1.5));
        }
        final spans = <TextSpan>[];
        int last = 0;
        for (final m in boldRegex.allMatches(line)) {
          if (m.start > last) spans.add(TextSpan(text: line.substring(last, m.start)));
          spans.add(TextSpan(text: m.group(1), style: const TextStyle(color: _T.text, fontWeight: FontWeight.bold)));
          last = m.end;
        }
        if (last < line.length) spans.add(TextSpan(text: line.substring(last)));
        return RichText(text: TextSpan(
          style: const TextStyle(color: _T.sub, fontSize: 13, height: 1.5),
          children: spans,
        ));
      }).toList(),
    );
  }   
}