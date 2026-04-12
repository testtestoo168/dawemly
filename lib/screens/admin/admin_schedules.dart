import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';
import '../../l10n/app_locale.dart';

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
  bool _showAllAssigned = false;
  bool _showAllAvailable = false;

  // ═══ أرصدة الإجازات ═══
  List<Map<String, dynamic>> _leaveBalances = [];
  bool _loadingLeaves = false;
  String? _expandedLeaveUid;

  // Schedule form state
  String _schName = '';
  String _schNameEn = '';
  int _schShift = 1;
  List<String> _schDays = L.dayNamesShort.sublist(0, 5);

  // Holiday form state
  String _holName = '';
  String _holDate = '';
  String _holType = L.tr('general');
  int _holDayCount = 1;
  final Set<String> _holEmpIds = {};

  static List<String> get _allDays => L.dayNamesShort;

  List<Map<String, dynamic>> get _shifts => [
    {'id': 1, 'name': L.tr('period_1'), 'start': '08:00 ${L.tr('am')}', 'end': '04:00 ${L.tr('pm')}', 'color': W.pri},
    {'id': 2, 'name': L.tr('period_2'), 'start': '01:00 ${L.tr('pm')}', 'end': '09:00 ${L.tr('pm')}', 'color': W.purple},
    {'id': 3, 'name': L.tr('period_3'), 'start': '04:00 ${L.tr('pm')}', 'end': '12:00 ${L.tr('am')}', 'color': W.teal},
  ];

  TextStyle _mono({double fontSize = 12, FontWeight fontWeight = FontWeight.w400, Color? color}) =>
      GoogleFonts.ibmPlexMono(fontSize: fontSize, fontWeight: fontWeight, color: color ?? W.sub);

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.index == 2 && _leaveBalances.isEmpty && !_loadingLeaves) {
        _loadLeaveBalances();
      }
    });
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
        _emps.sort((a, b) => L.localName(a).compareTo(L.localName(b)));
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
    _schNameEn = sch?['name_en']?.toString() ?? '';
    _schShift = (sch?['shiftId'] is int ? sch!['shiftId'] : int.tryParse('${sch?['shiftId']}')) ?? 1;
    _schDays = sch != null ? List<String>.from(sch['days'] ?? []) : L.dayNamesShort.sublist(0, 5);
  }

  void _resetHolForm() {
    _holName = '';
    _holDate = '';
    _holType = L.tr('general');
    _holDayCount = 1;
    _holEmpIds.clear();
  }

  Future<void> _saveSchedule() async {
    if (_schName.trim().isEmpty) return;
    final payload = <String, dynamic>{
      'name': _schName.trim(),
      'name_en': _schNameEn.trim(),
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
      'empIds': _holType == L.tr('custom_type') ? _holEmpIds.toList() : [],
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
          tabs: [Tab(text: L.tr('schedules_tab')), Tab(text: L.tr('leaves_tab')), Tab(text: L.tr('leave_balance'))],
        ),
      ),
      const SizedBox(height: 8),
      // Tab content
      Expanded(
        child: TabBarView(controller: _tabCtrl, children: [
          _buildSchedulesTab(isMobile, isWide),
          _buildHolidaysTab(isMobile, isWide),
          _buildLeaveBalancesTab(isMobile, isWide),
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

  // ── Wide: left list+employees (2/3) + right form (1/3) ──
  Widget _wideSchedules() {
    final activeSch = _schedules.firstWhere(
      (s) => s['id']?.toString() == _selSchId,
      orElse: () => _schedules.isNotEmpty ? _schedules.first : {},
    );

    return Directionality(
      textDirection: L.textDirection,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // LEFT 2/3: schedule list + employees
          Expanded(flex: 2, child: Column(children: [
            _scheduleListPanel(),
            if (activeSch.isNotEmpty) ...[
              const SizedBox(height: 20),
              _employeePanel(activeSch),
            ],
          ])),
          const SizedBox(width: 24),
          // RIGHT 1/3: form
          Expanded(flex: 1, child: _scheduleForm(false)),
        ]),
      ),
    );
  }

  // ── Wide: schedule list as clean table rows ──
  Widget _scheduleListPanel() {
    return Container(
      decoration: BoxDecoration(
        color: W.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: W.border),
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: W.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(bottom: BorderSide(color: W.div)),
          ),
          child: Row(children: [
            Icon(Icons.calendar_today_outlined, size: 18, color: W.pri),
            const SizedBox(width: 10),
            Text(L.tr('schedules_tab'), style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: W.text)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: W.priLight, borderRadius: BorderRadius.circular(20)),
              child: Text('${_schedules.length}', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w700, color: W.pri)),
            ),
          ]),
        ),
        if (_schedules.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(children: [
              Icon(Icons.event_note_outlined, size: 40, color: W.hint),
              const SizedBox(height: 12),
              Text(L.tr('no_schedules_yet'), style: GoogleFonts.tajawal(fontSize: 14, color: W.muted)),
            ]),
          )
        else
          ..._schedules.asMap().entries.map((entry) {
            final i = entry.key;
            final sch = entry.value;
            return _scheduleListRow(sch, i);
          }),
      ]),
    );
  }

  // ── Single schedule row in wide list ──
  Widget _scheduleListRow(Map<String, dynamic> sch, int index) {
    final sh = _shiftFor(sch['shiftId']);
    final c = sh['color'] as Color;
    final days = List<String>.from(sch['days'] ?? []);
    final empCount = (sch['empIds'] as List?)?.length ?? 0;
    final isSel = _selSchId == sch['id']?.toString();

    return InkWell(
      onTap: () => setState(() { _selSchId = sch['id']?.toString(); _showAllAssigned = false; _showAllAvailable = false; }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isSel ? W.priLight : (index.isEven ? W.white : W.bg.withOpacity(0.3)),
          border: Border(bottom: BorderSide(color: W.div)),
        ),
        child: Row(children: [
          // Schedule name
          Expanded(
            flex: 3,
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: c.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.schedule, size: 18, color: c),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(L.localName(sch), style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: W.text)),
              ),
            ]),
          ),
          // Shift badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${sh['name']}', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
              const SizedBox(width: 6),
              Text('${sh['start']} - ${sh['end']}', style: _mono(fontSize: 10, color: c)),
            ]),
          ),
          const SizedBox(width: 16),
          // Day circles
          Row(mainAxisSize: MainAxisSize.min, children: _allDays.map((d) {
            final active = days.contains(d);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: active ? c.withOpacity(0.15) : W.bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: active ? c.withOpacity(0.3) : W.border, width: 1),
                ),
                child: Center(child: Text(
                  d.length >= 2 ? d.substring(0, 2) : d,
                  style: GoogleFonts.tajawal(fontSize: 9, fontWeight: FontWeight.w700, color: active ? c : W.hint),
                )),
              ),
            );
          }).toList()),
          const SizedBox(width: 16),
          // Employee count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.people_outline, size: 14, color: W.muted),
              const SizedBox(width: 4),
              Text('$empCount', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub)),
            ]),
          ),
          const SizedBox(width: 12),
          // Action buttons
          _iconBtn(Icons.edit_outlined, W.orange, W.orangeL, () {
            _editSchId = sch['id']?.toString();
            _resetSchForm(sch);
            setState(() {});
          }),
          const SizedBox(width: 6),
          _iconBtn(Icons.delete_outline, W.red, W.redL, () => _deleteSchedule(sch['id'])),
        ]),
      ),
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

  // ── Schedule card (mobile only) ──
  Widget _scheduleCard(Map<String, dynamic> sch, bool compact) {
    final sh = _shiftFor(sch['shiftId']);
    final c = sh['color'] as Color;
    final days = List<String>.from(sch['days'] ?? []);
    final empCount = (sch['empIds'] as List?)?.length ?? 0;
    final isSel = _selSchId == sch['id']?.toString();

    return InkWell(
      onTap: () => setState(() { _selSchId = sch['id']?.toString(); _showAllAssigned = false; _showAllAvailable = false; }),
      child: Container(
        padding: EdgeInsets.all(compact ? 14 : 16),
        decoration: BoxDecoration(
          color: isSel ? W.priLight : W.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: W.border),
        ),
        child: Directionality(
          textDirection: L.textDirection,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Row 1: name + actions
            Row(children: [
              Flexible(child: Text(L.localName(sch), style: GoogleFonts.tajawal(fontSize: compact ? 14 : 15, fontWeight: FontWeight.w700, color: W.text))),
              const Spacer(),
              _iconBtn(Icons.edit_outlined, W.orange, W.orangeL, () {
                _editSchId = sch['id']?.toString();
                _resetSchForm(sch);
                _showSchBottomSheet();
                setState(() {});
              }),
              const SizedBox(width: 6),
              _iconBtn(Icons.delete_outline, W.red, W.redL, () => _deleteSchedule(sch['id'])),
            ]),
            const SizedBox(height: 10),
            // Row 2: shift badge + employee count
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${sh['name']}', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
                  const SizedBox(width: 6),
                  Text('${sh['start']} - ${sh['end']}', style: _mono(fontSize: 10, color: c)),
                ]),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.people_outline, size: 13, color: W.muted),
                  const SizedBox(width: 4),
                  Text(L.tr('n_employee', args: {'n': empCount.toString()}), style: GoogleFonts.tajawal(fontSize: 11, color: W.muted, fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            // Row 3: day circles
            Row(children: _allDays.map((d) {
              final active = days.contains(d);
              return Expanded(child: Container(
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: active ? c.withOpacity(0.12) : W.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Text(
                  d.length >= 2 ? d.substring(0, 2) : d,
                  style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w700, color: active ? c : W.hint),
                )),
              ));
            }).toList()),
          ]),
        ),
      ),
    );
  }

  // ── Schedule form (wide: always visible panel, mobile: bottom sheet content) ──
  Widget _scheduleForm(bool isMobile) {
    final isEditing = _editSchId != null;
    final accent = isEditing ? W.orange : W.pri;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: W.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: W.border),
      ),
      child: Directionality(
        textDirection: L.textDirection,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          // Header
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(isEditing ? Icons.edit_note : Icons.add_circle_outline, size: 20, color: accent),
            ),
            const SizedBox(width: 10),
            Text(isEditing ? L.tr('edit_schedule') : L.tr('new_schedule'), style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: W.text)),
          ]),
          const SizedBox(height: 6),
          Divider(color: W.div, height: 24),
          // Name
          _inputField(L.tr('schedule_name'), L.tr('schedule_example'), _schName, (v) => setState(() => _schName = v)),
          const SizedBox(height: 10),
          _inputField(L.tr('schedule_name_en'), 'e.g. Morning Shift', _schNameEn, (v) => setState(() => _schNameEn = v), isLtr: true),
          const SizedBox(height: 16),
          // Shift dropdown
          Text(L.tr('linked_period'), style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DS.radiusMd),
              border: Border.all(color: W.border),
              color: W.white,
            ),
            child: DropdownButtonHideUnderline(child: DropdownButton<int>(
              value: _schShift,
              isExpanded: true,
              style: GoogleFonts.tajawal(fontSize: 13, color: W.text),
              icon: Icon(Icons.keyboard_arrow_down, color: W.muted, size: 20),
              items: _shifts.map((s) => DropdownMenuItem(
                value: s['id'] as int,
                child: Text('${s['name']} (${s['start']} - ${s['end']})'),
              )).toList(),
              onChanged: (v) => setState(() => _schShift = v ?? 1),
            )),
          ),
          const SizedBox(height: 16),
          // Day toggles
          Text(L.tr('work_days'), style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub)),
          const SizedBox(height: 8),
          Row(children: _allDays.map((d) {
            final on = _schDays.contains(d);
            return Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => on ? _schDays.remove(d) : _schDays.add(d)),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: on ? accent.withOpacity(0.1) : W.bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: on ? accent : W.border, width: on ? 1.5 : 1),
                  ),
                  child: Center(child: Text(
                    isMobile ? (d.length >= 2 ? d.substring(0, 2) : d) : d,
                    style: GoogleFonts.tajawal(fontSize: isMobile ? 10 : 11, fontWeight: FontWeight.w600, color: on ? accent : W.muted),
                  )),
                ),
              ),
            ));
          }).toList()),
          const SizedBox(height: 24),
          // Buttons
          Row(children: [
            Expanded(child: _actionBtn(
              L.tr('cancel'), W.white, W.sub,
              border: W.border,
              onTap: () {
                setState(() { _editSchId = null; _resetSchForm(); });
                if (isMobile) Navigator.pop(context);
              },
            )),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: _actionBtn(
              isEditing ? L.tr('save_edits') : L.tr('create_schedule'), accent, Colors.white,
              onTap: () async {
                await _saveSchedule();
                if (isMobile && mounted) Navigator.pop(context);
              },
            )),
          ]),
        ]),
      ),
    );
  }

  void _showSchBottomSheet() {
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
        : available.where((e) => (e['name'] ?? '').toString().contains(_empSearch) || (e['name_en'] ?? '').toString().toLowerCase().contains(_empSearch.toLowerCase())).toList();
    final isWide = MediaQuery.of(context).size.width > 800;

    return Container(
      decoration: BoxDecoration(
        color: W.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: W.border),
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: W.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(bottom: BorderSide(color: W.div)),
          ),
          child: Directionality(
            textDirection: L.textDirection,
            child: Row(children: [
              Icon(Icons.people_outline, size: 18, color: c),
              const SizedBox(width: 10),
              Flexible(child: Text(L.tr('assign_employees', args: {'name': L.localName(sch)}), style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: W.text))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text('${assigned.length} / ${_emps.length}', style: _mono(fontSize: 12, fontWeight: FontWeight.w600, color: c)),
              ),
            ]),
          ),
        ),
        // Split: available | assigned
        if (isWide)
          IntrinsicHeight(child: Directionality(
            textDirection: L.textDirection,
            child: Row(children: [
              Expanded(child: _empList(L.tr('assigned_employees'), assigned, false, c, sch)),
              Container(width: 1, color: W.div),
              Expanded(child: _empList(L.tr('available_employees'), filtered, true, c, sch, search: true)),
            ]),
          ))
        else
          Directionality(
            textDirection: L.textDirection,
            child: Column(children: [
              _empList(L.tr('assigned_employees'), assigned, false, c, sch),
              Divider(height: 1, color: W.div),
              _empList(L.tr('available_employees'), filtered, true, c, sch, search: true),
            ]),
          ),
      ]),
    );
  }

  Widget _empList(String title, List<Map<String, dynamic>> emps, bool isAdd, Color c, Map<String, dynamic> sch, {bool search = false}) {
    final showAll = isAdd ? _showAllAvailable : _showAllAssigned;
    final hasMore = emps.length > 4;
    final visibleEmps = (showAll || !hasMore) ? emps : emps.sublist(0, 4);

    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: W.div))),
        child: Column(children: [
          Row(children: [
            Icon(isAdd ? Icons.person_add_outlined : Icons.group_outlined, size: 16, color: isAdd ? W.green : c),
            const SizedBox(width: 8),
            Text(title, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: W.text)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(12)),
              child: Text('${emps.length}', style: _mono(fontSize: 11, fontWeight: FontWeight.w600, color: W.muted)),
            ),
          ]),
          if (search) ...[
            const SizedBox(height: 10),
            TextField(
              onChanged: (v) => setState(() => _empSearch = v),
              textDirection: L.textDirection,
              style: GoogleFonts.tajawal(fontSize: 12),
              decoration: InputDecoration(
                hintText: L.tr('search'),
                hintStyle: GoogleFonts.tajawal(color: W.hint, fontSize: 12),
                prefixIcon: Icon(Icons.search, size: 18, color: W.hint),
                filled: true,
                fillColor: W.bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: W.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: W.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: W.pri)),
                isDense: true,
              ),
            ),
          ],
        ]),
      ),
      if (emps.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Icon(isAdd ? Icons.person_add_disabled_outlined : Icons.group_off_outlined, size: 28, color: W.hint),
            const SizedBox(height: 8),
            Text(isAdd ? L.tr('no_available_employees') : L.tr('no_assigned_employees'), style: GoogleFonts.tajawal(fontSize: 12, color: W.muted)),
          ]),
        )
      else ...[
        ...visibleEmps.map((emp) {
          final uid = _uidOf(emp);
          return _empRow(emp, isAdd, c, () => _toggleEmp(sch, uid, isAdd));
        }),
        if (hasMore)
          InkWell(
            onTap: () => setState(() {
              if (isAdd) {
                _showAllAvailable = !_showAllAvailable;
              } else {
                _showAllAssigned = !_showAllAssigned;
              }
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: W.div))),
              child: Center(
                child: Text(
                  showAll ? L.tr('show_less') : '${L.tr('show_more')} (${emps.length - 4})',
                  style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.pri),
                ),
              ),
            ),
          ),
      ],
    ]);
  }

  Widget _empRow(Map<String, dynamic> emp, bool isAdd, Color c, VoidCallback onTap) {
    final name = L.localName(emp);
    final dept = L.localDept(emp).isNotEmpty ? L.localDept(emp) : (emp['dept'] ?? emp['department'] ?? '').toString();
    final initials = name.length >= 2 ? name.substring(0, 2) : (name.isNotEmpty ? name[0] : '?');
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: W.div))),
        child: Row(children: [
          // Avatar
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: c.withOpacity(0.08), shape: BoxShape.circle),
            child: Center(child: Text(initials, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w700, color: c))),
          ),
          const SizedBox(width: 10),
          // Name + department
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w500, color: W.text)),
              if (dept.isNotEmpty)
                Text(dept, style: GoogleFonts.tajawal(fontSize: 11, color: W.muted)),
            ],
          )),
          // Action button
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: isAdd ? W.greenL : W.redL,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isAdd ? W.greenBd : W.redBd),
            ),
            child: Icon(isAdd ? Icons.add : Icons.close, size: 14, color: isAdd ? W.green : W.red),
          ),
        ]),
      ),
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
              Text(L.tr('no_leaves'), style: GoogleFonts.tajawal(fontSize: 13, color: W.muted)),
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
    final isGeneral = hol['type'] == L.tr('general');
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
            child: Text('${hol['days'] ?? 1} ${L.tr('day_unit')}', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
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
              decoration: BoxDecoration(color: W.purpleL, borderRadius: BorderRadius.circular(DS.radiusMd)),
              child: Text(L.localName(emp), style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: W.purple)),
            );
          }).toList()),
        ],
        if (isGeneral) ...[
          const SizedBox(height: 6),
          Text(L.tr('applies_to_all'), style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.green)),
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
            SizedBox(width: 50, child: Text(L.tr('action_col'), style: _headerStyle, textAlign: TextAlign.center)),
            SizedBox(width: 70, child: Text(L.tr('status'), style: _headerStyle, textAlign: TextAlign.center)),
            SizedBox(width: 50, child: Text(L.tr('days_col'), style: _headerStyle, textAlign: TextAlign.center)),
            Expanded(flex: 2, child: Text(L.tr('date'), style: _headerStyle, textAlign: TextAlign.right)),
            SizedBox(width: 80, child: Text(L.tr('type'), style: _headerStyle, textAlign: TextAlign.center)),
            Expanded(flex: 3, child: Text(L.tr('leave_name'), style: _headerStyle, textAlign: TextAlign.right)),
          ]),
        ),
        if (_holidays.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(children: [
              Icon(Icons.beach_access_outlined, size: 36, color: W.hint),
              const SizedBox(height: 8),
              Text(L.tr('no_leaves_recorded'), style: GoogleFonts.tajawal(fontSize: 13, color: W.muted)),
            ]),
          )
        else
          ..._holidays.asMap().entries.map((e) {
            final i = e.key;
            final hol = e.value;
            final isGen = hol['type'] == L.tr('general');
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
                  child: Text(isGen ? L.tr('for_all') : L.tr('n_employee', args: {'n': empIds.length.toString()}), style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
                ))),
                SizedBox(width: 50, child: Center(child: Text('${hol['days'] ?? 1}', style: _mono(fontSize: 14, fontWeight: FontWeight.w700, color: W.text)))),
                Expanded(flex: 2, child: Text(hol['date'] ?? '', style: _mono(fontSize: 12, color: W.sub), textAlign: TextAlign.right)),
                SizedBox(width: 80, child: Center(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(DS.radiusMd)),
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
          Text(L.tr('add_leave'), style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: W.text)),
        ]),
        const Divider(height: 24),
        _inputField(L.tr('leave_name'), L.tr('leave_example'), _holName, (v) => setState(() => _holName = v)),
        const SizedBox(height: 12),
        _inputField(L.tr('date'), '2026-03-20', _holDate, (v) => setState(() => _holDate = v)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _inputField(L.tr('number_of_days'), '1', _holDayCount.toString(), (v) => setState(() => _holDayCount = int.tryParse(v) ?? 1))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(L.tr('type'), style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              width: double.infinity,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(DS.radiusMd), border: Border.all(color: W.border)),
              child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                value: _holType,
                isExpanded: true,
                style: GoogleFonts.tajawal(fontSize: 13, color: W.text),
                items: [L.tr('general'), L.tr('custom_type')].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() { _holType = v ?? L.tr('general'); _holEmpIds.clear(); }),
              )),
            ),
          ])),
        ]),
        if (_holType == L.tr('custom_type')) ...[
          const SizedBox(height: 14),
          Text(L.tr('choose_employees', args: {'count': _holEmpIds.length.toString()}), style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: SingleChildScrollView(child: Wrap(spacing: 6, runSpacing: 6, children: _emps.map((emp) {
              final uid = _uidOf(emp);
              final sel = _holEmpIds.contains(uid);
              return InkWell(
                onTap: () => setState(() => sel ? _holEmpIds.remove(uid) : _holEmpIds.add(uid)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? W.purpleL : W.white,
                    borderRadius: BorderRadius.circular(DS.radiusMd),
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
                    Text(L.localName(emp), style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.text)),
                  ]),
                ),
              );
            }).toList())),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: _actionBtn(L.tr('add_leave_btn'), W.green, Colors.white, onTap: () async {
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

  // ═══════════════════════════════════════════
  //           LEAVE BALANCES TAB
  // ═══════════════════════════════════════════

  Future<void> _loadLeaveBalances() async {
    setState(() => _loadingLeaves = true);
    try {
      final res = await ApiService.get('leaves.php?action=all_balances&year=${DateTime.now().year}');
      if (res['success'] == true) {
        _leaveBalances = (res['balances'] as List? ?? []).cast<Map<String, dynamic>>();
      }
      // Ensure every active employee has a balance row
      for (final u in _emps) {
        final uid = _uidOf(u);
        if (uid.isEmpty) continue;
        final exists = _leaveBalances.any((b) => b['uid'] == uid);
        if (!exists) {
          await ApiService.get('leaves.php?action=balance&uid=$uid&year=${DateTime.now().year}');
        }
      }
      // Reload after creating missing ones
      final res2 = await ApiService.get('leaves.php?action=all_balances&year=${DateTime.now().year}');
      if (res2['success'] == true) {
        _leaveBalances = (res2['balances'] as List? ?? []).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingLeaves = false);
  }

  Future<void> _saveLeaveBalance(String uid, {int? annual, int? sick, int? emergency}) async {
    try {
      await ApiService.post('leaves.php?action=set_balance', {
        'uid': uid,
        'year': DateTime.now().year,
        if (annual != null) 'annual_total': annual,
        if (sick != null) 'sick_total': sick,
        if (emergency != null) 'emergency_total': emergency,
      });
      await _loadLeaveBalances();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L.tr('leave_balance_saved'), style: GoogleFonts.tajawal()),
          backgroundColor: W.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L.tr('error_prefix', args: {'error': e.toString()}), style: GoogleFonts.tajawal()),
          backgroundColor: W.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd)),
        ));
      }
    }
  }

  Widget _buildLeaveBalancesTab(bool isMobile, bool isWide) {
    final hPad = isWide ? 28.0 : (isMobile ? 14.0 : 18.0);
    return Column(children: [
      // Header bar
      Padding(
        padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 0),
        child: Row(children: [
          ElevatedButton.icon(
            onPressed: _loadLeaveBalances,
            icon: const Icon(Icons.refresh, size: 14),
            label: Text(L.tr('update_balances'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w600, fontSize: 13)),
            style: ElevatedButton.styleFrom(backgroundColor: W.priLight, foregroundColor: W.pri, side: BorderSide(color: W.pri), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd))),
          ),
          const Spacer(),
          Text(L.tr('set_leave_balances'), style: GoogleFonts.tajawal(fontSize: 12, color: W.sub)),
        ]),
      ),
      const SizedBox(height: 10),

      // Content
      Expanded(child: _loadingLeaves
        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
        : _leaveBalances.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.event_busy_outlined, size: 36, color: W.hint),
              const SizedBox(height: 8),
              Text(L.tr('no_data_check'), style: GoogleFonts.tajawal(fontSize: 13, color: W.muted)),
            ]))
          : Container(
              margin: EdgeInsets.fromLTRB(hPad, 0, hPad, hPad),
              decoration: BoxDecoration(
                color: W.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: W.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ListView.builder(
                  itemCount: _leaveBalances.length,
                  itemBuilder: (ctx, i) => _leaveBalanceRow(_leaveBalances[i], i),
                ),
              ),
            ),
      ),
    ]);
  }

  Widget _leaveBalanceRow(Map<String, dynamic> bal, int index) {
    final name = L.localName(bal);
    final dept = (bal['dept'] ?? '').toString();
    final uid = (bal['uid'] ?? '').toString();
    final isExpanded = _expandedLeaveUid == uid;
    final initials = name.length >= 2 ? name.substring(0, 2) : (name.isNotEmpty ? name[0] : '?');

    final annualTotal = (bal['annual_total'] as num?)?.toInt() ?? 21;
    final annualUsed = (bal['annual_used'] as num?)?.toInt() ?? 0;
    final sickTotal = (bal['sick_total'] as num?)?.toInt() ?? 10;
    final sickUsed = (bal['sick_used'] as num?)?.toInt() ?? 0;
    final emergencyTotal = (bal['emergency_total'] as num?)?.toInt() ?? 5;
    final emergencyUsed = (bal['emergency_used'] as num?)?.toInt() ?? 0;
    final unpaidUsed = (bal['unpaid_used'] as num?)?.toInt() ?? 0;

    return Column(children: [
      // Employee header row (always visible)
      InkWell(
        onTap: () => setState(() => _expandedLeaveUid = isExpanded ? null : uid),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isExpanded ? W.priLight.withOpacity(0.5) : (index.isEven ? W.white : W.bg.withOpacity(0.4)),
            border: Border(bottom: BorderSide(color: W.div)),
          ),
          child: Directionality(
            textDirection: L.textDirection,
            child: Row(children: [
              // Avatar
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: isExpanded ? W.pri.withOpacity(0.12) : W.priLight,
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text(initials, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: W.pri))),
              ),
              const SizedBox(width: 12),
              // Name + dept
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: W.text)),
                  if (dept.isNotEmpty)
                    Text(dept, style: GoogleFonts.tajawal(fontSize: 11, color: W.muted)),
                ],
              )),
              // Arrow
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down, size: 22, color: isExpanded ? W.pri : W.muted),
              ),
            ]),
          ),
        ),
      ),
      // Expandable detail section
      AnimatedCrossFade(
        firstChild: const SizedBox(width: double.infinity),
        secondChild: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          decoration: BoxDecoration(
            color: W.bg.withOpacity(0.5),
            border: Border(bottom: BorderSide(color: W.div)),
          ),
          child: Column(children: [
            _leaveTypeRow(
              label: L.tr('annual'),
              icon: Icons.beach_access,
              color: W.pri,
              total: annualTotal,
              used: annualUsed,
              onTotalChanged: (v) => _saveLeaveBalance(uid, annual: v),
            ),
            const SizedBox(height: 10),
            _leaveTypeRow(
              label: L.tr('sick'),
              icon: Icons.local_hospital,
              color: W.red,
              total: sickTotal,
              used: sickUsed,
              onTotalChanged: (v) => _saveLeaveBalance(uid, sick: v),
            ),
            const SizedBox(height: 10),
            _leaveTypeRow(
              label: L.tr('emergency'),
              icon: Icons.warning_amber,
              color: W.orange,
              total: emergencyTotal,
              used: emergencyUsed,
              onTotalChanged: (v) => _saveLeaveBalance(uid, emergency: v),
            ),
            if (unpaidUsed > 0) ...[
              const SizedBox(height: 10),
              Row(children: [
                Text('$unpaidUsed ${L.tr("day_unit")}', style: GoogleFonts.ibmPlexMono(fontSize: 12, fontWeight: FontWeight.w700, color: W.muted)),
                const Spacer(),
                Text(L.tr('unpaid'), style: GoogleFonts.tajawal(fontSize: 12, color: W.muted)),
                const SizedBox(width: 6),
                Icon(Icons.money_off, size: 16, color: W.muted),
              ]),
            ],
          ]),
        ),
        crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        duration: const Duration(milliseconds: 250),
        sizeCurve: Curves.easeInOut,
      ),
    ]);
  }

  Widget _leaveTypeRow({
    required String label,
    required IconData icon,
    required Color color,
    required int total,
    required int used,
    required Function(int) onTotalChanged,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 500;
    final remaining = total - used;
    final progress = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    return Row(children: [
      // Edit button
      InkWell(
        onTap: () {
          final ctrl = TextEditingController(text: '$total');
          showDialog(context: context, builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(L.tr('edit_balance_label', args: {'label': label}), style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700), textAlign: TextAlign.right),
            content: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexMono(fontSize: 20, fontWeight: FontWeight.w800, color: color),
              decoration: InputDecoration(
                hintText: L.tr('number_of_days'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixText: L.tr('day_unit'),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(L.tr('cancel'), style: GoogleFonts.tajawal(color: W.sub))),
              ElevatedButton(
                onPressed: () {
                  final v = int.tryParse(ctrl.text);
                  if (v != null && v >= 0) {
                    Navigator.pop(ctx);
                    onTotalChanged(v);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
                child: Text(L.tr('save'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
              ),
            ],
          )).whenComplete(ctrl.dispose);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(DS.radiusMd)),
          child: Icon(Icons.edit, size: 14, color: color),
        ),
      ),
      const SizedBox(width: 8),
      // Progress bar + numbers
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(children: [
          Text(L.tr('n_remaining_of_total', args: {'remaining': remaining.toString(), 'total': total.toString()}), style: GoogleFonts.tajawal(fontSize: isMobile ? 10 : 11, color: W.muted)),
          const Spacer(),
          Text(L.tr('n_used', args: {'used': used.toString()}), style: GoogleFonts.tajawal(fontSize: isMobile ? 10 : 11, color: color)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withOpacity(0.1),
            color: color,
            minHeight: 6,
          ),
        ),
      ])),
      const SizedBox(width: 10),
      // Label + icon
      Text(label, style: GoogleFonts.tajawal(fontSize: isMobile ? 12 : 13, fontWeight: FontWeight.w600, color: W.text)),
      const SizedBox(width: 6),
      Container(
        width: isMobile ? 28 : 32, height: isMobile ? 28 : 32,
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(DS.radiusMd)),
        child: Icon(icon, size: isMobile ? 14 : 16, color: color),
      ),
    ]);
  }

  // ───────────────── Shared Widgets ─────────────────

  TextStyle get _headerStyle => GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w700, color: W.sub);

  Widget _inputField(String label, String hint, String value, ValueChanged<String> onChanged, {bool isLtr = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(label, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub)),
      const SizedBox(height: 4),
      TextFormField(
        initialValue: value.isEmpty ? null : value,
        onChanged: onChanged,
        textAlign: isLtr ? TextAlign.left : TextAlign.right,
        style: GoogleFonts.tajawal(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.tajawal(color: W.hint, fontSize: 13),
          filled: true,
          fillColor: W.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(DS.radiusMd), borderSide: BorderSide(color: W.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(DS.radiusMd), borderSide: BorderSide(color: W.border)),
          isDense: true,
        ),
      ),
    ]);
  }

  Widget _iconBtn(IconData icon, Color iconColor, Color bg, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: 14, color: iconColor),
      ),
    );
  }

  Widget _actionBtn(String label, Color bg, Color fg, {VoidCallback? onTap, Color? border}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(DS.radiusMd),
          border: border != null ? Border.all(color: border) : null,
        ),
        child: Center(child: Text(label, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: fg))),
      ),
    );
  }
}
