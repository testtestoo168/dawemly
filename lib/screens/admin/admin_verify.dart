import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

class AdminVerify extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminVerify({super.key, required this.user});
  @override State<AdminVerify> createState() => _AdminVerifyState();
}

class _AdminVerifyState extends State<AdminVerify> {
  final Set<String> _sel = {};
  bool _selectAll = false, _sending = false;
  final _mono = GoogleFonts.ibmPlexMono;
  final _months = const ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];

  // Date filter
  late int _filterMonth;
  late int _filterYear;
  late int _filterDay; // 0 = all days in month
  late int _daysInMonth;

  // Data
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _verifications = [];
  List<Map<String, dynamic>> _todayAttendance = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _filterMonth = now.month;
    _filterYear = now.year;
    _filterDay = now.day;
    _daysInMonth = DateTime(_filterYear, _filterMonth + 1, 0).day;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final usersRes = await ApiService.get('users.php?action=list');
      final locsRes = await ApiService.get('admin.php?action=get_locations');
      final verifRes = await ApiService.get('admin.php?action=get_verifications');
      final attRes = await ApiService.get('attendance.php?action=all_today');

      if (mounted) {
        setState(() {
          _allUsers = (usersRes['users'] as List? ?? []).cast<Map<String, dynamic>>();
          _locations = (locsRes['locations'] as List? ?? []).cast<Map<String, dynamic>>();
          _verifications = (verifRes['verifications'] as List? ?? []).cast<Map<String, dynamic>>();
          _todayAttendance = (attRes['records'] as List? ?? []).cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _updateDaysInMonth() {
    _daysInMonth = DateTime(_filterYear, _filterMonth + 1, 0).day;
    if (_filterDay > _daysInMonth) _filterDay = _daysInMonth;
  }

  String get _filterDateKey {
    if (_filterDay == 0) return '';
    return '$_filterYear-${_filterMonth.toString().padLeft(2, '0')}-${_filterDay.toString().padLeft(2, '0')}';
  }

  DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is String) { try { return DateTime.parse(v); } catch (_) { return null; } }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));

    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final dateKeyForAttendance = _filterDateKey.isNotEmpty ? _filterDateKey : todayKey;

    final all = _allUsers.where((e) => (e['name'] ?? '').toString().isNotEmpty).toList();
    all.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));

    final presentUids = <String>{};
    for (final rec in _todayAttendance) {
      if ((rec['firstCheckIn'] ?? rec['first_check_in'] ?? rec['checkIn'] ?? rec['check_in']) != null) presentUids.add(rec['uid'] ?? '');
    }
    final active = all.where((e) => presentUids.contains(e['uid'] ?? e['_id'])).toList();

    final locations = _locations.where((l) => l['active'] == true || l['active'] == 1).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(MediaQuery.of(context).size.width > 800 ? 28 : 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('إثبات الحالة', style: GoogleFonts.tajawal(fontSize: MediaQuery.of(context).size.width < 400 ? 18 : 24, fontWeight: FontWeight.w800, color: W.text)),
          const SizedBox(height: 4),
          Text('أرسل طلب إثبات تواجد للتأكد من وجودهم في نطاق العمل', style: GoogleFonts.tajawal(fontSize: 12, color: W.sub)),
          const SizedBox(height: 24),

          // ═══ Send Card — Grouped by Locations ═══
          Container(
            width: double.infinity, padding: EdgeInsets.all(MediaQuery.of(context).size.width < 400 ? 14 : 22),
            decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
            child: Column(children: [
              // Title row
              Row(children: [
                const Spacer(),
                Flexible(child: Text('إرسال طلب جديد', style: GoogleFonts.tajawal(fontSize: MediaQuery.of(context).size.width < 400 ? 14 : 16, fontWeight: FontWeight.w700, color: W.text))),
                const SizedBox(width: 8),
                Container(width: 32, height: 32, decoration: BoxDecoration(color: W.priLight, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.cell_tower, size: 16, color: W.pri)),
              ]),
              const SizedBox(height: 10),
              // Send button - full width on small screens
              Align(alignment: Alignment.centerLeft, child: InkWell(
                onTap: _sel.isEmpty || _sending ? null : () => _sendVerification(all),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width < 400 ? 14 : 24, vertical: 10),
                  decoration: BoxDecoration(color: _sending ? W.muted : _sel.isEmpty ? W.hint : W.pri, borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (_sending) ...[const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), const SizedBox(width: 6), Text('جارٍ الإرسال...', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white))]
                    else ...[const Icon(Icons.send, size: 14, color: Colors.white), const SizedBox(width: 6), Text('إرسال (${_sel.length})', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white))],
                  ]),
                ),
              )),
              const SizedBox(height: 16),

              // Locations with their employees
              ...locations.map((loc) {
                final locId = loc['_locId'] ?? loc['id'] ?? '';
                final locName = loc['name'] ?? 'موقع';
                final assignedEmps = ((loc['assigned_employees'] ?? loc['assignedEmployees']) as List?)?.cast<String>() ?? [];
                // Get employees for this location ONLY (strictly assigned, or all if empty)
                final locEmployees = active.where((emp) {
                  final uid = emp['uid'] ?? emp['_id'] ?? '';
                  return assignedEmps.isEmpty || assignedEmps.contains(uid);
                }).toList();

                if (locEmployees.isEmpty) return const SizedBox.shrink();

                // Select/deselect all in this location
                final allLocSelected = locEmployees.every((emp) => _sel.contains('${locId}_${emp['_id'] ?? emp['uid']}'));

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    // Location header
                    Row(children: [
                      InkWell(
                        onTap: () => setState(() {
                          if (allLocSelected) {
                            for (final emp in locEmployees) _sel.remove('${locId}_${emp['_id'] ?? emp['uid']}');
                          } else {
                            for (final emp in locEmployees) _sel.add('${locId}_${emp['_id'] ?? emp['uid']}');
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: allLocSelected ? W.pri.withOpacity(0.1) : W.div, borderRadius: BorderRadius.circular(6)),
                          child: Text(allLocSelected ? 'إلغاء' : 'الكل', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: allLocSelected ? W.pri : W.sub)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: W.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text('${locEmployees.length}', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: W.green))),
                      const Spacer(),
                      Flexible(child: Text(locName, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: W.text))),
                      const SizedBox(width: 6),
                      Icon(Icons.location_on, size: 16, color: W.pri),
                    ]),
                    const SizedBox(height: 10),
                    // Employees in this location
                    Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end, children: locEmployees.map((emp) {
                      final empKey = emp['_id'] ?? emp['uid'] ?? '';
                      final selKey = '${locId}_$empKey';
                      final sel = _sel.contains(selKey);
                      final av = (emp['name'] ?? '').toString().length >= 2 ? emp['name'].toString().substring(0,2) : 'م';
                      return InkWell(
                        onTap: () => setState(() { sel ? _sel.remove(selKey) : _sel.add(selKey); }),
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 140, maxWidth: 200), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(color: sel ? W.priLight : W.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: sel ? W.pri : W.border)),
                          child: Row(children: [
                            Icon(sel ? Icons.check_circle : Icons.circle_outlined, size: 16, color: sel ? W.pri : W.muted),
                            const SizedBox(width: 6),
                            Expanded(child: Text(emp['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? W.pri : W.text))),
                            Container(width: 24, height: 24, decoration: BoxDecoration(color: W.pri.withOpacity(0.08), shape: BoxShape.circle), child: Center(child: Text(av, style: GoogleFonts.tajawal(fontSize: 9, fontWeight: FontWeight.w700, color: W.pri)))),
                          ]),
                        ),
                      );
                    }).toList()),
                  ]),
                );
              }),
            ]),
          ),
          const SizedBox(height: 20),

          // ═══ Date/Month Filter ═══
          Text('نتائج الإثبات', style: GoogleFonts.tajawal(fontSize: MediaQuery.of(context).size.width < 400 ? 16 : 18, fontWeight: FontWeight.w700, color: W.text)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              // Label row on its own line
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('فلتر حسب التاريخ', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: W.text)),
                const SizedBox(width: 6),
                Icon(Icons.filter_list, size: 18, color: W.pri),
              ]),
              const SizedBox(height: 10),
              // 3 dropdowns in a row, equally spaced
              Row(children: [
                // Day picker
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('اليوم', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.sub)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(4), border: Border.all(color: W.border)),
                    child: DropdownButtonHideUnderline(child: DropdownButton<int>(
                      value: _filterDay, isExpanded: true,
                      style: GoogleFonts.tajawal(fontSize: 13, color: W.text),
                      items: [
                        DropdownMenuItem(value: 0, child: Text('الكل', style: GoogleFonts.tajawal(fontSize: 12))),
                        ...List.generate(_daysInMonth, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}', style: GoogleFonts.ibmPlexMono(fontSize: 13)))),
                      ],
                      onChanged: (v) => setState(() => _filterDay = v ?? 0),
                    )),
                  ),
                ])),
                const SizedBox(width: 8),
                // Month picker
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('الشهر', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.sub)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(4), border: Border.all(color: W.border)),
                    child: DropdownButtonHideUnderline(child: DropdownButton<int>(
                      value: _filterMonth, isExpanded: true,
                      style: GoogleFonts.tajawal(fontSize: 13, color: W.text),
                      items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_months[i], style: GoogleFonts.tajawal(fontSize: 12)))),
                      onChanged: (v) => setState(() { _filterMonth = v ?? now.month; _updateDaysInMonth(); }),
                    )),
                  ),
                ])),
                const SizedBox(width: 8),
                // Year picker
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('السنة', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.sub)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(4), border: Border.all(color: W.border)),
                    child: DropdownButtonHideUnderline(child: DropdownButton<int>(
                      value: _filterYear, isExpanded: true,
                      style: GoogleFonts.ibmPlexMono(fontSize: 13, color: W.text),
                      items: List.generate(3, (i) => DropdownMenuItem(value: now.year - i, child: Text('${now.year - i}', style: GoogleFonts.ibmPlexMono(fontSize: 13)))),
                      onChanged: (v) => setState(() { _filterYear = v ?? now.year; _updateDaysInMonth(); }),
                    )),
                  ),
                ])),
              ]),
            ]),
          ),
          const SizedBox(height: 10),

          // ═══ Results ═══
          _buildVerificationResults(),
        ]),
      ),
    );
  }

  Widget _buildVerificationResults() {
    // Filter by selected date/month
    final requests = _verifications.where((r) {
      final sentAt = _parseTs(r['sent_at'] ?? r['sentAt']);
      if (sentAt == null) return false;
      if (sentAt.year != _filterYear || sentAt.month != _filterMonth) return false;
      if (_filterDay > 0 && sentAt.day != _filterDay) return false;
      return true;
    }).toList();

    if (requests.isEmpty) return Container(
      width: double.infinity, padding: const EdgeInsets.all(50),
      decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
      child: Column(children: [Icon(Icons.cell_tower, size: 40, color: W.hint), SizedBox(height: 12), Text('لا توجد طلبات إثبات في هذا التاريخ', style: GoogleFonts.tajawal(fontSize: 14, color: W.muted))]),
    );

    final responded = requests.where((r) => r['status'] == 'responded').length;
    final pending = requests.where((r) => r['status'] == 'pending').length;
    final inRange = requests.where((r) => r['inRange'] == true || r['in_range'] == 1 || r['in_range'] == true).length;
    final outRange = requests.where((r) => (r['inRange'] == false || r['in_range'] == 0) && r['status'] == 'responded').length;

    return Column(children: [
      Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.start, children: [
        _rBadge('$outRange خارج', W.red, W.redL),
        _rBadge('$inRange داخل', W.green, W.greenL),
        _rBadge('$pending بانتظار', W.orange, W.orangeL),
        _rBadge('$responded استجاب', W.pri, W.priLight),
      ]),
      const SizedBox(height: 14),
      ...requests.map((r) {
        final isPending = r['status'] == 'pending';
        final isInRange = r['inRange'] == true || r['in_range'] == 1 || r['in_range'] == true;
        final stColor = isPending ? W.orange : (isInRange ? W.green : W.red);
        final stText = isPending ? 'بانتظار الاستجابة' : (isInRange ? 'داخل النطاق ✓' : 'خارج النطاق ⚠');
        final dist = r['distance'];
        final av = (r['emp_name'] ?? r['empName'] ?? 'م').toString().length >= 2 ? (r['emp_name'] ?? r['empName']).toString().substring(0, 2) : 'م';
        final sentAt = _parseTs(r['sent_at'] ?? r['sentAt']);
        final sentTime = sentAt != null ? _fmtTime(sentAt) : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width < 400 ? 12 : 18, vertical: 12),
          decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: isPending ? W.orangeBd : (isInRange ? W.greenBd : W.redBd))),
          child: Row(children: [
            Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: stColor.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                child: Text(stText, style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: stColor))),
              if (dist != null) ...[
                const SizedBox(height: 3),
                Text('${(dist as num).toInt()} م', style: _mono(fontSize: 10, color: W.sub)),
              ],
              if (sentTime.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(sentTime, style: _mono(fontSize: 9, color: W.hint)),
              ],
            ])),
            const SizedBox(width: 8),
            Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(r['emp_name'] ?? r['empName'] ?? '—', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: W.text)),
              Text(r['emp_id'] ?? r['empId'] ?? '', style: GoogleFonts.tajawal(fontSize: 10, color: W.muted), overflow: TextOverflow.ellipsis),
            ])),
            const SizedBox(width: 8),
            Container(width: 34, height: 34, decoration: BoxDecoration(color: stColor.withOpacity(0.08), shape: BoxShape.circle),
              child: Center(child: Text(av, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w700, color: stColor)))),
          ]),
        );
      }),
    ]);
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'م' : 'ص'}';
  }

  Future<void> _sendVerification(List<Map<String, dynamic>> all) async {
    setState(() => _sending = true);

    // Extract unique employee UIDs from scoped keys (format: "locId_empId")
    final uniqueEmpKeys = <String>{};
    for (final key in _sel) {
      final parts = key.split('_');
      if (parts.length >= 2) {
        uniqueEmpKeys.add(parts.sublist(1).join('_'));
      } else {
        uniqueEmpKeys.add(key);
      }
    }

    final employees = <Map<String, dynamic>>[];
    for (var id in uniqueEmpKeys) {
      final emp = all.firstWhere((e) => (e['_id'] ?? e['uid']) == id, orElse: () => {});
      if (emp.isEmpty) continue;
      employees.add({
        'uid': emp['uid'] ?? id,
        'emp_id': emp['emp_id'] ?? '',
        'name': emp['name'] ?? '',
      });
    }

    await ApiService.post('admin.php?action=send_verification', {'employees': employees});

    // Audit log
    await ApiService.post('admin.php?action=audit_log', {
      'user': widget.user['name'] ?? 'مدير النظام',
      'action': 'إرسال إثبات حالة',
      'target': '${_sel.length} موظفين',
      'details': 'تم إرسال طلب إثبات لـ ${employees.length} موظف',
      'type': 'verify',
    });

    // Reload verifications
    final verifRes = await ApiService.get('admin.php?action=get_verifications');
    if (mounted) {
      setState(() {
        _verifications = (verifRes['verifications'] as List? ?? []).cast<Map<String, dynamic>>();
        _sending = false;
        _sel.clear();
        _selectAll = false;
      });
    }
  }

  Widget _rBadge(String t, Color c, Color bg) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)), child: Text(t, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: c)));
}
