import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_colors.dart';
import '../../theme/shimmer.dart';
import '../../services/api_service.dart';

class AdminDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(String) onNav;
  const AdminDashboard({super.key, required this.user, required this.onNav});
  @override State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _attRecords = [];
  List<Map<String, dynamic>> _pendingReqs = [];
  List<Map<String, dynamic>> _schedules = [];
  bool _loading = true;

  TextStyle _tj(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);

  // Colors via design system
  static Color get _fg => W.text;
  static Color get _muted => W.sub;
  static Color get _border => W.border;
  static Color get _card => W.card;
  static Color get _secondary => W.div;
  static Color get _primary => W.pri;

  // Chart colors
  static const _chartBlue = Color(0xFF1D4ED8);
  static const _chartGreen = Color(0xFF17B26A);
  static const _chartRed = Color(0xFFF04438);
  // ignore: unused_field
  static const _chartOrange = Color(0xFFF79009);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<Map<String, dynamic>>([
        ApiService.get('users.php?action=list'),
        ApiService.get('attendance.php?action=all_today'),
        ApiService.get('requests.php?action=pending'),
        ApiService.get('admin.php?action=get_schedules'),
      ]);
      if (mounted) {
        setState(() {
          _users = (results[0]['users'] as List? ?? []).cast<Map<String, dynamic>>();
          _attRecords = (results[1]['records'] as List? ?? []).cast<Map<String, dynamic>>();
          _pendingReqs = (results[2]['requests'] as List? ?? []).cast<Map<String, dynamic>>();
          _schedules = (results[3]['schedules'] as List? ?? []).cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is String) { try { return DateTime.parse(v); } catch (_) { return null; } }
    return null;
  }

  String _fmtTs(dynamic v) {
    final dt = _parseTs(v);
    if (dt == null) return '';
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'م' : 'ص'}';
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isWide = screenW > 800;
    final isSmall = screenW < 600;

    final totalEmps = _users.where((u) => (u['name'] ?? '').toString().isNotEmpty && u['role'] != 'admin' && u['role'] != 'superadmin').length;
    final present = _attRecords.where((r) => r['is_checked_in'] == 1 || r['is_checked_in'] == true).length;
    final complete = _attRecords.where((r) => (r['is_checked_in'] == 0 || r['is_checked_in'] == false) && (r['check_in'] ?? r['first_check_in']) != null).length;
    final absent = totalEmps > present ? totalEmps - present : 0;
    final pendingReqs = _pendingReqs.length;

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isWide ? 28 : 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [

          // ═══ STATS GRID — URS exact style ═══
          if (_loading)
            GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              mainAxisSpacing: isSmall ? 12 : 20,
              crossAxisSpacing: isSmall ? 12 : 20,
              childAspectRatio: isWide ? 2.6 : (isSmall ? 1.4 : 1.8),
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              children: List.generate(4, (_) => const ShimmerStatCard()),
            )
          else
            GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              mainAxisSpacing: isSmall ? 12 : 20,
              crossAxisSpacing: isSmall ? 12 : 20,
              childAspectRatio: isWide ? 2.6 : (isSmall ? 1.4 : 1.8),
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              children: [
                _statCard(Icons.people_rounded, 'إجمالي الموظفين', '$totalEmps', 'موظف', W.pri),
                _statCard(Icons.check_circle_rounded, 'الحاضرون', '$present', '$complete مكتمل', W.green),
                _statCard(Icons.cancel_rounded, 'الغائبون', '$absent', 'غائب', W.red),
                _statCard(Icons.pending_actions_rounded, 'طلبات معلقة', '$pendingReqs', 'طلب', W.orange),
              ],
            ),
          const SizedBox(height: 24),

          // ═══ QUICK ACTIONS — URS exact style ═══
          GridView.count(
            crossAxisCount: isWide ? 4 : 2,
            mainAxisSpacing: isSmall ? 8 : 12,
            crossAxisSpacing: isSmall ? 8 : 12,
            childAspectRatio: isWide ? 3.5 : (isSmall ? 2.2 : 2.8),
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            children: [
              _quickAction(Icons.wifi_tethering_rounded, 'إثبات الحالة', () => widget.onNav('verify')),
              _quickAction(Icons.person_add_alt_1_rounded, 'إضافة موظف', () => widget.onNav('usermgmt')),
              _quickAction(Icons.assignment_rounded, 'الطلبات المعلقة', () => widget.onNav('requests')),
              _quickAction(Icons.bar_chart_rounded, 'التقارير', () => widget.onNav('reports')),
            ],
          ),
          const SizedBox(height: 24),

          // ═══ CHARTS + TOP LIST — fl_chart professional ═══
          if (isWide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, textDirection: TextDirection.rtl, children: [
              // Bar Chart — 2fr
              Expanded(flex: 2, child: _barChartCard(250)),
              const SizedBox(width: 20),
              // Pie Chart — 1fr
              Expanded(child: _pieChartCard(present, absent, complete, totalEmps, 250)),
            ])
          else ...[
            _barChartCard(200),
            const SizedBox(height: 20),
            _pieChartCard(present, absent, complete, totalEmps, 200),
          ],
          const SizedBox(height: 20),

          // ═══ LINE CHART — full width ═══
          _lineChartCard(isWide ? 250 : 200),
          const SizedBox(height: 20),

          // ═══ ABSENT TODAY ═══
          _absentTodayCard(),
          const SizedBox(height: 20),

          // ═══ TOP ATTENDANCE ��══
          _topAttendanceCard(),
          const SizedBox(height: 24),

          // ═══ WHO'S IN/OUT — Jibble style ═══
          _whosInOut(),
          const SizedBox(height: 24),

          // ═══ RECENT TABLE — URS style ═══
          _recentRequestsTable(),
        ]),
      ),
    );
  }

  // ─── Stat Card — URS exact: icon left + info right ───
  Widget _statCard(IconData icon, String label, String value, String change, Color accent) {
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width < 400 ? 12 : 20),
      decoration: DS.gradientCard(accent),
      child: Row(textDirection: TextDirection.rtl, children: [
        // Info right
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: _tj(11, color: _muted), overflow: TextOverflow.ellipsis, maxLines: 1),
          const SizedBox(height: 4),
          Text(value, style: _tj(MediaQuery.of(context).size.width < 400 ? 20 : 26, weight: FontWeight.w600, color: _fg)),
          const SizedBox(height: 2),
          Text(change, style: _tj(10, color: _muted)),
        ])),
        const SizedBox(width: 8),
        // Icon left
        Container(
          width: MediaQuery.of(context).size.width < 400 ? 36 : 44, height: MediaQuery.of(context).size.width < 400 ? 36 : 44,
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(DS.radiusMd)),
          child: Icon(icon, size: MediaQuery.of(context).size.width < 400 ? 18 : 20, color: accent),
        ),
      ]),
    );
  }

  // ─── Quick Action — URS exact style ───
  Widget _quickAction(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        hoverColor: _secondary,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width < 400 ? 12 : 20, vertical: MediaQuery.of(context).size.width < 400 ? 10 : 16),
          decoration: DS.cardDecoration(),
          child: Row(textDirection: TextDirection.rtl, children: [
            Icon(icon, size: 18, color: _primary),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: _tj(13, weight: FontWeight.w600, color: _fg), overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ),
    );
  }

  // ─── Helper: chart card wrapper ───
  Widget _chartWrapper({required String title, required IconData icon, required double height, required Widget child}) {
    return Container(
      decoration: DS.cardDecoration(),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: W.div))),
          child: Row(textDirection: TextDirection.rtl, children: [
            Icon(icon, size: 14, color: _muted),
            const SizedBox(width: 8),
            Text(title, style: _tj(15, weight: FontWeight.w600, color: _fg)),
          ]),
        ),
        SizedBox(height: height, child: child),
      ]),
    );
  }

  // ─── Chart 1: Bar Chart — حضور آخر 7 أيام ───
  Widget _barChartCard(double chartHeight) {
    return _chartWrapper(
      title: 'حضور آخر 7 أيام',
      icon: Icons.bar_chart_rounded,
      height: chartHeight,
      child: FutureBuilder<List<int>>(
        future: _getLast7Days(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          final counts = snap.data ?? List.filled(7, 0);
          final now = DateTime.now();
          final dayNames = ['أحد','إثنين','ثلاثاء','أربعاء','خميس','جمعة','سبت'];
          final maxY = counts.isEmpty ? 5.0 : (counts.reduce((a, b) => a > b ? a : b)).toDouble();
          final topY = maxY < 1 ? 5.0 : (maxY * 1.3).ceilToDouble();

          return Directionality(
            textDirection: TextDirection.ltr,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: topY,
                  minY: 0,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipRoundedRadius: 8,
                      tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      getTooltipColor: (_) => _fg,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final d = now.subtract(Duration(days: 6 - group.x.toInt()));
                        return BarTooltipItem(
                          '${dayNames[d.weekday % 7]}\n${rod.toY.toInt()} حاضر',
                          GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max || value == meta.min) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text('${value.toInt()}', style: GoogleFonts.tajawal(fontSize: 10, color: _muted)),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx > 6) return const SizedBox.shrink();
                          final d = now.subtract(Duration(days: 6 - idx));
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(dayNames[d.weekday % 7], style: GoogleFonts.tajawal(fontSize: 10, color: _muted)),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: topY > 10 ? (topY / 5).ceilToDouble() : 1,
                    getDrawingHorizontalLine: (value) => FlLine(color: _border.withValues(alpha: 0.5), strokeWidth: 0.8),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(7, (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: counts[i].toDouble(),
                        color: _chartBlue,
                        width: chartHeight > 220 ? 22 : 16,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                        backDrawRodData: BackgroundBarChartRodData(show: true, toY: topY, color: _secondary.withValues(alpha: 0.3)),
                      ),
                    ],
                  )),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Chart 2: Pie/Donut Chart — حالة اليوم ───
  Widget _pieChartCard(int present, int absent, int complete, int totalEmps, double chartHeight) {
    return _chartWrapper(
      title: 'حالة اليوم',
      icon: Icons.pie_chart_rounded,
      height: chartHeight + 60, // extra for legend
      child: Column(children: [
        Expanded(
          child: totalEmps == 0
            ? Center(child: Text('لا توجد بيانات', style: _tj(13, color: _muted)))
            : PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: chartHeight > 220 ? 44 : 34,
                  sections: [
                    if (present > 0)
                      PieChartSectionData(
                        value: present.toDouble(),
                        color: _chartGreen,
                        radius: chartHeight > 220 ? 40 : 30,
                        title: '$present',
                        titleStyle: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    if (absent > 0)
                      PieChartSectionData(
                        value: absent.toDouble(),
                        color: _chartRed,
                        radius: chartHeight > 220 ? 40 : 30,
                        title: '$absent',
                        titleStyle: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    if (complete > 0)
                      PieChartSectionData(
                        value: complete.toDouble(),
                        color: _chartBlue,
                        radius: chartHeight > 220 ? 40 : 30,
                        title: '$complete',
                        titleStyle: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    if (present == 0 && absent == 0 && complete == 0)
                      PieChartSectionData(
                        value: 1,
                        color: _border,
                        radius: chartHeight > 220 ? 40 : 30,
                        title: '',
                      ),
                  ],
                  pieTouchData: PieTouchData(
                    enabled: true,
                    touchCallback: (event, response) {},
                  ),
                ),
              ),
        ),
        // Center overlay text
        // Legend
        Padding(
          padding: const EdgeInsets.only(bottom: 14, left: 16, right: 16),
          child: Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(_chartGreen, 'حاضر ($present)'),
              const SizedBox(width: 14),
              _legendDot(_chartRed, 'غائب ($absent)'),
              const SizedBox(width: 14),
              _legendDot(_chartBlue, 'مكتمل ($complete)'),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(textDirection: TextDirection.rtl, mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 5),
      Text(label, style: _tj(11, color: _muted)),
    ]);
  }

  // ─── Chart 3: Line Chart — التأخير الأسبوعي ───
  Widget _lineChartCard(double chartHeight) {
    return _chartWrapper(
      title: 'التأخير الأسبوعي',
      icon: Icons.show_chart_rounded,
      height: chartHeight,
      child: FutureBuilder<List<int>>(
        future: _getLast7DaysLateMinutes(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          final minutes = snap.data ?? List.filled(7, 0);
          final now = DateTime.now();
          final dayNames = ['أحد','إثنين','ثلاثاء','أربعاء','خميس','جمعة','سبت'];
          final maxY = minutes.isEmpty ? 10.0 : (minutes.reduce((a, b) => a > b ? a : b)).toDouble();
          final topY = maxY < 1 ? 10.0 : (maxY * 1.3).ceilToDouble();

          return Directionality(
            textDirection: TextDirection.ltr,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: topY,
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipRoundedRadius: 8,
                      tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      getTooltipColor: (_) => _fg,
                      getTooltipItems: (spots) => spots.map((spot) {
                        final d = now.subtract(Duration(days: 6 - spot.x.toInt()));
                        return LineTooltipItem(
                          '${dayNames[d.weekday % 7]}\n${spot.y.toInt()} دقيقة',
                          GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                        );
                      }).toList(),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max || value == meta.min) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text('${value.toInt()}', style: GoogleFonts.tajawal(fontSize: 10, color: _muted)),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx > 6) return const SizedBox.shrink();
                          final d = now.subtract(Duration(days: 6 - idx));
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(dayNames[d.weekday % 7], style: GoogleFonts.tajawal(fontSize: 10, color: _muted)),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: topY > 10 ? (topY / 5).ceilToDouble() : 2,
                    getDrawingHorizontalLine: (value) => FlLine(color: _border.withValues(alpha: 0.5), strokeWidth: 0.8),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(7, (i) => FlSpot(i.toDouble(), minutes[i].toDouble())),
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: _chartRed,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 4,
                          color: _card,
                          strokeWidth: 2.5,
                          strokeColor: _chartRed,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [_chartRed.withValues(alpha: 0.25), _chartRed.withValues(alpha: 0.0)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<List<int>> _getLast7Days() async {
    final now = DateTime.now();
    // Single API call instead of 7 separate calls
    try {
      final res = await ApiService.get('attendance.php?action=all_records');
      final records = (res['records'] as List? ?? []).cast<Map<String, dynamic>>();
      List<int> counts = [];
      for (int i = 6; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        counts.add(records.where((r) => (r['date_key'] ?? r['dateKey'] ?? '').toString() == dateStr).length);
      }
      return counts;
    } catch (_) { return List.filled(7, 0); }
  }

  Future<List<int>> _getLast7DaysLateMinutes() async {
    final now = DateTime.now();
    try {
      final res = await ApiService.get('attendance.php?action=all_records');
      final records = (res['records'] as List? ?? []).cast<Map<String, dynamic>>();
      List<int> minutes = [];
      for (int i = 6; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        final dayRecords = records.where((r) => (r['date_key'] ?? r['dateKey'] ?? '').toString() == dateStr);
        int totalLate = 0;
        for (final r in dayRecords) {
          final late = r['late_minutes'] ?? r['lateMinutes'] ?? 0;
          if (late is int) {
            totalLate += late;
          } else if (late is double) {
            totalLate += late.toInt();
          } else {
            totalLate += int.tryParse(late.toString()) ?? 0;
          }
        }
        minutes.add(totalLate);
      }
      return minutes;
    } catch (_) { return List.filled(7, 0); }
  }

  // ─── Absent Today — غائبون اليوم ───
  Widget _absentTodayCard() {
    // Day name mapping: Dart weekday 1=Mon..7=Sun -> Arabic short names
    final dayMap = {1: 'إثنين', 2: 'ثلاثاء', 3: 'أربعاء', 4: 'خميس', 5: 'جمعة', 6: 'سبت', 7: 'أحد'};
    final todayName = dayMap[DateTime.now().weekday] ?? '';

    // Get all active employees (not admin/superadmin)
    final allEmps = _users.where((u) =>
      (u['name'] ?? '').toString().isNotEmpty &&
      u['role'] != 'admin' && u['role'] != 'superadmin'
    ).toList();

    // Build set of UIDs who have checked in today
    final checkedInUids = <String>{};
    for (final r in _attRecords) {
      final uid = (r['uid'] ?? '').toString();
      if (uid.isNotEmpty) checkedInUids.add(uid);
    }

    // Find employees who should work today (have a schedule with today's day) but haven't checked in
    final absentEmps = <Map<String, dynamic>>[];

    for (final emp in allEmps) {
      final uid = (emp['uid'] ?? emp['_id'] ?? '').toString();
      if (checkedInUids.contains(uid)) continue; // Already checked in

      // Check if this employee has a schedule for today
      bool scheduledToday = false;
      for (final sch in _schedules) {
        final empIds = (sch['emp_ids'] as List?)?.cast<String>() ??
            (sch['empIds'] as List?)?.cast<String>() ?? [];
        final days = (sch['days'] as List?)?.cast<String>() ??
            (sch['days'] is String ? (sch['days'] as String).split(',') : []);

        if (empIds.contains(uid) && days.contains(todayName)) {
          scheduledToday = true;
          break;
        }
      }

      // If no schedules exist at all, consider all employees as expected
      if (_schedules.isEmpty || scheduledToday) {
        absentEmps.add(emp);
      }
    }

    return Container(
      decoration: DS.cardDecoration(),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: W.div))),
          child: Row(textDirection: TextDirection.rtl, children: [
            Icon(Icons.person_off_rounded, size: 14, color: _chartRed),
            const SizedBox(width: 8),
            Text('غائبون اليوم', style: _tj(15, weight: FontWeight.w600, color: _fg)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFFEF3F2), borderRadius: BorderRadius.circular(DS.radiusMd)),
              child: Text('${absentEmps.length}', style: GoogleFonts.ibmPlexMono(fontSize: 12, fontWeight: FontWeight.w700, color: _chartRed)),
            ),
          ]),
        ),
        if (absentEmps.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: Column(children: [
              Icon(Icons.check_circle_outline, size: 36, color: _chartGreen),
              const SizedBox(height: 8),
              Text('جميع الموظفين حاضرون', style: _tj(13, color: _muted)),
            ])),
          )
        else
          Column(children: absentEmps.take(10).map((emp) {
            final av = (emp['name'] ?? '').toString().length >= 2
                ? emp['name'].toString().substring(0, 2) : 'م';
            final dept = emp['dept'] ?? '';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
              child: Row(textDirection: TextDirection.rtl, children: [
                Stack(children: [
                  Container(width: 36, height: 36,
                    decoration: const BoxDecoration(color: Color(0xFFFEF3F2), shape: BoxShape.circle),
                    child: Center(child: Text(av, style: _tj(12, weight: FontWeight.w700, color: _chartRed))),
                  ),
                  Positioned(bottom: 0, right: 0, child: Container(width: 10, height: 10,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _chartRed, border: Border.all(color: Colors.white, width: 1.5)))),
                ]),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(emp['name'] ?? '', style: _tj(13, weight: FontWeight.w600, color: _fg)),
                  if (dept.toString().isNotEmpty) Text(dept.toString(), style: _tj(10, color: _muted)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFFEF3F2), borderRadius: BorderRadius.circular(DS.radiusMd)),
                  child: Text('غائب', style: _tj(10, weight: FontWeight.w500, color: _chartRed)),
                ),
              ]),
            );
          }).toList()),
        if (absentEmps.length > 10)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text('و ${absentEmps.length - 10} آخرين...', style: _tj(12, color: _muted)),
          ),
      ]),
    );
  }

  // ─── Top Attendance — URS "الأكثر مبيعاً" style ───
  Widget _topAttendanceCard() {
    return Container(
      decoration: DS.cardDecoration(),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: W.div))),
          child: Row(textDirection: TextDirection.rtl, children: [
            Icon(Icons.local_fire_department_rounded, size: 14, color: _muted),
            const SizedBox(width: 8),
            Text('آخر الحضور', style: _tj(15, weight: FontWeight.w600, color: _fg)),
          ]),
        ),
        if (_attRecords.isEmpty)
          Padding(padding: const EdgeInsets.all(40), child: Center(child: Text('لا توجد بيانات', style: _tj(13, color: _muted))))
        else
          Column(children: _attRecords.take(5).map((r) {
            final hasOut = (r['lastCheckOut'] ?? r['last_check_out'] ?? r['checkOut'] ?? r['check_out']) != null;
            final isCheckedIn = r['isCheckedIn'] == true || r['is_checked_in'] == 1 || r['is_checked_in'] == true;
            final av = (r['name'] ?? '').toString().length >= 2 ? r['name'].toString().substring(0, 2) : 'م';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
              child: Row(textDirection: TextDirection.rtl, children: [
                // Avatar with green/grey dot
                Stack(children: [
                  Container(width: 32, height: 32, decoration: BoxDecoration(color: const Color(0xFFEEF2FF), shape: BoxShape.circle),
                    child: Center(child: Text(av, style: _tj(11, weight: FontWeight.w700, color: const Color(0xFF175CD3))))),
                  Positioned(bottom: 0, right: 0, child: Container(width: 10, height: 10,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: isCheckedIn ? const Color(0xFF17B26A) : const Color(0xFFD0D5DD), border: Border.all(color: Colors.white, width: 1.5)))),
                ]),
                const SizedBox(width: 10),
                Expanded(child: Text(r['name'] ?? '', style: _tj(14, weight: FontWeight.w600, color: _fg))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: W.greenL, borderRadius: BorderRadius.circular(DS.radiusMd)),
                  child: Text(hasOut && !isCheckedIn ? 'مكتمل' : 'حاضر', style: _tj(11, weight: FontWeight.w500, color: W.green)),
                ),
              ]),
            );
          }).toList()),
      ]),
    );
  }

  // ─── Who's In/Out — Jibble style ───
  Widget _whosInOut() {
    final screenW = MediaQuery.of(context).size.width;
    final isSmall = screenW < 600;
    final allUsers = _users.where((u) => (u['name'] ?? '').toString().isNotEmpty && u['role'] != 'admin' && u['role'] != 'superadmin').toList();
    allUsers.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));

    final attMap = <String, Map<String, dynamic>>{};
    for (final r in _attRecords) {
      attMap[r['uid'] ?? ''] = r;
    }

    final inList = <Map<String, dynamic>>[];
    final outList = <Map<String, dynamic>>[];

    for (final u in allUsers) {
      final uid = u['uid'] ?? u['_id'] ?? '';
      final att = attMap[uid];
      final isIn = att != null && (att['isCheckedIn'] == true || att['is_checked_in'] == 1 || att['is_checked_in'] == true);
      final hasCheckIn = att != null && (att['firstCheckIn'] ?? att['first_check_in'] ?? att['checkIn'] ?? att['check_in']) != null;
      if (isIn) {
        inList.add({...u, '_att': att});
      } else if (hasCheckIn) {
        outList.add({...u, '_att': att, '_status': 'مكتمل'});
      } else {
        outList.add({...u, '_att': null, '_status': 'غائب'});
      }
    }

    return Container(
      decoration: DS.cardDecoration(),
      child: Column(children: [
        // Header with tabs — wraps on small screens
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: W.div))),
          child: isSmall
            ? Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(textDirection: TextDirection.rtl, children: [
                  Text("Who's in/out", style: _tj(15, weight: FontWeight.w700, color: _fg)),
                  const SizedBox(width: 8),
                  Text('${allUsers.length} موظف', style: _tj(12, color: _muted)),
                ]),
                const SizedBox(height: 8),
                Row(textDirection: TextDirection.rtl, mainAxisAlignment: MainAxisAlignment.end, children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(DS.radiusMd)),
                    child: Text('${inList.length} IN', style: GoogleFonts.ibmPlexMono(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF166534)))),
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFFEF3F2), borderRadius: BorderRadius.circular(DS.radiusMd)),
                    child: Text('${outList.length} OUT', style: GoogleFonts.ibmPlexMono(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFB42318)))),
                ]),
              ])
            : Row(textDirection: TextDirection.rtl, children: [
                Text("Who's in/out", style: _tj(15, weight: FontWeight.w700, color: _fg)),
                const SizedBox(width: 8),
                Text('${allUsers.length} موظف', style: _tj(12, color: _muted)),
                const Spacer(),
                // Counters
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(DS.radiusMd)),
                  child: Text('${inList.length} IN', style: GoogleFonts.ibmPlexMono(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF166534)))),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFFEF3F2), borderRadius: BorderRadius.circular(DS.radiusMd)),
                  child: Text('${outList.length} OUT', style: GoogleFonts.ibmPlexMono(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFB42318)))),
              ]),
        ),

        // IN list
        if (inList.isNotEmpty) ...[
          Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), color: const Color(0xFFF0FDF4),
            child: Text('حاضرون الآن', style: _tj(12, weight: FontWeight.w600, color: const Color(0xFF166534)), textDirection: TextDirection.rtl)),
          ...inList.map((u) {
            final att = u['_att'] as Map<String, dynamic>?;
            final checkInTime = att?['firstCheckIn'] ?? att?['first_check_in'] ?? att?['checkIn'] ?? att?['check_in'];
            final av = (u['name'] ?? '').toString().length >= 2 ? u['name'].toString().substring(0, 2) : 'م';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
              child: Row(textDirection: TextDirection.rtl, children: [
                Stack(children: [
                  Container(width: 36, height: 36, decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
                    child: Center(child: Text(av, style: _tj(12, weight: FontWeight.w700, color: const Color(0xFF175CD3))))),
                  Positioned(bottom: 0, right: 0, child: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF17B26A), border: Border.all(color: Colors.white, width: 1.5)))),
                ]),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u['name'] ?? '', style: _tj(13, weight: FontWeight.w600, color: _fg)),
                  if (checkInTime != null) Text(_fmtTs(checkInTime), style: GoogleFonts.ibmPlexMono(fontSize: 10, color: _muted)),
                ])),
              ]),
            );
          }),
        ],

        // OUT list
        if (outList.isNotEmpty) ...[
          Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), color: const Color(0xFFFEF3F2),
            child: Text('غير متواجدين', style: _tj(12, weight: FontWeight.w600, color: const Color(0xFFB42318)), textDirection: TextDirection.rtl)),
          ...outList.take(10).map((u) {
            final av = (u['name'] ?? '').toString().length >= 2 ? u['name'].toString().substring(0, 2) : 'م';
            final st = u['_status'] ?? 'غائب';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
              child: Row(textDirection: TextDirection.rtl, children: [
                Stack(children: [
                  Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), shape: BoxShape.circle),
                    child: Center(child: Text(av, style: _tj(12, weight: FontWeight.w700, color: _muted)))),
                  Positioned(bottom: 0, right: 0, child: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFD0D5DD), border: Border.all(color: Colors.white, width: 1.5)))),
                ]),
                const SizedBox(width: 10),
                Expanded(child: Text(u['name'] ?? '', style: _tj(13, weight: FontWeight.w600, color: _muted))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: st == 'مكتمل' ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(DS.radiusMd)),
                  child: Text(st, style: _tj(10, weight: FontWeight.w500, color: st == 'مكتمل' ? const Color(0xFF166534) : _muted))),
              ]),
            );
          }),
        ],
      ]),
    );
  }

  // ─── Recent Requests Table — URS "آخر فواتير المبيعات" style ───
  Widget _recentRequestsTable() {
    final screenW = MediaQuery.of(context).size.width;
    final isSmall = screenW < 600;

    Widget tableHeader = Container(
      color: _secondary,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(textDirection: TextDirection.rtl, children: [
        Expanded(flex: 2, child: Text('الموظف', style: _tj(12, weight: FontWeight.w500, color: _muted))),
        Expanded(flex: 2, child: Text('نوع الطلب', style: _tj(12, weight: FontWeight.w500, color: _muted))),
        Expanded(child: Text('الحالة', style: _tj(12, weight: FontWeight.w500, color: _muted))),
      ]),
    );

    Widget tableBody;
    if (_pendingReqs.isEmpty) {
      tableBody = Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('لا توجد طلبات معلقة', style: _tj(13, color: _muted))));
    } else {
      tableBody = Column(children: _pendingReqs.take(8).map((r) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFD1D5DB)))),
          child: Row(textDirection: TextDirection.rtl, children: [
            Expanded(flex: 2, child: Text(r['name'] ?? '', style: _tj(13, weight: FontWeight.w600, color: _fg))),
            Expanded(flex: 2, child: Text('${r['requestType'] ?? r['request_type'] ?? ''} — ${r['leaveType'] ?? r['leave_type'] ?? r['permType'] ?? r['perm_type'] ?? ''}', style: _tj(13, color: _muted), overflow: TextOverflow.ellipsis)),
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFFEF9C3), borderRadius: BorderRadius.circular(DS.radiusMd)),
              child: Text('تحت الإجراء', style: _tj(11, weight: FontWeight.w500, color: const Color(0xFF854D0E))),
            )),
          ]),
        );
      }).toList());
    }

    Widget tableContent = Column(children: [tableHeader, tableBody]);

    // Wrap in horizontal scroll on small screens to prevent overflow
    if (isSmall) {
      tableContent = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 520),
          child: tableContent,
        ),
      );
    }

    return Container(
      decoration: DS.cardDecoration(),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: W.div))),
          child: Row(textDirection: TextDirection.rtl, children: [
            Expanded(child: Row(children: [
              Icon(Icons.assignment_rounded, size: 14, color: _muted),
              const SizedBox(width: 8),
              Text('الطلبات المعلقة', style: _tj(15, weight: FontWeight.w600, color: _fg)),
            ])),
            Material(
              color: _primary, borderRadius: BorderRadius.circular(DS.radiusMd),
              child: InkWell(onTap: () => widget.onNav('requests'), borderRadius: BorderRadius.circular(DS.radiusMd),
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(children: [const Icon(Icons.visibility_rounded, size: 12, color: Colors.white), const SizedBox(width: 4), Text('عرض الكل', style: _tj(12, weight: FontWeight.w500, color: Colors.white))]))),
            ),
          ]),
        ),
        tableContent,
      ]),
    );
  }
}
