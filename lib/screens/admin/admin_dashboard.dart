import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/attendance_service.dart';

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
  bool _loading = true;

  TextStyle _tj(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);

  // URS exact colors
  static const _fg = Color(0xFF1A1A2E);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFD1D5DB);
  static const _card = Colors.white;
  static const _secondary = Color(0xFFE8EDF2);
  static const _primary = Color(0xFF0F3460);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.get('users.php?action=list'),
        ApiService.get('attendance.php?action=all_today'),
        ApiService.get('requests.php?action=pending'),
      ]);
      if (mounted) {
        setState(() {
          _users = (results[0]['users'] as List? ?? []).cast<Map<String, dynamic>>();
          _attRecords = (results[1]['records'] as List? ?? []).cast<Map<String, dynamic>>();
          _pendingReqs = (results[2]['requests'] as List? ?? []).cast<Map<String, dynamic>>();
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
    final isWide = MediaQuery.of(context).size.width > 800;

    final totalEmps = _users.where((u) => (u['name'] ?? '').toString().isNotEmpty && u['role'] != 'admin').length;
    final present = _attRecords.where((r) => r['checkIn'] != null).length;
    final complete = _attRecords.where((r) => r['checkOut'] != null).length;
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
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else
            GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              mainAxisSpacing: 20, crossAxisSpacing: 20,
              childAspectRatio: isWide ? 2.6 : 1.8,
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              children: [
                _statCard(Icons.people_rounded, 'إجمالي الموظفين', '$totalEmps', 'موظف'),
                _statCard(Icons.check_circle_rounded, 'الحاضرون', '$present', '$complete مكتمل'),
                _statCard(Icons.cancel_rounded, 'الغائبون', '$absent', 'غائب'),
                _statCard(Icons.pending_actions_rounded, 'طلبات معلقة', '$pendingReqs', 'طلب'),
              ],
            ),
          const SizedBox(height: 24),

          // ═══ QUICK ACTIONS — URS exact style ═══
          GridView.count(
            crossAxisCount: isWide ? 4 : 2,
            mainAxisSpacing: 12, crossAxisSpacing: 12,
            childAspectRatio: isWide ? 3.5 : 2.8,
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            children: [
              _quickAction(Icons.wifi_tethering_rounded, 'إثبات الحالة', () => widget.onNav('verify')),
              _quickAction(Icons.person_add_alt_1_rounded, 'إضافة موظف', () => widget.onNav('usermgmt')),
              _quickAction(Icons.assignment_rounded, 'الطلبات المعلقة', () => widget.onNav('requests')),
              _quickAction(Icons.bar_chart_rounded, 'التقارير', () => widget.onNav('reports')),
            ],
          ),
          const SizedBox(height: 24),

          // ═══ CHARTS + TOP LIST — URS grid 2fr 1fr ═══
          if (isWide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, textDirection: TextDirection.rtl, children: [
              // Chart — 2fr
              Expanded(flex: 2, child: _chartCard()),
              const SizedBox(width: 20),
              // Top attendance — 1fr
              Expanded(child: _topAttendanceCard()),
            ])
          else ...[
            _chartCard(),
            const SizedBox(height: 20),
            _topAttendanceCard(),
          ],
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
  Widget _statCard(IconData icon, String label, String value, String change) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _card, border: Border.all(color: _border), borderRadius: BorderRadius.circular(6)),
      child: Row(textDirection: TextDirection.rtl, children: [
        // Info right
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: _tj(12, color: _muted)),
          const SizedBox(height: 6),
          Text(value, style: _tj(26, weight: FontWeight.w600, color: _fg)),
          const SizedBox(height: 2),
          Text(change, style: _tj(11, color: _muted)),
        ])),
        const SizedBox(width: 12),
        // Icon left
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: _secondary, borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 20, color: _primary),
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
        borderRadius: BorderRadius.circular(6),
        hoverColor: _secondary,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(color: _card, border: Border.all(color: _border), borderRadius: BorderRadius.circular(6)),
          child: Row(textDirection: TextDirection.rtl, children: [
            Icon(icon, size: 20, color: _primary),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: _tj(14, weight: FontWeight.w600, color: _fg))),
          ]),
        ),
      ),
    );
  }

  // ─── Chart Card — URS "مبيعات آخر 7 أيام" style ───
  Widget _chartCard() {
    return Container(
      decoration: BoxDecoration(color: _card, border: Border.all(color: _border), borderRadius: BorderRadius.circular(6)),
      child: Column(children: [
        // Card header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
          child: Row(textDirection: TextDirection.rtl, children: [
            Icon(Icons.bar_chart_rounded, size: 14, color: _muted),
            const SizedBox(width: 8),
            Text('حضور آخر 7 أيام', style: _tj(15, weight: FontWeight.w600, color: _fg)),
          ]),
        ),
        // Chart body — simple bar chart
        SizedBox(
          height: 250,
          child: FutureBuilder<List<int>>(
            future: _getLast7Days(),
            builder: (context, snap) {
              final counts = snap.data ?? List.filled(7, 0);
              final maxVal = counts.isEmpty ? 1 : (counts.reduce((a, b) => a > b ? a : b));
              final maxH = maxVal == 0 ? 1 : maxVal;
              final now = DateTime.now();
              final dayNames = ['أحد','إثنين','ثلاثاء','أربعاء','خميس','جمعة','سبت'];

              return Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  textDirection: TextDirection.rtl,
                  children: List.generate(7, (i) {
                    final d = now.subtract(Duration(days: 6 - i));
                    final h = maxH > 0 ? (counts[i] / maxH) * 160 : 0.0;
                    return Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text('${counts[i]}', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w700, color: _fg)),
                      const SizedBox(height: 4),
                      Container(
                        height: h < 4 ? 4 : h,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(color: const Color(0xFF1D4ED8), borderRadius: BorderRadius.circular(4)),
                      ),
                      const SizedBox(height: 8),
                      Text(dayNames[d.weekday % 7], style: _tj(11, color: _muted)),
                    ]));
                  }),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Future<List<int>> _getLast7Days() async {
    final now = DateTime.now();
    List<int> counts = [];
    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      try {
        final res = await ApiService.get('attendance.php?action=all_records');
        final records = (res['records'] as List? ?? []).cast<Map<String, dynamic>>();
        counts.add(records.where((r) => (r['dateKey'] ?? r['date'] ?? '').toString() == dateStr).length);
      } catch (_) { counts.add(0); }
    }
    return counts;
  }

  // ─── Top Attendance — URS "الأكثر مبيعاً" style ───
  Widget _topAttendanceCard() {
    return Container(
      decoration: BoxDecoration(color: _card, border: Border.all(color: _border), borderRadius: BorderRadius.circular(6)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
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
            final hasOut = (r['lastCheckOut'] ?? r['checkOut']) != null;
            final isCheckedIn = r['isCheckedIn'] == true;
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
                Expanded(child: Text(r['name'] ?? '', style: _tj(14, weight: FontWeight.w600, color: _fg), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: hasOut && !isCheckedIn ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(6)),
                  child: Text(hasOut && !isCheckedIn ? 'مكتمل' : 'حاضر', style: _tj(11, weight: FontWeight.w500, color: hasOut && !isCheckedIn ? const Color(0xFF166534) : const Color(0xFF1E40AF))),
                ),
              ]),
            );
          }).toList()),
      ]),
    );
  }

  // ─── Who's In/Out — Jibble style ───
  Widget _whosInOut() {
    final allUsers = _users.where((u) => (u['name'] ?? '').toString().isNotEmpty && u['role'] != 'admin').toList();
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
      final isIn = att != null && (att['isCheckedIn'] == true);
      final hasCheckIn = att != null && (att['firstCheckIn'] ?? att['checkIn']) != null;
      if (isIn) {
        inList.add({...u, '_att': att});
      } else if (hasCheckIn) {
        outList.add({...u, '_att': att, '_status': 'مكتمل'});
      } else {
        outList.add({...u, '_att': null, '_status': 'غائب'});
      }
    }

    return Container(
      decoration: BoxDecoration(color: _card, border: Border.all(color: _border), borderRadius: BorderRadius.circular(6)),
      child: Column(children: [
        // Header with tabs
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
          child: Row(textDirection: TextDirection.rtl, children: [
            Text("Who's in/out", style: _tj(15, weight: FontWeight.w700, color: _fg)),
            const SizedBox(width: 8),
            Text('${allUsers.length} موظف', style: _tj(12, color: _muted)),
            const Spacer(),
            // Counters
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
              child: Text('${inList.length} IN', style: GoogleFonts.ibmPlexMono(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF166534)))),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFFEF3F2), borderRadius: BorderRadius.circular(6)),
              child: Text('${outList.length} OUT', style: GoogleFonts.ibmPlexMono(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFB42318)))),
          ]),
        ),

        // IN list
        if (inList.isNotEmpty) ...[
          Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), color: const Color(0xFFF0FDF4),
            child: Text('حاضرون الآن', style: _tj(12, weight: FontWeight.w600, color: const Color(0xFF166534)), textDirection: TextDirection.rtl)),
          ...inList.map((u) {
            final att = u['_att'] as Map<String, dynamic>?;
            final checkInTime = att?['firstCheckIn'] ?? att?['checkIn'];
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
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: st == 'مكتمل' ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
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
    return Container(
      decoration: BoxDecoration(color: _card, border: Border.all(color: _border), borderRadius: BorderRadius.circular(6)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
          child: Row(textDirection: TextDirection.rtl, children: [
            Expanded(child: Row(children: [
              Icon(Icons.assignment_rounded, size: 14, color: _muted),
              const SizedBox(width: 8),
              Text('الطلبات المعلقة', style: _tj(15, weight: FontWeight.w600, color: _fg)),
            ])),
            Material(
              color: _primary, borderRadius: BorderRadius.circular(6),
              child: InkWell(onTap: () => widget.onNav('requests'), borderRadius: BorderRadius.circular(6),
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(children: [const Icon(Icons.visibility_rounded, size: 12, color: Colors.white), const SizedBox(width: 4), Text('عرض الكل', style: _tj(12, weight: FontWeight.w500, color: Colors.white))]))),
            ),
          ]),
        ),
        // Table header
        Container(
          color: _secondary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(textDirection: TextDirection.rtl, children: [
            Expanded(flex: 2, child: Text('الموظف', style: _tj(12, weight: FontWeight.w500, color: _muted))),
            Expanded(flex: 2, child: Text('نوع الطلب', style: _tj(12, weight: FontWeight.w500, color: _muted))),
            Expanded(child: Text('الحالة', style: _tj(12, weight: FontWeight.w500, color: _muted))),
          ]),
        ),
        if (_pendingReqs.isEmpty)
          Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('لا توجد طلبات معلقة', style: _tj(13, color: _muted))))
        else
          Column(children: _pendingReqs.take(8).map((r) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFD1D5DB)))),
              child: Row(textDirection: TextDirection.rtl, children: [
                Expanded(flex: 2, child: Text(r['name'] ?? '', style: _tj(13, weight: FontWeight.w600, color: _fg), overflow: TextOverflow.ellipsis)),
                Expanded(flex: 2, child: Text('${r['requestType'] ?? ''} — ${r['leaveType'] ?? r['permType'] ?? ''}', style: _tj(13, color: _muted), overflow: TextOverflow.ellipsis)),
                Expanded(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFFEF9C3), borderRadius: BorderRadius.circular(6)),
                  child: Text('تحت الإجراء', style: _tj(11, weight: FontWeight.w500, color: const Color(0xFF854D0E))),
                )),
              ]),
            );
          }).toList()),
      ]),
    );
  }
}
