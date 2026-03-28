import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_colors.dart';

class AdminVerify extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminVerify({super.key, required this.user});
  @override State<AdminVerify> createState() => _AdminVerifyState();
}

class _AdminVerifyState extends State<AdminVerify> {
  final _db = FirebaseFirestore.instance;
  final Set<String> _sel = {};
  bool _selectAll = false, _sending = false;
  final _mono = GoogleFonts.ibmPlexMono;
  final _months = const ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];

  // Date filter
  late int _filterMonth;
  late int _filterYear;
  late int _filterDay; // 0 = all days in month
  late int _daysInMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _filterMonth = now.month;
    _filterYear = now.year;
    _filterDay = now.day;
    _daysInMonth = DateTime(_filterYear, _filterMonth + 1, 0).day;
  }

  void _updateDaysInMonth() {
    _daysInMonth = DateTime(_filterYear, _filterMonth + 1, 0).day;
    if (_filterDay > _daysInMonth) _filterDay = _daysInMonth;
  }

  String get _filterDateKey {
    if (_filterDay == 0) return '';
    return '$_filterYear-${_filterMonth.toString().padLeft(2, '0')}-${_filterDay.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final dateKeyForAttendance = _filterDateKey.isNotEmpty ? _filterDateKey : todayKey;

    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('users').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('خطأ: ${snap.error}', style: GoogleFonts.tajawal(color: C.red)));
        if (snap.connectionState == ConnectionState.waiting && (snap.data?.docs ?? []).isEmpty) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        final all = (snap.data?.docs ?? []).map((d) { final m = d.data() as Map<String, dynamic>; m['_id'] = d.id; return m; }).where((e) => (e['name'] ?? '').toString().isNotEmpty).toList();
        all.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));

        return StreamBuilder<QuerySnapshot>(
          stream: _db.collection('attendance_daily').where('dateKey', isEqualTo: dateKeyForAttendance).snapshots(),
          builder: (context, attSnap) {
            final attDocs = attSnap.data?.docs ?? [];
            final presentUids = <String>{};
            for (final doc in attDocs) {
              final m = doc.data() as Map<String, dynamic>;
              if ((m['firstCheckIn'] ?? m['checkIn']) != null) presentUids.add(m['uid'] ?? '');
            }
            final active = all.where((e) => presentUids.contains(e['uid'] ?? e['_id'])).toList();

        return SingleChildScrollView(padding: EdgeInsets.all(MediaQuery.of(context).size.width > 800 ? 28 : 14), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('إثبات الحالة', style: GoogleFonts.tajawal(fontSize: 24, fontWeight: FontWeight.w800, color: C.text)),
          const SizedBox(height: 4),
          Text('أرسل طلب إثبات تواجد للتأكد من وجودهم في نطاق العمل', style: GoogleFonts.tajawal(fontSize: 13, color: C.sub)),
          const SizedBox(height: 24),

          // ═══ Send Card — Grouped by Locations ═══
          StreamBuilder<QuerySnapshot>(
            stream: _db.collection('locations').where('active', isEqualTo: true).snapshots(),
            builder: (ctx, locSnap) {
              final locations = (locSnap.data?.docs ?? []).map((d) { final m = d.data() as Map<String, dynamic>; m['_locId'] = d.id; return m; }).toList();

              return Container(
                width: double.infinity, padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
                child: Column(children: [
                  Row(children: [
                    InkWell(
                      onTap: _sel.isEmpty || _sending ? null : () => _sendVerification(all),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        decoration: BoxDecoration(color: _sending ? C.muted : _sel.isEmpty ? C.hint : C.pri, borderRadius: BorderRadius.circular(10)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (_sending) ...[const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), const SizedBox(width: 8), Text('جارٍ الإرسال...', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))]
                          else ...[const Icon(Icons.send, size: 16, color: Colors.white), const SizedBox(width: 8), Text('إرسال طلب إثبات (${_sel.length})', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))],
                        ]),
                      ),
                    ),
                    const Spacer(),
                    Text('إرسال طلب جديد', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
                    const SizedBox(width: 8),
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: C.priLight, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.cell_tower, size: 18, color: C.pri)),
                  ]),
                  const SizedBox(height: 16),

                  // Locations with their employees
                  ...locations.map((loc) {
                    final locId = loc['_locId'] ?? '';
                    final locName = loc['name'] ?? 'موقع';
                    final assignedEmps = (loc['assignedEmployees'] as List?)?.cast<String>() ?? [];
                    // Get employees for this location ONLY (strictly assigned, or all if empty)
                    final locEmployees = active.where((emp) {
                      final uid = emp['uid'] ?? emp['_id'] ?? '';
                      return assignedEmps.isEmpty || assignedEmps.contains(uid);
                    }).toList();
                    // Filter out employees that are already shown in a previous location with specific assignment
                    // to avoid duplication

                    if (locEmployees.isEmpty) return const SizedBox.shrink();

                    // Select/deselect all in this location
                    final allLocSelected = locEmployees.every((emp) => _sel.contains('${locId}_${emp['_id']}'));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        // Location header
                        Row(children: [
                          InkWell(
                            onTap: () => setState(() {
                              if (allLocSelected) {
                                for (final emp in locEmployees) _sel.remove('${locId}_${emp['_id']}');
                              } else {
                                for (final emp in locEmployees) _sel.add('${locId}_${emp['_id']}');
                              }
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: allLocSelected ? C.pri.withOpacity(0.1) : C.div, borderRadius: BorderRadius.circular(6)),
                              child: Text(allLocSelected ? 'إلغاء الكل' : 'تحديد الكل', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: allLocSelected ? C.pri : C.sub)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: C.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                            child: Text('${locEmployees.length} موظف', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: C.green))),
                          const Spacer(),
                          Text(locName, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: C.text)),
                          const SizedBox(width: 8),
                          const Icon(Icons.location_on, size: 18, color: C.pri),
                        ]),
                        const SizedBox(height: 10),
                        // Employees in this location
                        Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end, children: locEmployees.map((emp) {
                          final selKey = '${locId}_${emp['_id']}';
                          final sel = _sel.contains(selKey);
                          final av = (emp['name'] ?? '').toString().length >= 2 ? emp['name'].toString().substring(0,2) : 'م';
                          return InkWell(
                            onTap: () => setState(() { sel ? _sel.remove(selKey) : _sel.add(selKey); }),
                            child: Container(
                              width: 200, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(color: sel ? C.priLight : C.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: sel ? C.pri : C.border)),
                              child: Row(children: [
                                Icon(sel ? Icons.check_circle : Icons.circle_outlined, size: 16, color: sel ? C.pri : C.muted),
                                const SizedBox(width: 6),
                                Expanded(child: Text(emp['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? C.pri : C.text), overflow: TextOverflow.ellipsis)),
                                Container(width: 24, height: 24, decoration: BoxDecoration(color: C.pri.withOpacity(0.08), shape: BoxShape.circle), child: Center(child: Text(av, style: GoogleFonts.tajawal(fontSize: 9, fontWeight: FontWeight.w700, color: C.pri)))),
                              ]),
                            ),
                          );
                        }).toList()),
                      ]),
                    );
                  }),
                ]),
              );
            },
          ),
          const SizedBox(height: 20),

          // ═══ Date/Month Filter ═══
          Text('نتائج الإثبات', style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w700, color: C.text)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
            child: Row(children: [
              // Day picker
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.border)),
                child: DropdownButtonHideUnderline(child: DropdownButton<int>(
                  value: _filterDay,
                  style: GoogleFonts.tajawal(fontSize: 13, color: C.text),
                  items: [
                    DropdownMenuItem(value: 0, child: Text('كل الأيام', style: GoogleFonts.tajawal(fontSize: 12))),
                    ...List.generate(_daysInMonth, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}', style: GoogleFonts.ibmPlexMono(fontSize: 13)))),
                  ],
                  onChanged: (v) => setState(() => _filterDay = v ?? 0),
                )),
              ),
              const SizedBox(width: 8),
              // Month picker
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.border)),
                child: DropdownButtonHideUnderline(child: DropdownButton<int>(
                  value: _filterMonth,
                  style: GoogleFonts.tajawal(fontSize: 13, color: C.text),
                  items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_months[i], style: GoogleFonts.tajawal(fontSize: 12)))),
                  onChanged: (v) => setState(() { _filterMonth = v ?? now.month; _updateDaysInMonth(); }),
                )),
              ),
              const SizedBox(width: 8),
              // Year picker
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.border)),
                child: DropdownButtonHideUnderline(child: DropdownButton<int>(
                  value: _filterYear,
                  style: GoogleFonts.ibmPlexMono(fontSize: 13, color: C.text),
                  items: List.generate(3, (i) => DropdownMenuItem(value: now.year - i, child: Text('${now.year - i}', style: GoogleFonts.ibmPlexMono(fontSize: 13)))),
                  onChanged: (v) => setState(() { _filterYear = v ?? now.year; _updateDaysInMonth(); }),
                )),
              ),
              const Spacer(),
              const Icon(Icons.filter_list, size: 18, color: C.pri),
              const SizedBox(width: 6),
              Text('فلتر حسب التاريخ', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: C.text)),
            ]),
          ),
          const SizedBox(height: 10),

          // ═══ Results ═══
          StreamBuilder<QuerySnapshot>(
            stream: _db.collection('verification_requests').orderBy('sentAt', descending: true).limit(100).snapshots(),
            builder: (ctx, vSnap) {
              if (vSnap.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2)));
              var vDocs = vSnap.data?.docs ?? [];
              
              // Filter by selected date/month
              final requests = vDocs.map((d) { final m = d.data() as Map<String, dynamic>; m['_docId'] = d.id; return m; }).where((r) {
                final sentAt = r['sentAt'] as Timestamp?;
                if (sentAt == null) return false;
                final dt = sentAt.toDate();
                if (dt.year != _filterYear || dt.month != _filterMonth) return false;
                if (_filterDay > 0 && dt.day != _filterDay) return false;
                return true;
              }).toList();

              if (requests.isEmpty) return Container(
                width: double.infinity, padding: const EdgeInsets.all(50),
                decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
                child: Column(children: [const Icon(Icons.cell_tower, size: 40, color: C.hint), const SizedBox(height: 12), Text('لا توجد طلبات إثبات في هذا التاريخ', style: GoogleFonts.tajawal(fontSize: 14, color: C.muted))]),
              );

              final responded = requests.where((r) => r['status'] == 'responded').length;
              final pending = requests.where((r) => r['status'] == 'pending').length;
              final inRange = requests.where((r) => r['inRange'] == true).length;
              final outRange = requests.where((r) => r['inRange'] == false && r['status'] == 'responded').length;

              return Column(children: [
                Row(children: [
                  _rBadge('$outRange خارج النطاق', C.red, C.redL),
                  const SizedBox(width: 8),
                  _rBadge('$inRange داخل النطاق', C.green, C.greenL),
                  const SizedBox(width: 8),
                  _rBadge('$pending بانتظار', C.orange, C.orangeL),
                  const SizedBox(width: 8),
                  _rBadge('$responded استجاب', C.pri, C.priLight),
                ]),
                const SizedBox(height: 14),
                ...requests.map((r) {
                  final isPending = r['status'] == 'pending';
                  final isInRange = r['inRange'] == true;
                  final stColor = isPending ? C.orange : (isInRange ? C.green : C.red);
                  final stText = isPending ? 'بانتظار الاستجابة' : (isInRange ? 'داخل النطاق ✓' : 'خارج النطاق ⚠');
                  final dist = r['distance'];
                  final av = (r['empName'] ?? 'م').toString().length >= 2 ? r['empName'].toString().substring(0, 2) : 'م';
                  final sentAt = r['sentAt'] as Timestamp?;
                  final sentTime = sentAt != null ? _fmtTime(sentAt) : '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isPending ? C.orangeBd : (isInRange ? C.greenBd : C.redBd))),
                    child: Row(children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: stColor.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                          child: Text(stText, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: stColor))),
                        if (dist != null) ...[
                          const SizedBox(height: 4),
                          Text('المسافة: ${(dist as num).toInt()} متر', style: _mono(fontSize: 11, color: C.sub)),
                        ],
                        if (sentTime.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(sentTime, style: _mono(fontSize: 10, color: C.hint)),
                        ],
                      ]),
                      const Spacer(),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(r['empName'] ?? '—', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600, color: C.text)),
                        Text(r['empId'] ?? '', style: GoogleFonts.tajawal(fontSize: 11, color: C.muted)),
                      ]),
                      const SizedBox(width: 10),
                      Container(width: 36, height: 36, decoration: BoxDecoration(color: stColor.withOpacity(0.08), shape: BoxShape.circle),
                        child: Center(child: Text(av, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w700, color: stColor)))),
                    ]),
                  );
                }),
              ]);
            },
          ),
        ]));}); });
  }

  String _fmtTime(Timestamp ts) {
    final dt = ts.toDate();
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'م' : 'ص'}';
  }

  Future<void> _sendVerification(List<Map<String, dynamic>> all) async {
    setState(() => _sending = true);
    final now = DateTime.now();
    final batchId = '${now.millisecondsSinceEpoch}';
    final empNames = <String>[];

    // Extract unique employee IDs from scoped keys (format: "locId_empId")
    final uniqueEmpIds = <String>{};
    for (final key in _sel) {
      final parts = key.split('_');
      if (parts.length >= 2) {
        uniqueEmpIds.add(parts.sublist(1).join('_'));
      } else {
        uniqueEmpIds.add(key);
      }
    }

    for (var id in uniqueEmpIds) {
      final emp = all.firstWhere((e) => e['_id'] == id, orElse: () => {});
      if (emp.isEmpty) continue;
      final empUid = emp['uid'] ?? id;
      final empName = emp['name'] ?? '—';
      empNames.add(empName);

      await _db.collection('verification_requests').add({
        'batchId': batchId, 'uid': empUid, 'empId': emp['empId'] ?? '', 'empName': empName,
        'status': 'pending', 'sentBy': widget.user['name'] ?? 'مدير النظام',
        'sentAt': FieldValue.serverTimestamp(), 'respondedAt': null,
        'empLat': null, 'empLng': null, 'inRange': null, 'distance': null,
      });

      await _db.collection('notifications').add({
        'uid': empUid, 'title': 'طلب إثبات حالة',
        'body': 'يرجى إثبات تواجدك في نطاق العمل الآن',
        'type': 'verify_request', 'batchId': batchId, 'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Queue FCM push notification
      try {
        final userDoc = await _db.collection('users').doc(empUid).get();
        final fcmToken = userDoc.data()?['fcmToken'] as String?;
        if (fcmToken != null && fcmToken.isNotEmpty) {
          await _db.collection('fcm_queue').add({
            'token': fcmToken, 'title': 'طلب إثبات حالة',
            'body': 'يرجى إثبات تواجدك في نطاق العمل الآن — اضغط للاستجابة',
            'data': {'type': 'verify_request', 'batchId': batchId},
            'createdAt': FieldValue.serverTimestamp(), 'sent': false,
          });
        }
      } catch (_) {}
    }

    await _db.collection('audit_log').add({
      'user': widget.user['name'] ?? 'مدير النظام', 'action': 'إرسال إثبات حالة',
      'target': '${_sel.length} موظفين', 'details': 'تم إرسال طلب إثبات لـ: ${empNames.join('، ')}',
      'timestamp': FieldValue.serverTimestamp(), 'type': 'verify',
    });

    setState(() { _sending = false; _sel.clear(); _selectAll = false; });
  }

  Widget _rBadge(String t, Color c, Color bg) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)), child: Text(t, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: c)));
}
