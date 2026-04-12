import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../theme/shimmer.dart';
import '../../services/attendance_service.dart';
import '../../services/api_service.dart';
import '../../l10n/app_locale.dart';

class AdminEmployees extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminEmployees({super.key, required this.user});
  @override State<AdminEmployees> createState() => _AdminEmployeesState();
}

class _AdminEmployeesState extends State<AdminEmployees> {
  final _svc = AttendanceService();
  String _search = '', _fDept = L.tr('all'), _fSt = L.tr('all');
  final _mono = GoogleFonts.ibmPlexMono;
  final _months = L.months;
  final _dayNames = L.dayNamesFull;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _attList = [];
  List<Map<String, dynamic>> _locations = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.get('users.php?action=list'),
        _svc.getAllTodayRecords(),
        ApiService.get('admin.php?action=get_locations'),
      ]);
      final usersRes = results[0] as Map<String, dynamic>;
      final attList = results[1] as List<Map<String, dynamic>>;
      final locsRes = results[2] as Map<String, dynamic>;
      if (mounted) setState(() {
        _users = (usersRes['users'] as List? ?? []).cast<Map<String, dynamic>>();
        _attList = attList;
        _locations = (locsRes['locations'] as List? ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _audit(String action, String target, String details) async {
    await ApiService.post('admin.php?action=audit_log', {
      'user': widget.user['name'] ?? L.tr('system_admin'),
      'action': action, 'target': target, 'details': details, 'type': 'edit',
    });
  }

  DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is String) { try { return DateTime.parse(v); } catch (_) { return null; } }
    return null;
  }

  String _fmtTs(dynamic ts) {
    final dt = _parseTs(ts);
    if (dt == null) return '—';
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? L.tr('pm') : L.tr('am')}';
  }

  String _fmtWorkedTime(int totalMinutes) {
    if (totalMinutes <= 0) return '—';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h > 0 && m > 0) return L.tr('h_m_format', args: {'h': h.toString(), 'm': m.toString()});
    if (h > 0) return L.tr('h_format', args: {'h': h.toString()});
    return L.tr('m_format', args: {'m': m.toString()});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return ListView(
      padding: const EdgeInsets.all(14),
      children: List.generate(6, (_) => const ShimmerEmployeeCard()),
    );

    final allUsers = _users.where((e) => (e['name'] ?? '').toString().isNotEmpty && e['role'] != 'admin' && e['role'] != 'superadmin').toList();
    allUsers.sort((a, b) => L.localName(a).compareTo(L.localName(b)));

    final attMap = <String, Map<String, dynamic>>{};
    for (final r in _attList) attMap[r['uid'] ?? ''] = r;

    final merged = allUsers.map((u) {
      final uid = u['uid'] ?? u['_id'] ?? '';
      final att = attMap[uid];
      final hasIn = (att?['first_check_in'] ?? att?['check_in']) != null;
      final isCheckedIn = att?['is_checked_in'] == 1 || att?['is_checked_in'] == true;
      String status = L.tr('not_present');
      if (isCheckedIn) status = L.tr('present');
      else if (hasIn) status = L.tr('complete');
      return {...u, '_status': status, '_att': att, '_isCheckedIn': isCheckedIn};
    }).toList();

    final depts = <String>{L.tr('all'), ...merged.map((e) => (e['dept'] ?? '').toString()).where((d) => d.isNotEmpty)};
    final filtered = merged.where((e) {
      if (_search.isNotEmpty && !(e['name'] ?? '').toString().contains(_search) && !(e['name_en'] ?? '').toString().toLowerCase().contains(_search.toLowerCase()) && !(e['empId'] ?? e['emp_id'] ?? '').toString().contains(_search)) return false;
      if (_fDept != L.tr('all') && e['dept'] != _fDept) return false;
      if (_fSt != L.tr('all') && e['_status'] != _fSt) return false;
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(MediaQuery.of(context).size.width > 800 ? 28 : 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(L.tr('employee_log'), style: GoogleFonts.tajawal(fontSize: MediaQuery.of(context).size.width < 400 ? 18 : 24, fontWeight: FontWeight.w800, color: W.text)),
          const SizedBox(height: 20),
          Builder(builder: (context) {
            final fW = MediaQuery.of(context).size.width;
            final isFilterWide = fW > 800;
            final countBadge = Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: W.div, borderRadius: BorderRadius.circular(4)),
              child: Text(L.tr('n_result', args: {'n': filtered.length.toString()}), style: GoogleFonts.tajawal(fontSize: 12, color: W.muted)));
            if (isFilterWide) {
              return Row(children: [
                countBadge,
                const SizedBox(width: 10),
                _drop(_fSt, [L.tr('all'),L.tr('present'),L.tr('complete'),L.tr('not_present')], (v) => setState(() { _fSt = v; }), L.tr('all_statuses')),
                const SizedBox(width: 10),
                _drop(_fDept, depts.toList(), (v) => setState(() { _fDept = v; }), L.tr('all_departments')),
                const Spacer(),
                _searchBox(),
              ]);
            }
            return Wrap(spacing: 12, runSpacing: 8, alignment: WrapAlignment.end, children: [
              _searchBox(),
              _drop(_fSt, [L.tr('all'),L.tr('present'),L.tr('complete'),L.tr('not_present')], (v) => setState(() { _fSt = v; }), L.tr('all_statuses')),
              _drop(_fDept, depts.toList(), (v) => setState(() { _fDept = v; }), L.tr('all_departments')),
              countBadge,
            ]);
          }),
          const SizedBox(height: 18),

          if (filtered.isEmpty)
            Container(width: double.infinity, padding: const EdgeInsets.all(50), decoration: DS.cardDecoration(),
              child: Center(child: Column(children: [Icon(Icons.people_outline, size: 48, color: W.hint), const SizedBox(height: 12), Text(L.tr('no_employees'), style: GoogleFonts.tajawal(fontSize: 14, color: W.muted))])))
          else if (MediaQuery.of(context).size.width > 800)
            // Grid layout for web: 2 columns (3 if very wide)
            Builder(builder: (context) {
              final gridW = MediaQuery.of(context).size.width;
              final cols = gridW > 1200 ? 3 : 2;
              final rows = (filtered.length / cols).ceil();
              return Column(children: List.generate(rows, (row) {
                final start = row * cols;
                final end = (start + cols).clamp(0, filtered.length);
                final items = filtered.sublist(start, end);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < items.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(child: _empCard(items[i])),
                      ],
                      for (int i = items.length; i < cols; i++) ...[
                        const SizedBox(width: 10),
                        const Expanded(child: SizedBox()),
                      ],
                    ],
                  ),
                );
              }));
            })
          else
            ...filtered.map((e) => _empCard(e)),
        ]),
      ),
    );
  }

  Widget _empCard(Map<String, dynamic> e) {
    final screenW = MediaQuery.of(context).size.width;
    final isSmall = screenW < 400;
    final n = L.localName(e).isNotEmpty ? L.localName(e) : '—';
    final av = n.length >= 2 ? n.substring(0,2) : L.tr('pm');
    final status = e['_status'] ?? L.tr('not_present');
    final att = e['_att'] as Map<String, dynamic>?;
    final ci = _fmtTs(att?['firstCheckIn'] ?? att?['first_check_in'] ?? att?['checkIn'] ?? att?['check_in']);
    final co = _fmtTs(att?['lastCheckOut'] ?? att?['last_check_out'] ?? att?['checkOut'] ?? att?['check_out']);
    final totalMin = ((att?['totalWorkedMinutes'] ?? att?['total_worked_minutes']) as num?)?.toInt() ?? 0;
    final isCheckedIn = e['_isCheckedIn'] == true;
    final stColor = status == L.tr('complete') ? W.green : status == L.tr('present') ? W.green : W.red;
    final byAdmin = att?['punchedByAdmin'] == true || att?['punched_by_admin'] == 1 || att?['punched_by_admin'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: DS.cardDecoration(),
      padding: EdgeInsets.all(isSmall ? 12 : 18),
      child: Column(children: [
        // Top row: avatar + name on right, status badge
        Row(children: [
          Container(padding: EdgeInsets.symmetric(horizontal: isSmall ? 6 : 10, vertical: 4), decoration: BoxDecoration(color: stColor.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7, height: 7, margin: const EdgeInsets.only(left: 4), decoration: BoxDecoration(color: status == L.tr('present') ? W.green : status == L.tr('complete') ? W.pri : const Color(0xFFD0D5DD), shape: BoxShape.circle)),
              Text(status, style: GoogleFonts.tajawal(fontSize: isSmall ? 10 : 11, fontWeight: FontWeight.w600, color: stColor)),
            ])),
          const Spacer(),
          Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (byAdmin) Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: W.orangeL, borderRadius: BorderRadius.circular(4)), child: Text(L.tr('admin_tag'), style: GoogleFonts.tajawal(fontSize: 8, fontWeight: FontWeight.w600, color: W.orange))),
              Flexible(child: Text(n, style: GoogleFonts.tajawal(fontSize: isSmall ? 13 : 15, fontWeight: FontWeight.w700, color: W.text))),
            ]),
            Text('${L.localDept(e)} • ${e['empId'] ?? e['emp_id'] ?? ''}', style: GoogleFonts.tajawal(fontSize: 11, color: W.muted), overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 8),
          Stack(children: [
            Container(width: isSmall ? 36 : 42, height: isSmall ? 36 : 42, decoration: BoxDecoration(color: W.pri.withOpacity(0.08), shape: BoxShape.circle),
              child: Center(child: Text(av, style: GoogleFonts.tajawal(fontSize: isSmall ? 12 : 15, fontWeight: FontWeight.w700, color: W.pri)))),
            Positioned(bottom: 0, right: 0, child: Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: status == L.tr('present') ? W.green : status == L.tr('complete') ? W.pri : const Color(0xFFD0D5DD), border: Border.all(color: W.white, width: 2)))),
          ]),
        ]),
        const SizedBox(height: 8),
        // Action buttons row - use Wrap to prevent overflow on narrow screens
        Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.start, children: [
          InkWell(onTap: () => _openEmployeeHistory(e), child: Container(padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 10, vertical: 6), decoration: BoxDecoration(color: W.priLight, borderRadius: BorderRadius.circular(4)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.history, size: 14, color: W.pri), const SizedBox(width: 4), Text(L.tr('history'), style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.pri))]))),
          InkWell(onTap: () => _adminPunchDialog(e), child: Container(padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 10, vertical: 6), decoration: BoxDecoration(color: W.orangeL, borderRadius: BorderRadius.circular(4)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.fingerprint, size: 14, color: W.orange), const SizedBox(width: 4), Text(L.tr('punch'), style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.orange))]))),
        ]),
        const SizedBox(height: 10),
        Container(height: 1, color: W.div),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _infoChip(Icons.timer, L.tr('total'), _fmtWorkedTime(totalMin), totalMin > 0 ? W.pri : W.muted)),
          const SizedBox(width: 6),
          Expanded(child: _infoChip(Icons.logout, L.tr('last_check_out'), co, co == '—' ? W.muted : W.red)),
          const SizedBox(width: 6),
          Expanded(child: _infoChip(Icons.login, L.tr('first_check_in'), ci, ci == '—' ? W.muted : W.green)),
        ]),
      ]),
    );
  }

  // ═══════════════════════════════════════════════
  //  ADMIN PUNCH — بصمة إدارية (دخول أو خروج)
  // ═══════════════════════════════════════════════
  void _adminPunchDialog(Map<String, dynamic> e) {
    final empName = L.localName(e).isNotEmpty ? L.localName(e) : '—';
    final uid = e['uid'] ?? e['_id'] ?? '';
    final empId = e['empId'] ?? e['emp_id'] ?? '';
    final isCheckedIn = e['_isCheckedIn'] == true;
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, ss) { final dw = MediaQuery.of(ctx).size.width; return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: EdgeInsets.symmetric(horizontal: dw > 800 ? 40 : 16, vertical: 24),
      child: Container(
      width: dw > 800 ? 440 : dw < 420 ? dw - 40 : 380, padding: EdgeInsets.all(dw < 400 ? 16 : 24),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: W.orangeL, shape: BoxShape.circle), child: Icon(Icons.fingerprint, size: 24, color: W.orange)),
        const SizedBox(height: 14),
        Text(L.tr('admin_punch'), style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w700, color: W.text)),
        const SizedBox(height: 4),
        Text(L.tr('register_face_for_admin', args: {'name': empName}), style: GoogleFonts.tajawal(fontSize: 13, color: W.sub), textAlign: TextAlign.center),
        const SizedBox(height: 16),

        // Time picker
        InkWell(
          onTap: () async {
            final picked = await showTimePicker(context: ctx, initialTime: selectedTime);
            if (picked != null) ss(() => selectedTime = picked);
          },
          child: Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(DS.radiusMd), border: Border.all(color: W.border)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('${selectedTime.hour > 12 ? selectedTime.hour - 12 : (selectedTime.hour == 0 ? 12 : selectedTime.hour)}:${selectedTime.minute.toString().padLeft(2, '0')} ${selectedTime.hour >= 12 ? L.tr('pm') : L.tr('am')}',
                style: _mono(fontSize: 20, fontWeight: FontWeight.w700, color: W.pri)),
              const SizedBox(width: 10),
              Icon(Icons.access_time, size: 20, color: W.pri),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Text(L.tr('tap_choose_time'), style: GoogleFonts.tajawal(fontSize: 10, color: W.muted)),
        const SizedBox(height: 16),

        // Check-in button
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: () async {
            Navigator.pop(ctx);
            await _adminCheckIn(uid, empId, empName, selectedTime);
          },
          icon: const Icon(Icons.login, size: 18),
          label: Text(L.tr('check_in_action'), style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(backgroundColor: W.green, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd))),
        )),
        const SizedBox(height: 10),

        // Check-out button
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: () async {
            Navigator.pop(ctx);
            await _adminCheckOut(uid, empId, empName, selectedTime);
          },
          icon: const Icon(Icons.logout, size: 18),
          label: Text(L.tr('check_out_action'), style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(backgroundColor: W.red, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd))),
        )),

        const SizedBox(height: 14),
        Container(width: double.infinity, padding: EdgeInsets.all(10), decoration: BoxDecoration(color: W.orangeL, borderRadius: BorderRadius.circular(4)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(L.tr('admin_punch_warning'), style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.orange)),
            SizedBox(width: 6), Icon(Icons.info_outline, size: 14, color: W.orange),
          ])),
        const SizedBox(height: 10),
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(L.tr('cancel'), style: GoogleFonts.tajawal(fontSize: 13, color: W.muted))),
      ])),
    )); }));

  }

  Future<void> _adminCheckIn(String uid, String empId, String empName, TimeOfDay time) async {
    final now = DateTime.now();
    final punchTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    final adminName = widget.user['name'] ?? L.tr('system_admin');
    await ApiService.post('admin.php?action=admin_checkin', {
      'uid': uid, 'emp_id': empId, 'name': empName,
      'time_override': punchTime.toIso8601String(),
      'punched_by_admin': true, 'admin_name': adminName,
    });
    await _audit(L.tr('admin_punch_checkin'), empName, L.tr('checkin_by_admin', args: {'name': adminName}));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L.tr('checkin_done_admin', args: {'name': empName}), style: GoogleFonts.tajawal()), backgroundColor: W.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd))));
      _load();
    }
  }

  Future<void> _adminCheckOut(String uid, String empId, String empName, TimeOfDay time) async {
    final now = DateTime.now();
    final punchTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    final adminName = widget.user['name'] ?? L.tr('system_admin');
    await ApiService.post('admin.php?action=admin_checkout', {
      'uid': uid, 'emp_id': empId, 'name': empName,
      'time_override': punchTime.toIso8601String(),
      'punched_by_admin': true, 'admin_name': adminName,
    });
    await _audit(L.tr('admin_punch_checkout'), empName, L.tr('checkout_by_admin', args: {'name': adminName}));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L.tr('checkout_done_admin', args: {'name': empName}), style: GoogleFonts.tajawal()), backgroundColor: W.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd))));
      _load();
    }
  }

  // ═══════════════════════════════════════════════
  //  EMPLOYEE HISTORY — سجل حضور الموظف التفصيلي
  // ═══════════════════════════════════════════════
  void _openEmployeeHistory(Map<String, dynamic> e) {
    final empName = L.localName(e).isNotEmpty ? L.localName(e) : '—';
    final uid = e['uid'] ?? e['_id'] ?? '';
    final av = empName.length >= 2 ? empName.substring(0,2) : L.tr('pm');

    int selMonth = DateTime.now().month;
    int selYear = DateTime.now().year;
    String? expandedDateKey;
    List<Map<String, dynamic>>? expandedPunches;
    bool loadingPunches = false;

    showDialog(context: context, barrierDismissible: true, builder: (ctx) { final dw = MediaQuery.of(ctx).size.width; final isNarrow = dw < 400; final isWebDialog = dw > 800; return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isNarrow ? 10 : isWebDialog ? 40 : 20),
      child: StatefulBuilder(builder: (ctx, ss) {
        return Container(
          constraints: BoxConstraints(maxWidth: isWebDialog ? 700 : 560, maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(18)),
          child: Column(children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: isNarrow ? 14 : 24, vertical: isNarrow ? 12 : 18),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF0F4199), W.pri]), borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
              child: Row(children: [
                InkWell(onTap: () => Navigator.pop(ctx), child: Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(4)), child: const Icon(Icons.close, size: 14, color: Colors.white))),
                const Spacer(),
                Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(L.tr('record_label', args: {'name': empName}), style: GoogleFonts.tajawal(fontSize: isNarrow ? 14 : 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('${L.localDept(e)} • ${e['empId'] ?? e['emp_id'] ?? ''}', style: GoogleFonts.tajawal(fontSize: 11, color: Colors.white70), overflow: TextOverflow.ellipsis),
                ])),
                const SizedBox(width: 8),
                Container(width: isNarrow ? 36 : 44, height: isNarrow ? 36 : 44, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.15)),
                  child: Center(child: Text(av, style: GoogleFonts.tajawal(fontSize: isNarrow ? 14 : 18, fontWeight: FontWeight.w700, color: Colors.white)))),
              ]),
            ),

            // Month selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: W.border))),
              child: Row(children: [
                InkWell(onTap: () => ss(() { selMonth--; if (selMonth < 1) { selMonth = 12; selYear--; } expandedDateKey = null; }), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(4)), child: Icon(Icons.chevron_right, size: 18, color: W.sub))),
                const Spacer(),
                Text('${_months[selMonth - 1]} $selYear', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: W.text)),
                const Spacer(),
                InkWell(onTap: () { final now = DateTime.now(); if (selYear == now.year && selMonth >= now.month) return; ss(() { selMonth++; if (selMonth > 12) { selMonth = 1; selYear++; } expandedDateKey = null; }); },
                  child: Container(width: 32, height: 32, decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(4)), child: Icon(Icons.chevron_left, size: 18, color: W.sub))),
              ]),
            ),

            // Records
            Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _svc.getMonthlyAttendance(uid, selYear, selMonth),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                final records = List<Map<String, dynamic>>.from(snap.data ?? []);
                records.sort((a, b) => (b['dateKey'] ?? b['date_key'] ?? '').compareTo(a['dateKey'] ?? a['date_key'] ?? ''));

                int totalMonthMin = 0;
                for (final r in records) totalMonthMin += ((r['totalWorkedMinutes'] ?? r['total_worked_minutes']) as num?)?.toInt() ?? 0;
                final present = records.where((r) => (r['firstCheckIn'] ?? r['first_check_in'] ?? r['checkIn'] ?? r['check_in']) != null).length;

                return ListView(padding: const EdgeInsets.all(14), children: [
                  // Stats
                  Container(
                    decoration: DS.cardDecoration(),
                    padding: const EdgeInsets.all(10),
                    child: Row(children: [
                      _stat(L.tr('total_hours'), _fmtWorkedTime(totalMonthMin), W.orange),
                      const SizedBox(width: 8),
                      _stat(L.tr('attendance_days'), '$present', W.pri),
                      const SizedBox(width: 8),
                      _stat(L.tr('recorded_days'), '${records.length}', W.green),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  if (records.isEmpty)
                    Padding(padding: EdgeInsets.all(30), child: Center(child: Text(L.tr('no_data_in_month', args: {'month': _months[selMonth - 1]}), style: GoogleFonts.tajawal(fontSize: 13, color: W.muted))))
                  else
                    ...records.map((r) {
                      final dateKey = r['dateKey'] ?? r['date_key'] ?? '';
                      final parts = dateKey.split('-');
                      final day = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
                      final month = parts.length > 1 ? int.tryParse(parts[1]) ?? selMonth : selMonth;
                      final year = parts.isNotEmpty ? int.tryParse(parts[0]) ?? selYear : selYear;
                      final dt = parts.length == 3 ? DateTime(year, month, day) : DateTime.now();
                      final dayName = _dayNames[dt.weekday % 7];
                      final firstIn = r['firstCheckIn'] ?? r['first_check_in'] ?? r['checkIn'] ?? r['check_in'];
                      final lastOut = r['lastCheckOut'] ?? r['last_check_out'] ?? r['checkOut'] ?? r['check_out'];
                      final hasOut = lastOut != null;
                      final totalMin = ((r['totalWorkedMinutes'] ?? r['total_worked_minutes']) as num?)?.toInt() ?? 0;
                      final sessions = ((r['sessions'] ?? 0) as num?)?.toInt() ?? 1;
                      final stColor = hasOut ? W.green : W.pri;
                      final isExpanded = expandedDateKey == dateKey;
                      final wasByAdmin = r['punchedByAdmin'] == true || r['punched_by_admin'] == 1 || r['punched_by_admin'] == true;

                      return InkWell(
                        onTap: () async {
                          if (isExpanded) { ss(() { expandedDateKey = null; expandedPunches = null; }); return; }
                          ss(() { expandedDateKey = dateKey; expandedPunches = null; loadingPunches = true; });
                          final punches = await _svc.getDayPunches(uid, dateKey);
                          ss(() { expandedPunches = punches; loadingPunches = false; });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(color: W.card, borderRadius: BorderRadius.circular(DS.radiusMd), border: Border.all(color: isExpanded ? W.pri.withOpacity(0.4) : W.border)),
                          child: Column(children: [
                            Padding(padding: const EdgeInsets.all(12), child: Row(children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: stColor.withOpacity(0.08), borderRadius: BorderRadius.circular(DS.radiusMd)),
                                  child: Text(hasOut ? L.tr('complete') : L.tr('present'), style: GoogleFonts.tajawal(fontSize: 9, fontWeight: FontWeight.w600, color: stColor))),
                                const SizedBox(height: 3),
                                Text(L.tr('checkout_label', args: {'time': _fmtTs(lastOut)}), style: _mono(fontSize: 9, color: W.muted)),
                                if (totalMin > 0) Text(_fmtWorkedTime(totalMin), style: GoogleFonts.tajawal(fontSize: 9, fontWeight: FontWeight.w600, color: W.green)),
                              ]),
                              const Spacer(),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Row(children: [
                                  if (wasByAdmin) Container(margin: EdgeInsets.only(left: 4), padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: W.orangeL, borderRadius: BorderRadius.circular(4)), child: Text(L.tr('admin_tag'), style: GoogleFonts.tajawal(fontSize: 7, fontWeight: FontWeight.w600, color: W.orange))),
                                  Text('$dayName $day ${_months[month - 1]}', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.text)),
                                ]),
                                Text(L.tr('checkin_label', args: {'time': _fmtTs(firstIn)}), style: _mono(fontSize: 10, color: W.sub)),
                                if (sessions > 1) Text(L.tr('n_sessions', args: {'n': sessions.toString()}), style: GoogleFonts.tajawal(fontSize: 8, color: W.pri)),
                              ]),
                              const SizedBox(width: 8),
                              Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 16, color: W.sub),
                            ])),

                            // Expanded punches + edit
                            if (isExpanded) ...[
                              Container(height: 1, color: W.border),
                              if (loadingPunches)
                                const Padding(padding: EdgeInsets.all(16), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
                              else if (expandedPunches != null) ...[
                                _buildPunchTimeline(expandedPunches!, uid, empName),
                                // Edit button
                                Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 10), child: InkWell(
                                  onTap: () => _editDayDialog(uid, empName, dateKey, r),
                                  child: Container(
                                    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(color: W.orangeL, borderRadius: BorderRadius.circular(4)),
                                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Text(L.tr('edit_day_times'), style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.orange)),
                                      SizedBox(width: 6), Icon(Icons.edit, size: 14, color: W.orange),
                                    ]),
                                  ),
                                )),
                              ],
                            ],
                          ]),
                        ),
                      );
                    }),
                ]);
              },
            )),
          ]),
        );
      }),
    ); });
  }

  Widget _buildPunchTimeline(List<Map<String, dynamic>> punches, String uid, String empName) {
    if (punches.isEmpty) return Padding(padding: EdgeInsets.all(14), child: Center(child: Text(L.tr('no_details'), style: GoogleFonts.tajawal(fontSize: 11, color: W.muted))));

    final allLocs = _locations;
    return Builder(builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Column(children: List.generate(punches.length, (i) {
            final punch = punches[i];
            final isCheckIn = punch['type'] == 'checkIn';
            final color = isCheckIn ? W.pri : W.red;
            final label = isCheckIn ? L.tr('entry_label') : L.tr('exit_label');
            final time = punch['localTime'] ?? punch['local_time'] ?? punch['timestamp'];
            final byAdmin = punch['punchedByAdmin'] == true || punch['punched_by_admin'] == 1 || punch['punched_by_admin'] == true;
            final adminName = punch['adminName'] ?? punch['admin_name'] ?? '';
            final lat = punch['lat'] as num?;
            final lng = punch['lng'] as num?;
            final hasLoc = lat != null && lng != null;
            final isLast = i == punches.length - 1;
            final authMethod = (punch['authMethod'] ?? punch['auth_method'] ?? '') as String;
            final facePhotoUrl = (punch['facePhotoUrl'] ?? punch['face_photo_url']) as String?;
            final isFace = authMethod == 'face' || (facePhotoUrl != null && facePhotoUrl.isNotEmpty);
            final isFingerprint = !isFace && !byAdmin;
            final punchId = '${punch['id'] ?? ''}';

            // Find matching location name
            String locName = '';
            if (hasLoc) {
              for (final loc in allLocs) {
                final locLat = (loc['lat'] as num?)?.toDouble() ?? 0;
                final locLng = (loc['lng'] as num?)?.toDouble() ?? 0;
                final radius = ((loc['radius'] as num?)?.toDouble() ?? 300) / 111000;
                final dist = ((lat!.toDouble() - locLat).abs() + (lng!.toDouble() - locLng).abs());
                if (dist < radius * 3) { locName = L.localName(loc); break; }
              }
              if (locName.isEmpty) locName = '${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)}';
            }

            return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 60, child: Text(_fmtTs(time), style: _mono(fontSize: 10, fontWeight: FontWeight.w600, color: W.text))),
              SizedBox(width: 24, child: Column(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: color, width: 1.5))),
                if (!isLast) Expanded(child: Container(width: 1.5, color: W.border)),
              ])),
              Expanded(child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: color.withOpacity(0.04), borderRadius: BorderRadius.circular(DS.radiusMd)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    // Edit button per punch
                    InkWell(
                      onTap: () => _editSinglePunchDialog(punchId, uid, empName, punch),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(color: W.orangeL, borderRadius: BorderRadius.circular(4)),
                        child: Icon(Icons.edit, size: 10, color: W.orange),
                      ),
                    ),
                    const Spacer(),
                    // Auth method badge
                    if (isFace) InkWell(
                      onTap: facePhotoUrl != null ? () => _showFacePhotoDialog(facePhotoUrl, _fmtTs(time), label) : null,
                      child: Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: W.priLight, borderRadius: BorderRadius.circular(4), border: Border.all(color: W.pri.withOpacity(0.3))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.face, size: 10, color: W.pri),
                          const SizedBox(width: 2),
                          Text(L.tr('face_label'), style: GoogleFonts.tajawal(fontSize: 8, fontWeight: FontWeight.w600, color: W.pri)),
                          if (facePhotoUrl != null) Icon(Icons.photo_camera, size: 8, color: W.pri),
                        ]),
                      ),
                    )
                    else if (isFingerprint) Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: W.greenL, borderRadius: BorderRadius.circular(4)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.fingerprint, size: 10, color: W.green),
                        const SizedBox(width: 2),
                        Text(L.tr('punch'), style: GoogleFonts.tajawal(fontSize: 8, fontWeight: FontWeight.w600, color: W.green)),
                      ]),
                    ),
                    if (byAdmin) Container(margin: EdgeInsets.only(left: 4), padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: W.orangeL, borderRadius: BorderRadius.circular(4)),
                      child: Text(adminName.isNotEmpty ? adminName : L.tr('admin_label'), style: GoogleFonts.tajawal(fontSize: 7, fontWeight: FontWeight.w600, color: W.orange))),
                    Text(label, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                  ]),
                  if (hasLoc) Padding(padding: const EdgeInsets.only(top: 2), child: Row(children: [
                    Icon(Icons.location_on, size: 10, color: W.green),
                    const SizedBox(width: 2),
                    Flexible(child: Text(locName, style: GoogleFonts.tajawal(fontSize: 9, color: W.muted), overflow: TextOverflow.ellipsis)),
                  ])),
                ]),
              )),
            ]));
          })),
        );
      },
    );
  }

  // ═══ Edit single punch time ═══
  void _editSinglePunchDialog(String punchId, String uid, String empName, Map<String, dynamic> punch) {
    final isCheckIn = punch['type'] == 'checkIn';
    final label = isCheckIn ? L.tr('entry_label') : L.tr('exit_label');
    final color = isCheckIn ? W.pri : W.red;
    final time = punch['localTime'] ?? punch['timestamp'];
    final currentTime = _parseTs(time) ?? DateTime.now();
    
    TimeOfDay selectedTime = TimeOfDay(hour: currentTime.hour, minute: currentTime.minute);

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, ss) { final pw = MediaQuery.of(ctx).size.width; return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: pw < 380 ? pw - 40 : 340, padding: EdgeInsets.all(pw < 400 ? 14 : 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text(L.tr('edit_time_label', args: {'label': label}), style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: W.text)),
            const SizedBox(width: 8),
            Icon(isCheckIn ? Icons.login : Icons.logout, size: 18, color: color),
          ]),
          const SizedBox(height: 4),
          Text(empName, style: GoogleFonts.tajawal(fontSize: 12, color: W.sub)),
          Text(L.tr('current_time_value', args: {'time': _fmtTs(time)}), style: _mono(fontSize: 11, color: W.muted)),
          const SizedBox(height: 16),

          // Time picker
          InkWell(
            onTap: () async {
              final picked = await showTimePicker(context: ctx, initialTime: selectedTime);
              if (picked != null) ss(() => selectedTime = picked);
            },
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(DS.radiusMd), border: Border.all(color: W.border)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${selectedTime.hour > 12 ? selectedTime.hour - 12 : (selectedTime.hour == 0 ? 12 : selectedTime.hour)}:${selectedTime.minute.toString().padLeft(2, '0')} ${selectedTime.hour >= 12 ? L.tr('pm') : L.tr('am')}',
                  style: _mono(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
                const SizedBox(width: 10),
                Icon(Icons.access_time, size: 20, color: color),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          Text(L.tr('tap_choose_new_time'), style: GoogleFonts.tajawal(fontSize: 10, color: W.muted)),
          const SizedBox(height: 16),

          Row(children: [
            Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), child: Text(L.tr('cancel'), style: GoogleFonts.tajawal(fontSize: 13, color: W.muted)))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(
              onPressed: () async {
                final oldDate = currentTime;
                final newTime = DateTime(oldDate.year, oldDate.month, oldDate.day, selectedTime.hour, selectedTime.minute);
                
                if (punchId.isNotEmpty) {
                  await ApiService.post('attendance.php?action=edit_punch', {
                    'punch_id': punchId, 'uid': uid,
                    'new_time': newTime.toIso8601String(),
                    'edited_by': widget.user['name'] ?? L.tr('system_admin'),
                  });
                }
                
                await _audit(L.tr('edit'), empName, L.tr('edit_time_audit', args: {'label': label, 'from': _fmtTs(time), 'to': '${selectedTime.hour}:${selectedTime.minute.toString().padLeft(2, '0')}'}));
                
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L.tr('edit_time_done', args: {'label': label, 'name': empName}), style: GoogleFonts.tajawal()), backgroundColor: W.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd))));
              },
              icon: const Icon(Icons.save, size: 14),
              label: Text(L.tr('save'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd))),
            )),
          ]),
        ]),
      ),
    ); }));
  }

  void _showFacePhotoDialog(String photoUrl, String time, String type) {
    showDialog(context: context, builder: (ctx) { final fw = MediaQuery.of(ctx).size.width; return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.hardEdge,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: fw < 360 ? fw - 40 : 320,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: W.pri.withOpacity(0.05)),
            child: Row(children: [
              InkWell(onTap: () => Navigator.pop(ctx), child: Icon(Icons.close, size: 18, color: W.sub)),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(L.tr('face_photo'), style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: W.text)),
                Text('$type — $time', style: GoogleFonts.tajawal(fontSize: 11, color: W.muted)),
              ]),
              const SizedBox(width: 8),
              Icon(Icons.face, size: 20, color: W.pri),
            ]),
          ),
          Container(
            height: 300, width: double.infinity,
            color: Colors.black,
            child: Image.network(
              photoUrl,
              fit: BoxFit.contain,
              loadingBuilder: (ctx, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  const SizedBox(height: 10),
                  Text(L.tr('loading_image'), style: GoogleFonts.tajawal(fontSize: 11, color: Colors.white54)),
                ]));
              },
              errorBuilder: (_, error, ___) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.broken_image, size: 40, color: Colors.white38),
                const SizedBox(height: 8),
                Text(L.tr('image_load_failed'), style: GoogleFonts.tajawal(fontSize: 11, color: Colors.white38)),
                const SizedBox(height: 4),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: SelectableText(photoUrl, style: GoogleFonts.ibmPlexMono(fontSize: 8, color: Colors.white24), textAlign: TextAlign.center)),
              ])),
            ),
          ),
        ]),
      ),
    ); });
  }

  // ═══ Edit day times dialog ═══
  void _editDayDialog(String uid, String empName, String dateKey, Map<String, dynamic> record) {
    final ciCtrl = TextEditingController();
    final coCtrl = TextEditingController();
    final minCtrl = TextEditingController(text: '${((record['totalWorkedMinutes'] ?? record['total_worked_minutes']) as num?)?.toInt() ?? 0}');
    void _disposeCtrls() { ciCtrl.dispose(); coCtrl.dispose(); minCtrl.dispose(); }

    showDialog(context: context, builder: (ctx) { final ew = MediaQuery.of(ctx).size.width; return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
      width: ew < 440 ? ew - 40 : 400, padding: EdgeInsets.all(ew < 400 ? 16 : 24),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text(L.tr('edit_day_data', args: {'date': dateKey}), style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: W.text)),
          SizedBox(width: 8), Icon(Icons.edit_calendar, size: 20, color: W.orange),
        ]),
        const SizedBox(height: 4),
        Text('$empName', style: GoogleFonts.tajawal(fontSize: 13, color: W.sub)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _timeField(coCtrl, L.tr('new_checkout_time'), '03:00 ${L.tr('pm')}', Icons.logout, W.red)),
          const SizedBox(width: 10),
          Expanded(child: _timeField(ciCtrl, L.tr('new_checkin_time'), '08:00 ${L.tr('am')}', Icons.login, W.green)),
        ]),
        const SizedBox(height: 10),
        _timeField(minCtrl, L.tr('total_calculated_minutes'), '480', Icons.timer, W.pri),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: () async {
            await ApiService.post('attendance.php?action=edit_day', {
              'uid': uid, 'date_key': dateKey,
              if (ciCtrl.text.trim().isNotEmpty) 'check_in_manual': ciCtrl.text.trim(),
              if (coCtrl.text.trim().isNotEmpty) 'check_out_manual': coCtrl.text.trim(),
              if (int.tryParse(minCtrl.text.trim()) != null) 'total_worked_minutes': int.parse(minCtrl.text.trim()),
              'edited_by': widget.user['name'] ?? L.tr('system_admin'),
            });
            await _audit(L.tr('admin_tag'), empName, L.tr('edit_day_audit', args: {'date': dateKey, 'ci': ciCtrl.text, 'co': coCtrl.text, 'min': minCtrl.text}));

            if (ctx.mounted) Navigator.pop(ctx);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L.tr('edit_day_done', args: {'name': empName}), style: GoogleFonts.tajawal()), backgroundColor: W.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd))));
          },
          icon: const Icon(Icons.save, size: 16),
          label: Text(L.tr('save_edit'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(backgroundColor: W.orange, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd))),
        )),
        const SizedBox(height: 6),
        Text(L.tr('manual_edit_audit_note'), style: GoogleFonts.tajawal(fontSize: 10, color: W.muted)),
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(L.tr('cancel'), style: GoogleFonts.tajawal(fontSize: 13, color: W.muted))),
      ])),
    )); }).whenComplete(_disposeCtrls);
  }

  // ═══ Helpers ═══
  Widget _stat(String label, String val, Color color) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.04), borderRadius: BorderRadius.circular(4)),
    child: Column(children: [
      Text(val, style: _mono(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.tajawal(fontSize: 9, fontWeight: FontWeight.w600, color: W.muted)),
    ]),
  ));

  Widget _infoChip(IconData icon, String label, String value, Color color) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withOpacity(0.04), borderRadius: BorderRadius.circular(DS.radiusMd)),
    child: Column(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(height: 4),
      Text(value, style: _mono(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      Text(label, style: GoogleFonts.tajawal(fontSize: 9, color: W.muted)),
    ]),
  );

  Widget _searchBox() { final sw = MediaQuery.of(context).size.width; final w = sw > 800 ? 360.0 : sw < 400 ? sw - 40.0 : 260.0; return SizedBox(width: w, child: TextField(onChanged: (v) => setState(() => _search = v), textAlign: TextAlign.right, style: GoogleFonts.tajawal(fontSize: 13), decoration: InputDecoration(hintText: L.tr('search_name_id'), hintStyle: GoogleFonts.tajawal(color: W.hint, fontSize: 13), filled: true, fillColor: W.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(DS.radiusMd), borderSide: BorderSide(color: W.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(DS.radiusMd), borderSide: BorderSide(color: W.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(DS.radiusMd), borderSide: BorderSide(color: W.pri, width: 2)), prefixIcon: Icon(Icons.search, size: 16, color: W.muted)))); }
  Widget _drop(String v, List<String> items, ValueChanged<String> cb, String all) => Container(padding: EdgeInsets.symmetric(horizontal: 16), decoration: DS.cardDecoration(), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: v, isDense: true, style: GoogleFonts.tajawal(fontSize: 13, color: W.text), items: items.map((s) => DropdownMenuItem(value: s, child: Text(s == L.tr('all') ? all : s))).toList(), onChanged: (x) { if (x != null) cb(x); })));

  Widget _timeField(TextEditingController ctrl, String label, String hint, IconData icon, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text(label, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub)),
        const SizedBox(width: 4), Icon(icon, size: 14, color: color),
      ]),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl, textAlign: TextAlign.center, textDirection: TextDirection.ltr,
        style: _mono(fontSize: 14),
        decoration: InputDecoration(hintText: hint, hintStyle: _mono(fontSize: 14, color: W.hint),
          filled: true, fillColor: W.bg, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: color, width: 2)),
        ),
      ),
    ],
  );
}
