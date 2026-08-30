import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  static const red     = Color(0xFFF87171);
}

// ═══════════════════════════════════════════════════════
//  TREE NODE
// ═══════════════════════════════════════════════════════
class _Node {
  final String name;
  final int level; // 0 = root (hidden), 1=Province, 2=District, 3=Tehsil, 4=Area Type, 5=Village
  final _Node? parent;
  final Map<String, _Node> _childMap = {};
  int deaths = 0;
  final Map<String, int> causeCounts = {};

  // Computed during layout
  double startAngle = 0;
  double sweepAngle = 0;

  _Node({required this.name, required this.level, this.parent});

  List<_Node> get children => _childMap.values.toList();

  _Node child(String name) {
    return _childMap.putIfAbsent(
      name,
      () => _Node(name: name, level: level + 1, parent: this),
    );
  }

  String get breadcrumb {
    final parts = <String>[];
    _Node? n = this;
    while (n != null && n.level > 0) {
      parts.add(n.name);
      n = n.parent;
    }
    return parts.reversed.join(' > ');
  }

  static const _levelLabels = ['Root', 'Province', 'District', 'Tehsil', 'Area Type', 'Village/City'];
  String get levelLabel => _levelLabels[level.clamp(0, _levelLabels.length - 1)];
}

// ═══════════════════════════════════════════════════════
//  PAGE
// ═══════════════════════════════════════════════════════
class RiskPatternPage extends StatefulWidget {
  const RiskPatternPage({super.key});

  @override
  State<RiskPatternPage> createState() => _RiskPatternPageState();
}

class _RiskPatternPageState extends State<RiskPatternPage> {
  final _sb = Supabase.instance.client;

  _Node? _root;
  List<_Node> _flatNodes = []; // every node, for hit-testing
  Map<int, int> _ringMaxDeaths = {}; // level -> max deaths among nodes at that level

  bool _loading = true;
  String? _error;
  _Node? _selected;

