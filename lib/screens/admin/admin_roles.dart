import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

class AdminRoles extends StatefulWidget {
  const AdminRoles({super.key});
  @override
  State<AdminRoles> createState() => _AdminRolesState();
}

class _AdminRolesState extends State<AdminRoles> {
  bool _loading = true;
  List<Map<String, dynamic>> _users = [];
  String _search = '';
  Map<String, dynamic>? _selectedUser;
  Map<String, bool> _editPerms = {};
  bool _saving = false;
  bool _saved = false;

  static const _permsMeta = [
    {'key': 'users',    'label': 'إدارة المستخدمين', 'sub': 'إضافة وتعديل حسابات الموظفين',  'icon': Icons.people_alt_rounded,      'dangerColor': false},
    {'key': 'settings', 'label': 'إعدادات النظام',   'sub': 'تعديل إعدادات التطبيق والشركة',  'icon': Icons.tune_rounded,             'dangerColor': false},
    {'key': 'reports',  'label': 'التقارير',          'sub': 'عرض وتصدير تقارير الحضور',        'icon': Icons.bar_chart_rounded,        'dangerColor': false},
    {'key': 'requests', 'label': 'إدارة الطلبات',    'sub': 'قبول ورفض طلبات الإجازات',       'icon': Icons.task_alt_rounded,         'dangerColor': false},
    {'key': 'verify',   'label': 'إثبات الحالة',     'sub': 'طلب التحقق من حضور الموظف',      'icon': Icons.wifi_tethering_rounded,   'dangerColor': false},
    {'key': 'delete',   'label': 'صلاحية الحذف',     'sub': 'حذف السجلات والبيانات',          'icon': Icons.delete_rounded,           'dangerColor': true},
  ];

  TextStyle _tj(double s, {FontWeight w = FontWeight.w400, Color? color}) =>
      GoogleFonts.tajawal(fontSize: s, fontWeight: w, color: color);

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('users.php?action=list');
      if (mounted) {
        setState(() {
          _users = (res['users'] as List? ?? [])
              .cast<Map<String, dynamic>>()
              .where((u) => u['role'] != 'admin' && u['role'] != 'superadmin')
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectUser(Map<String, dynamic> u) {
    final raw = u['permissions'];
    Map<String, bool> perms = {};
    if (raw is Map) {
      perms = raw.map((k, v) => MapEntry(k.toString(), v == true));
    }
    // Fill missing keys with false
    for (final p in _permsMeta) {
      perms.putIfAbsent(p['key'] as String, () => false);
    }
    setState(() {
      _selectedUser = u;
      _editPerms = perms;
      _saved = false;
    });
  }

  Future<void> _savePerms() async {
    if (_selectedUser == null) return;
    setState(() => _saving = true);
    try {
      await ApiService.post('users.php?action=save_permissions', {
        'uid': _selectedUser!['uid'],
        'permissions': _editPerms,
      });
      // Update local list
      final idx = _users.indexWhere((u) => u['uid'] == _selectedUser!['uid']);
      if (idx != -1) _users[idx] = {..._users[idx], 'permissions': Map.from(_editPerms)};
      if (mounted) setState(() { _saving = false; _saved = true; });
      Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _saved = false); });
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _users;
    final q = _search.toLowerCase();
    return _users.where((u) =>
      (u['name'] ?? '').toString().toLowerCase().contains(q) ||
      (u['emp_id'] ?? u['empId'] ?? '').toString().contains(q) ||
      (u['dept'] ?? '').toString().contains(q)
    ).toList();
  }

  int _permCount(Map<String, dynamic> u) {
    final raw = u['permissions'];
    if (raw is Map) return raw.values.where((v) => v == true).length;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));

