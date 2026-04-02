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
  bool _listVisible = true;

  static const _sections = [
    {
      'title': 'الرئيسية',
      'color': 0xFF1D4ED8,
      'icon': Icons.home_rounded,
      'perms': [
        {'key': 'dashboard', 'label': 'لوحة التحكم', 'icon': Icons.speed_rounded},
      ],
    },
    {
      'title': 'الموظفون',
      'color': 0xFF0891B2,
      'icon': Icons.people_rounded,
      'perms': [
        {'key': 'employees', 'label': 'سجل الموظفين',     'icon': Icons.people_alt_rounded},
        {'key': 'usermgmt',  'label': 'إدارة المستخدمين', 'icon': Icons.manage_accounts_rounded},
        {'key': 'roles',     'label': 'الصلاحيات',        'icon': Icons.vpn_key_rounded},
      ],
    },
    {
      'title': 'الحضور والانصراف',
      'color': 0xFF7C3AED,
      'icon': Icons.fingerprint_rounded,
      'perms': [
        {'key': 'verify',    'label': 'إثبات الحالة',      'icon': Icons.wifi_tethering_rounded},
        {'key': 'overtime',  'label': 'الأوفرتايم',        'icon': Icons.more_time_rounded},
        {'key': 'schedules', 'label': 'الجداول والإجازات', 'icon': Icons.calendar_month_rounded},
        {'key': 'requests',  'label': 'الطلبات',           'icon': Icons.task_alt_rounded},
      ],
    },
    {
      'title': 'التقارير والمراقبة',
      'color': 0xFF059669,
      'icon': Icons.analytics_rounded,
      'perms': [
        {'key': 'reports',       'label': 'التقارير',        'icon': Icons.bar_chart_rounded},
        {'key': 'devices',       'label': 'مراقبة الأجهزة', 'icon': Icons.devices_rounded},
        {'key': 'notifications', 'label': 'الإشعارات',      'icon': Icons.notifications_rounded},
        {'key': 'audit',         'label': 'سجل التدقيق',    'icon': Icons.history_rounded},
      ],
    },
    {
      'title': 'النظام',
      'color': 0xFFDC2626,
      'icon': Icons.settings_rounded,
      'perms': [
        {'key': 'settings', 'label': 'الإعدادات',      'icon': Icons.tune_rounded},
        {'key': 'delete',   'label': 'صلاحية الحذف',   'icon': Icons.delete_forever_rounded},
      ],
    },
  ];

  static List<String> get _allKeys =>
      _sections.expand((s) => (s['perms'] as List).map((p) => p['key'] as String)).toList();

  TextStyle _tj(double s, {FontWeight w = FontWeight.w400, Color? color}) =>
      GoogleFonts.tajawal(fontSize: s, fontWeight: w, color: color);

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('users.php?action=list');
      if (mounted) setState(() {
        _users = (res['users'] as List? ?? []).cast<Map<String, dynamic>>()
            .where((u) => u['role'] != 'admin' && u['role'] != 'superadmin').toList();
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _selectUser(Map<String, dynamic> u) {
    final raw = u['permissions'];
    final saved = raw is Map
        ? Map<String, bool>.from(raw.map((k, v) => MapEntry(k.toString(), v == true)))
        : <String, bool>{};
    final perms = {for (final k in _allKeys) k: saved[k] ?? false};
    setState(() { _selectedUser = u; _editPerms = perms; _saved = false; });
  }

  Future<void> _savePerms() async {
    if (_selectedUser == null) return;
    setState(() => _saving = true);
    try {
      await ApiService.post('users.php?action=save_permissions', {
        'uid': _selectedUser!['uid'], 'permissions': _editPerms,
      });
      final idx = _users.indexWhere((u) => u['uid'] == _selectedUser!['uid']);
      if (idx != -1) _users[idx] = {..._users[idx], 'permissions': Map.from(_editPerms)};
      if (mounted) setState(() { _saving = false; _saved = true; });
      Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _saved = false); });
    } catch (_) { if (mounted) setState(() => _saving = false); }
  }

  int _permCount(Map<String, dynamic> u) {
    final raw = u['permissions'];
    return raw is Map ? raw.values.where((v) => v == true).length : 0;
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _users;
    final q = _search.toLowerCase();
    return _users.where((u) =>
      (u['name'] ?? '').toString().toLowerCase().contains(q) ||
      (u['emp_id'] ?? u['empId'] ?? '').toString().contains(q) ||
      (u['dept'] ?? '').toString().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    final isWide = MediaQuery.of(context).size.width > 700;

    if (isWide) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _header(),
          const SizedBox(height: 20),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Permissions panel (left) ──
              Expanded(
                child: _selectedUser == null ? _emptyState() : _permsPanel(),
              ),
              if (_listVisible) ...[
                const SizedBox(width: 16),
                SizedBox(width: 290, child: _employeeList()),
              ],
            ]),
          ),
        ]),
      );
    }

    // Mobile
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

  Widget _header() => Align(
    alignment: Alignment.centerRight,
    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('إدارة الصلاحيات', style: _tj(20, w: FontWeight.w800, color: W.text)),
      Text('اضغط على موظف لتحديد صلاحياته', style: _tj(11, color: W.muted)),
    ]),
  );

  Widget _emptyState() => Container(
    decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 64, height: 64, decoration: BoxDecoration(color: W.priLight, borderRadius: BorderRadius.circular(18)),
        child: Icon(Icons.vpn_key_rounded, size: 30, color: W.pri)),
      const SizedBox(height: 16),
      Text('اختر موظفاً من القائمة', style: _tj(16, w: FontWeight.w700, color: W.text)),
      const SizedBox(height: 6),
      Text('ستظهر هنا صلاحياته للتعديل', style: _tj(12, color: W.muted)),
    ])),
  );

  // ══════ EMPLOYEE LIST ══════
  Widget _employeeList() {
    final list = _filtered;
    return Container(
      decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(10, 11, 14, 11),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: W.div)), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          child: Row(children: [
            GestureDetector(
              onTap: () => setState(() => _listVisible = !_listVisible),
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(7), border: Border.all(color: W.border)),
                child: Icon(_listVisible ? Icons.remove_rounded : Icons.add_rounded, size: 14, color: W.sub),
              ),
            ),
            const SizedBox(width: 6),
            Text('${_users.length}', style: _tj(11, color: W.muted)),
            const Spacer(),
            Text('الموظفون', style: _tj(14, w: FontWeight.w800, color: W.text)),
            const SizedBox(width: 8),
            Container(width: 30, height: 30, decoration: BoxDecoration(color: W.priLight, borderRadius: BorderRadius.circular(4)),
              child: Icon(Icons.people_rounded, size: 15, color: W.pri)),
          ]),
        ),
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          child: Container(
            height: 38,
            decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(9), border: Border.all(color: W.border)),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              textAlign: TextAlign.right,
              style: _tj(12, color: W.text),
              decoration: InputDecoration(
                hintText: 'بحث...',
                hintStyle: _tj(12, color: W.hint),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                suffixIcon: Icon(Icons.search_rounded, size: 16, color: W.hint),
              ),
            ),
          ),
        ),
        // List
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 520),
          child: list.isEmpty
            ? Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.search_off_rounded, size: 32, color: W.hint),
                const SizedBox(height: 8),
                Text('لا يوجد نتائج', style: _tj(12, color: W.muted)),
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

    return GestureDetector(
      onTap: () => _selectUser(u),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? W.priLight : Colors.transparent,
          border: Border(top: BorderSide(color: W.div)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: count > 0 ? W.green.withValues(alpha: 0.1) : W.bg, borderRadius: BorderRadius.circular(20)),
            child: Text(count > 0 ? '$count' : '—', style: _tj(10, w: FontWeight.w700, color: count > 0 ? W.green : W.hint)),
          ),
          const Spacer(),
          Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(name, style: _tj(13, w: FontWeight.w600, color: isSelected ? W.pri : W.text), overflow: TextOverflow.ellipsis),
            Text('${u['dept'] ?? ''} · ${u['emp_id'] ?? u['empId'] ?? ''}', style: _tj(10, color: W.muted), overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 8),
          CircleAvatar(radius: 16, backgroundColor: isSelected ? W.pri : W.div,
            child: Text(initials, style: _tj(11, w: FontWeight.w700, color: isSelected ? Colors.white : W.sub))),
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
      decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
      child: Column(children: [
        // ── Header ──
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: W.div)), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          child: Row(children: [
            // Save
            _saving
              ? const SizedBox(width: 34, height: 34, child: CircularProgressIndicator(strokeWidth: 2))
              : GestureDetector(
                  onTap: _savePerms,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: _saved ? W.green : W.pri, borderRadius: BorderRadius.circular(9)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_saved ? Icons.check_rounded : Icons.save_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(_saved ? 'تم الحفظ' : 'حفظ', style: _tj(12, w: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
                ),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(name, style: _tj(14, w: FontWeight.w700, color: W.text)),
              Text('$enabledCount / $total صلاحية', style: _tj(11, color: W.muted)),
            ]),
            const SizedBox(width: 10),
            CircleAvatar(radius: 19, backgroundColor: W.priLight,
              child: Text(initials, style: _tj(12, w: FontWeight.w700, color: W.pri))),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() { _selectedUser = null; _editPerms = {}; }),
              child: Container(width: 28, height: 28, decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(4), border: Border.all(color: W.border)),
                child: Icon(Icons.close_rounded, size: 14, color: W.muted)),
            ),
          ]),
        ),

        // ── Sections grid ──
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _sections.map((section) => _sectionCard(section)).toList(),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _sectionCard(Map<String, dynamic> section) {
    final perms = section['perms'] as List;
    final color = Color(section['color'] as int);
    final enabledCount = perms.where((p) => _editPerms[p['key']] == true).length;
    final allOn = enabledCount == perms.length;

    return LayoutBuilder(builder: (ctx, constraints) {
      // On wide: 2 cards per row; otherwise full width
      final cardWidth = constraints.maxWidth > 500
          ? (constraints.maxWidth - 12) / 2
          : constraints.maxWidth;

      return SizedBox(
        width: cardWidth,
        child: Container(
          decoration: BoxDecoration(
            color: enabledCount > 0 ? color.withValues(alpha: 0.04) : W.bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: enabledCount > 0 ? color.withValues(alpha: 0.25) : W.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            // Section header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 8),
              child: Row(children: [
                // Toggle all
                GestureDetector(
                  onTap: () => setState(() { for (final p in perms) _editPerms[p['key'] as String] = !allOn; }),
                  child: Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(color: allOn ? color.withValues(alpha: 0.15) : W.div, borderRadius: BorderRadius.circular(7)),
                    child: Icon(allOn ? Icons.remove_rounded : Icons.add_rounded, size: 13, color: allOn ? color : W.hint),
                  ),
                ),
                const SizedBox(width: 6),
                Text('$enabledCount/${perms.length}', style: _tj(10, w: FontWeight.w600, color: enabledCount > 0 ? color : W.hint)),
                const Spacer(),
                Text(section['title'] as String, style: _tj(12, w: FontWeight.w700, color: W.text)),
                const SizedBox(width: 6),
                Container(width: 26, height: 26, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(7)),
                  child: Icon(section['icon'] as IconData, size: 13, color: color)),
              ]),
            ),
            Container(height: 1, color: W.div),
            // Perm items
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(children: perms.map((p) {
                final key = p['key'] as String;
                final isDanger = key == 'delete';
                final on = _editPerms[key] ?? false;
                final activeColor = isDanger ? W.red : color;
                return GestureDetector(
                  onTap: () => setState(() => _editPerms[key] = !on),
                  child: Container(
      
                    margin: const EdgeInsets.only(bottom: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: on ? activeColor.withValues(alpha: 0.08) : W.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: on ? activeColor.withValues(alpha: 0.25) : W.div),
                    ),
                    child: Row(children: [
                      Container(
          
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          color: on ? activeColor : W.div,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: on ? const Icon(Icons.check_rounded, size: 11, color: Colors.white) : null,
                      ),
                      const Spacer(),
                      Text(p['label'] as String, style: _tj(12, w: FontWeight.w600, color: on ? W.text : W.muted)),
                      const SizedBox(width: 8),
                      Container(width: 28, height: 28, decoration: BoxDecoration(color: on ? activeColor.withValues(alpha: 0.1) : W.div, borderRadius: BorderRadius.circular(7)),
                        child: Icon(p['icon'] as IconData, size: 13, color: on ? activeColor : W.hint)),
                    ]),
                  ),
                );
              }).toList()),
            ),
          ]),
        ),
      );
    });
  }
}
