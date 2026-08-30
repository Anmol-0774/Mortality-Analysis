import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════════════
//  THEME
// ═══════════════════════════════════════════════════════
class _T {
  static const bg      = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const surfaceAlt = Color(0xFF25324A);
  static const border  = Color(0xFF334155);
  static const muted   = Color(0xFF94A3B8);
  static const sub     = Color(0xFFCBD5E1);
  static const text    = Color(0xFFF1F5F9);
  static const accent  = Color(0xFF38BDF8);
  static const red     = Color(0xFFF87171);

  // One distinct hue family per ring so the sunburst reads as
  // colourful "petals" instead of one flat heat scale. Index by
  // node.level (0 is the hidden root and unused).
  static const List<double> ringHue = [0, 206, 262, 168, 28, 332];

  static const List<String> ringNames = [
    'Root',
    'Province',
    'District',
    'Tehsil',
    'Area Type',
    'Specific Locality',
  ];

  /// A representative swatch for a ring, used in legends/dialogs —
  /// independent of any particular node's death-count ratio.
  static Color ringSwatch(int level) {
    final hue = ringHue[level.clamp(0, ringHue.length - 1)];
    return HSLColor.fromAHSL(1, hue, 0.68, 0.58).toColor();
  }
}

// ═══════════════════════════════════════════════════════
//  TREE NODE
// ═══════════════════════════════════════════════════════
class _Node {
  final String name;
  final int level; // 0=root(hidden) 1=Province 2=District 3=Tehsil 4=AreaType 5=Specific Locality
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

  String get levelLabel => _T.ringNames[level.clamp(0, _T.ringNames.length - 1)];
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

  // Province, District, Tehsil, Area Type, Specific Locality — five rings,
  // the outermost ring is built directly from the `specific_locality` field.
  static const _ringLevels = [1, 2, 3, 4, 5];
  static const _innerHoleRadius = 46.0;

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
        final areaType = clean(r['area_type'], 'Unknown Area Type');
        // Outermost ring: the exact specific_locality value from the schema.
        final locality = clean(r['specific_locality'], 'Locality Not Specified');
        final cause    = r['cause_of_death']?.toString().trim() ?? '';

        final nProvince = root.child(province);
        final nDistrict = nProvince.child(district);
        final nTehsil   = nDistrict.child(tehsil);
        final nArea     = nTehsil.child(areaType);
        final nLocality = nArea.child(locality);

