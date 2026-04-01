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

  // ═══ كل صفحة في النظام = صلاحية مستقلة ═══
  static const _sections = [
    {
      'title': 'الرئيسية',
      'color': 0xFF1D4ED8,
      'icon': Icons.home_rounded,
      'perms': [
        {'key': 'dashboard', 'label': 'لوحة التحكم', 'sub': 'عرض الإحصائيات العامة والحضور اليومي', 'icon': Icons.speed_rounded},
      ],
    },
    {
      'title': 'الموظفون',
      'color': 0xFF0891B2,
      'icon': Icons.people_rounded,
      'perms': [
        {'key': 'employees',  'label': 'سجل الموظفين',      'sub': 'عرض قائمة الموظفين وسجلات حضورهم',       'icon': Icons.people_alt_rounded},
        {'key': 'usermgmt',   'label': 'إدارة المستخدمين',  'sub': 'إضافة وتعديل وحذف حسابات المستخدمين',    'icon': Icons.manage_accounts_rounded},
        {'key': 'roles',      'label': 'الصلاحيات',         'sub': 'تعديل صلاحيات المستخدمين',               'icon': Icons.vpn_key_rounded},
      ],
    },
    {
      'title': 'الحضور والانصراف',
      'color': 0xFF7C3AED,
      'icon': Icons.fingerprint_rounded,
      'perms': [
        {'key': 'verify',     'label': 'إثبات الحالة',      'sub': 'إرسال طلبات التحقق من حضور الموظف',      'icon': Icons.wifi_tethering_rounded},
        {'key': 'overtime',   'label': 'الأوفرتايم',        'sub': 'عرض وإدارة ساعات العمل الإضافية',        'icon': Icons.more_time_rounded},
        {'key': 'schedules',  'label': 'الجداول والإجازات', 'sub': 'إنشاء وتعديل جداول العمل والإجازات',     'icon': Icons.calendar_month_rounded},
        {'key': 'requests',   'label': 'الطلبات',           'sub': 'مراجعة وقبول ورفض طلبات الموظفين',       'icon': Icons.task_alt_rounded},
      ],
    },
    {
      'title': 'التقارير والمراقبة',
      'color': 0xFF059669,
      'icon': Icons.analytics_rounded,
      'perms': [
        {'key': 'reports',       'label': 'التقارير',         'sub': 'عرض وتصدير تقارير الحضور والأداء',       'icon': Icons.bar_chart_rounded},
        {'key': 'devices',       'label': 'مراقبة الأجهزة',  'sub': 'عرض أجهزة تسجيل الدخول ومراقبتها',      'icon': Icons.devices_rounded},
        {'key': 'notifications', 'label': 'الإشعارات',       'sub': 'إرسال واستقبال إشعارات النظام',          'icon': Icons.notifications_rounded},
        {'key': 'audit',         'label': 'سجل التدقيق',     'sub': 'عرض سجل جميع العمليات في النظام',        'icon': Icons.history_rounded},
      ],
    },
    {
      'title': 'النظام',
      'color': 0xFFDC2626,
      'icon': Icons.settings_rounded,
      'perms': [
        {'key': 'settings', 'label': 'الإعدادات', 'sub': 'تعديل إعدادات التطبيق والشركة والموقع', 'icon': Icons.tune_rounded},
        {'key': 'delete',   'label': 'صلاحية الحذف', 'sub': 'حذف السجلات والبيانات والمستخدمين', 'icon': Icons.delete_forever_rounded},
      ],
    },
  ];

  // All permission keys flat list
  static List<String> get _allKeys => _sections
      .expand((s) => (s['perms'] as List).map((p) => p['key'] as String))
      .toList();

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
    final saved = raw is Map ? Map<String, bool>.from(raw.map((k, v) => MapEntry(k.toString(), v == true))) : <String, bool>{};
    final perms = <String, bool>{};
    for (final key in _allKeys) perms[key] = saved[key] ?? false;
    setState(() { _selectedUser = u; _editPerms = perms; _saved = false; });
  }

  Future<void> _savePerms() async {
    if (_selectedUser == null) return;
    setState(() => _saving = true);
    try {
      await ApiService.post('users.php?action=save_permissions', {
        'uid': _selectedUser!['uid'],
        'permissions': _editPerms,
      });
      final idx = _users.indexWhere((u) => u['uid'] == _selectedUser!['uid']);
      if (idx != -1) _users[idx] = {..._users[idx], 'permissions': Map.from(_editPerms)};
      if (mounted) setState(() { _saving = false; _saved = true; });
      Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _saved = false); });
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleSection(List perms, bool value) {
    setState(() { for (final p in perms) _editPerms[p['key'] as String] = value; });
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
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    final isWide = MediaQuery.of(context).size.width > 700;
    return isWide ? _wideLayout() : _mobileLayout();
  }

  Widget _wideLayout() => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      _header(),
      const SizedBox(height: 20),
      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_selectedUser != null) ...[
          Expanded(flex: 6, child: _permsPanel()),
          const SizedBox(width: 16),
        ],
        SizedBox(width: _selectedUser != null ? null : double.infinity,
          child: _selectedUser != null
            ? Expanded(flex: 4, child: _employeeList())
            : _employeeList()),
      ])),
    ]),
  );

  Widget _mobileLayout() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      _header(),
      const SizedBox(height: 16),
      _employeeList(),
      if (_selectedUser != null) ...[const SizedBox(height: 16), _permsPanel()],
      const SizedBox(height: 24),
    ]),
  );

  Widget _header() => Row(children: [
    const Spacer(),
    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('إدارة الصلاحيات', style: _tj(20, w: FontWeight.w800, color: C.text)),
      Text('اختر موظفاً لتحديد صلاحياته بالتفصيل', style: _tj(11, color: C.muted)),
    ]),
  ]);

  // ══════ EMPLOYEE LIST ══════
  Widget _employeeList() {
    final list = _filtered;
    return Container(
      decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
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
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 500),
          child: list.isEmpty
            ? Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.search_off_rounded, size: 36, color: C.hint),
                const SizedBox(height: 8),
                Text('لا يوجد نتائج', style: _tj(13, color: C.muted)),
              ]))
            : ListView.builder(shrinkWrap: true, itemCount: list.length,
                itemBuilder: (_, i) => _empTile(list[i])),
        ),
      ]),
    );
  }

  Widget _empTile(Map<String, dynamic> u) {
    final name = (u['name'] ?? '').toString();
    final initials = name.length >= 2 ? name.substring(0, 2) : (name.isNotEmpty ? name[0] : 'م');
    final isSelected = _selectedUser?['uid'] == u['uid'];
    final count = _permCount(u);
    final total = _allKeys.length;

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: count > 0 ? C.green.withValues(alpha: 0.1) : C.bg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(count > 0 ? '$count/$total' : '—', style: _tj(10, w: FontWeight.w700, color: count > 0 ? C.green : C.hint)),
          ),
          const Spacer(),
          Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(name, style: _tj(13, w: FontWeight.w600, color: isSelected ? C.pri : C.text), overflow: TextOverflow.ellipsis),
            Text('${u['dept'] ?? ''} · ${u['emp_id'] ?? u['empId'] ?? ''}', style: _tj(10, color: C.muted), overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 10),
          CircleAvatar(radius: 17, backgroundColor: isSelected ? C.pri : C.div,
            child: Text(initials, style: _tj(11, w: FontWeight.w700, color: isSelected ? Colors.white : C.sub))),
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
    final total = _allKeys.length;

    return Container(
      decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // User info + save
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.div)), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          child: Row(children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _saving
                ? const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 2))
                : GestureDetector(
                    key: ValueKey(_saved),
                    onTap: _savePerms,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(color: _saved ? C.green : C.pri, borderRadius: BorderRadius.circular(10)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_saved ? Icons.check_rounded : Icons.save_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(_saved ? 'تم الحفظ' : 'حفظ', style: _tj(13, w: FontWeight.w700, color: Colors.white)),
                      ]),
                    ),
                  ),
            ),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(name, style: _tj(15, w: FontWeight.w700, color: C.text)),
              Row(children: [
                Text('$enabledCount من $total صلاحية مفعّلة', style: _tj(11, color: C.muted)),
                const SizedBox(width: 6),
                Container(width: 60, height: 4, decoration: BoxDecoration(color: C.div, borderRadius: BorderRadius.circular(2)),
                  child: FractionallySizedBox(alignment: Alignment.centerRight, widthFactor: total > 0 ? enabledCount / total : 0,
                    child: Container(decoration: BoxDecoration(color: C.pri, borderRadius: BorderRadius.circular(2))))),
              ]),
            ]),
            const SizedBox(width: 10),
            CircleAvatar(radius: 20, backgroundColor: C.priLight,
              child: Text(initials, style: _tj(13, w: FontWeight.w700, color: C.pri))),
          ]),
        ),

        // Sections
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(children: _sections.map((section) {
              final sectionPerms = section['perms'] as List;
              final sectionColor = Color(section['color'] as int);
              final enabledInSection = sectionPerms.where((p) => _editPerms[p['key']] == true).length;
              final allEnabled = enabledInSection == sectionPerms.length;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: C.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.border),
                ),
                child: Column(children: [
                  // Section header with toggle-all
                  GestureDetector(
                    onTap: () => _toggleSection(sectionPerms, !allEnabled),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: enabledInSection > 0 ? sectionColor.withValues(alpha: 0.06) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        // Toggle all in section
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: allEnabled ? sectionColor.withValues(alpha: 0.12) : C.div,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(allEnabled ? Icons.check_rounded : Icons.remove_rounded, size: 14, color: allEnabled ? sectionColor : C.hint),
                        ),
                        const SizedBox(width: 8),
                        Text('$enabledInSection/${sectionPerms.length}', style: _tj(10, w: FontWeight.w600, color: enabledInSection > 0 ? sectionColor : C.hint)),
                        const Spacer(),
                        Text(section['title'] as String, style: _tj(13, w: FontWeight.w700, color: C.text)),
                        const SizedBox(width: 8),
                        Container(width: 28, height: 28, decoration: BoxDecoration(color: sectionColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(7)),
                          child: Icon(section['icon'] as IconData, size: 14, color: sectionColor)),
                      ]),
                    ),
                  ),
                  // Perm rows
                  ...sectionPerms.map((p) {
                    final key = p['key'] as String;
                    final isDanger = key == 'delete';
                    final on = _editPerms[key] ?? false;
                    final activeColor = isDanger ? C.red : sectionColor;

                    return Container(
                      margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                      decoration: BoxDecoration(
                        color: on ? activeColor.withValues(alpha: 0.05) : C.white,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: on ? activeColor.withValues(alpha: 0.2) : C.div),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(9),
                        onTap: () => setState(() => _editPerms[key] = !on),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          child: Row(children: [
                            Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: on,
                                activeColor: activeColor,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onChanged: (v) => setState(() => _editPerms[key] = v),
                              ),
                            ),
                            const Spacer(),
                            Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text(p['label'] as String, style: _tj(12, w: FontWeight.w600, color: on ? C.text : C.muted)),
                              Text(p['sub'] as String, style: _tj(10, color: C.hint), overflow: TextOverflow.ellipsis),
                            ])),
                            const SizedBox(width: 8),
                            Container(width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: on ? activeColor.withValues(alpha: 0.1) : C.div,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(p['icon'] as IconData, size: 15, color: on ? activeColor : C.hint)),
                          ]),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 2),
                ]),
              );
            }).toList()),
          ),
        ),
      ]),
    );
  }
}
