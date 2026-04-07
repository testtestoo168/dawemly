import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../theme/shimmer.dart';
import '../../services/attendance_service.dart';
import '../../services/api_service.dart';

class AdminEmployees extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminEmployees({super.key, required this.user});
  @override State<AdminEmployees> createState() => _AdminEmployeesState();
}

class _AdminEmployeesState extends State<AdminEmployees> {
  final _svc = AttendanceService();
  String _search = '', _fDept = 'الكل', _fSt = 'الكل';
  final _mono = GoogleFonts.ibmPlexMono;
  final _months = const ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
  final _dayNames = const ['الأحد','الإثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت'];

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _attList = [];
  List<Map<String, dynamic>> _locations = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final usersRes = await ApiService.get('users.php?action=list');
      final attList = await _svc.getAllTodayRecords();
      final locsRes = await ApiService.get('admin.php?action=get_locations');
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
      'user': widget.user['name'] ?? 'مدير النظام',
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
    return '${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'م' : 'ص'}';
  }

  String _fmtWorkedTime(int totalMinutes) {
    if (totalMinutes <= 0) return '—';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h > 0 && m > 0) return '${h}س ${m}د';
    if (h > 0) return '${h} ساعة';
    return '${m} دقيقة';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return ListView(
      padding: const EdgeInsets.all(14),
      children: List.generate(6, (_) => const ShimmerEmployeeCard()),
    );

    final allUsers = _users.where((e) => (e['name'] ?? '').toString().isNotEmpty && e['role'] != 'admin' && e['role'] != 'superadmin').toList();
    allUsers.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));

    final attMap = <String, Map<String, dynamic>>{};
    for (final r in _attList) attMap[r['uid'] ?? ''] = r;

    final merged = allUsers.map((u) {
      final uid = u['uid'] ?? u['_id'] ?? '';
      final att = attMap[uid];
      final hasIn = (att?['first_check_in'] ?? att?['check_in']) != null;
      final isCheckedIn = att?['is_checked_in'] == 1 || att?['is_checked_in'] == true;
      String status = 'غير حاضر';
      if (isCheckedIn) status = 'حاضر';
      else if (hasIn) status = 'مكتمل';
      return {...u, '_status': status, '_att': att, '_isCheckedIn': isCheckedIn};
    }).toList();

    final depts = <String>{'الكل', ...merged.map((e) => (e['dept'] ?? '').toString()).where((d) => d.isNotEmpty)};
    final filtered = merged.where((e) {
      if (_search.isNotEmpty && !(e['name'] ?? '').toString().contains(_search) && !(e['empId'] ?? e['emp_id'] ?? '').toString().contains(_search)) return false;
      if (_fDept != 'الكل' && e['dept'] != _fDept) return false;
      if (_fSt != 'الكل' && e['_status'] != _fSt) return false;
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(MediaQuery.of(context).size.width > 800 ? 28 : 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('سجل الموظفين', style: GoogleFonts.tajawal(fontSize: MediaQuery.of(context).size.width < 400 ? 18 : 24, fontWeight: FontWeight.w800, color: W.text)),
          const SizedBox(height: 20),
          Wrap(spacing: 12, runSpacing: 8, alignment: WrapAlignment.end, children: [
            _searchBox(),
            _drop(_fSt, ['الكل','حاضر','مكتمل','غير حاضر'], (v) => setState(() { _fSt = v; }), 'كل الحالات'),
            _drop(_fDept, depts.toList(), (v) => setState(() { _fDept = v; }), 'كل الأقسام'),
            Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: W.div, borderRadius: BorderRadius.circular(4)),
              child: Text('${filtered.length} نتيجة', style: GoogleFonts.tajawal(fontSize: 12, color: W.muted))),
          ]),
          const SizedBox(height: 18),

          if (filtered.isEmpty)
            Container(width: double.infinity, padding: EdgeInsets.all(50), decoration: DS.cardDecoration(),
              child: Center(child: Column(children: [Icon(Icons.people_outline, size: 48, color: W.hint), SizedBox(height: 12), Text('لا يوجد موظفين', style: GoogleFonts.tajawal(fontSize: 14, color: W.muted))])))
          else
            ...filtered.map((e) => _empCard(e)),
        ]),
      ),
    );
  }

  Widget _empCard(Map<String, dynamic> e) {
    final screenW = MediaQuery.of(context).size.width;
    final isSmall = screenW < 400;
    final n = e['name'] ?? '—';
    final av = n.length >= 2 ? n.substring(0,2) : 'م';
    final status = e['_status'] ?? 'غير حاضر';
    final att = e['_att'] as Map<String, dynamic>?;
    final ci = _fmtTs(att?['firstCheckIn'] ?? att?['first_check_in'] ?? att?['checkIn'] ?? att?['check_in']);
    final co = _fmtTs(att?['lastCheckOut'] ?? att?['last_check_out'] ?? att?['checkOut'] ?? att?['check_out']);
    final totalMin = (att?['totalWorkedMinutes'] as int?) ?? (att?['total_worked_minutes'] as int?) ?? 0;
    final isCheckedIn = e['_isCheckedIn'] == true;
    final stColor = status == 'مكتمل' ? W.green : status == 'حاضر' ? W.green : W.red;
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
              Container(width: 7, height: 7, margin: const EdgeInsets.only(left: 4), decoration: BoxDecoration(color: status == 'حاضر' ? W.green : status == 'مكتمل' ? W.pri : const Color(0xFFD0D5DD), shape: BoxShape.circle)),
              Text(status, style: GoogleFonts.tajawal(fontSize: isSmall ? 10 : 11, fontWeight: FontWeight.w600, color: stColor)),
            ])),
          const Spacer(),
          Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (byAdmin) Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: W.orangeL, borderRadius: BorderRadius.circular(4)), child: Text('إدارية', style: GoogleFonts.tajawal(fontSize: 8, fontWeight: FontWeight.w600, color: W.orange))),
              Flexible(child: Text(n, style: GoogleFonts.tajawal(fontSize: isSmall ? 13 : 15, fontWeight: FontWeight.w700, color: W.text))),
            ]),
            Text('${e['dept'] ?? ''} • ${e['empId'] ?? e['emp_id'] ?? ''}', style: GoogleFonts.tajawal(fontSize: 11, color: W.muted), overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 8),
          Stack(children: [
            Container(width: isSmall ? 36 : 42, height: isSmall ? 36 : 42, decoration: BoxDecoration(color: W.pri.withOpacity(0.08), shape: BoxShape.circle),
              child: Center(child: Text(av, style: GoogleFonts.tajawal(fontSize: isSmall ? 12 : 15, fontWeight: FontWeight.w700, color: W.pri)))),
            Positioned(bottom: 0, right: 0, child: Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: status == 'حاضر' ? W.green : status == 'مكتمل' ? W.pri : const Color(0xFFD0D5DD), border: Border.all(color: W.white, width: 2)))),
          ]),
        ]),
        const SizedBox(height: 8),
        // Action buttons row - use Wrap to prevent overflow on narrow screens
        Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.start, children: [
          InkWell(onTap: () => _openEmployeeHistory(e), child: Container(padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 10, vertical: 6), decoration: BoxDecoration(color: W.priLight, borderRadius: BorderRadius.circular(4)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.history, size: 14, color: W.pri), const SizedBox(width: 4), Text('السجل', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.pri))]))),
          InkWell(onTap: () => _adminPunchDialog(e), child: Container(padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 10, vertical: 6), decoration: BoxDecoration(color: W.orangeL, borderRadius: BorderRadius.circular(4)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.fingerprint, size: 14, color: W.orange), const SizedBox(width: 4), Text('بصمة', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.orange))]))),
        ]),
        const SizedBox(height: 10),
        Container(height: 1, color: W.div),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _infoChip(Icons.timer, 'إجمالي', _fmtWorkedTime(totalMin), totalMin > 0 ? W.pri : W.muted)),
          const SizedBox(width: 6),
          Expanded(child: _infoChip(Icons.logout, 'آخر خروج', co, co == '—' ? W.muted : W.red)),
          const SizedBox(width: 6),
          Expanded(child: _infoChip(Icons.login, 'أول حضور', ci, ci == '—' ? W.muted : W.green)),
        ]),
      ]),
    );
  }

  // ═══════════════════════════════════════════════
  //  ADMIN PUNCH — بصمة إدارية (دخول أو خروج)
  // ═══════════════════════════════════════════════
  void _adminPunchDialog(Map<String, dynamic> e) {
    final empName = e['name'] ?? '—';
    final uid = e['uid'] ?? e['_id'] ?? '';
    final empId = e['empId'] ?? e['emp_id'] ?? '';
    final isCheckedIn = e['_isCheckedIn'] == true;
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, ss) { final dw = MediaQuery.of(ctx).size.width; return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
      width: dw < 420 ? dw - 40 : 380, padding: EdgeInsets.all(dw < 400 ? 16 : 24),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: W.orangeL, shape: BoxShape.circle), child: Icon(Icons.fingerprint, size: 24, color: W.orange)),
        const SizedBox(height: 14),
        Text('بصمة إدارية', style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w700, color: W.text)),
        const SizedBox(height: 4),
        Text('تسجيل بصمة لـ $empName بواسطة الأدمن', style: GoogleFonts.tajawal(fontSize: 13, color: W.sub), textAlign: TextAlign.center),
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
              Text('${selectedTime.hour > 12 ? selectedTime.hour - 12 : (selectedTime.hour == 0 ? 12 : selectedTime.hour)}:${selectedTime.minute.toString().padLeft(2, '0')} ${selectedTime.hour >= 12 ? 'م' : 'ص'}',
                style: _mono(fontSize: 20, fontWeight: FontWeight.w700, color: W.pri)),
              const SizedBox(width: 10),
              Icon(Icons.access_time, size: 20, color: W.pri),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Text('اضغط لاختيار الوقت', style: GoogleFonts.tajawal(fontSize: 10, color: W.muted)),
        const SizedBox(height: 16),

        // Check-in button
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: () async {
            Navigator.pop(ctx);
            await _adminCheckIn(uid, empId, empName, selectedTime);
          },
          icon: const Icon(Icons.login, size: 18),
          label: Text('تسجيل دخول', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700)),
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
          label: Text('تسجيل خروج', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(backgroundColor: W.red, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd))),
        )),

        const SizedBox(height: 14),
        Container(width: double.infinity, padding: EdgeInsets.all(10), decoration: BoxDecoration(color: W.orangeL, borderRadius: BorderRadius.circular(4)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('سيتم تسجيل البصمة باسم الأدمن', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.orange)),
            SizedBox(width: 6), Icon(Icons.info_outline, size: 14, color: W.orange),
          ])),
        const SizedBox(height: 10),
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.tajawal(fontSize: 13, color: W.muted))),
      ])),
    )); }));

  }

  Future<void> _adminCheckIn(String uid, String empId, String empName, TimeOfDay time) async {
    final now = DateTime.now();
    final punchTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    final adminName = widget.user['name'] ?? 'مدير النظام';
    await ApiService.post('admin.php?action=admin_checkin', {
      'uid': uid, 'emp_id': empId, 'name': empName,
      'time_override': punchTime.toIso8601String(),
      'punched_by_admin': true, 'admin_name': adminName,
    });
    await _audit('بصمة دخول إدارية', empName, 'تسجيل دخول بواسطة $adminName');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تسجيل دخول $empName بواسطة الأدمن', style: GoogleFonts.tajawal()), backgroundColor: W.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd))));
      _load();
    }
  }

  Future<void> _adminCheckOut(String uid, String empId, String empName, TimeOfDay time) async {
    final now = DateTime.now();
    final punchTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    final adminName = widget.user['name'] ?? 'مدير النظام';
    await ApiService.post('admin.php?action=admin_checkout', {
      'uid': uid, 'emp_id': empId, 'name': empName,
      'time_override': punchTime.toIso8601String(),
      'punched_by_admin': true, 'admin_name': adminName,
    });
    await _audit('بصمة خروج إدارية', empName, 'تسجيل خروج بواسطة $adminName');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تسجيل خروج $empName بواسطة الأدمن', style: GoogleFonts.tajawal()), backgroundColor: W.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd))));
      _load();
    }
  }

  // ═══════════════════════════════════════════════
  //  EMPLOYEE HISTORY — سجل حضور الموظف التفصيلي
  // ═══════════════════════════════════════════════
  void _openEmployeeHistory(Map<String, dynamic> e) {
    final empName = e['name'] ?? '—';
    final uid = e['uid'] ?? e['_id'] ?? '';
    final av = empName.length >= 2 ? empName.substring(0,2) : 'م';

    int selMonth = DateTime.now().month;
    int selYear = DateTime.now().year;
    String? expandedDateKey;
    List<Map<String, dynamic>>? expandedPunches;
    bool loadingPunches = false;

    showDialog(context: context, barrierDismissible: true, builder: (ctx) { final dw = MediaQuery.of(ctx).size.width; final isNarrow = dw < 400; return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isNarrow ? 10 : 20),
      child: StatefulBuilder(builder: (ctx, ss) {
        return Container(
          constraints: BoxConstraints(maxWidth: 560, maxHeight: MediaQuery.of(ctx).size.height * 0.85),
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
                  Text('سجل: $empName', style: GoogleFonts.tajawal(fontSize: isNarrow ? 14 : 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('${e['dept'] ?? ''} • ${e['empId'] ?? e['emp_id'] ?? ''}', style: GoogleFonts.tajawal(fontSize: 11, color: Colors.white70), overflow: TextOverflow.ellipsis),
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
                for (final r in records) totalMonthMin += ((r['totalWorkedMinutes'] ?? r['total_worked_minutes']) as int?) ?? 0;
                final present = records.where((r) => (r['firstCheckIn'] ?? r['first_check_in'] ?? r['checkIn'] ?? r['check_in']) != null).length;

                return ListView(padding: const EdgeInsets.all(14), children: [
                  // Stats
                  Container(
                    decoration: DS.cardDecoration(),
                    padding: const EdgeInsets.all(10),
                    child: Row(children: [
                      _stat('إجمالي ساعات', _fmtWorkedTime(totalMonthMin), W.orange),
                      const SizedBox(width: 8),
                      _stat('أيام حضور', '$present', W.pri),
                      const SizedBox(width: 8),
                      _stat('أيام مسجلة', '${records.length}', W.green),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  if (records.isEmpty)
                    Padding(padding: EdgeInsets.all(30), child: Center(child: Text('لا توجد بيانات في ${_months[selMonth - 1]}', style: GoogleFonts.tajawal(fontSize: 13, color: W.muted))))
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
                      final totalMin = ((r['totalWorkedMinutes'] ?? r['total_worked_minutes']) as int?) ?? 0;
                      final sessions = ((r['sessions'] ?? 0) as int?) ?? 1;
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
                                  child: Text(hasOut ? 'مكتمل' : 'حاضر', style: GoogleFonts.tajawal(fontSize: 9, fontWeight: FontWeight.w600, color: stColor))),
                                const SizedBox(height: 3),
                                Text('خروج: ${_fmtTs(lastOut)}', style: _mono(fontSize: 9, color: W.muted)),
                                if (totalMin > 0) Text(_fmtWorkedTime(totalMin), style: GoogleFonts.tajawal(fontSize: 9, fontWeight: FontWeight.w600, color: W.green)),
                              ]),
                              const Spacer(),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Row(children: [
                                  if (wasByAdmin) Container(margin: EdgeInsets.only(left: 4), padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: W.orangeL, borderRadius: BorderRadius.circular(4)), child: Text('إدارية', style: GoogleFonts.tajawal(fontSize: 7, fontWeight: FontWeight.w600, color: W.orange))),
                                  Text('$dayName $day ${_months[month - 1]}', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.text)),
                                ]),
                                Text('حضور: ${_fmtTs(firstIn)}', style: _mono(fontSize: 10, color: W.sub)),
                                if (sessions > 1) Text('$sessions فترات', style: GoogleFonts.tajawal(fontSize: 8, color: W.pri)),
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
                                      Text('تعديل أوقات هذا اليوم', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.orange)),
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
    if (punches.isEmpty) return Padding(padding: EdgeInsets.all(14), child: Center(child: Text('لا توجد تفاصيل', style: GoogleFonts.tajawal(fontSize: 11, color: W.muted))));

    final allLocs = _locations;
    return Builder(builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Column(children: List.generate(punches.length, (i) {
            final punch = punches[i];
            final isCheckIn = punch['type'] == 'checkIn';
            final color = isCheckIn ? W.pri : W.red;
            final label = isCheckIn ? 'دخول' : 'خروج';
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
                if (dist < radius * 3) { locName = loc['name'] ?? ''; break; }
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
                          Text('وجه', style: GoogleFonts.tajawal(fontSize: 8, fontWeight: FontWeight.w600, color: W.pri)),
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
                        Text('بصمة', style: GoogleFonts.tajawal(fontSize: 8, fontWeight: FontWeight.w600, color: W.green)),
                      ]),
                    ),
                    if (byAdmin) Container(margin: EdgeInsets.only(left: 4), padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: W.orangeL, borderRadius: BorderRadius.circular(4)),
                      child: Text(adminName.isNotEmpty ? adminName : 'أدمن', style: GoogleFonts.tajawal(fontSize: 7, fontWeight: FontWeight.w600, color: W.orange))),
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
    final label = isCheckIn ? 'دخول' : 'خروج';
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
            Text('تعديل وقت $label', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: W.text)),
            const SizedBox(width: 8),
            Icon(isCheckIn ? Icons.login : Icons.logout, size: 18, color: color),
          ]),
          const SizedBox(height: 4),
          Text(empName, style: GoogleFonts.tajawal(fontSize: 12, color: W.sub)),
          Text('الوقت الحالي: ${_fmtTs(time)}', style: _mono(fontSize: 11, color: W.muted)),
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
                Text('${selectedTime.hour > 12 ? selectedTime.hour - 12 : (selectedTime.hour == 0 ? 12 : selectedTime.hour)}:${selectedTime.minute.toString().padLeft(2, '0')} ${selectedTime.hour >= 12 ? 'م' : 'ص'}',
                  style: _mono(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
                const SizedBox(width: 10),
                Icon(Icons.access_time, size: 20, color: color),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          Text('اضغط لاختيار الوقت الجديد', style: GoogleFonts.tajawal(fontSize: 10, color: W.muted)),
          const SizedBox(height: 16),

          Row(children: [
            Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.tajawal(fontSize: 13, color: W.muted)))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(
              onPressed: () async {
                final oldDate = currentTime;
                final newTime = DateTime(oldDate.year, oldDate.month, oldDate.day, selectedTime.hour, selectedTime.minute);
                
                if (punchId.isNotEmpty) {
                  await ApiService.post('attendance.php?action=edit_punch', {
                    'punch_id': punchId, 'uid': uid,
                    'new_time': newTime.toIso8601String(),
                    'edited_by': widget.user['name'] ?? 'مدير النظام',
                  });
                }
                
                await _audit('تعديل بصمة فردية', empName, 'تعديل وقت $label من ${_fmtTs(time)} إلى ${selectedTime.hour}:${selectedTime.minute.toString().padLeft(2, '0')}');
                
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تعديل وقت $label لـ $empName', style: GoogleFonts.tajawal()), backgroundColor: W.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd))));
              },
              icon: const Icon(Icons.save, size: 14),
              label: Text('حفظ', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
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
                Text('صورة بصمة الوجه', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: W.text)),
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
                  Text('جارٍ تحميل الصورة...', style: GoogleFonts.tajawal(fontSize: 11, color: Colors.white54)),
                ]));
              },
              errorBuilder: (_, error, ___) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.broken_image, size: 40, color: Colors.white38),
                const SizedBox(height: 8),
                Text('فشل تحميل الصورة', style: GoogleFonts.tajawal(fontSize: 11, color: Colors.white38)),
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
    final minCtrl = TextEditingController(text: '${(record['totalWorkedMinutes'] as int?) ?? (record['total_worked_minutes'] as int?) ?? 0}');

    showDialog(context: context, builder: (ctx) { final ew = MediaQuery.of(ctx).size.width; return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
      width: ew < 440 ? ew - 40 : 400, padding: EdgeInsets.all(ew < 400 ? 16 : 24),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('تعديل بيانات يوم $dateKey', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: W.text)),
          SizedBox(width: 8), Icon(Icons.edit_calendar, size: 20, color: W.orange),
        ]),
        const SizedBox(height: 4),
        Text('$empName', style: GoogleFonts.tajawal(fontSize: 13, color: W.sub)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _timeField(coCtrl, 'وقت الخروج الجديد', '03:00 م', Icons.logout, W.red)),
          const SizedBox(width: 10),
          Expanded(child: _timeField(ciCtrl, 'وقت الحضور الجديد', '08:00 ص', Icons.login, W.green)),
        ]),
        const SizedBox(height: 10),
        _timeField(minCtrl, 'إجمالي الدقائق المحسوبة', '480', Icons.timer, W.pri),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: () async {
            await ApiService.post('attendance.php?action=edit_day', {
              'uid': uid, 'date_key': dateKey,
              if (ciCtrl.text.trim().isNotEmpty) 'check_in_manual': ciCtrl.text.trim(),
              if (coCtrl.text.trim().isNotEmpty) 'check_out_manual': coCtrl.text.trim(),
              if (int.tryParse(minCtrl.text.trim()) != null) 'total_worked_minutes': int.parse(minCtrl.text.trim()),
              'edited_by': widget.user['name'] ?? 'مدير النظام',
            });
            await _audit('تعديل بصمة يدوي', empName, 'تعديل يوم $dateKey — حضور: ${ciCtrl.text} خروج: ${coCtrl.text} دقائق: ${minCtrl.text}');

            if (ctx.mounted) Navigator.pop(ctx);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تعديل بيانات $empName', style: GoogleFonts.tajawal()), backgroundColor: W.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd))));
          },
          icon: const Icon(Icons.save, size: 16),
          label: Text('حفظ التعديل', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(backgroundColor: W.orange, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd))),
        )),
        const SizedBox(height: 6),
        Text('التعديل اليدوي يُسجّل في سجل التدقيق', style: GoogleFonts.tajawal(fontSize: 10, color: W.muted)),
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.tajawal(fontSize: 13, color: W.muted))),
      ])),
    )); });
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

  Widget _searchBox() { final sw = MediaQuery.of(context).size.width; return SizedBox(width: sw < 400 ? sw - 40 : 260, child: TextField(onChanged: (v) => setState(() => _search = v), textAlign: TextAlign.right, style: GoogleFonts.tajawal(fontSize: 13), decoration: InputDecoration(hintText: 'بحث...', hintStyle: GoogleFonts.tajawal(color: W.hint, fontSize: 13), filled: true, fillColor: W.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(DS.radiusMd), borderSide: BorderSide(color: W.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(DS.radiusMd), borderSide: BorderSide(color: W.border)), prefixIcon: Icon(Icons.search, size: 16, color: W.muted)))); }
  Widget _drop(String v, List<String> items, ValueChanged<String> cb, String all) => Container(padding: EdgeInsets.symmetric(horizontal: 16), decoration: DS.cardDecoration(), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: v, isDense: true, style: GoogleFonts.tajawal(fontSize: 13, color: W.text), items: items.map((s) => DropdownMenuItem(value: s, child: Text(s == 'الكل' ? all : s))).toList(), onChanged: (x) { if (x != null) cb(x); })));

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
