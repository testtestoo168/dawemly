import 'dart:math' show min, max;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';
import '../../l10n/app_locale.dart';

class AdminOvertime extends StatefulWidget {
  final Map<String, dynamic>? adminUser;
  const AdminOvertime({super.key, this.adminUser});
  @override State<AdminOvertime> createState() => _AdminOvertimeState();
}

class _AdminOvertimeState extends State<AdminOvertime> {
  final _mono = GoogleFonts.ibmPlexMono;
  final _months = L.months;
  late int _selMonth, _selYear;
  double _standardHours = 8.0;
  List<Map<String, dynamic>> _allRecords = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selMonth = now.month;
    _selYear = now.year;
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final settingsRes = await ApiService.get('admin.php?action=get_settings');
      if (settingsRes['success'] == true && mounted) {
        final s = settingsRes['settings'] as Map<String, dynamic>? ?? {};
        _standardHours = double.tryParse('${s['generalH'] ?? ''}') ?? 8.0;
      }
      final recRes = await ApiService.get('attendance.php?action=all_records');
      if (recRes['success'] == true && mounted) {
        final list = (recRes['records'] as List? ?? []).cast<Map<String, dynamic>>();
        setState(() { _allRecords = list; _loading = false; });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Compute overtime list for selected month
  List<Map<String, dynamic>> _computeOvertimeList(List<Map<String, dynamic>> records) {
    final withOT = <Map<String, dynamic>>[];
    for (final r in records) {
      final ci = r['first_check_in'] ?? r['check_in'];
      final co = r['last_check_out'] ?? r['check_out'];
      if (ci != null && co != null) {
        final totalMin = (r['total_worked_minutes'] is int)
            ? r['total_worked_minutes'] as int
            : int.tryParse('${r['total_worked_minutes'] ?? ''}') ?? 0;
        double hours;
        if (totalMin > 0) {
          hours = totalMin / 60.0;
        } else {
          final ciDt = _parseTs(ci);
          final coDt = _parseTs(co);
          hours = (ciDt != null && coDt != null) ? coDt.difference(ciDt).inMinutes / 60.0 : 0;
        }
        final otManualRaw = r['overtime_manual_minutes'];
        final otManual = otManualRaw != null ? (otManualRaw is int ? otManualRaw : int.tryParse('$otManualRaw')) : null;
        final otCancelled = r['overtime_cancelled'] == true;

        double ot;
        if (otCancelled) {
          ot = 0;
        } else if (otManual != null) {
          ot = otManual / 60.0;
        } else {
          ot = (hours - _standardHours).clamp(0.0, 24.0);
        }

        if (ot > 0 || otCancelled || otManual != null) {
          withOT.add({...r, 'workH': hours, 'overtime': ot, 'otCancelled': otCancelled, 'otReason': r['overtime_reason'] ?? ''});
        }
      }
    }
    withOT.sort((a, b) => (b['overtime'] as double).compareTo(a['overtime'] as double));
    return withOT;
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isWide = screenW > 800;
    final isMobile = screenW < 500;
    final monthPrefix = '$_selYear-${_selMonth.toString().padLeft(2, '0')}';

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final records = _allRecords.where((r) => (r['date_key'] ?? '').toString().startsWith(monthPrefix)).toList();
    final withOT = _computeOvertimeList(records);
    double totalOT = 0;
    for (final e in withOT) { totalOT += e['overtime'] as double; }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: SingleChildScrollView(padding: EdgeInsets.all(isWide ? 28 : 14), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const SizedBox(height: 4),

        // Month selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: DS.cardDecoration(),
          child: Row(children: [
            InkWell(onTap: () => setState(() { _selMonth--; if (_selMonth < 1) { _selMonth = 12; _selYear--; } }), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(4)), child: Icon(Icons.chevron_right, size: 18, color: W.sub))),
            const Spacer(),
            Text('${_months[_selMonth - 1]} $_selYear', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: W.text)),
            const Spacer(),
            InkWell(onTap: () => setState(() { _selMonth++; if (_selMonth > 12) { _selMonth = 1; _selYear++; } }), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(4)), child: Icon(Icons.chevron_left, size: 18, color: W.sub))),
          ]),
        ),

        // Stat cards
        if (isWide)
          Row(children: [
            Expanded(child: _stat(Icons.more_time, L.tr('total_overtime'), '${totalOT.toStringAsFixed(1)}h', W.orange, const Color(0xFFFFFAEB), L.tr('overtime'))),
            const SizedBox(width: 14),
            Expanded(child: _stat(Icons.people, L.tr('total_employees'), '${withOT.where((e) => (e['overtime'] as double) > 0).length}', W.pri, W.priLight, L.tr('n_record', args: {'n': records.length.toString()}))),
            const SizedBox(width: 14),
            Expanded(child: _stat(Icons.access_time, L.tr('top_overtime'), withOT.isNotEmpty && (withOT.first['overtime'] as double) > 0 ? '${withOT.first['overtime'].toStringAsFixed(1)}h' : '—', W.green, const Color(0xFFECFDF3), withOT.isNotEmpty && (withOT.first['overtime'] as double) > 0 ? L.localName(withOT.first) : '—')),
          ])
        else
          SizedBox(height: 130, child: ListView(scrollDirection: Axis.horizontal, children: [
            SizedBox(width: isMobile ? 160 : 180, child: _stat(Icons.more_time, L.tr('total_overtime'), '${totalOT.toStringAsFixed(1)}h', W.orange, const Color(0xFFFFFAEB), L.tr('overtime'))),
            const SizedBox(width: 10),
            SizedBox(width: isMobile ? 140 : 160, child: _stat(Icons.people, L.tr('total_employees'), '${withOT.where((e) => (e['overtime'] as double) > 0).length}', W.pri, W.priLight, L.tr('n_employee', args: {'n': records.length.toString()}))),
            const SizedBox(width: 10),
            SizedBox(width: isMobile ? 160 : 180, child: _stat(Icons.access_time, L.tr('top_overtime'), withOT.isNotEmpty && (withOT.first['overtime'] as double) > 0 ? '${withOT.first['overtime'].toStringAsFixed(1)}h' : '—', W.green, const Color(0xFFECFDF3), withOT.isNotEmpty && (withOT.first['overtime'] as double) > 0 ? L.localName(withOT.first) : '—')),
          ])),
        const SizedBox(height: 20),

        // ─── WEB: Two-panel layout ───
        if (isWide) ...[
          if (withOT.isEmpty)
            _emptyState()
          else
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Left panel (40%) - Summary
              Expanded(flex: 4, child: _webSummaryPanel(withOT, totalOT)),
              const SizedBox(width: 20),
              // Right panel (60%) - Overtime data table
              Expanded(flex: 6, child: _webOvertimeTable(withOT)),
            ]),
          const SizedBox(height: 20),
          // Full-width bottom table (all employees)
          _allEmployeesTable(records, isMobile),
        ]

        // ─── MOBILE: Original card layout ───
        else ...[
          if (withOT.isEmpty)
            _emptyState()
          else
            ...withOT.map((emp) => _overtimeCard(emp, isMobile)),
          const SizedBox(height: 20),
          _allEmployeesTable(records, isMobile),
        ],

        const SizedBox(height: 20),
      ])),
    );
  }

  // ────────────────────────────────────────────────────────
  //  WEB: Right panel — Overtime data table
  // ────────────────────────────────────────────────────────
  Widget _webOvertimeTable(List<Map<String, dynamic>> withOT) {
    return Container(
      decoration: DS.cardDecoration(),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: W.div))),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFFFFAEB), borderRadius: BorderRadius.circular(20)),
              child: Text('${withOT.length}', style: _mono(fontSize: 12, fontWeight: FontWeight.w700, color: W.orange)),
            ),
            const SizedBox(width: 10),
            const Spacer(),
            Icon(Icons.more_time, size: 18, color: W.orange),
            const SizedBox(width: 8),
            Text(L.tr('overtime_records'), style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: W.text)),
          ]),
        ),
        // Table header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(color: W.bg),
          child: Row(children: [
            SizedBox(width: 140, child: Text(L.tr('actions'), style: _tableHeader(), textAlign: TextAlign.center)),
            Expanded(flex: 2, child: Text(L.tr('status'), style: _tableHeader(), textAlign: TextAlign.center)),
            Expanded(flex: 2, child: Text(L.tr('overtime'), style: _tableHeader(), textAlign: TextAlign.center)),
            Expanded(flex: 2, child: Text(L.tr('work_hours'), style: _tableHeader(), textAlign: TextAlign.center)),
            Expanded(flex: 3, child: Text(L.tr('employee_filter'), style: _tableHeader(), textAlign: TextAlign.right)),
          ]),
        ),
        // Table rows
        ...withOT.asMap().entries.map((entry) {
          final i = entry.key;
          final emp = entry.value;
          final name = L.localName(emp).isNotEmpty ? L.localName(emp) : '—';
          final ot = emp['overtime'] as double;
          final workH = emp['workH'] as double;
          final otCancelled = emp['otCancelled'] == true;
          final otReason = emp['otReason'] ?? '';
          final docId = emp['id']?.toString() ?? emp['_docId']?.toString() ?? '';
          final dateKey = emp['dateKey'] ?? '';

          return Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: i.isEven ? W.white : W.bg.withValues(alpha: 0.4),
                border: otCancelled ? Border.all(color: W.red.withValues(alpha: 0.15)) : null,
              ),
              child: Row(children: [
                // Actions
                SizedBox(width: 140, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _webActionBtn(Icons.edit, L.tr('edit'), W.orange, const Color(0xFFFFFAEB), () => _editOvertimeDialog(docId, name, emp)),
                  const SizedBox(width: 6),
                  if (!otCancelled)
                    _webActionBtn(Icons.cancel, L.tr('cancel'), W.red, const Color(0xFFFEF3F2), () => _cancelOvertimeDialog(docId, name))
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: const Color(0xFFFEF3F2), borderRadius: BorderRadius.circular(DS.radiusMd)),
                      child: Text(L.tr('cancelled'), style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.red)),
                    ),
                ])),
                // Status
                Expanded(flex: 2, child: Center(child: _badge(
                  otCancelled ? L.tr('cancelled') : L.tr('overtime_stat'),
                  otCancelled ? W.red : W.orange,
                  otCancelled ? const Color(0xFFFEF3F2) : const Color(0xFFFFFAEB),
                ))),
                // Overtime hours
                Expanded(flex: 2, child: Center(child: Text(
                  otCancelled ? '0.0h' : '+${ot.toStringAsFixed(1)}h',
                  style: _mono(fontSize: 13, fontWeight: FontWeight.w700, color: otCancelled ? W.muted : W.orange),
                ))),
                // Work hours
                Expanded(flex: 2, child: Center(child: Text(
                  '${workH.toStringAsFixed(1)}h',
                  style: _mono(fontSize: 13, color: W.text),
                ))),
                // Name + date
                Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(name, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: otCancelled ? W.muted : W.text), overflow: TextOverflow.ellipsis),
                  if (dateKey.toString().isNotEmpty)
                    Text(dateKey.toString(), style: _mono(fontSize: 10, color: W.sub)),
                ])),
              ]),
            ),
            // Reason row (if exists)
            if (otReason.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
                color: W.bg.withValues(alpha: 0.3),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Flexible(child: Text(otReason, style: GoogleFonts.tajawal(fontSize: 11, color: W.sub), textAlign: TextAlign.right)),
                  const SizedBox(width: 6),
                  Icon(Icons.comment, size: 12, color: W.muted),
                ]),
              ),
            Divider(height: 1, color: W.div),
          ]);
        }),
      ]),
    );
  }

  Widget _webActionBtn(IconData icon, String label, Color color, Color bg, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DS.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(DS.radiusMd), border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  TextStyle _tableHeader() => GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.sub);

  // ────────────────────────────────────────────────────────
  //  WEB: Left panel — Summary with chart
  // ────────────────────────────────────────────────────────
  Widget _webSummaryPanel(List<Map<String, dynamic>> withOT, double totalOT) {
    // Aggregate by employee name for top 5
    final Map<String, double> byEmployee = {};
    for (final e in withOT) {
      final name = L.localName(e).isNotEmpty ? L.localName(e) : '—';
      final ot = e['overtime'] as double;
      byEmployee[name] = (byEmployee[name] ?? 0) + ot;
    }
    final sorted = byEmployee.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();
    final activeCount = withOT.where((e) => (e['overtime'] as double) > 0).length;
    final cancelledCount = withOT.where((e) => e['otCancelled'] == true).length;

    return Column(children: [
      // Big total OT card
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: W.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: W.border),
        ),
        child: Column(children: [
          Icon(Icons.more_time, size: 32, color: W.orange),
          const SizedBox(height: 8),
          Text(totalOT.toStringAsFixed(1), style: _mono(fontSize: 36, fontWeight: FontWeight.w800, color: W.text)),
          Text(L.tr('overtime_hour'), style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w500, color: W.sub)),
          const SizedBox(height: 16),
          Divider(color: W.div),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _miniStat('$cancelledCount', L.tr('cancelled'), W.red),
            Container(width: 1, height: 30, color: W.div),
            _miniStat('$activeCount', L.tr('enabled'), W.green),
          ]),
        ]),
      ),
      const SizedBox(height: 16),

      // Pie chart: active vs cancelled
      if (activeCount > 0 || cancelledCount > 0)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: DS.cardDecoration(),
          child: Column(children: [
            Align(alignment: Alignment.centerRight, child: Text(L.tr('status_distribution_label'), style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: W.text))),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: PieChart(PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 30,
                sections: [
                  if (activeCount > 0)
                    PieChartSectionData(
                      value: activeCount.toDouble(),
                      title: '$activeCount',
                      color: W.orange,
                      radius: 35,
                      titleStyle: _mono(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  if (cancelledCount > 0)
                    PieChartSectionData(
                      value: cancelledCount.toDouble(),
                      title: '$cancelledCount',
                      color: W.red,
                      radius: 35,
                      titleStyle: _mono(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                ],
              )),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _legendDot(W.red, L.tr('cancelled')),
              const SizedBox(width: 16),
              _legendDot(W.orange, L.tr('enabled')),
            ]),
          ]),
        ),
      const SizedBox(height: 16),

      // Top 5 bar chart
      if (top5.isNotEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: DS.cardDecoration(),
          child: Column(children: [
            Align(alignment: Alignment.centerRight, child: Text(L.tr('top_5_employees_label'), style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: W.text))),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (top5.first.value * 1.2).ceilToDouble(),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIdx, rod, rodIdx) {
                      final name = top5[group.x.toInt()].key;
                      return BarTooltipItem(
                        '$name\n${rod.toY.toStringAsFixed(1)}h',
                        GoogleFonts.tajawal(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= top5.length) return const SizedBox.shrink();
                      final name = top5[idx].key;
                      final short = name.length > 8 ? '${name.substring(0, 8)}..' : name;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(short, style: GoogleFonts.tajawal(fontSize: 9, color: W.sub), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                      );
                    },
                  )),
                  leftTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) => Text('${value.toInt()}', style: _mono(fontSize: 9, color: W.muted)),
                  )),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: max(1, (top5.first.value / 4).ceilToDouble()), getDrawingHorizontalLine: (v) => FlLine(color: W.div, strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                barGroups: top5.asMap().entries.map((entry) {
                  final i = entry.key;
                  final val = entry.value.value;
                  // gradient from orange to a lighter shade
                  final colors = [W.orange, W.orange.withValues(alpha: 0.6)];
                  return BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: val,
                      width: 22,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      gradient: LinearGradient(colors: colors, begin: Alignment.bottomCenter, end: Alignment.topCenter),
                    ),
                  ]);
                }).toList(),
              )),
            ),
          ]),
        ),
      const SizedBox(height: 16),

      // Top 5 list
      if (top5.isNotEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: DS.cardDecoration(),
          child: Column(children: [
            Align(alignment: Alignment.centerRight, child: Text(L.tr('overtime_ranking'), style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: W.text))),
            const SizedBox(height: 12),
            ...top5.asMap().entries.map((entry) {
              final i = entry.key;
              final name = entry.value.key;
              final hrs = entry.value.value;
              final maxH = top5.first.value;
              final ratio = maxH > 0 ? hrs / maxH : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  SizedBox(width: 40, child: Text('${hrs.toStringAsFixed(1)}h', style: _mono(fontSize: 11, fontWeight: FontWeight.w700, color: W.orange))),
                  const SizedBox(width: 8),
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 18,
                      backgroundColor: W.bg,
                      valueColor: AlwaysStoppedAnimation(W.orange.withValues(alpha: 0.7 + 0.3 * (1 - i / 5))),
                    ),
                  )),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 80,
                    child: Text(name, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.text), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(color: i == 0 ? const Color(0xFFFFFAEB) : W.bg, borderRadius: BorderRadius.circular(4)),
                    child: Center(child: Text('${i + 1}', style: _mono(fontSize: 10, fontWeight: FontWeight.w700, color: i == 0 ? W.orange : W.sub))),
                  ),
                ]),
              );
            }),
          ]),
        ),
    ]);
  }

  Widget _miniStat(String value, String label, Color color) {
    return Column(children: [
      Text(value, style: _mono(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.tajawal(fontSize: 11, color: W.sub)),
    ]);
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.tajawal(fontSize: 11, color: W.sub)),
    ]);
  }

  // ────────────────────────────────────────────────────────
  //  Empty state
  // ────────────────────────────────────────────────────────
  Widget _emptyState() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(40),
      decoration: DS.cardDecoration(),
      child: Center(child: Column(children: [
        Icon(Icons.more_time, size: 36, color: W.hint),
        const SizedBox(height: 10),
        Text(L.tr('no_overtime'), style: GoogleFonts.tajawal(fontSize: 13, color: W.muted)),
      ])),
    );
  }

  // ────────────────────────────────────────────────────────
  //  Bottom table: All employees
  // ────────────────────────────────────────────────────────
  Widget _allEmployeesTable(List<Map<String, dynamic>> records, bool isMobile) {
    return Container(
      decoration: DS.cardDecoration(),
      child: Column(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: W.div))),
          child: Align(alignment: Alignment.centerRight, child: Text(L.tr('work_hours_all'), style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: W.text)))),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
          columnSpacing: isMobile ? 16 : 56,
          headingRowColor: WidgetStateProperty.all(W.bg),
          columns: [L.tr('overtime'), L.tr('work_hours'), L.tr('status'), L.tr('employee_filter')].map((h) => DataColumn(label: Text(h, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.sub)))).toList(),
          rows: records.where((r) => (r['first_check_in'] ?? r['check_in']) != null).map((r) {
            final ci = r['first_check_in'] ?? r['check_in'];
            double workH = 0; double ot = 0;
            if (ci != null) {
              final co = r['last_check_out'] ?? r['check_out'];
              final totalMin = (r['total_worked_minutes'] is int)
                  ? r['total_worked_minutes'] as int
                  : int.tryParse('${r['total_worked_minutes'] ?? ''}') ?? 0;
              if (totalMin > 0) {
                workH = totalMin / 60.0;
              } else if (co != null) {
                final ciDt = _parseTs(ci);
                final coDt = _parseTs(co);
                if (ciDt != null && coDt != null) workH = coDt.difference(ciDt).inMinutes / 60.0;
              }
              ot = (workH - 8.0).clamp(0.0, 24.0);
            }
            final hasOut = (r['last_check_out'] ?? r['check_out']) != null;
            return DataRow(cells: [
              DataCell(ot > 0 ? Text('+${ot.toStringAsFixed(1)}h', style: _mono(fontSize: 12, fontWeight: FontWeight.w600, color: W.orange)) : Text('—', style: GoogleFonts.tajawal(color: W.muted))),
              DataCell(Text('${workH.toStringAsFixed(1)}h', style: _mono(fontSize: 12))),
              DataCell(_badge(hasOut ? L.tr('complete') : L.tr('present'), hasOut ? W.green : W.pri, hasOut ? const Color(0xFFECFDF3) : W.priLight)),
              DataCell(Text(L.localName(r), style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.text))),
            ]);
          }).toList(),
        )),
      ]),
    );
  }

  // ────────────────────────────────────────────────────────
  //  Helpers
  // ────────────────────────────────────────────────────────
  DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is String) { try { return DateTime.parse(v); } catch(_) { return null; } }
    return null;
  }

  // ────────────────────────────────────────────────────────
  //  MOBILE: Original overtime card (unchanged)
  // ────────────────────────────────────────────────────────
  Widget _overtimeCard(Map<String, dynamic> emp, bool isMobile) {
    final name = L.localName(emp).isNotEmpty ? L.localName(emp) : '—';
    final ot = emp['overtime'] as double;
    final workH = emp['workH'] as double;
    final otCancelled = emp['otCancelled'] == true;
    final otReason = emp['otReason'] ?? '';
    final docId = emp['id']?.toString() ?? emp['_docId']?.toString() ?? '';
    final dateKey = emp['dateKey'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10), padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(DS.radiusMd), border: Border.all(color: otCancelled ? W.red.withValues(alpha: 0.3) : W.border)),
      child: Column(children: [
        // Top: OT badge + name on the right
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Action buttons (left side in RTL)
          Flexible(
            flex: 0,
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              InkWell(onTap: () => _editOvertimeDialog(docId, name, emp),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: W.orangeL, borderRadius: BorderRadius.circular(DS.radiusMd)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.edit, size: 12, color: W.orange), const SizedBox(width: 4), Text(L.tr('edit'), style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: W.orange))]))),
              if (!otCancelled) InkWell(onTap: () => _cancelOvertimeDialog(docId, name),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFFEF3F2), borderRadius: BorderRadius.circular(DS.radiusMd)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.cancel, size: 12, color: W.red), const SizedBox(width: 4), Text(L.tr('cancel'), style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: W.red))])))
              else Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFFEF3F2), borderRadius: BorderRadius.circular(DS.radiusMd)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.cancel, size: 12, color: W.red), const SizedBox(width: 4), Text(L.tr('cancelled'), style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: W.red))])),
            ]),
          ),
          const Spacer(),
          // Name + date
          Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(name, style: GoogleFonts.tajawal(fontSize: isMobile ? 13 : 14, fontWeight: FontWeight.w700, color: otCancelled ? W.muted : W.text)),
            Text('$dateKey  •  ${workH.toStringAsFixed(1)}h', style: _mono(fontSize: 10, color: W.sub)),
          ])),
          const SizedBox(width: 8),
          // OT badge
          Container(padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: 6), decoration: BoxDecoration(color: otCancelled ? const Color(0xFFFEF3F2) : const Color(0xFFFFFAEB), borderRadius: BorderRadius.circular(DS.radiusMd)),
            child: Column(children: [
              Text(otCancelled ? L.tr('cancelled') : '+${ot.toStringAsFixed(1)}h', style: _mono(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w700, color: otCancelled ? W.red : W.orange)),
              Text(L.tr('overtime_stat'), style: GoogleFonts.tajawal(fontSize: 9, color: W.muted)),
            ])),
        ]),
        if (otReason.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(width: double.infinity, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(DS.radiusMd)),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Flexible(child: Text(otReason, style: GoogleFonts.tajawal(fontSize: 11, color: W.sub), textAlign: TextAlign.right)),
              const SizedBox(width: 6), Icon(Icons.comment, size: 12, color: W.muted),
            ])),
        ],
      ]),
    );
  }

  // ────────────────────────────────────────────────────────
  //  Edit overtime dialog (wider on web)
  // ────────────────────────────────────────────────────────
  void _editOvertimeDialog(String docId, String empName, Map<String, dynamic> emp) {
    final screenW = MediaQuery.of(context).size.width;
    final isWide = screenW > 800;
    final currentOT = emp['overtime'] as double;
    final hoursCtrl = TextEditingController(text: currentOT.toStringAsFixed(1));
    final reasonCtrl = TextEditingController(text: emp['otReason'] ?? '');
    final reasons = [L.tr('forgot_checkout'), L.tr('extra_work_required'), L.tr('system_error'), L.tr('admin_tag'), L.tr('other')];

    showDialog(context: context, builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      insetPadding: EdgeInsets.symmetric(horizontal: isWide ? 40 : 16, vertical: 24),
      child: Container(width: min(isWide ? 500 : 380, screenW - 40), padding: EdgeInsets.all(isWide ? 28 : 20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Flexible(child: Text(L.tr('edit_overtime'), style: GoogleFonts.tajawal(fontSize: isWide ? 18 : 16, fontWeight: FontWeight.w700, color: W.text))),
            const SizedBox(width: 8), Icon(Icons.edit, size: 18, color: W.orange),
          ]),
          const SizedBox(height: 4),
          Text(empName, style: GoogleFonts.tajawal(fontSize: 13, color: W.sub), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Flexible(child: Text(L.tr('overtime_hours_count'), style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub))),
              const SizedBox(width: 4), Icon(Icons.access_time, size: 14, color: W.orange),
            ]),
            const SizedBox(height: 4),
            TextField(controller: hoursCtrl, textAlign: TextAlign.center, textDirection: TextDirection.ltr, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: _mono(fontSize: 18, fontWeight: FontWeight.w700),
              decoration: InputDecoration(hintText: '0.0', suffixText: L.tr('hour'), filled: true, fillColor: W.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.orange, width: 2)))),
          ]),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: Text(L.tr('reason'), style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub))),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end, children: reasons.map((r) => InkWell(onTap: () => reasonCtrl.text = r,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: W.border)),
              child: Text(r, style: GoogleFonts.tajawal(fontSize: 10, color: W.sub))))).toList()),
          const SizedBox(height: 8),
          TextField(controller: reasonCtrl, textAlign: TextAlign.right, maxLines: 2, style: GoogleFonts.tajawal(fontSize: 13),
            decoration: InputDecoration(hintText: L.tr('write_reason_or_select'), hintStyle: GoogleFonts.tajawal(color: W.hint, fontSize: 12), filled: true, fillColor: W.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.border)))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () async {
              final hours = double.tryParse(hoursCtrl.text.trim()) ?? 0;
              await ApiService.post('attendance.php?action=update_record', {
                'id': docId,
                'overtimeManualMinutes': (hours * 60).round(),
                'overtimeCancelled': false,
                'overtimeReason': reasonCtrl.text.trim(),
                'overtimeEditedBy': widget.adminUser?['name'] ?? L.tr('system_admin'),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L.tr('overtime_edited_msg', args: {'name': empName}), style: GoogleFonts.tajawal()), backgroundColor: W.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd))));
                _loadAll();
              }
            },
            icon: const Icon(Icons.save, size: 16), label: Text(L.tr('save_edit'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(backgroundColor: W.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd))))),
          const SizedBox(height: 6),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(L.tr('cancel'), style: GoogleFonts.tajawal(fontSize: 13, color: W.muted))),
        ]))),
    )).whenComplete(() { hoursCtrl.dispose(); reasonCtrl.dispose(); });
  }

  // ────────────────────────────────────────────────────────
  //  Cancel overtime dialog (wider on web)
  // ────────────────────────────────────────────────────────
  void _cancelOvertimeDialog(String docId, String empName) {
    final screenW = MediaQuery.of(context).size.width;
    final isWide = screenW > 800;
    final reasonCtrl = TextEditingController();
    final reasons = [L.tr('forgot_checkout'), L.tr('data_error'), L.tr('did_not_work'), L.tr('other')];

    showDialog(context: context, builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      insetPadding: EdgeInsets.symmetric(horizontal: isWide ? 40 : 16, vertical: 24),
      child: Container(width: min(isWide ? 450 : 360, screenW - 40), padding: EdgeInsets.all(isWide ? 28 : 20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Flexible(child: Text(L.tr('cancel_overtime'), style: GoogleFonts.tajawal(fontSize: isWide ? 18 : 16, fontWeight: FontWeight.w700, color: W.red))),
            const SizedBox(width: 8), Icon(Icons.cancel, size: 18, color: W.red),
          ]),
          const SizedBox(height: 4),
          Text(empName, style: GoogleFonts.tajawal(fontSize: 13, color: W.sub), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),
          Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end, children: reasons.map((r) => InkWell(onTap: () => reasonCtrl.text = r,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: W.border)),
              child: Text(r, style: GoogleFonts.tajawal(fontSize: 10, color: W.sub))))).toList()),
          const SizedBox(height: 8),
          TextField(controller: reasonCtrl, textAlign: TextAlign.right, style: GoogleFonts.tajawal(fontSize: 13),
            decoration: InputDecoration(hintText: L.tr('cancel_reason'), hintStyle: GoogleFonts.tajawal(color: W.hint, fontSize: 12), filled: true, fillColor: W.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.border)))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () async {
              await ApiService.post('attendance.php?action=update_record', {
                'id': docId,
                'overtimeCancelled': true,
                'overtimeManualMinutes': 0,
                'overtimeReason': reasonCtrl.text.trim(),
                'overtimeEditedBy': widget.adminUser?['name'] ?? L.tr('system_admin'),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L.tr('overtime_cancelled_msg', args: {'name': empName}), style: GoogleFonts.tajawal()), backgroundColor: W.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd))));
                _loadAll();
              }
            },
            icon: const Icon(Icons.cancel, size: 16), label: Text(L.tr('confirm_cancel'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(backgroundColor: W.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd))))),
          const SizedBox(height: 6),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(L.tr('back'), style: GoogleFonts.tajawal(fontSize: 13, color: W.muted))),
        ]))),
    )).whenComplete(reasonCtrl.dispose);
  }

  Widget _stat(IconData icon, String label, String value, Color color, Color bg, String sub) {
    return Container(padding: const EdgeInsets.all(14), decoration: DS.gradientCard(color), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(DS.radiusMd)), child: Icon(icon, size: 16, color: color)),
      const SizedBox(height: 8),
      Text(value, style: _mono(fontSize: 20, fontWeight: FontWeight.w800, color: W.text)),
      const SizedBox(height: 4),
      Text(label, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w500, color: W.sub), overflow: TextOverflow.ellipsis, maxLines: 1),
      if (sub.isNotEmpty) Text(sub, style: GoogleFonts.tajawal(fontSize: 10, color: W.muted), overflow: TextOverflow.ellipsis, maxLines: 1),
    ]));
  }

  Widget _badge(String text, Color color, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );
}