    return isWide ? _wideLayout() : _mobileLayout();
  }

  // ══════ WIDE: side by side ══════
  Widget _wideLayout() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        _header(),
        const SizedBox(height: 24),
        Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Left: permissions panel
          if (_selectedUser != null)
            Expanded(flex: 5, child: _permsPanel()),
          if (_selectedUser != null) const SizedBox(width: 16),
          // Right: employee list
          Expanded(flex: 4, child: _employeeList()),
        ])),
      ]),
    );
  }

  // ══════ MOBILE: stacked ══════
  Widget _mobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _header(),
        const SizedBox(height: 16),
        _employeeList(),
        if (_selectedUser != null) ...[const SizedBox(height: 16), _permsPanel()],
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _header() {
    return Row(children: [
      const Spacer(),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('إدارة الصلاحيات', style: _tj(20, w: FontWeight.w800, color: C.text)),
        Text('اختر موظفاً لتعديل صلاحياته', style: _tj(11, color: C.muted)),
      ]),
    ]);
  }

  // ══════ EMPLOYEE LIST ══════
  Widget _employeeList() {
    final list = _filtered;
    return Container(
      decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.div)), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          child: Row(children: [
            Text('${_users.length} موظف', style: _tj(11, color: C.muted)),
            const Spacer(),
            Text('الموظفون', style: _tj(15, w: FontWeight.w800, color: C.text)),
            const SizedBox(width: 8),
            Container(width: 32, height: 32, decoration: BoxDecoration(color: C.priLight, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.people_rounded, size: 16, color: C.pri)),
          ]),
        ),
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Container(
            height: 40,
            decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              textAlign: TextAlign.right,
              style: _tj(13, color: C.text),
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو القسم...',
                hintStyle: _tj(12, color: C.hint),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: const Icon(Icons.search_rounded, size: 18, color: C.hint),
              ),
            ),
          ),
        ),
        // List
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 480),
          child: list.isEmpty
            ? Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.search_off_rounded, size: 36, color: C.hint),
                const SizedBox(height: 8),
                Text('لا يوجد نتائج', style: _tj(13, color: C.muted)),
              ]))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (_, i) => _empTile(list[i]),
              ),
        ),
      ]),
    );
  }

  Widget _empTile(Map<String, dynamic> u) {
    final name = (u['name'] ?? '').toString();
    final initials = name.length >= 2 ? name.substring(0, 2) : (name.isNotEmpty ? name[0] : 'م');
    final isSelected = _selectedUser?['uid'] == u['uid'];
    final count = _permCount(u);

    return GestureDetector(
      onTap: () => _selectUser(u),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? C.priLight : Colors.transparent,
          border: const Border(top: BorderSide(color: C.div)),
        ),
        child: Row(children: [
          // Permission count badge
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: C.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text('$count', style: _tj(10, w: FontWeight.w700, color: C.green)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(20)),
              child: Text('—', style: _tj(10, color: C.hint)),
            ),
          const Spacer(),
          Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(name, style: _tj(13, w: FontWeight.w600, color: isSelected ? C.pri : C.text), overflow: TextOverflow.ellipsis),
            Text('${u['dept'] ?? ''} · ${u['emp_id'] ?? u['empId'] ?? ''}', style: _tj(10, color: C.muted), overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 17,
            backgroundColor: isSelected ? C.pri : C.div,
            child: Text(initials, style: _tj(11, w: FontWeight.w700, color: isSelected ? Colors.white : C.sub)),
          ),
        ]),
      ),
    );
  }

  // ══════ PERMISSIONS PANEL ══════
  Widget _permsPanel() {
    final u = _selectedUser!;
    final name = (u['name'] ?? '').toString();
    final initials = name.length >= 2 ? name.substring(0, 2) : (name.isNotEmpty ? name[0] : 'م');
    final enabledCount = _editPerms.values.where((v) => v).length;

    return Container(
      decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        // User info header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: C.div)),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            // Save button
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _saving
                ? const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 2))
                : GestureDetector(
                    key: ValueKey(_saved),
                    onTap: _savePerms,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _saved ? C.green : C.pri,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_saved ? Icons.check_rounded : Icons.save_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(_saved ? 'تم الحفظ' : 'حفظ', style: _tj(12, w: FontWeight.w700, color: Colors.white)),
                      ]),
                    ),
                  ),
            ),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(name, style: _tj(15, w: FontWeight.w700, color: C.text)),
              Text('${u['dept'] ?? ''} — $enabledCount صلاحية مفعّلة', style: _tj(11, color: C.muted)),
            ]),
            const SizedBox(width: 10),
            CircleAvatar(radius: 20, backgroundColor: C.priLight,
              child: Text(initials, style: _tj(13, w: FontWeight.w700, color: C.pri))),
          ]),
        ),

        // Permissions rows
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          child: Column(children: _permsMeta.map((p) {
            final key = p['key'] as String;
            final isDanger = p['dangerColor'] as bool;
            final on = _editPerms[key] ?? false;
            final activeColor = isDanger ? C.red : C.green;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: on ? activeColor.withValues(alpha: 0.06) : C.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: on ? activeColor.withValues(alpha: 0.2) : C.div),
                ),
                child: Row(children: [
                  Transform.scale(
                    scale: 0.82,
                    child: Switch(
                      value: on,
                      activeColor: activeColor,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) => setState(() => _editPerms[key] = v),
                    ),
                  ),
                  const Spacer(),
                  Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(p['label'] as String, style: _tj(13, w: FontWeight.w600, color: on ? C.text : C.muted)),
                    Text(p['sub'] as String, style: _tj(10, color: C.hint), overflow: TextOverflow.ellipsis),
                  ])),
                  const SizedBox(width: 10),
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: on ? activeColor.withValues(alpha: 0.1) : C.div,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(p['icon'] as IconData, size: 15, color: on ? activeColor : C.hint),
                  ),
                ]),
              ),
            );
          }).toList()),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}