        for (final n in [root, nProvince, nDistrict, nTehsil, nArea, nLocality]) {
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

      _layout(root, -pi / 2, 2 * pi); // start at 12 o'clock, looks nicer

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
  //  COLOR SCALE — distinct hue per ring, intensity by risk
  // ─────────────────────────────────────────────
  Color _colorFor(_Node n) {
    final maxD = _ringMaxDeaths[n.level] ?? 1;
    final ratio = maxD == 0 ? 0.0 : (n.deaths / maxD).clamp(0.0, 1.0);
    final hue = _T.ringHue[n.level.clamp(0, _T.ringHue.length - 1)];

    // Few deaths -> pale & soft. Many deaths (within that ring) -> deep & saturated.
    final lightness = (0.86 - ratio * 0.52).clamp(0.30, 0.90);
    final saturation = (0.32 + ratio * 0.55).clamp(0.30, 0.90);

    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
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
    if (angle < -pi / 2) angle += 2 * pi; // align with layout's start angle
    while (angle < -pi / 2) {
      angle += 2 * pi;
    }
    while (angle >= 3 * pi / 2) {
      angle -= 2 * pi;
    }

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
        return;
      }
    }
  }

  void _showNodeInfo(_Node n) {
    final sortedCauses = n.causeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final swatch = _T.ringSwatch(n.level);

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
              decoration: BoxDecoration(
                border: const Border(bottom: BorderSide(color: _T.border)),
                gradient: LinearGradient(
                  colors: [swatch.withValues(alpha: 0.16), Colors.transparent],
                ),
              ),
              child: Row(children: [
                Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(color: swatch, shape: BoxShape.circle, boxShadow: [
                    BoxShadow(color: swatch.withValues(alpha: 0.6), blurRadius: 8),
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(n.name,
                        style: const TextStyle(color: _T.text, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(n.levelLabel, style: TextStyle(color: swatch, fontSize: 11, fontWeight: FontWeight.w600)),
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
                              valueColor: AlwaysStoppedAnimation(swatch),
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
          const Flexible(
            child: Text('Mortality Risk Pattern',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ),
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
    final w = MediaQuery.sizeOf(context).width;
    final pad = w < 600 ? 14.0 : 20.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(children: [
        _explanationBanner(),
        const SizedBox(height: 20),
        _sunburstCard(),
        const SizedBox(height: 16),
        if (_selected != null) _selectionSummaryCard(_selected!),
        const SizedBox(height: 20),
        if (_root != null)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.people_alt_rounded, color: _T.muted, size: 14),
            const SizedBox(width: 6),
            Text('Total deaths analyzed: ${_root!.deaths}',
                style: const TextStyle(color: _T.muted, fontSize: 12)),
          ]),
        const SizedBox(height: 40),
      ]),
    );
  }

  // ── Explanation + legend banner ──────────────────────
  Widget _explanationBanner() {
    return Container(
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
            child: Text(
              'Tap any arc to drill in — rings run from Province all the way out to '
              'the exact Specific Locality. Tap the center to reset.',
              style: TextStyle(color: _T.sub, fontSize: 12),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 8, children: [
          _RingLegendChip(label: '① Province', color: _T.ringSwatch(1)),
          _RingLegendChip(label: '② District', color: _T.ringSwatch(2)),
          _RingLegendChip(label: '③ Tehsil', color: _T.ringSwatch(3)),
          _RingLegendChip(label: '④ Area Type', color: _T.ringSwatch(4)),
          _RingLegendChip(label: '⑤ Specific Locality', color: _T.ringSwatch(5)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const Text('Pale', style: TextStyle(color: _T.muted, fontSize: 10)),
          const SizedBox(width: 6),
          const Text('= fewer deaths', style: TextStyle(color: _T.muted, fontSize: 10)),
          const SizedBox(width: 16),
          const Text('Deep / saturated', style: TextStyle(color: _T.muted, fontSize: 10)),
          const SizedBox(width: 6),
          const Text('= more deaths', style: TextStyle(color: _T.muted, fontSize: 10)),
          const Spacer(),
          Row(children: [
            for (final ratio in [0.15, 0.4, 0.65, 0.9])
              Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.only(left: 3),
                decoration: BoxDecoration(
                  color: HSLColor.fromAHSL(
                          1, _T.ringHue[5], (0.32 + ratio * 0.55).clamp(0.0, 1.0),
                          (0.86 - ratio * 0.52).clamp(0.0, 1.0))
                      .toColor(),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _T.border),
                ),
              ),
          ]),
        ]),
      ]),
    );
  }

  // ── The sunburst itself, in its own elevated card ────
  Widget _sunburstCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_T.surface, _T.surfaceAlt],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _T.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: LayoutBuilder(builder: (ctx, box) {
        final size = min(box.maxWidth, 640.0);
        return Center(
          child: GestureDetector(
            onTapUp: (details) {
              _handleTap(details.localPosition, size);
              if (_selected != null) _showNodeInfo(_selected!);
            },
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
                  totalDeaths: _root?.deaths ?? 0,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── Persistent summary card for whatever is selected ─
  Widget _selectionSummaryCard(_Node n) {
    final swatch = _T.ringSwatch(n.level);
    final topCauses = (n.causeCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: swatch.withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(color: swatch.withValues(alpha: 0.12), blurRadius: 16)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: swatch, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(n.levelLabel.toUpperCase(),
                style: TextStyle(color: swatch, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: _T.muted),
            onPressed: () => setState(() => _selected = null),
            tooltip: 'Clear selection',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ]),
        const SizedBox(height: 8),
        Text(n.name,
            style: const TextStyle(color: _T.text, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(n.breadcrumb, style: const TextStyle(color: _T.muted, fontSize: 11)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: _miniStat('Total Deaths', '${n.deaths}', _T.red),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _miniStat('Diseases Recorded', '${n.causeCounts.length}', _T.accent),
          ),
        ]),
        if (topCauses.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('TOP CAUSES HERE',
              style: TextStyle(color: _T.muted, fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...topCauses.map((e) {
            final pct = n.deaths == 0 ? 0.0 : (e.value / n.deaths * 100);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Expanded(
                  child: Text(e.key,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _T.sub, fontSize: 12)),
                ),
                Text('${e.value} · ${pct.toStringAsFixed(1)}%',
                    style: TextStyle(color: swatch, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            );
          }),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showNodeInfo(n),
            icon: const Icon(Icons.list_alt_rounded, size: 16),
            label: const Text('View full disease breakdown'),
            style: OutlinedButton.styleFrom(
              foregroundColor: swatch,
              side: BorderSide(color: swatch.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _miniStat(String label, String value, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: _T.muted, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        ]),
      );
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
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
  final int totalDeaths;

  _SunburstPainter({
    required this.nodes,
    required this.colorFor,
    required this.innerHole,
    required this.ringCount,
    required this.selected,
    required this.totalDeaths,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final ringWidth = (maxRadius - innerHole) / ringCount;

    for (final n in nodes) {
      final baseInnerR = innerHole + (n.level - 1) * ringWidth;
      final baseOuterR = baseInnerR + ringWidth;

      final isSelected = n == selected;
      final isRelated = selected == null || _isRelated(n, selected!);
      final isDimmed = !isRelated;

      // Selected arc "pops" outward slightly for a satisfying, tactile feel.
      final pop = isSelected ? 6.0 : 0.0;
      final innerR = baseInnerR + (isSelected ? pop * 0.3 : 0);
      final outerR = baseOuterR + pop;

      // Small angular gap between segments so the sunburst reads as
      // distinct, rounded "petals" rather than one solid disc.
      final gap = min(0.014, n.sweepAngle * 0.12);
      final start = n.startAngle + gap;
      final sweep = max(n.sweepAngle - gap * 2, 0.0001);

      final path = _segmentPath(center, innerR, outerR, start, sweep);

      final fillColor = colorFor(n);

      if (isDimmed) {
        // Simple flat, faded fill for context that isn't on the
        // selected path — keeps focus on what matters.
        canvas.drawPath(
          path,
          Paint()
            ..color = fillColor.withValues(alpha: 0.18)
            ..style = PaintingStyle.fill,
        );
      } else {
        // Subtle radial gradient gives each petal a touch of depth.
        final rect = Rect.fromCircle(center: center, radius: outerR);
        final shader = RadialGradient(
          colors: [Color.lerp(fillColor, Colors.white, 0.18)!, fillColor],
          stops: const [0.0, 1.0],
        ).createShader(rect);

        canvas.drawPath(path, Paint()..shader = shader..style = PaintingStyle.fill);
      }

      // Soft outer glow for the exact selected arc.
      if (isSelected) {
        canvas.drawPath(
          path,
          Paint()
            ..color = fillColor.withValues(alpha: 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6),
        );
      }

      final strokePaint = Paint()
        ..color = _T.bg.withValues(alpha: isDimmed ? 0.35 : 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 1.6 : 0.8;
      canvas.drawPath(path, strokePaint);
    }

    _drawCenterHub(canvas, center);
  }

  Path _segmentPath(Offset center, double innerR, double outerR, double start, double sweep) {
    return Path()
      ..moveTo(
        center.dx + innerR * cos(start),
        center.dy + innerR * sin(start),
      )
      ..arcTo(Rect.fromCircle(center: center, radius: innerR), start, sweep, false)
      ..lineTo(
        center.dx + outerR * cos(start + sweep),
        center.dy + outerR * sin(start + sweep),
      )
      ..arcTo(Rect.fromCircle(center: center, radius: outerR), start + sweep, -sweep, false)
      ..close();
  }

  void _drawCenterHub(Canvas canvas, Offset center) {
    final holeRadius = innerHole - 4;

    final gradient = const RadialGradient(colors: [_T.surfaceAlt, _T.bg]);
    final rect = Rect.fromCircle(center: center, radius: holeRadius);
    canvas.drawCircle(center, holeRadius, Paint()..shader = gradient.createShader(rect));
    canvas.drawCircle(
      center,
      holeRadius,
      Paint()
        ..color = _T.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final headline = selected != null ? '${selected!.deaths}' : '$totalDeaths';
    final subline = selected != null ? _shortName(selected!.name) : 'Total Deaths';
    final headlineColor = selected != null ? colorFor(selected!) : _T.text;

    final tp = TextPainter(
      text: TextSpan(children: [
        TextSpan(
          text: '$headline\n',
          style: TextStyle(color: headlineColor, fontSize: 20, fontWeight: FontWeight.bold, height: 1.1),
        ),
        TextSpan(
          text: subline,
          style: const TextStyle(color: _T.muted, fontSize: 9, fontWeight: FontWeight.w600),
        ),
      ]),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '…',
    )..layout(maxWidth: holeRadius * 1.7);

    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  String _shortName(String s) => s.length > 16 ? '${s.substring(0, 15)}…' : s;

  bool _isRelated(_Node n, _Node selected) {
    if (n == selected) return true;
    _Node? p = selected.parent;
    while (p != null) {
      if (p == n) return true;
      p = p.parent;
    }
    return n.breadcrumb.startsWith(selected.breadcrumb);
  }

  @override
  bool shouldRepaint(covariant _SunburstPainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.selected != selected ||
        oldDelegate.totalDeaths != totalDeaths;
  }
}