  static const _ringLevels = [1, 2, 3, 4, 5]; // Province..Village
  static const _innerHoleRadius = 34.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ─────────────────────────────────────────────
  //  LOAD + BUILD TREE
  // ─────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
      _selected = null;
    });

    try {
      final res = await _sb
          .from('mortality_records_clean')
          .select('province, district, tehsil, area_type, specific_locality, '
              'cause_of_death, quality_score')
          .gte('quality_score', 60)
          .limit(10000);

      final data = List<Map<String, dynamic>>.from(res as List);

      final root = _Node(name: 'All', level: 0);

      String clean(dynamic v, String fallback) {
        final s = v?.toString().trim() ?? '';
        return s.isEmpty ? fallback : s;
      }

      for (final r in data) {
        final province = clean(r['province'], 'Unknown Province');
        final district = clean(r['district'], 'Unknown District');
        final tehsil   = clean(r['tehsil'], 'Unknown Tehsil');
        final areaType = clean(r['area_type'], 'Unknown');
        final village  = clean(r['specific_locality'], 'Not Specified');
        final cause    = r['cause_of_death']?.toString().trim() ?? '';

        final nProvince = root.child(province);
        final nDistrict = nProvince.child(district);
        final nTehsil   = nDistrict.child(tehsil);
        final nArea     = nTehsil.child(areaType);
        final nVillage  = nArea.child(village);

        for (final n in [root, nProvince, nDistrict, nTehsil, nArea, nVillage]) {
          n.deaths += 1;
          if (cause.isNotEmpty && cause != 'Unspecified' && cause != 'Unknown') {
            n.causeCounts[cause] = (n.causeCounts[cause] ?? 0) + 1;
          }
        }
      }

      if (root.deaths == 0) {
        setState(() {
          _error = 'No records found to build the pattern.';
          _loading = false;
        });
        return;
      }

      _layout(root, 0, 2 * pi);

      // Flatten + compute per-ring max for color normalization
      _flatNodes = [];
      _ringMaxDeaths = {};
      void collect(_Node n) {
        if (n.level > 0) {
          _flatNodes.add(n);
          _ringMaxDeaths[n.level] = max(_ringMaxDeaths[n.level] ?? 0, n.deaths);
        }
        for (final c in n.children) {
          collect(c);
        }
      }
      collect(root);

      setState(() {
        _root = root;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // Classic sunburst layout: partition a parent's angular span among children by weight
  void _layout(_Node node, double startAngle, double sweepAngle) {
    node.startAngle = startAngle;
    node.sweepAngle = sweepAngle;

    final children = node.children..sort((a, b) => b.deaths.compareTo(a.deaths));
    if (children.isEmpty || node.deaths == 0) return;

    double angleCursor = startAngle;
    for (final c in children) {
      final childSweep = sweepAngle * (c.deaths / node.deaths);
      _layout(c, angleCursor, childSweep);
      angleCursor += childSweep;
    }
  }

  // ─────────────────────────────────────────────
  //  COLOR SCALE (per-ring normalized)
  // ─────────────────────────────────────────────
  Color _colorFor(_Node n) {
    final maxD = _ringMaxDeaths[n.level] ?? 1;
    final ratio = maxD == 0 ? 0.0 : (n.deaths / maxD).clamp(0.0, 1.0);
    // Light warm -> dark red
    const light = Color(0xFFFFE8D6);
    const dark = Color(0xFF7F1D1D);
    return Color.lerp(light, dark, ratio) ?? light;
  }

  // ─────────────────────────────────────────────
  //  HIT TESTING
  // ─────────────────────────────────────────────
  void _handleTap(Offset localPos, double size) {
    final center = Offset(size / 2, size / 2);
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;
    final radius = sqrt(dx * dx + dy * dy);
    double angle = atan2(dy, dx);
    if (angle < 0) angle += 2 * pi;

    final maxRadius = size / 2;
    final ringWidth = (maxRadius - _innerHoleRadius) / _ringLevels.length;

    if (radius < _innerHoleRadius || radius > maxRadius) {
      setState(() => _selected = null);
      return;
    }

    final ringIndex = ((radius - _innerHoleRadius) / ringWidth).floor() + 1;
    if (ringIndex < 1 || ringIndex > _ringLevels.length) return;

    for (final n in _flatNodes) {
      if (n.level != ringIndex) continue;
      final end = n.startAngle + n.sweepAngle;
      if (angle >= n.startAngle && angle < end) {
        setState(() => _selected = n);
        _showNodeInfo(n);
        return;
      }
    }
  }

  void _showNodeInfo(_Node n) {
    final sortedCauses = n.causeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _T.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _T.border))),
              child: Row(children: [
                Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(color: _colorFor(n), shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(n.name,
                        style: const TextStyle(color: _T.text, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(n.levelLabel, style: const TextStyle(color: _T.muted, fontSize: 11)),
                  ]),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: _T.muted),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n.breadcrumb, style: const TextStyle(color: _T.sub, fontSize: 12)),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _T.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Total Deaths', style: TextStyle(color: _T.muted, fontSize: 10)),
                          Text('${n.deaths}',
                              style: const TextStyle(color: _T.red, fontSize: 20, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _T.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Diseases Recorded', style: TextStyle(color: _T.muted, fontSize: 10)),
                          Text('${sortedCauses.length}',
                              style: const TextStyle(color: _T.accent, fontSize: 20, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  const Text('FULL DISEASE BREAKDOWN',
                      style: TextStyle(
                          color: _T.muted, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  if (sortedCauses.isEmpty)
                    const Text('No cause-of-death data recorded for this area.',
                        style: TextStyle(color: _T.muted, fontSize: 12))
                  else
                    ...sortedCauses.map((e) {
                      final pct = n.deaths == 0 ? 0.0 : (e.value / n.deaths * 100);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(
                              child: Text(e.key,
                                  style: const TextStyle(color: _T.text, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                            Text('${e.value} (${pct.toStringAsFixed(1)}%)',
                                style: const TextStyle(color: _T.sub, fontSize: 11)),
                          ]),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: n.deaths == 0 ? 0 : e.value / n.deaths,
                              minHeight: 5,
                              backgroundColor: _T.border,
                              valueColor: const AlwaysStoppedAnimation(_T.red),
                            ),
                          ),
                        ]),
                      );
                    }),
                ]),
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
              color: _T.red, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: _T.red.withValues(alpha: 0.5), blurRadius: 8)])),
          const SizedBox(width: 10),
          const Text('Mortality Risk Pattern', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        ]),
        actions: [
          if (!_loading)
            TextButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: _T.accent),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _T.accent, strokeWidth: 2))
          : _error != null
              ? _errView()
              : _body(),
    );
  }

  Widget _errView() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline_rounded, color: _T.red, size: 48),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Text(_error ?? '', textAlign: TextAlign.center,
                style: const TextStyle(color: _T.muted, fontSize: 12)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(backgroundColor: _T.accent, foregroundColor: _T.bg),
            child: const Text('Retry'),
          ),
        ]),
      );

  Widget _body() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        // ── Explanation banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _T.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _T.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.info_outline_rounded, color: _T.accent, size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Tap any arc to see full death & disease details for that area.',
                    style: TextStyle(color: _T.sub, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 10),
            // Ring order legend
            Wrap(spacing: 14, runSpacing: 6, children: const [
              _RingLegendChip(label: '① Province', color: _T.accent),
              _RingLegendChip(label: '② District', color: _T.accent),
              _RingLegendChip(label: '③ Tehsil', color: _T.accent),
              _RingLegendChip(label: '④ Area Type', color: _T.accent),
              _RingLegendChip(label: '⑤ Village/City', color: _T.accent),
            ]),
            const SizedBox(height: 12),
            // Color scale legend
            Row(children: [
              const Text('Low risk', style: TextStyle(color: _T.muted, fontSize: 10)),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFE8D6), Color(0xFF7F1D1D)],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('High risk', style: TextStyle(color: _T.muted, fontSize: 10)),
            ]),
          ]),
        ),
        const SizedBox(height: 20),

        // ── The sunburst image itself
        LayoutBuilder(builder: (ctx, box) {
          final size = min(box.maxWidth, 640.0);
          return Center(
            child: GestureDetector(
              onTapUp: (details) => _handleTap(details.localPosition, size),
              child: SizedBox(
                width: size,
                height: size,
                child: CustomPaint(
                  painter: _SunburstPainter(
                    nodes: _flatNodes,
                    colorFor: _colorFor,
                    innerHole: _innerHoleRadius,
                    ringCount: _ringLevels.length,
                    selected: _selected,
                  ),
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 20),
        if (_root != null)
          Text('Total deaths analyzed: ${_root!.deaths}',
              style: const TextStyle(color: _T.muted, fontSize: 12)),
        const SizedBox(height: 40),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  LEGEND CHIP
// ═══════════════════════════════════════════════════════
class _RingLegendChip extends StatelessWidget {
  final String label;
  final Color color;
  const _RingLegendChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  SUNBURST PAINTER
// ═══════════════════════════════════════════════════════
class _SunburstPainter extends CustomPainter {
  final List<_Node> nodes;
  final Color Function(_Node) colorFor;
  final double innerHole;
  final int ringCount;
  final _Node? selected;

  _SunburstPainter({
    required this.nodes,
    required this.colorFor,
    required this.innerHole,
    required this.ringCount,
    required this.selected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final ringWidth = (maxRadius - innerHole) / ringCount;

    for (final n in nodes) {
      final innerR = innerHole + (n.level - 1) * ringWidth;
      final outerR = innerR + ringWidth;

      final isDimmed = selected != null && !_isRelated(n, selected!);

      final path = Path()
        ..moveTo(
          center.dx + innerR * cos(n.startAngle),
          center.dy + innerR * sin(n.startAngle),
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: innerR),
          n.startAngle,
          n.sweepAngle,
          false,
        )
        ..lineTo(
          center.dx + outerR * cos(n.startAngle + n.sweepAngle),
          center.dy + outerR * sin(n.startAngle + n.sweepAngle),
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: outerR),
          n.startAngle + n.sweepAngle,
          -n.sweepAngle,
          false,
        )
        ..close();

      final fillColor = colorFor(n);
      final paint = Paint()
        ..color = isDimmed ? fillColor.withValues(alpha: 0.25) : fillColor
        ..style = PaintingStyle.fill;

      canvas.drawPath(path, paint);

      final strokePaint = Paint()
        ..color = _T.bg.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6;
      canvas.drawPath(path, strokePaint);
    }
  }

  bool _isRelated(_Node n, _Node selected) {
    if (n == selected) return true;
    // ancestor of selected?
    _Node? p = selected.parent;
    while (p != null) {
      if (p == n) return true;
      p = p.parent;
    }
    // descendant of selected?
    return n.breadcrumb.startsWith(selected.breadcrumb);
  }

  @override
  bool shouldRepaint(covariant _SunburstPainter oldDelegate) {
    return oldDelegate.nodes != nodes || oldDelegate.selected != selected;
  }
}