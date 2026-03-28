import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';

class AdminSchedules extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminSchedules({super.key, required this.user});
  @override State<AdminSchedules> createState() => _AdminSchedulesState();
}

class _AdminSchedulesState extends State<AdminSchedules> {
  String _tab = 'schedules';
  bool _saved = false;
  final _mono = GoogleFonts.ibmPlexMono;
  final _allDays = ['أحد','إثنين','ثلاثاء','أربعاء','خميس','جمعة','سبت'];
  String? _selSchId;

  // Data
  List<Map<String, dynamic>> _emps = [];
  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _holidays = [];
  bool _loading = true;

  // Add schedule form
  bool _showAddSch = false;
  String _newSchName = '';
  int _newSchShift = 1;
  List<String> _newSchDays = ['أحد','إثنين','ثلاثاء','أربعاء','خميس'];

  // Add holiday form
  bool _showAddHol = false;
  String _newHolName = '', _newHolDate = '', _newHolType = 'عامة';
  int _newHolDays = 1;
  final Set<String> _holSelEmps = {};

  final _shifts = [
    {'id': 1, 'name': 'الفترة الأولى', 'start': '08:00 ص', 'end': '04:00 م', 'color': C.pri},
    {'id': 2, 'name': 'الفترة الثانية', 'start': '01:00 م', 'end': '09:00 م', 'color': C.purple},
    {'id': 3, 'name': 'الفترة الثالثة', 'start': '04:00 م', 'end': '12:00 ص', 'color': C.teal},
  ];

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.get('users.php?action=list'),
        ApiService.get('admin.php?action=get_schedules'),
        ApiService.get('admin.php?action=get_holidays'),
      ]);

      final empResult = results[0];
      final schResult = results[1];
      final holResult = results[2];

      final empList = List<Map<String, dynamic>>.from(empResult['users'] ?? empResult['data'] ?? []);
      empList.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));

      final schList = List<Map<String, dynamic>>.from(schResult['schedules'] ?? schResult['data'] ?? []);
      final holList = List<Map<String, dynamic>>.from(holResult['holidays'] ?? holResult['data'] ?? []);

      // Init defaults if schedules empty
      if (schList.isEmpty) {
        await _initDefaults();
        return; // _initDefaults calls _loadData again
      }
      if (holList.isEmpty) {
        await _initDefaultHolidays();
        return;
      }

      if (mounted) {
        setState(() {
          _emps = empList;
          _schedules = schList;
          _holidays = holList;
          _loading = false;
          if (_schedules.isNotEmpty && _selSchId == null) _selSchId = _schedules.first['id']?.toString();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _initDefaults() async {
    for (var s in [
      {'name': 'الجدول الأساسي', 'shiftId': 1, 'days': ['أحد','إثنين','ثلاثاء','أربعاء','خميس'], 'empIds': []},
      {'name': 'الجدول المسائي', 'shiftId': 2, 'days': ['أحد','إثنين','ثلاثاء','أربعاء','خميس'], 'empIds': []},
      {'name': 'جدول الفترة الثالثة', 'shiftId': 3, 'days': ['أحد','إثنين','ثلاثاء','أربعاء'], 'empIds': []},
    ]) { await ApiService.post('admin.php?action=save_schedule', body: s); }
    await _loadData();
  }

  Future<void> _initDefaultHolidays() async {
    for (var h in [
      {'name': 'اليوم الوطني السعودي', 'date': '23 سبتمبر 2026', 'days': 1, 'type': 'عامة', 'empIds': []},
      {'name': 'عيد الفطر', 'date': '20 مارس — 24 مارس 2026', 'days': 5, 'type': 'عامة', 'empIds': []},
      {'name': 'عيد الأضحى', 'date': '6 يونيو — 11 يونيو 2026', 'days': 6, 'type': 'عامة', 'empIds': []},
    ]) { await ApiService.post('admin.php?action=save_holiday', body: h); }
    await _loadData();
  }

  @override
  void initState() { super.initState(); _loadData(); }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));

    final emps = _emps;

    return SingleChildScrollView(padding: EdgeInsets.all(MediaQuery.of(context).size.width > 800 ? 28 : 14), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Row(children: [_saveBtn(), const Spacer(), Text('الجداول والإجازات', style: GoogleFonts.tajawal(fontSize: 24, fontWeight: FontWeight.w800, color: C.text))]),
      const SizedBox(height: 24),
      Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [_tabBtn('الجداول', 'schedules'), _tabBtn('الإجازات', 'holidays')])),
      const SizedBox(height: 24),
      if (_tab == 'schedules') _schedulesTab(emps),
      if (_tab == 'holidays') _holidaysTab(emps),
    ]));
  }

  // ═══ SCHEDULES TAB ═══
  Widget _schedulesTab(List<Map<String, dynamic>> emps) {
    final schedules = _schedules;
    if (schedules.isNotEmpty && _selSchId == null) _selSchId = schedules.first['id']?.toString();
    final activeSch = schedules.firstWhere((s) => s['id']?.toString() == _selSchId, orElse: () => schedules.isNotEmpty ? schedules.first : {});
    if (activeSch.isEmpty) return const SizedBox();
    final activeShId = (activeSch['shiftId'] is int) ? activeSch['shiftId'] : int.tryParse('${activeSch['shiftId']}') ?? 1;
    final shift = _shifts.firstWhere((s) => s['id'] == activeShId, orElse: () => _shifts.first);
    final schColor = shift['color'] as Color;
    final schEmpIds = List<String>.from(activeSch['empIds'] ?? []);
    final schEmps = emps.where((e) => schEmpIds.contains(e['id']?.toString())).toList();
    final availEmps = emps.where((e) => !schEmpIds.contains(e['id']?.toString())).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Row(children: [_addBtnDash(Icons.add, 'جدول جديد', C.pri, C.priLight, () => setState(() => _showAddSch = true)), const Spacer(), Text('كل جدول مربوط بفترة عمل — حدد الأيام والموظفين', style: GoogleFonts.tajawal(fontSize: 13, color: C.sub))]),
      const SizedBox(height: 16),
      if (_showAddSch) _addSchForm(),
      SizedBox(height: 150, child: ListView.builder(
        scrollDirection: Axis.horizontal, reverse: true,
        itemCount: schedules.length,
        itemBuilder: (ctx, i) {
          final sch = schedules[i];
          final shId = (sch['shiftId'] is int) ? sch['shiftId'] : int.tryParse('${sch['shiftId']}') ?? 1;
          final sh = _shifts.firstWhere((s) => s['id'] == shId, orElse: () => _shifts.first);
          final isSel = _selSchId == sch['id']?.toString();
          final c = sh['color'] as Color;
          final days = List<String>.from(sch['days'] ?? []);
          return Padding(padding: const EdgeInsets.only(left: 14), child: InkWell(onTap: () => setState(() => _selSchId = sch['id']?.toString()),
            child: Container(width: 260, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: isSel ? c.withOpacity(0.04) : C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isSel ? c : C.border, width: isSel ? 2 : 1)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(children: [
                  InkWell(onTap: () async { await ApiService.post('admin.php?action=delete_schedule', body: {'id': sch['id']}); _loadData(); }, child: Container(width: 26, height: 26, decoration: BoxDecoration(color: C.redL, borderRadius: BorderRadius.circular(6), border: Border.all(color: C.redBd)), child: const Icon(Icons.delete, size: 11, color: C.red))),
                  const SizedBox(width: 4),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: C.div, borderRadius: BorderRadius.circular(6)), child: Text('${(sch['empIds'] as List?)?.length ?? 0} موظف', style: GoogleFonts.tajawal(fontSize: 11, color: C.muted))),
                  const Spacer(),
                  Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(sch['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: C.text), overflow: TextOverflow.ellipsis),
                    Text('${sh['name']}', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: c)),
                  ])),
                ]),
                const SizedBox(height: 4),
                Text('(${sh['start']} — ${sh['end']})', style: _mono(fontSize: 10, color: C.muted)),
                const Spacer(),
                Row(children: _allDays.map((d) => Expanded(child: Container(height: 24, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: BoxDecoration(color: days.contains(d) ? c.withOpacity(0.12) : C.div, borderRadius: BorderRadius.circular(5)), child: Center(child: Text(d.substring(0,2), style: GoogleFonts.tajawal(fontSize: 9, fontWeight: FontWeight.w600, color: days.contains(d) ? c : C.hint)))))).toList()),
              ]))));
        },
      )),
      const SizedBox(height: 24),
      // Employee assignment
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Container(decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: schColor)),
          child: Column(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.div))),
              child: Row(children: [Text('${availEmps.length} متاح', style: GoogleFonts.tajawal(fontSize: 12, color: C.muted)), const Spacer(), Text('إضافة موظفين ←', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: C.text))])),
            ConstrainedBox(constraints: const BoxConstraints(maxHeight: 350), child: ListView(shrinkWrap: true, children: availEmps.map((emp) => _empRow(emp, true, schColor, () async {
              final newIds = List<String>.from(schEmpIds)..add(emp['id']?.toString() ?? '');
              await ApiService.post('admin.php?action=save_schedule', body: {'id': _selSchId, 'empIds': newIds});
              _loadData();
            })).toList())),
          ]))),
        const SizedBox(width: 20),
        Expanded(child: Container(decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: schColor.withOpacity(0.4))),
          child: Column(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14), decoration: BoxDecoration(color: schColor.withOpacity(0.03), border: const Border(bottom: BorderSide(color: C.div))),
              child: Row(children: [Text('${schEmps.length} موظف', style: GoogleFonts.tajawal(fontSize: 12, color: C.muted)), const Spacer(), Text('موظفين "${activeSch['name']}"', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: C.text))])),
            if (schEmps.isEmpty) Padding(padding: const EdgeInsets.all(30), child: Text('لا يوجد موظفين — أضف من القائمة', style: GoogleFonts.tajawal(fontSize: 12, color: C.muted))),
            ...schEmps.map((emp) => _empRow(emp, false, schColor, () async {
              final newIds = List<String>.from(schEmpIds)..remove(emp['id']?.toString());
              await ApiService.post('admin.php?action=save_schedule', body: {'id': _selSchId, 'empIds': newIds});
              _loadData();
            })),
          ]))),
      ]),
    ]);
  }

  Widget _addSchForm() => Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.pri, width: 2)),
    child: Column(children: [
      Row(children: [
        Expanded(child: _field('اسم الجدول', 'مثال: جدول رمضان', (v) => _newSchName = v)),
        const SizedBox(width: 14),
        SizedBox(width: 250, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('الفترة المرتبطة', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.sub)),
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.symmetric(horizontal: 14), width: double.infinity, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: C.border)),
            child: DropdownButtonHideUnderline(child: DropdownButton<int>(value: _newSchShift, isExpanded: true, style: GoogleFonts.tajawal(fontSize: 13, color: C.text),
              items: _shifts.map((s) => DropdownMenuItem(value: s['id'] as int, child: Text('${s['name']} (${s['start']} — ${s['end']})'))).toList(), onChanged: (v) => setState(() => _newSchShift = v ?? 1)))),
        ])),
      ]),
      const SizedBox(height: 14),
      Align(alignment: Alignment.centerRight, child: Text('أيام العمل', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.sub))),
      const SizedBox(height: 6),
      Row(children: _allDays.map((d) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: InkWell(onTap: () => setState(() => _newSchDays.contains(d) ? _newSchDays.remove(d) : _newSchDays.add(d)),
        child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: _newSchDays.contains(d) ? C.priLight : C.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _newSchDays.contains(d) ? C.pri : C.border, width: _newSchDays.contains(d) ? 2 : 1)),
          child: Center(child: Text(d, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: _newSchDays.contains(d) ? C.pri : C.muted)))))))).toList()),
      const SizedBox(height: 14),
      Row(children: [
        _actBtn('✓ إنشاء', C.green, Colors.white, () async { if (_newSchName.isNotEmpty) { await ApiService.post('admin.php?action=save_schedule', body: {'name': _newSchName, 'shiftId': _newSchShift, 'days': _newSchDays, 'empIds': []}); setState(() => _showAddSch = false); _loadData(); } }),
        const SizedBox(width: 8),
        _actBtn('إلغاء', C.white, C.sub, () => setState(() => _showAddSch = false), bd: C.border),
      ]),
    ]));

  // ═══ HOLIDAYS TAB ═══
  Widget _holidaysTab(List<Map<String, dynamic>> emps) {
    final holidays = _holidays;
    final gen = holidays.where((h) => h['type'] == 'عامة').toList();
    final cust = holidays.where((h) => h['type'] == 'مخصصة').toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Row(children: [_addBtnDash(Icons.add, 'إضافة إجازة', C.green, C.greenL, () => setState(() => _showAddHol = true)), const Spacer(), Text('إجازات عامة (للكل) أو مخصصة (لموظفين محددين)', style: GoogleFonts.tajawal(fontSize: 13, color: C.sub))]),
      const SizedBox(height: 20),
      Row(children: [
        _stat(Icons.check, C.greenL, C.green, 'إجازات عامة', '${gen.length}', '${gen.fold<int>(0, (a,h) => a + ((h['days'] ?? 0) is int ? (h['days'] ?? 0) as int : int.tryParse('${h['days']}') ?? 0))} يوم'),
        const SizedBox(width: 14),
        _stat(Icons.people, C.purpleL, C.purple, 'إجازات مخصصة', '${cust.length}', '${cust.fold<int>(0, (a,h) => a + ((h['days'] ?? 0) is int ? (h['days'] ?? 0) as int : int.tryParse('${h['days']}') ?? 0))} يوم'),
      ]),
      const SizedBox(height: 20),
      if (_showAddHol) _addHolForm(emps),
      for (var type in ['عامة','مخصصة']) ...[
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text('إجازات $type', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)), const SizedBox(width: 8), Container(width: 28, height: 28, decoration: BoxDecoration(color: type == 'عامة' ? C.greenL : C.purpleL, borderRadius: BorderRadius.circular(8)), child: Icon(type == 'عامة' ? Icons.check : Icons.people, size: 14, color: type == 'عامة' ? C.green : C.purple))]),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: holidays.where((h) => h['type'] == type).map((hol) => _holCard(hol, emps)).toList()),
        const SizedBox(height: 20),
      ],
    ]);
  }

  Widget _addHolForm(List<Map<String, dynamic>> emps) => Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.green, width: 2)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('إضافة إجازة جديدة', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
      const SizedBox(height: 14),
      Row(children: [
        SizedBox(width: 140, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('النوع', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.sub)), const SizedBox(height: 4), Container(padding: const EdgeInsets.symmetric(horizontal: 14), width: double.infinity, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: C.border)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _newHolType, isExpanded: true, style: GoogleFonts.tajawal(fontSize: 13, color: C.text), items: ['عامة','مخصصة'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() { _newHolType = v ?? 'عامة'; _holSelEmps.clear(); }))))])),
        const SizedBox(width: 12),
        SizedBox(width: 100, child: _field('عدد الأيام', '1', (v) => _newHolDays = int.tryParse(v) ?? 1)),
        const SizedBox(width: 12),
        SizedBox(width: 180, child: _field('التاريخ', '20 مارس 2026', (v) => _newHolDate = v)),
        const SizedBox(width: 12),
        Expanded(child: _field('اسم الإجازة', 'مثال: عيد الفطر', (v) => _newHolName = v)),
      ]),
      if (_newHolType == 'مخصصة') ...[
        const SizedBox(height: 14),
        Text('اختر الموظفين (${_holSelEmps.length} محدد)', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.sub)),
        const SizedBox(height: 8),
        ConstrainedBox(constraints: const BoxConstraints(maxHeight: 180), child: SingleChildScrollView(child: Wrap(spacing: 6, runSpacing: 6, children: emps.map((emp) {
          final sel = _holSelEmps.contains(emp['id']?.toString());
          return InkWell(onTap: () => setState(() => sel ? _holSelEmps.remove(emp['id']?.toString()) : _holSelEmps.add(emp['id']?.toString() ?? '')),
            child: Container(width: 200, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: sel ? C.purpleL : C.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: sel ? C.purple : C.border)),
              child: Row(children: [Checkbox(value: sel, activeColor: C.purple, onChanged: (_) => setState(() => sel ? _holSelEmps.remove(emp['id']?.toString()) : _holSelEmps.add(emp['id']?.toString() ?? '')), visualDensity: VisualDensity.compact), Expanded(child: Text(emp['name'] ?? '', textAlign: TextAlign.right, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.text)))])));
        }).toList()))),
      ],
      const SizedBox(height: 14),
      Row(children: [
        _actBtn('✓ إضافة الإجازة', C.green, Colors.white, () async { if (_newHolName.isNotEmpty && _newHolDate.isNotEmpty) { await ApiService.post('admin.php?action=save_holiday', body: {'name': _newHolName, 'date': _newHolDate, 'days': _newHolDays, 'type': _newHolType, 'empIds': _newHolType == 'مخصصة' ? _holSelEmps.toList() : []}); setState(() { _showAddHol = false; _holSelEmps.clear(); }); _loadData(); } }),
        const SizedBox(width: 8),
        _actBtn('إلغاء', C.white, C.sub, () => setState(() { _showAddHol = false; _holSelEmps.clear(); }), bd: C.border),
      ]),
    ]));

  Widget _holCard(Map<String, dynamic> hol, List<Map<String, dynamic>> emps) => Container(width: 340, padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Row(children: [
        InkWell(onTap: () async { await ApiService.post('admin.php?action=delete_holiday', body: {'id': hol['id']}); _loadData(); }, child: Container(width: 26, height: 26, decoration: BoxDecoration(color: C.redL, borderRadius: BorderRadius.circular(6), border: Border.all(color: C.redBd)), child: const Icon(Icons.delete, size: 11, color: C.red))),
        const SizedBox(width: 6),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: hol['type'] == 'عامة' ? C.greenL : C.purpleL, borderRadius: BorderRadius.circular(20)), child: Text('${hol['days']} يوم', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: hol['type'] == 'عامة' ? C.green : C.purple))),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(hol['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: C.text)), Text(hol['date'] ?? '', style: _mono(fontSize: 12, color: C.sub))]),
      ]),
      const SizedBox(height: 8),
      if (hol['type'] == 'عامة') Text('✓ تُطبق على جميع الموظفين', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.green)),
      if (hol['type'] == 'مخصصة') Wrap(spacing: 4, runSpacing: 4, alignment: WrapAlignment.end, children: ((hol['empIds'] as List?) ?? []).map((eid) {
        final emp = emps.firstWhere((e) => e['id']?.toString() == eid?.toString(), orElse: () => {'name': '—'});
        return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: C.purpleL, borderRadius: BorderRadius.circular(6)),
          child: Text((emp['name'] ?? '—').toString().split(' ').take(2).join(' '), style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: C.purple)));
      }).toList()),
    ]));

  // ═══ Shared widgets ═══
  Widget _empRow(Map<String, dynamic> emp, bool isAdd, Color c, VoidCallback onTap) {
    final av = (emp['name'] ?? '').toString().length >= 2 ? emp['name'].toString().substring(0,2) : 'م';
    return Container(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.div))),
      child: Row(children: [InkWell(onTap: onTap, child: Container(width: 28, height: 28, decoration: BoxDecoration(color: isAdd ? C.greenL : C.redL, borderRadius: BorderRadius.circular(7), border: Border.all(color: isAdd ? C.greenBd : C.redBd)), child: Icon(isAdd ? Icons.add : Icons.close, size: 12, color: isAdd ? C.green : C.red))), const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(emp['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.text)), Text(emp['dept'] ?? '', style: GoogleFonts.tajawal(fontSize: 10, color: C.muted))]),
        const SizedBox(width: 8), Container(width: 28, height: 28, decoration: BoxDecoration(color: c.withOpacity(0.08), shape: BoxShape.circle), child: Center(child: Text(av, style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w700, color: c))))]));
  }

  Widget _tabBtn(String l, String k) => InkWell(onTap: () => setState(() => _tab = k), child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), decoration: BoxDecoration(color: _tab == k ? C.white : Colors.transparent, borderRadius: BorderRadius.circular(9)), child: Text(l, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600, color: _tab == k ? C.pri : C.sub))));
  Widget _saveBtn() => InkWell(onTap: () { setState(() => _saved = true); Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _saved = false); }); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10), decoration: BoxDecoration(color: _saved ? C.green : C.pri, borderRadius: BorderRadius.circular(10)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(_saved ? Icons.check : Icons.save, size: 16, color: Colors.white), const SizedBox(width: 6), Text(_saved ? 'تم الحفظ' : 'حفظ', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))])));
  Widget _addBtnDash(IconData i, String l, Color c, Color bg, VoidCallback onTap) => InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: c)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(i, size: 14, color: c), const SizedBox(width: 6), Text(l, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: c))])));
  Widget _actBtn(String l, Color bg, Color fg, VoidCallback onTap, {Color? bd}) => InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: bd != null ? Border.all(color: bd) : null), child: Text(l, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600, color: fg))));
  Widget _stat(IconData i, Color bg, Color c, String l, String v, String sub) => Expanded(child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)), child: Icon(i, size: 22, color: c)), const SizedBox(height: 14), Text(v, style: GoogleFonts.tajawal(fontSize: 28, fontWeight: FontWeight.w800, color: C.text)), Text(l, style: GoogleFonts.tajawal(fontSize: 13, color: C.sub)), Text(sub, style: GoogleFonts.tajawal(fontSize: 11, color: C.muted))])));
  Widget _field(String label, String hint, ValueChanged<String> cb) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(label, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.sub)), const SizedBox(height: 4), TextField(onChanged: cb, textAlign: TextAlign.right, style: GoogleFonts.tajawal(fontSize: 13), decoration: InputDecoration(hintText: hint, hintStyle: GoogleFonts.tajawal(color: C.hint, fontSize: 13), filled: true, fillColor: C.white, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: C.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: C.border))))]);
}
