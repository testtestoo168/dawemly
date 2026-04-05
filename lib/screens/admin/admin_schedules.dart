import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

class AdminSchedules extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminSchedules({super.key, required this.user});
  @override
  State<AdminSchedules> createState() => _AdminSchedulesState();
}

class _AdminSchedulesState extends State<AdminSchedules> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _loading = true;

  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _holidays = [];
  List<Map<String, dynamic>> _emps = [];

  String? _selSchId;
  String? _editSchId;
  String _empSearch = '';

  // Schedule form state
  String _schName = '';
  int _schShift = 1;
  List<String> _schDays = ['أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس'];

  // Holiday form state
  String _holName = '';
  String _holDate = '';
  String _holType = 'عامة';
  int _holDayCount = 1;
  final Set<String> _holEmpIds = {};

  static const _allDays = ['أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];

  List<Map<String, dynamic>> get _shifts => [
    {'id': 1, 'name': 'الفترة الأولى', 'start': '08:00 ص', 'end': '04:00 م', 'color': W.pri},
    {'id': 2, 'name': 'الفترة الثانية', 'start': '01:00 م', 'end': '09:00 م', 'color': W.purple},
    {'id': 3, 'name': 'الفترة الثالثة', 'start': '04:00 م', 'end': '12:00 ص', 'color': W.teal},
  ];

  TextStyle _mono({double fontSize = 12, FontWeight fontWeight = FontWeight.w400, Color? color}) =>
      GoogleFonts.ibmPlexMono(fontSize: fontSize, fontWeight: fontWeight, color: color ?? W.sub);

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final res = await Future.wait([
      ApiService.get('admin.php?action=get_schedules'),
      ApiService.get('admin.php?action=get_holidays'),
      ApiService.get('users.php?action=list'),
    ]);
    if (!mounted) return;
    setState(() {
      if (res[0]['success'] == true) {
        _schedules = (res[0]['schedules'] as List? ?? []).cast<Map<String, dynamic>>();
      }
      if (res[1]['success'] == true) {
        _holidays = (res[1]['holidays'] as List? ?? []).cast<Map<String, dynamic>>();
      }
      if (res[2]['success'] == true) {
        _emps = (res[2]['users'] as List? ?? []).cast<Map<String, dynamic>>();
        _emps.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
      }
      if (_schedules.isNotEmpty && _selSchId == null) {
        _selSchId = _schedules.first['id']?.toString();
      }
      _loading = false;
    });
  }

  // ───────────────── Helpers ─────────────────

  Map<String, dynamic> _shiftFor(dynamic shiftId) {
    final id = shiftId is int ? shiftId : int.tryParse('$shiftId') ?? 1;
    return _shifts.firstWhere((s) => s['id'] == id, orElse: () => _shifts.first);
  }

  List<String> _empIdsOf(Map<String, dynamic> sch) => List<String>.from(sch['empIds'] ?? []);

  String _uidOf(Map<String, dynamic> emp) => (emp['uid'] ?? emp['id'])?.toString() ?? '';

  void _resetSchForm([Map<String, dynamic>? sch]) {
    _schName = sch?['name']?.toString() ?? '';
    _schShift = (sch?['shiftId'] is int ? sch!['shiftId'] : int.tryParse('${sch?['shiftId']}')) ?? 1;
    _schDays = sch != null ? List<String>.from(sch['days'] ?? []) : ['أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس'];
  }

  void _resetHolForm() {
    _holName = '';
    _holDate = '';
    _holType = 'عامة';
    _holDayCount = 1;
    _holEmpIds.clear();
  }

  Future<void> _saveSchedule() async {
    if (_schName.trim().isEmpty) return;
    final payload = <String, dynamic>{
      'name': _schName.trim(),
      'shiftId': _schShift,
      'days': _schDays,
    };
    if (_editSchId != null) {
      payload['id'] = _editSchId;
      final existing = _schedules.firstWhere((s) => s['id']?.toString() == _editSchId, orElse: () => {});
      payload['empIds'] = existing['empIds'] ?? [];
    } else {
      payload['empIds'] = [];
    }
    await ApiService.post('admin.php?action=save_schedule', payload);
    _editSchId = null;
    _resetSchForm();
    _loadAll();
  }

  Future<void> _deleteSchedule(dynamic id) async {
    await ApiService.post('admin.php?action=delete_schedule', {'id': id});
    if (_selSchId == id?.toString()) _selSchId = null;
    _loadAll();
  }

  Future<void> _toggleEmp(Map<String, dynamic> sch, String uid, bool add) async {
    final ids = _empIdsOf(sch);
    final newIds = add ? [...ids, uid] : ids.where((id) => id != uid).toList();
    await ApiService.post('admin.php?action=save_schedule', {...sch, 'empIds': newIds});
    _loadAll();
  }

  Future<void> _saveHoliday() async {
    if (_holName.trim().isEmpty || _holDate.trim().isEmpty) return;
    await ApiService.post('admin.php?action=save_holiday', {
      'name': _holName.trim(),
      'date': _holDate.trim(),
      'days': _holDayCount,
      'type': _holType,
      'empIds': _holType == 'مخصصة' ? _holEmpIds.toList() : [],
    });
    _resetHolForm();
    _loadAll();
  }

  Future<void> _deleteHoliday(dynamic id) async {
    await ApiService.post('admin.php?action=delete_holiday', {'id': id});
    _loadAll();
  }

  // ───────────────── Build ─────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 500;
    final isWide = w > 800;

    return Column(children: [
      // Tab bar
      Container(
        margin: EdgeInsets.fromLTRB(isWide ? 28 : 14, isWide ? 20 : 10, isWide ? 28 : 14, 0),
        decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: W.border)),
        child: TabBar(
          controller: _tabCtrl,
          labelStyle: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w500),
          labelColor: W.pri,
          unselectedLabelColor: W.sub,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(7)),
          indicatorPadding: const EdgeInsets.all(3),
          dividerColor: Colors.transparent,
          tabs: const [Tab(text: 'الجداول'), Tab(text: 'الإجازات')],
        ),
      ),
      const SizedBox(height: 8),
      // Tab content
      Expanded(
        child: TabBarView(controller: _tabCtrl, children: [
          _buildSchedulesTab(isMobile, isWide),
          _buildHolidaysTab(isMobile, isWide),
        ]),
      ),
    ]);
  }

  // ═══════════════════════════════════════════
  //           SCHEDULES TAB
  // ═══════════════════════════════════════════

  Widget _buildSchedulesTab(bool isMobile, bool isWide) {
    if (isWide) return _wideSchedules();
    return _mobileSchedules(isMobile);
  }

  // ── Wide: left form (1/3) + right grid & employees (2/3) ──
  Widget _wideSchedules() {
    final activeSch = _schedules.firstWhere(
      (s) => s['id']?.toString() == _selSchId,
      orElse: () => _schedules.isNotEmpty ? _schedules.first : {},
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // RIGHT 2/3: grid + employees
        Expanded(flex: 2, child: Column(children: [
          _scheduleGrid(),
          if (activeSch.isNotEmpty) ...[
            const SizedBox(height: 20),
            _employeePanel(activeSch),
          ],
        ])),
        const SizedBox(width: 20),
        // LEFT 1/3: form
        Expanded(flex: 1, child: _scheduleForm(false)),
      ]),
    );
  }

  // ── Mobile: card list + FAB ──
  Widget _mobileSchedules(bool isMobile) {
    return Stack(children: [
      ListView(padding: EdgeInsets.all(isMobile ? 14 : 18), children: [
        ..._schedules.map((sch) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _scheduleCard(sch, isMobile),
        )),
        if (_selSchId != null) ...[
          const SizedBox(height: 8),
          Builder(builder: (_) {
            final sch = _schedules.firstWhere(
              (s) => s['id']?.toString() == _selSchId,
              orElse: () => {},
            );
            return sch.isNotEmpty ? _employeePanel(sch) : const SizedBox();
          }),
        ],
        const SizedBox(height: 80),
      ]),
      Positioned(
        left: 16,
        bottom: 16,
        child: FloatingActionButton(
          backgroundColor: W.pri,
          child: const Icon(Icons.add, color: Colors.white),
          onPressed: () {
            _editSchId = null;
            _resetSchForm();
            _showSchBottomSheet();
          },
        ),
      ),
    ]);
  }

  // ── Schedule card (used in both mobile list and wide grid) ──
  Widget _scheduleCard(Map<String, dynamic> sch, bool compact) {
    final sh = _shiftFor(sch['shiftId']);
    final c = sh['color'] as Color;
    final days = List<String>.from(sch['days'] ?? []);
    final empCount = (sch['empIds'] as List?)?.length ?? 0;
    final isSel = _selSchId == sch['id']?.toString();

    return GestureDetector(
      onTap: () => setState(() => _selSchId = sch['id']?.toString()),
      child: Container(
        padding: EdgeInsets.all(compact ? 12 : 16),
        decoration: BoxDecoration(
          color: isSel ? c.withOpacity(0.03) : W.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSel ? c : W.border, width: isSel ? 2 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // Row 1: name + actions
          Row(children: [
            // Actions
            _iconBtn(Icons.delete_outline, W.red, W.redL, () => _deleteSchedule(sch['id'])),
            const SizedBox(width: 6),
            _iconBtn(Icons.edit_outlined, W.orange, W.orangeL, () {
              _editSchId = sch['id']?.toString();
              _resetSchForm(sch);
              if (MediaQuery.of(context).size.width < 800) _showSchBottomSheet();
              setState(() {});
            }),
            const Spacer(),
            Flexible(child: Text(sch['name'] ?? '', style: GoogleFonts.tajawal(fontSize: compact ? 14 : 15, fontWeight: FontWeight.w700, color: W.text))),
          ]),
          const SizedBox(height: 8),
          // Row 2: shift badge + employee count
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(12)),
              child: Text('$empCount موظف', style: GoogleFonts.tajawal(fontSize: 11, color: W.muted, fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${sh['start']} - ${sh['end']}', style: _mono(fontSize: 10, color: c)),
                const SizedBox(width: 6),
                Text('${sh['name']}', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          // Row 3: day chips
          Row(children: _allDays.map((d) {
            final active = days.contains(d);
            return Expanded(child: Container(
              height: 26,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: active ? c.withOpacity(0.12) : W.bg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(child: Text(
                d.substring(0, 2),
                style: GoogleFonts.tajawal(fontSize: 9, fontWeight: FontWeight.w700, color: active ? c : W.hint),
              )),
            ));
          }).toList()),
        ]),
      ),
    );
  }

  // ── Wide-only: 2-column grid of schedule cards ──
  Widget _scheduleGrid() {
    return Wrap(spacing: 14, runSpacing: 14, children: _schedules.map((sch) {
      return SizedBox(
        width: (MediaQuery.of(context).size.width * 2 / 3 - 80) / 2,
        child: _scheduleCard(sch, false),
      );
    }).toList());
  }

  // ── Schedule form (wide: always visible panel, mobile: bottom sheet content) ──
  Widget _scheduleForm(bool isMobile) {
    final isEditing = _editSchId != null;
    final accent = isEditing ? W.orange : W.pri;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      decoration: BoxDecoration(
        color: W.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent, width: isEditing ? 2 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
        // Header
        Row(children: [
          const Spacer(),
          Icon(isEditing ? Icons.edit_note : Icons.add_circle_outline, size: 18, color: accent),
          const SizedBox(width: 8),
          Text(isEditing ? 'تعديل الجدول' : 'جدول جديد', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: W.text)),
        ]),
        const Divider(height: 24),
        // Name
        _inputField('اسم الجدول', 'مثال: جدول رمضان', _schName, (v) => setState(() => _schName = v)),
        const SizedBox(height: 14),
        // Shift dropdown
        Text('الفترة المرتبطة', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          width: double.infinity,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
          child: DropdownButtonHideUnderline(child: DropdownButton<int>(
            value: _schShift,
            isExpanded: true,
            style: GoogleFonts.tajawal(fontSize: 13, color: W.text),
            items: _shifts.map((s) => DropdownMenuItem(
              value: s['id'] as int,
              child: Text('${s['name']} (${s['start']} - ${s['end']})'),
            )).toList(),
            onChanged: (v) => setState(() => _schShift = v ?? 1),
          )),
        ),
        const SizedBox(height: 14),
        // Day toggles
        Text('أيام العمل', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub)),
        const SizedBox(height: 6),
        Row(children: _allDays.map((d) {
          final on = _schDays.contains(d);
          return Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: GestureDetector(
              onTap: () => setState(() => on ? _schDays.remove(d) : _schDays.add(d)),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: on ? accent.withOpacity(0.1) : W.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: on ? accent : W.border, width: on ? 2 : 1),
                ),
                child: Center(child: Text(
                  isMobile ? d.substring(0, 2) : d,
                  style: GoogleFonts.tajawal(fontSize: isMobile ? 10 : 11, fontWeight: FontWeight.w600, color: on ? accent : W.muted),
                )),
              ),
            ),
          ));
        }).toList()),
        const SizedBox(height: 20),
        // Buttons
        Row(children: [
          Expanded(child: _actionBtn(
            'إلغاء', W.white, W.sub,
            border: W.border,
            onTap: () {
              setState(() { _editSchId = null; _resetSchForm(); });
              if (isMobile) Navigator.pop(context);
            },
          )),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: _actionBtn(
            isEditing ? 'حفظ التعديلات' : 'إنشاء الجدول', accent, Colors.white,
            onTap: () async {
              await _saveSchedule();
              if (isMobile && mounted) Navigator.pop(context);
            },
          )),
        ]),
      ]),
    );
  }

  void _showSchBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setBS) {
        // Wrap in a listener so setState in the main widget updates the sheet
        return Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(16)),
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _scheduleForm(true),
          ),
        );
      }),
    );
  }

  // ── Employee assignment panel ──
  Widget _employeePanel(Map<String, dynamic> sch) {
    final sh = _shiftFor(sch['shiftId']);
    final c = sh['color'] as Color;
    final ids = _empIdsOf(sch);
    final assigned = _emps.where((e) => ids.contains(_uidOf(e))).toList();
    final available = _emps.where((e) => !ids.contains(_uidOf(e))).toList();
    final filtered = _empSearch.isEmpty
        ? available
        : available.where((e) => (e['name'] ?? '').toString().contains(_empSearch)).toList();
    final isWide = MediaQuery.of(context).size.width > 800;

    return Container(
      decoration: BoxDecoration(
        color: W.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: W.border),
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: c.withOpacity(0.03),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border(bottom: BorderSide(color: W.div)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text('${assigned.length} / ${_emps.length}', style: _mono(fontSize: 12, fontWeight: FontWeight.w600, color: c)),
            ),
            const Spacer(),
            Icon(Icons.people_outline, size: 18, color: c),
            const SizedBox(width: 8),
            Flexible(child: Text('تعيين الموظفين - "${sch['name']}"', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: W.text))),
          ]),
        ),
        // Split: available | assigned
        if (isWide)
          IntrinsicHeight(child: Row(children: [
            Expanded(child: _empList('موظفين متاحين', filtered, true, c, sch, search: true)),
            Container(width: 1, color: W.div),
            Expanded(child: _empList('الموظفين المعينين', assigned, false, c, sch)),
          ]))
        else
          Column(children: [
            _empList('الموظفين المعينين', assigned, false, c, sch),
            Divider(height: 1, color: W.div),
            _empList('موظفين متاحين', filtered, true, c, sch, search: true),
          ]),
      ]),
    );
  }

  Widget _empList(String title, List<Map<String, dynamic>> emps, bool isAdd, Color c, Map<String, dynamic> sch, {bool search = false}) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: W.div))),
        child: Column(children: [
          Row(children: [
            Text('${emps.length}', style: _mono(fontSize: 12, color: W.muted)),
            const Spacer(),
            Text(title, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: W.text)),
            const SizedBox(width: 6),
            Icon(isAdd ? Icons.person_add_outlined : Icons.group_outlined, size: 15, color: isAdd ? W.green : c),
          ]),
          if (search) ...[
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => setState(() => _empSearch = v),
              textAlign: TextAlign.right,
              style: GoogleFonts.tajawal(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'بحث عن موظف...',
                hintStyle: GoogleFonts.tajawal(color: W.hint, fontSize: 12),
                prefixIcon: Icon(Icons.search, size: 18, color: W.hint),
                filled: true,
                fillColor: W.bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: W.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: W.border)),
                isDense: true,
              ),
            ),
          ],
        ]),
      ),
      if (emps.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(isAdd ? 'لا يوجد موظفين متاحين' : 'لا يوجد موظفين معينين', style: GoogleFonts.tajawal(fontSize: 12, color: W.muted)),
        )
      else
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView(shrinkWrap: true, children: emps.map((emp) {
            final uid = _uidOf(emp);
            return _empRow(emp, isAdd, c, () => _toggleEmp(sch, uid, isAdd));
          }).toList()),
        ),
    ]);
  }

  Widget _empRow(Map<String, dynamic> emp, bool isAdd, Color c, VoidCallback onTap) {
    final initials = (emp['name'] ?? '').toString().length >= 2 ? emp['name'].toString().substring(0, 2) : 'م';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: W.div))),
      child: Row(children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: isAdd ? W.greenL : W.redL,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: isAdd ? W.greenBd : W.redBd),
            ),
            child: Icon(isAdd ? Icons.add : Icons.close, size: 13, color: isAdd ? W.green : W.red),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(emp['name'] ?? '', textAlign: TextAlign.right, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.text))),
        const SizedBox(width: 8),
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: c.withOpacity(0.08), shape: BoxShape.circle),
          child: Center(child: Text(initials, style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w700, color: c))),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════
  //           HOLIDAYS TAB
  // ═══════════════════════════════════════════

  Widget _buildHolidaysTab(bool isMobile, bool isWide) {
    if (isWide) return _wideHolidays();
    return _mobileHolidays(isMobile);
  }

  Widget _wideHolidays() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // RIGHT 2/3: table
        Expanded(flex: 2, child: _holidayTable()),
        const SizedBox(width: 20),
        // LEFT 1/3: form
        Expanded(flex: 1, child: _holidayForm(false)),
      ]),
    );
  }

  Widget _mobileHolidays(bool isMobile) {
    return Stack(children: [
      ListView(padding: EdgeInsets.all(isMobile ? 14 : 18), children: [
        ..._holidays.map((hol) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _holidayCard(hol),
        )),
        if (_holidays.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(child: Column(children: [
              Icon(Icons.beach_access_outlined, size: 36, color: W.hint),
              const SizedBox(height: 8),
              Text('لا توجد إجازات', style: GoogleFonts.tajawal(fontSize: 13, color: W.muted)),
            ])),
          ),
        const SizedBox(height: 80),
      ]),
      Positioned(
        left: 16,
        bottom: 16,
        child: FloatingActionButton(
          backgroundColor: W.green,
          child: const Icon(Icons.add, color: Colors.white),
          onPressed: () => _showHolBottomSheet(),
        ),
      ),
    ]);
  }

  Widget _holidayCard(Map<String, dynamic> hol) {
    final isGeneral = hol['type'] == 'عامة';
    final c = isGeneral ? W.green : W.purple;
    final bg = isGeneral ? W.greenL : W.purpleL;
    final empIds = (hol['empIds'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: W.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: W.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(children: [
          _iconBtn(Icons.delete_outline, W.red, W.redL, () => _deleteHoliday(hol['id'])),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Text('${hol['days'] ?? 1} يوم', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Text(hol['type'] ?? '', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
          ),
          const Spacer(),
          Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(hol['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: W.text)),
            Text(hol['date'] ?? '', style: _mono(fontSize: 11, color: W.sub)),
          ])),
        ]),
        if (!isGeneral && empIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 4, runSpacing: 4, alignment: WrapAlignment.end, children: empIds.map((eid) {
            final emp = _emps.firstWhere((e) => _uidOf(e) == eid?.toString(), orElse: () => {'name': '-'});
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: W.purpleL, borderRadius: BorderRadius.circular(6)),
              child: Text(emp['name']?.toString() ?? '-', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: W.purple)),
            );
          }).toList()),
        ],
        if (isGeneral) ...[
          const SizedBox(height: 6),
          Text('تُطبق على جميع الموظفين', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.green)),
        ],
      ]),
    );
  }

  Widget _holidayTable() {
    return Container(
      decoration: BoxDecoration(
        color: W.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: W.border),
      ),
      child: Column(children: [
        // Table header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: W.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border(bottom: BorderSide(color: W.div)),
          ),
          child: Row(children: [
            SizedBox(width: 50, child: Text('إجراء', style: _headerStyle, textAlign: TextAlign.center)),
            SizedBox(width: 70, child: Text('الحالة', style: _headerStyle, textAlign: TextAlign.center)),
            SizedBox(width: 50, child: Text('أيام', style: _headerStyle, textAlign: TextAlign.center)),
            Expanded(flex: 2, child: Text('التاريخ', style: _headerStyle, textAlign: TextAlign.right)),
            SizedBox(width: 80, child: Text('النوع', style: _headerStyle, textAlign: TextAlign.center)),
            Expanded(flex: 3, child: Text('اسم الإجازة', style: _headerStyle, textAlign: TextAlign.right)),
          ]),
        ),
        if (_holidays.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(children: [
              Icon(Icons.beach_access_outlined, size: 36, color: W.hint),
              const SizedBox(height: 8),
              Text('لا توجد إجازات مسجلة', style: GoogleFonts.tajawal(fontSize: 13, color: W.muted)),
            ]),
          )
        else
          ..._holidays.asMap().entries.map((e) {
            final i = e.key;
            final hol = e.value;
            final isGen = hol['type'] == 'عامة';
            final c = isGen ? W.green : W.purple;
            final bg = isGen ? W.greenL : W.purpleL;
            final empIds = (hol['empIds'] as List?) ?? [];

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              decoration: BoxDecoration(
                color: i.isEven ? W.white : W.bg.withOpacity(0.5),
                border: Border(bottom: BorderSide(color: W.div)),
              ),
              child: Row(children: [
                SizedBox(width: 50, child: Center(child: _iconBtn(Icons.delete_outline, W.red, W.redL, () => _deleteHoliday(hol['id'])))),
                SizedBox(width: 70, child: Center(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                  child: Text(isGen ? 'للكل' : '${empIds.length} موظف', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
                ))),
                SizedBox(width: 50, child: Center(child: Text('${hol['days'] ?? 1}', style: _mono(fontSize: 14, fontWeight: FontWeight.w700, color: W.text)))),
                Expanded(flex: 2, child: Text(hol['date'] ?? '', style: _mono(fontSize: 12, color: W.sub), textAlign: TextAlign.right)),
                SizedBox(width: 80, child: Center(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
                  child: Text(hol['type'] ?? '', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: c)),
                ))),
                Expanded(flex: 3, child: Text(hol['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600, color: W.text), textAlign: TextAlign.right)),
              ]),
            );
          }),
      ]),
    );
  }

  Widget _holidayForm(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      decoration: BoxDecoration(
        color: W.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: W.green),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Spacer(),
          Icon(Icons.event_note_outlined, size: 18, color: W.green),
          const SizedBox(width: 8),
          Text('إضافة إجازة', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: W.text)),
        ]),
        const Divider(height: 24),
        _inputField('اسم الإجازة', 'مثال: عيد الفطر', _holName, (v) => setState(() => _holName = v)),
        const SizedBox(height: 12),
        _inputField('التاريخ', '2026-03-20', _holDate, (v) => setState(() => _holDate = v)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _inputField('عدد الأيام', '1', _holDayCount.toString(), (v) => setState(() => _holDayCount = int.tryParse(v) ?? 1))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('النوع', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              width: double.infinity,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
              child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                value: _holType,
                isExpanded: true,
                style: GoogleFonts.tajawal(fontSize: 13, color: W.text),
                items: ['عامة', 'مخصصة'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() { _holType = v ?? 'عامة'; _holEmpIds.clear(); }),
              )),
            ),
          ])),
        ]),
        if (_holType == 'مخصصة') ...[
          const SizedBox(height: 14),
          Text('اختر الموظفين (${_holEmpIds.length} محدد)', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: SingleChildScrollView(child: Wrap(spacing: 6, runSpacing: 6, children: _emps.map((emp) {
              final uid = _uidOf(emp);
              final sel = _holEmpIds.contains(uid);
              return GestureDetector(
                onTap: () => setState(() => sel ? _holEmpIds.remove(uid) : _holEmpIds.add(uid)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? W.purpleL : W.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: sel ? W.purple : W.border),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 20, height: 20, child: Checkbox(
                      value: sel,
                      activeColor: W.purple,
                      onChanged: (_) => setState(() => sel ? _holEmpIds.remove(uid) : _holEmpIds.add(uid)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )),
                    const SizedBox(width: 4),
                    Text(emp['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.text)),
                  ]),
                ),
              );
            }).toList())),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: _actionBtn('إضافة الإجازة', W.green, Colors.white, onTap: () async {
            await _saveHoliday();
            if (isMobile && mounted) Navigator.pop(context);
          }),
        ),
      ]),
    );
  }

  void _showHolBottomSheet() {
    _resetHolForm();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setBS) {
        return Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(16)),
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _holidayForm(true),
          ),
        );
      }),
    );
  }

  // ───────────────── Shared Widgets ─────────────────

  TextStyle get _headerStyle => GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w700, color: W.sub);

  Widget _inputField(String label, String hint, String value, ValueChanged<String> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(label, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub)),
      const SizedBox(height: 4),
      TextFormField(
        initialValue: value.isEmpty ? null : value,
        onChanged: onChanged,
        textAlign: TextAlign.right,
        style: GoogleFonts.tajawal(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.tajawal(color: W.hint, fontSize: 13),
          filled: true,
          fillColor: W.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: W.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: W.border)),
          isDense: true,
        ),
      ),
    ]);
  }

  Widget _iconBtn(IconData icon, Color iconColor, Color bg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: 14, color: iconColor),
      ),
    );
  }

  Widget _actionBtn(String label, Color bg, Color fg, {VoidCallback? onTap, Color? border}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: border != null ? Border.all(color: border) : null,
        ),
        child: Center(child: Text(label, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: fg))),
      ),
    );
  }
}
