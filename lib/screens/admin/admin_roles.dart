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
  String _selectedRole = 'admin';
  bool _saved = false;
  bool _loading = true;
  List<Map<String, dynamic>> _users = [];

  static const _rolesMeta = {
    'admin': {
      'name': 'مدير النظام',
      'nameEn': 'Administrator',
      'color': 0xFFDC2626,
      'bgColor': 0xFFFEF2F2,
      'icon': Icons.shield_rounded,
      'desc': 'صلاحيات كاملة على جميع أقسام النظام',
    },
    'moderator': {
      'name': 'مشرف',
      'nameEn': 'Moderator',
      'color': 0xFF7C3AED,
      'bgColor': 0xFFF5F3FF,
      'icon': Icons.manage_accounts_rounded,
      'desc': 'إدارة الحضور والطلبات بدون صلاحيات الحذف',
    },
    'employee': {
      'name': 'موظف',
      'nameEn': 'Employee',
      'color': 0xFF1D4ED8,
      'bgColor': 0xFFEFF6FF,
      'icon': Icons.person_rounded,
      'desc': 'عرض البيانات الشخصية وتقديم الطلبات فقط',
    },
  };

  static const _permsMeta = [
    {'key': 'users',    'label': 'إدارة المستخدمين', 'sub': 'إضافة وتعديل حسابات الموظفين',  'icon': Icons.people_alt_rounded},
    {'key': 'settings', 'label': 'إعدادات النظام',   'sub': 'تعديل إعدادات التطبيق والشركة',  'icon': Icons.tune_rounded},
    {'key': 'reports',  'label': 'التقارير',          'sub': 'عرض وتصدير تقارير الحضور',        'icon': Icons.bar_chart_rounded},
    {'key': 'requests', 'label': 'إدارة الطلبات',    'sub': 'قبول ورفض طلبات الإجازات',       'icon': Icons.task_alt_rounded},
    {'key': 'verify',   'label': 'إثبات الحالة',     'sub': 'طلب التحقق من حضور الموظف',      'icon': Icons.wifi_tethering_rounded},
    {'key': 'delete',   'label': 'صلاحية الحذف',     'sub': 'حذف السجلات والمستخدمين',        'icon': Icons.delete_rounded},
  ];

  final Map<String, Map<String, bool>> _perms = {
    'admin':     {'users': true,  'settings': true,  'reports': true,  'requests': true,  'verify': true,  'delete': true},
    'moderator': {'users': false, 'settings': false, 'reports': true,  'requests': true,  'verify': true,  'delete': false},
    'employee':  {'users': false, 'settings': false, 'reports': false, 'requests': false, 'verify': false, 'delete': false},
  };

  TextStyle _tj(double size, {FontWeight w = FontWeight.w400, Color? color}) =>
      GoogleFonts.tajawal(fontSize: size, fontWeight: w, color: color);

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final settingsRes = await ApiService.get('admin.php?action=get_settings');
      if (settingsRes['success'] == true) {
        final s = settingsRes['settings'] as Map<String, dynamic>? ?? {};
        for (final role in ['admin', 'moderator', 'employee']) {
          final rp = s['perms_$role'];
          if (rp is Map) _perms[role] = Map<String, bool>.from(rp.map((k, v) => MapEntry(k.toString(), v == true)));
        }
      }
      final usersRes = await ApiService.get('users.php?action=list');
      if (mounted) {
        setState(() {
          if (usersRes['success'] == true) _users = (usersRes['users'] as List? ?? []).cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _save() async {
    try {
      final map = <String, dynamic>{};
      for (final role in ['admin', 'moderator', 'employee']) map['perms_$role'] = _perms[role];
      await ApiService.post('admin.php?action=save_settings', {'settings': map});
      if (mounted) {
        setState(() => _saved = true);
        Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _saved = false); });
      }
    } catch (_) {}
  }

  Future<void> _changeRole(String uid, String role) async {
    await ApiService.post('users.php?action=update', {'uid': uid, 'role': role});
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    final isWide = MediaQuery.of(context).size.width > 800;
    final meta = _rolesMeta[_selectedRole]!;
    final roleColor = Color(meta['color'] as int);
    final activePerms = _perms[_selectedRole]!;
    final roleUsers = _users.where((u) => u['role'] == _selectedRole).toList();
    final otherUsers = _users.where((u) => u['role'] != _selectedRole && u['role'] != 'superadmin').toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isWide ? 28 : 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [

          // ══════════ HEADER ══════════
          Row(children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: ElevatedButton.icon(
                key: ValueKey(_saved),
                onPressed: _save,
                icon: Icon(_saved ? Icons.check_rounded : Icons.save_rounded, size: 16),
                label: Text(_saved ? 'تم الحفظ' : 'حفظ التغييرات', style: _tj(13, w: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _saved ? C.green : C.pri,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('إدارة الصلاحيات', style: _tj(isWide ? 22 : 18, w: FontWeight.w800, color: C.text)),
              Text('تحكم في صلاحيات كل دور في النظام', style: _tj(11, color: C.muted)),
            ]),
          ]),
          const SizedBox(height: 24),

          // ══════════ ROLE TABS ══════════
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
            child: Row(children: _rolesMeta.entries.map((e) {
              final key = e.key; final m = e.value;
              final on = _selectedRole == key;
              final c = Color(m['color'] as int);
              final count = _users.where((u) => u['role'] == key).length;
              return Expanded(child: GestureDetector(
                onTap: () => setState(() => _selectedRole = key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: on ? Color(m['bgColor'] as int) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: on ? Border.all(color: c.withValues(alpha: 0.3)) : null,
                  ),
                  child: Column(children: [
                    Icon(m['icon'] as IconData, size: 20, color: on ? c : C.muted),
                    const SizedBox(height: 4),
                    Text(m['name'] as String, style: _tj(11, w: FontWeight.w700, color: on ? c : C.muted)),
                    Text('$count مستخدم', style: _tj(9, color: on ? c.withValues(alpha: 0.7) : C.hint)),
                  ]),
                ),
              ));
            }).toList()),
          ),
          const SizedBox(height: 8),

          // Role description strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Color(meta['bgColor'] as int),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: roleColor.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 14, color: roleColor.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
              Expanded(child: Text(meta['desc'] as String, style: _tj(11, color: roleColor.withValues(alpha: 0.85)), textAlign: TextAlign.end)),
            ]),
          ),
          const SizedBox(height: 20),

          // ══════════ MAIN CONTENT ══════════
          if (isWide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 5, child: _permissionsPanel(roleColor, activePerms)),
              const SizedBox(width: 16),
              Expanded(flex: 4, child: Column(children: [
                _usersPanel(roleUsers, roleColor, meta['name'] as String),
                if (_selectedRole != 'employee') ...[const SizedBox(height: 14), _assignPanel(otherUsers, roleColor, meta['name'] as String)],
              ])),
            ])
          else ...[
            _permissionsPanel(roleColor, activePerms),
            const SizedBox(height: 14),
            _usersPanel(roleUsers, roleColor, meta['name'] as String),
            if (_selectedRole != 'employee') ...[const SizedBox(height: 14), _assignPanel(otherUsers, roleColor, meta['name'] as String)],
          ],

          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  // ══════════ PERMISSIONS PANEL ══════════
  Widget _permissionsPanel(Color roleColor, Map<String, bool> perms) {
    return Container(
      decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        // Panel header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            border: const Border(bottom: BorderSide(color: C.div)),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text('${perms.values.where((v) => v).length} / ${perms.length}', style: _tj(11, w: FontWeight.w700, color: roleColor)),
            ),
            const Spacer(),
            Text('الصلاحيات', style: _tj(15, w: FontWeight.w800, color: C.text)),
            const SizedBox(width: 8),
            Container(width: 32, height: 32, decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.vpn_key_rounded, size: 15, color: roleColor)),
          ]),
        ),

        // Perm rows
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: _permsMeta.map((p) {
            final key = p['key'] as String;
            final on = perms[key] ?? false;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: on ? (p['icon'] == Icons.delete_rounded ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4)) : C.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Transform.scale(
                    scale: 0.85,
                    child: Switch(
                      value: on,
                      activeColor: key == 'delete' ? C.red : C.green,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) => setState(() => _perms[_selectedRole]![key] = v),
                    ),
                  ),
                  const Spacer(),
                  Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(p['label'] as String, style: _tj(13, w: FontWeight.w600, color: on ? C.text : C.muted)),
                    Text(p['sub'] as String, style: _tj(10, color: C.hint), overflow: TextOverflow.ellipsis),
                  ])),
                  const SizedBox(width: 10),
                  Container(width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: on ? (key == 'delete' ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7)) : C.div,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(p['icon'] as IconData, size: 15, color: on ? (key == 'delete' ? C.red : C.green) : C.hint)),
                ]),
              ),
            );
          }).toList()),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  // ══════════ USERS IN ROLE ══════════
  Widget _usersPanel(List<Map<String, dynamic>> users, Color roleColor, String roleName) {
    return Container(
      decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.div)), borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
          child: Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(20)),
              child: Text('${users.length}', style: _tj(11, w: FontWeight.w700, color: C.sub))),
            const Spacer(),
            Text('مستخدمو "$roleName"', style: _tj(14, w: FontWeight.w800, color: C.text)),
            const SizedBox(width: 8),
            Container(width: 32, height: 32, decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.group_rounded, size: 15, color: roleColor)),
          ]),
        ),
        if (users.isEmpty)
          Padding(padding: const EdgeInsets.all(28), child: Column(children: [
            Icon(Icons.person_off_outlined, size: 36, color: C.hint),
            const SizedBox(height: 8),
            Text('لا يوجد مستخدمون في هذا الدور', style: _tj(12, color: C.muted)),
          ]))
        else
          ...users.map((u) => _userRow(u, roleColor, canRemove: _selectedRole != 'admin')),
      ]),
    );
  }

  // ══════════ ASSIGN TO ROLE ══════════
  Widget _assignPanel(List<Map<String, dynamic>> others, Color roleColor, String roleName) {
    return Container(
      decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: roleColor.withValues(alpha: 0.35))),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: roleColor.withValues(alpha: 0.04),
            border: const Border(bottom: BorderSide(color: C.div)),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            const Spacer(),
            Text('إضافة مستخدمين إلى "$roleName"', style: _tj(14, w: FontWeight.w800, color: C.text)),
            const SizedBox(width: 8),
            Container(width: 32, height: 32, decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.person_add_rounded, size: 15, color: roleColor)),
          ]),
        ),
        if (others.isEmpty)
          Padding(padding: const EdgeInsets.all(24), child: Text('لا يوجد مستخدمون متاحون للإضافة', style: _tj(12, color: C.muted)))
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView(shrinkWrap: true, children: others.map((u) => _userRow(u, roleColor, canAdd: true)).toList()),
          ),
      ]),
    );
  }

  Widget _userRow(Map<String, dynamic> u, Color roleColor, {bool canRemove = false, bool canAdd = false}) {
    final name = (u['name'] ?? '').toString();
    final initials = name.length >= 2 ? name.substring(0, 2) : (name.isNotEmpty ? name[0] : 'م');
    final isFirst = canRemove
        ? _users.where((x) => x['role'] == _selectedRole).first == u
        : canAdd
            ? _users.where((x) => x['role'] != _selectedRole && x['role'] != 'superadmin').first == u
            : false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(border: isFirst ? null : const Border(top: BorderSide(color: C.div))),
      child: Row(children: [
        if (canRemove)
          GestureDetector(
            onTap: () => _changeRole(u['uid'] ?? u['id'] ?? '', 'employee'),
            child: Container(width: 30, height: 30, decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFECDCA))),
              child: const Icon(Icons.remove_rounded, size: 14, color: C.red)),
          )
        else if (canAdd)
          GestureDetector(
            onTap: () => _changeRole(u['uid'] ?? u['id'] ?? '', _selectedRole),
            child: Container(width: 30, height: 30, decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFBBF7D0))),
              child: const Icon(Icons.add_rounded, size: 14, color: C.green)),
          ),
        const Spacer(),
        Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(name, style: _tj(13, w: FontWeight.w600, color: C.text), overflow: TextOverflow.ellipsis),
          Text('${u['dept'] ?? ''} · ${u['empId'] ?? u['emp_id'] ?? ''}', style: _tj(10, color: C.muted), overflow: TextOverflow.ellipsis),
        ])),
        const SizedBox(width: 10),
        CircleAvatar(radius: 17, backgroundColor: roleColor.withValues(alpha: 0.12),
          child: Text(initials, style: _tj(11, w: FontWeight.w700, color: roleColor))),
      ]),
    );
  }
}
