import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

class AdminSchedules extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminSchedules({super.key, required this.user});
  @override State<AdminSchedules> createState() => _AdminSchedulesState();
}

class _AdminSchedulesState extends State<AdminSchedules> {
  String _tab = 'schedules';
  bool _saved = false;
  bool _loading = true;
  final _mono = GoogleFonts.ibmPlexMono;
  final _allDays = ['أحد','إثنين','ثلاثاء','أربعاء','خميس','جمعة','سبت'];
  String? _selSchId;

  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _holidays = [];
  List<Map<String, dynamic>> _emps = [];

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
    {'id': 1, 'name': 'الفترة الأولى', 'start': '08:00 ص', 'end': '04:00 م', 'color': W.pri},
    {'id': 2, 'name': 'الفترة الثانية', 'start': '01:00 م', 'end': '09:00 م', 'color': W.purple},
    {'id': 3, 'name': 'الفترة الثالثة', 'start': '04:00 م', 'end': '12:00 ص', 'color': W.teal},
  ];

  @override
  void initState() { super.initState(); _loadAll(); }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<Map<String, dynamic>>([
        ApiService.get('admin.php?action=get_schedules'),
        ApiService.get('admin.php?action=get_holidays'),
        ApiService.get('users.php?action=list'),
      ]);
      if (mounted) {
        final schRes = results[0];
        final holRes = results[1];
        final usrRes = results[2];
        setState(() {
          if (schRes['success'] == true) {
            _schedules = (schRes['schedules'] as List? ?? []).cast<Map<String, dynamic>>();
            if (_schedules.isNotEmpty && _selSchId == null) {
              _selSchId = _schedules.first['id']?.toString();
            }
          }
          if (holRes['success'] == true) {
            _holidays = (holRes['holidays'] as List? ?? []).cast<Map<String, dynamic>>();
          }
          if (usrRes['success'] == true) {
            _emps = (usrRes['users'] as List? ?? []).cast<Map<String, dynamic>>();
            _emps.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 500;
    final isWide = screenW > 800;

    return SingleChildScrollView(padding: EdgeInsets.all(isWide ? 28 : 14), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Align(alignment: Alignment.centerLeft, child: _saveBtn()),
      const SizedBox(height: 14),
      Container(padding: EdgeInsets.all(4), decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [_tabBtn('الجداول', 'schedules'), _tabBtn('الإجازات', 'holidays')])),
      const SizedBox(height: 24),
      if (_tab == 'schedules') _schedulesTab(_emps, isMobile, isWide),
      if (_tab == 'holidays') _holidaysTab(_emps, isMobile, isWide),
    ]));
  }

  // ═══ SCHEDULES TAB ═══
  Widget _schedulesTab(List<Map<String, dynamic>> emps, bool isMobile, bool isWide) {
    if (_schedules.isNotEmpty && _selSchId == null) _selSchId = _schedules.first['id']?.toString();
    final activeSch = _schedules.firstWhere((s) => s['id']?.toString() == _selSchId, orElse: () => _schedules.isNotEmpty ? _schedules.first : {});
    if (activeSch.isEmpty) return const SizedBox();
    final activeShId = (activeSch['shiftId'] is int) ? activeSch['shiftId'] : int.tryParse('${activeSch['shiftId']}') ?? 1;
    final shift = _shifts.firstWhere((s) => s['id'] == activeShId, orElse: () => _shifts.first);
    final schColor = shift['color'] as Color;
    final schEmpIds = List<String>.from(activeSch['empIds'] ?? []);
    final schEmps = emps.where((e) => schEmpIds.contains((e['uid'] ?? e['id'])?.toString())).toList();
    final availEmps = emps.where((e) => !schEmpIds.contains((e['uid'] ?? e['id'])?.toString())).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      // Header row - wrap on mobile
      isMobile
        ? Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('كل جدول مربوط بفترة عمل — حدد الأيام والموظفين', style: GoogleFonts.tajawal(fontSize: 12, color: W.sub)),
            const SizedBox(height: 8),
            _addBtnDash(Icons.add, 'جدول جديد', W.pri, W.priLight, () => setState(() => _showAddSch = true)),
          ])
        : Row(children: [
            _addBtnDash(Icons.add, 'جدول جديد', W.pri, W.priLight, () => setState(() => _showAddSch = true)),
            const Spacer(),
            Flexible(child: Text('كل جدول مربوط بفترة عمل — حدد الأيام والموظفين', style: GoogleFonts.tajawal(fontSize: 13, color: W.sub))),
          ]),
      const SizedBox(height: 16),
      if (_showAddSch) _addSchForm(isMobile),
      SizedBox(height: 160, child: ListView.builder(
        scrollDirection: Axis.horizontal, reverse: true,
        itemCount: _schedules.length,
        itemBuilder: (ctx, i) {
          final sch = _schedules[i];
          final shId = (sch['shiftId'] is int) ? sch['shiftId'] : int.tryParse('${sch['shiftId']}') ?? 1;
          final sh = _shifts.firstWhere((s) => s['id'] == shId, orElse: () => _shifts.first);
          final isSel = _selSchId == sch['id']?.toString();
          final c = sh['color'] as Color;
          final days = List<String>.from(sch['days'] ?? []);
          return Padding(padding: const EdgeInsets.only(left: 10), child: InkWell(onTap: () => setState(() => _selSchId = sch['id']?.toString()),
            child: Container(width: isMobile ? (MediaQuery.of(context).size.width * 0.65).clamp(200.0, 260.0) : 260, padding: EdgeInsets.all(isMobile ? 10 : 14), decoration: BoxDecoration(color: isSel ? c.withOpacity(0.04) : W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: isSel ? c : W.border, width: isSel ? 2 : 1)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                // Name and shift - full width for name
                Row(children: [
                  InkWell(onTap: () async {
                    await ApiService.post('admin.php?action=delete_schedule', {'id': sch['id']});
                    _loadAll();
                  }, child: Container(width: 24, height: 24, decoration: BoxDecoration(color: W.redL, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.redBd)), child: Icon(Icons.delete, size: 11, color: W.red))),
                  const SizedBox(width: 4),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: W.div, borderRadius: BorderRadius.circular(6)), child: Text('${(sch['empIds'] as List?)?.length ?? 0} موظف', style: GoogleFonts.tajawal(fontSize: 10, color: W.muted))),
                  const Spacer(),
                  Flexible(child: Text(sch['name'] ?? '', style: GoogleFonts.tajawal(fontSize: isMobile ? 12 : 13, fontWeight: FontWeight.w700, color: W.text), textAlign: TextAlign.right)),
                ]),
                const SizedBox(height: 4),
                Text('${sh['name']}', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: c)),
                Text('(${sh['start']} — ${sh['end']})', style: _mono(fontSize: 10, color: W.muted)),
                const Spacer(),
                Row(children: _allDays.map((d) => Expanded(child: Container(height: 22, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: BoxDecoration(color: days.contains(d) ? c.withOpacity(0.12) : W.div, borderRadius: BorderRadius.circular(5)), child: Center(child: Text(d.substring(0,2), style: GoogleFonts.tajawal(fontSize: 8, fontWeight: FontWeight.w600, color: days.contains(d) ? c : W.hint)))))).toList()),
              ]))));
        },
      )),
      const SizedBox(height: 24),
      // Employee assignment - stack on mobile
      if (isMobile)
        Column(children: [
          // Assigned employees first on mobile
          Container(decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: schColor.withOpacity(0.4))),
            child: Column(children: [
              Container(padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: schColor.withOpacity(0.03), border: Border(bottom: BorderSide(color: W.div))),
                child: Row(children: [Text('${schEmps.length} موظف', style: GoogleFonts.tajawal(fontSize: 12, color: W.muted)), Spacer(), Flexible(child: Text('موظفين "${activeSch['name']}"', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: W.text)))])),
              if (schEmps.isEmpty) Padding(padding: EdgeInsets.all(20), child: Text('لا يوجد موظفين — أضف من القائمة', style: GoogleFonts.tajawal(fontSize: 12, color: W.muted))),
              ...schEmps.map((emp) => _empRow(emp, false, schColor, () async {
                final uid = (emp['uid'] ?? emp['id'])?.toString() ?? '';
                final newIds = schEmpIds.where((id) => id != uid).toList();
                await ApiService.post('admin.php?action=save_schedule', {
                  ...activeSch,
                  'empIds': newIds,
                });
                _loadAll();
              })),
            ])),
          const SizedBox(height: 14),
          // Available employees
          Container(decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: schColor)),
            child: Column(children: [
              Container(padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: W.div))),
                child: Row(children: [Text('${availEmps.length} متاح', style: GoogleFonts.tajawal(fontSize: 12, color: W.muted)), Spacer(), Text('إضافة موظفين', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: W.text))])),
              ConstrainedBox(constraints: const BoxConstraints(maxHeight: 250), child: ListView(shrinkWrap: true, children: availEmps.map((emp) => _empRow(emp, true, schColor, () async {
                final uid = (emp['uid'] ?? emp['id'])?.toString() ?? '';
                final newIds = [...schEmpIds, uid];
                await ApiService.post('admin.php?action=save_schedule', {
                  ...activeSch,
                  'empIds': newIds,
                });
                _loadAll();
              })).toList())),
            ])),
        ])
      else
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Container(decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: schColor)),
            child: Column(children: [
              Container(padding: EdgeInsets.symmetric(horizontal: 22, vertical: 14), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: W.div))),
                child: Row(children: [Text('${availEmps.length} متاح', style: GoogleFonts.tajawal(fontSize: 12, color: W.muted)), Spacer(), Text('إضافة موظفين ←', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: W.text))])),
              ConstrainedBox(constraints: const BoxConstraints(maxHeight: 350), child: ListView(shrinkWrap: true, children: availEmps.map((emp) => _empRow(emp, true, schColor, () async {
                final uid = (emp['uid'] ?? emp['id'])?.toString() ?? '';
                final newIds = [...schEmpIds, uid];
                await ApiService.post('admin.php?action=save_schedule', {
                  ...activeSch,
                  'empIds': newIds,
                });
                _loadAll();
              })).toList())),
            ]))),
          const SizedBox(width: 20),
          Expanded(child: Container(decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: schColor.withOpacity(0.4))),
            child: Column(children: [
              Container(padding: EdgeInsets.symmetric(horizontal: 22, vertical: 14), decoration: BoxDecoration(color: schColor.withOpacity(0.03), border: Border(bottom: BorderSide(color: W.div))),
                child: Row(children: [Text('${schEmps.length} موظف', style: GoogleFonts.tajawal(fontSize: 12, color: W.muted)), Spacer(), Flexible(child: Text('موظفين "${activeSch['name']}"', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: W.text)))])),
              if (schEmps.isEmpty) Padding(padding: EdgeInsets.all(30), child: Text('لا يوجد موظفين — أضف من القائمة', style: GoogleFonts.tajawal(fontSize: 12, color: W.muted))),
              ...schEmps.map((emp) => _empRow(emp, false, schColor, () async {
                final uid = (emp['uid'] ?? emp['id'])?.toString() ?? '';
                final newIds = schEmpIds.where((id) => id != uid).toList();
                await ApiService.post('admin.php?action=save_schedule', {
                  ...activeSch,
                  'empIds': newIds,
                });
                _loadAll();
              })),
            ]))),
        ]),
    ]);
  }

  Widget _addSchForm(bool isMobile) => Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 16), padding: EdgeInsets.all(isMobile ? 14 : 22),
    decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.pri, width: 2)),
    child: Column(children: [
      if (isMobile) ...[
        // Stack fields vertically on mobile
        _field('اسم الجدول', 'مثال: جدول رمضان', (v) => _newSchName = v),
        const SizedBox(height: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('الفترة المرتبطة', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub)),
          const SizedBox(height: 4),
          Container(padding: EdgeInsets.symmetric(horizontal: 14), width: double.infinity, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: W.border)),
            child: DropdownButtonHideUnderline(child: DropdownButton<int>(value: _newSchShift, isExpanded: true, style: GoogleFonts.tajawal(fontSize: 12, color: W.text),
              items: _shifts.map((s) => DropdownMenuItem(value: s['id'] as int, child: Text('${s['name']}', overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => setState(() => _newSchShift = v ?? 1)))),
        ]),
      ] else
        Row(children: [
          Expanded(child: _field('اسم الجدول', 'مثال: جدول رمضان', (v) => _newSchName = v)),
          const SizedBox(width: 14),
          SizedBox(width: 250, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('الفترة المرتبطة', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub)),
            const SizedBox(height: 4),
            Container(padding: EdgeInsets.symmetric(horizontal: 14), width: double.infinity, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: W.border)),
              child: DropdownButtonHideUnderline(child: DropdownButton<int>(value: _newSchShift, isExpanded: true, style: GoogleFonts.tajawal(fontSize: 13, color: W.text),
                items: _shifts.map((s) => DropdownMenuItem(value: s['id'] as int, child: Text('${s['name']} (${s['start']} — ${s['end']})'))).toList(), onChanged: (v) => setState(() => _newSchShift = v ?? 1)))),
          ])),
        ]),
      const SizedBox(height: 14),
      Align(alignment: Alignment.centerRight, child: Text('أيام العمل', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub))),
      const SizedBox(height: 6),
      Row(children: _allDays.map((d) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: InkWell(onTap: () => setState(() => _newSchDays.contains(d) ? _newSchDays.remove(d) : _newSchDays.add(d)),
        child: Container(padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 8), decoration: BoxDecoration(color: _newSchDays.contains(d) ? W.priLight : W.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: _newSchDays.contains(d) ? W.pri : W.border, width: _newSchDays.contains(d) ? 2 : 1)),
          child: Center(child: Text(isMobile ? d.substring(0, 2) : d, style: GoogleFonts.tajawal(fontSize: isMobile ? 10 : 12, fontWeight: FontWeight.w600, color: _newSchDays.contains(d) ? W.pri : W.muted)))))))).toList()),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _actBtn('✓ إنشاء', W.green, Colors.white, () async {
          if (_newSchName.isNotEmpty) {
            await ApiService.post('admin.php?action=save_schedule', {'name': _newSchName, 'shiftId': _newSchShift, 'days': _newSchDays, 'empIds': []});
            setState(() => _showAddSch = false);
            _loadAll();
          }
        }),
        _actBtn('إلغاء', W.white, W.sub, () => setState(() => _showAddSch = false), bd: W.border),
      ]),
    ]));

  // ═══ HOLIDAYS TAB ═══
  Widget _holidaysTab(List<Map<String, dynamic>> emps, bool isMobile, bool isWide) {
    final gen = _holidays.where((h) => h['type'] == 'عامة').toList();
    final cust = _holidays.where((h) => h['type'] == 'مخصصة').toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      // Header - wrap on mobile
      isMobile
        ? Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('إجازات عامة (للكل) أو مخصصة (لموظفين محددين)', style: GoogleFonts.tajawal(fontSize: 12, color: W.sub)),
            const SizedBox(height: 8),
            _addBtnDash(Icons.add, 'إضافة إجازة', W.green, W.greenL, () => setState(() => _showAddHol = true)),
          ])
        : Row(children: [
            _addBtnDash(Icons.add, 'إضافة إجازة', W.green, W.greenL, () => setState(() => _showAddHol = true)),
            const Spacer(),
            Flexible(child: Text('إجازات عامة (للكل) أو مخصصة (لموظفين محددين)', style: GoogleFonts.tajawal(fontSize: 13, color: W.sub))),
          ]),
      const SizedBox(height: 20),
      Row(children: [
        _statCard(Icons.check, W.greenL, W.green, isMobile ? 'عامة' : 'إجازات عامة', '${gen.length}', '${gen.fold<int>(0, (a,h) => a + ((h['days'] is int ? h['days'] : int.tryParse('${h['days']}') ?? 0) as int))} يوم', isMobile),
        SizedBox(width: isMobile ? 8 : 14),
        _statCard(Icons.people, W.purpleL, W.purple, isMobile ? 'مخصصة' : 'إجازات مخصصة', '${cust.length}', '${cust.fold<int>(0, (a,h) => a + ((h['days'] is int ? h['days'] : int.tryParse('${h['days']}') ?? 0) as int))} يوم', isMobile),
      ]),
      const SizedBox(height: 20),
      if (_showAddHol) _addHolForm(emps, isMobile),
      for (var type in ['عامة','مخصصة']) ...[
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Flexible(child: Text('إجازات $type', style: GoogleFonts.tajawal(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w700, color: W.text))),
          SizedBox(width: 8),
          Container(width: isMobile ? 24 : 28, height: isMobile ? 24 : 28, decoration: BoxDecoration(color: type == 'عامة' ? W.greenL : W.purpleL, borderRadius: BorderRadius.circular(7)), child: Icon(type == 'عامة' ? Icons.check : Icons.people, size: isMobile ? 12 : 14, color: type == 'عامة' ? W.green : W.purple)),
        ]),
        const SizedBox(height: 12),
        // Holiday cards - use Wrap with responsive width
        Wrap(spacing: 12, runSpacing: 12, children: _holidays.where((h) => h['type'] == type).map((hol) => _holCard(hol, emps, isMobile)).toList()),
        const SizedBox(height: 20),
      ],
    ]);
  }

  Widget _addHolForm(List<Map<String, dynamic>> emps, bool isMobile) => Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 16), padding: EdgeInsets.all(isMobile ? 14 : 22),
    decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.green, width: 2)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('إضافة إجازة جديدة', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: W.text)),
      const SizedBox(height: 14),
      if (isMobile) ...[
        // Stack fields vertically on mobile
        _field('اسم الإجازة', 'مثال: عيد الفطر', (v) => _newHolName = v),
        const SizedBox(height: 10),
        _field('التاريخ', '20 مارس 2026', (v) => _newHolDate = v),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('النوع', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub)),
            SizedBox(height: 4),
            Container(padding: EdgeInsets.symmetric(horizontal: 14), width: double.infinity, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: W.border)),
              child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _newHolType, isExpanded: true, style: GoogleFonts.tajawal(fontSize: 13, color: W.text),
                items: ['عامة','مخصصة'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() { _newHolType = v ?? 'عامة'; _holSelEmps.clear(); })))),
          ])),
          const SizedBox(width: 10),
          SizedBox(width: 90, child: _field('عدد الأيام', '1', (v) => _newHolDays = int.tryParse(v) ?? 1)),
        ]),
      ] else
        Row(children: [
          SizedBox(width: 140, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('النوع', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub)), SizedBox(height: 4), Container(padding: EdgeInsets.symmetric(horizontal: 14), width: double.infinity, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: W.border)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _newHolType, isExpanded: true, style: GoogleFonts.tajawal(fontSize: 13, color: W.text), items: ['عامة','مخصصة'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() { _newHolType = v ?? 'عامة'; _holSelEmps.clear(); }))))])),
          const SizedBox(width: 12),
          SizedBox(width: 100, child: _field('عدد الأيام', '1', (v) => _newHolDays = int.tryParse(v) ?? 1)),
          const SizedBox(width: 12),
          SizedBox(width: 180, child: _field('التاريخ', '20 مارس 2026', (v) => _newHolDate = v)),
          const SizedBox(width: 12),
          Expanded(child: _field('اسم الإجازة', 'مثال: عيد الفطر', (v) => _newHolName = v)),
        ]),
      if (_newHolType == 'مخصصة') ...[
        const SizedBox(height: 14),
        Text('اختر الموظفين (${_holSelEmps.length} محدد)', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub)),
        const SizedBox(height: 8),
        ConstrainedBox(constraints: const BoxConstraints(maxHeight: 180), child: SingleChildScrollView(child: Wrap(spacing: 6, runSpacing: 6, children: emps.map((emp) {
          final uid = (emp['uid'] ?? emp['id'])?.toString() ?? '';
          final sel = _holSelEmps.contains(uid);
          final chipW = isMobile ? ((MediaQuery.of(context).size.width - 28 - 6) / 2).clamp(140.0, 200.0) : 200.0;
          return InkWell(onTap: () => setState(() => sel ? _holSelEmps.remove(uid) : _holSelEmps.add(uid)),
            child: Container(width: chipW, padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 12, vertical: 8), decoration: BoxDecoration(color: sel ? W.purpleL : W.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: sel ? W.purple : W.border)),
              child: Row(children: [SizedBox(width: 24, height: 24, child: Checkbox(value: sel, activeColor: W.purple, onChanged: (_) => setState(() => sel ? _holSelEmps.remove(uid) : _holSelEmps.add(uid)), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)), const SizedBox(width: 4), Expanded(child: Text(emp['name'] ?? '', textAlign: TextAlign.right, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.text)))])));
        }).toList()))),
      ],
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _actBtn('✓ إضافة الإجازة', W.green, Colors.white, () async {
          if (_newHolName.isNotEmpty && _newHolDate.isNotEmpty) {
            await ApiService.post('admin.php?action=save_holiday', {'name': _newHolName, 'date': _newHolDate, 'days': _newHolDays, 'type': _newHolType, 'empIds': _newHolType == 'مخصصة' ? _holSelEmps.toList() : []});
            setState(() { _showAddHol = false; _holSelEmps.clear(); });
            _loadAll();
          }
        }),
        _actBtn('إلغاء', W.white, W.sub, () => setState(() { _showAddHol = false; _holSelEmps.clear(); }), bd: W.border),
      ]),
    ]));

  Widget _holCard(Map<String, dynamic> hol, List<Map<String, dynamic>> emps, bool isMobile) {
    final screenW = MediaQuery.of(context).size.width;
    final cardW = isMobile ? (screenW - 28.0) : 340.0; // full width on mobile minus padding

    return Container(width: cardW, padding: EdgeInsets.all(isMobile ? 12 : 18),
      decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        // Header row: name + date on right, badges on left
        Row(children: [
          InkWell(onTap: () async {
            await ApiService.post('admin.php?action=delete_holiday', {'id': hol['id']});
            _loadAll();
          }, child: Container(width: 24, height: 24, decoration: BoxDecoration(color: W.redL, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.redBd)), child: Icon(Icons.delete, size: 11, color: W.red))),
          const SizedBox(width: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: hol['type'] == 'عامة' ? W.greenL : W.purpleL, borderRadius: BorderRadius.circular(20)), child: Text('${hol['days']} يوم', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: hol['type'] == 'عامة' ? W.green : W.purple))),
          const Spacer(),
          Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(hol['name'] ?? '', style: GoogleFonts.tajawal(fontSize: isMobile ? 13 : 15, fontWeight: FontWeight.w700, color: W.text)),
            Text(hol['date'] ?? '', style: _mono(fontSize: 11, color: W.sub)),
          ])),
        ]),
        const SizedBox(height: 8),
        if (hol['type'] == 'عامة') Text('تُطبق على جميع الموظفين', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.green)),
        if (hol['type'] == 'مخصصة') Wrap(spacing: 4, runSpacing: 4, alignment: WrapAlignment.end, children: ((hol['empIds'] as List?) ?? []).map((eid) {
          final emp = emps.firstWhere((e) => (e['uid'] ?? e['id'])?.toString() == eid?.toString(), orElse: () => {'name': '—'});
          return Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: W.purpleL, borderRadius: BorderRadius.circular(6)),
            child: Text((emp['name'] ?? '—').toString().split(' ').take(2).join(' '), style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: W.purple)));
        }).toList()),
      ]));
  }

  // ═══ Shared widgets ═══
  Widget _empRow(Map<String, dynamic> emp, bool isAdd, Color c, VoidCallback onTap) {
    final av = (emp['name'] ?? '').toString().length >= 2 ? emp['name'].toString().substring(0,2) : 'م';
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: W.div))),
      child: Row(children: [
        InkWell(onTap: onTap, child: Container(width: 26, height: 26, decoration: BoxDecoration(color: isAdd ? W.greenL : W.redL, borderRadius: BorderRadius.circular(7), border: Border.all(color: isAdd ? W.greenBd : W.redBd)), child: Icon(isAdd ? Icons.add : Icons.close, size: 12, color: isAdd ? W.green : W.red))),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(emp['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.text)),
          if ((emp['dept'] ?? '').toString().isNotEmpty)
            Text(emp['dept'] ?? '', style: GoogleFonts.tajawal(fontSize: 10, color: W.muted), overflow: TextOverflow.ellipsis),
        ])),
        const SizedBox(width: 8),
        Container(width: 26, height: 26, decoration: BoxDecoration(color: c.withOpacity(0.08), shape: BoxShape.circle), child: Center(child: Text(av, style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w700, color: c)))),
      ]));
  }

  Widget _tabBtn(String l, String k) => InkWell(onTap: () => setState(() => _tab = k), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: _tab == k ? W.white : Colors.transparent, borderRadius: BorderRadius.circular(9)), child: Text(l, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: _tab == k ? W.pri : W.sub))));
  Widget _saveBtn() => InkWell(onTap: () { setState(() => _saved = true); Future.delayed(Duration(seconds: 2), () { if (mounted) setState(() => _saved = false); }); }, child: Container(padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10), decoration: BoxDecoration(color: _saved ? W.green : W.pri, borderRadius: BorderRadius.circular(6)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(_saved ? Icons.check : Icons.save, size: 16, color: Colors.white), SizedBox(width: 6), Text(_saved ? 'تم الحفظ' : 'حفظ', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))])));
  Widget _addBtnDash(IconData i, String l, Color c, Color bg, VoidCallback onTap) => InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: c)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(i, size: 14, color: c), const SizedBox(width: 6), Text(l, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: c))])));
  Widget _actBtn(String l, Color bg, Color fg, VoidCallback onTap, {Color? bd}) => InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4), border: bd != null ? Border.all(color: bd) : null), child: Text(l, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600, color: fg))));
  Widget _statCard(IconData i, Color bg, Color c, String l, String v, String sub, bool isMobile) => Expanded(child: Container(padding: EdgeInsets.all(isMobile ? 14 : 20), decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Container(width: isMobile ? 32 : 44, height: isMobile ? 32 : 44, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)), child: Icon(i, size: isMobile ? 16 : 22, color: c)), SizedBox(height: isMobile ? 8 : 14), Text(v, style: GoogleFonts.tajawal(fontSize: isMobile ? 22 : 28, fontWeight: FontWeight.w800, color: W.text)), Text(l, style: GoogleFonts.tajawal(fontSize: isMobile ? 11 : 13, color: W.sub)), Text(sub, style: GoogleFonts.tajawal(fontSize: 11, color: W.muted))])));
  Widget _field(String label, String hint, ValueChanged<String> cb) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(label, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub)), SizedBox(height: 4), TextField(onChanged: cb, textAlign: TextAlign.right, style: GoogleFonts.tajawal(fontSize: 13), decoration: InputDecoration(hintText: hint, hintStyle: GoogleFonts.tajawal(color: W.hint, fontSize: 13), filled: true, fillColor: W.white, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.border))))]);
}
