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

  final _rolesMeta = const {
    'admin': {'name': 'مدير النظام', 'color': 0xFFF04438, 'desc': 'صلاحيات كاملة — إضافة/حذف/تعديل مستخدمين وإعدادات'},
    'moderator': {'name': 'مشرف', 'color': 0xFF7F56D9, 'desc': 'إدارة الحضور والطلبات بدون صلاحيات حذف أو إعدادات'},
    'employee': {'name': 'موظف', 'color': 0xFF175CD3, 'desc': 'عرض بياناته الشخصية وتقديم الطلبات فقط'},
  };

  final _permLabels = const {'users': 'إدارة المستخدمين', 'settings': 'الإعدادات', 'reports': 'التقارير', 'requests': 'إدارة الطلبات', 'verify': 'إثبات الحالة', 'delete': 'الحذف'};
  final _permIcons = const {'users': Icons.person_add, 'settings': Icons.settings, 'reports': Icons.insert_chart, 'requests': Icons.description, 'verify': Icons.wifi_tethering, 'delete': Icons.delete};

  final Map<String, Map<String, bool>> _perms = {
    'admin': {'users': true, 'settings': true, 'reports': true, 'requests': true, 'verify': true, 'delete': true},
    'moderator': {'users': false, 'settings': false, 'reports': true, 'requests': true, 'verify': true, 'delete': false},
    'employee': {'users': false, 'settings': false, 'reports': false, 'requests': false, 'verify': false, 'delete': false},
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final settingsRes = await ApiService.get('admin.php?action=get_settings');
      if (settingsRes['success'] == true) {
        final s = settingsRes['settings'] as Map<String, dynamic>? ?? {};
        // Load permissions from settings if saved
        for (final role in ['admin', 'moderator', 'employee']) {
          final rolePerms = s['perms_$role'];
          if (rolePerms is Map) {
            _perms[role] = Map<String, bool>.from(rolePerms.map((k, v) => MapEntry(k.toString(), v == true)));
          }
        }
      }
      final usersRes = await ApiService.get('users.php?action=list');
      if (usersRes['success'] == true && mounted) {
        setState(() {
          _users = (usersRes['users'] as List? ?? []).cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _save() async {
    try {
      final settingsMap = <String, dynamic>{};
      for (final role in ['admin', 'moderator', 'employee']) {
        settingsMap['perms_$role'] = _perms[role];
      }
      await ApiService.post('admin.php?action=save_settings', {'settings': settingsMap});
      setState(() => _saved = true);
      Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _saved = false); });
    } catch (_) {}
  }

  Future<void> _updateUserRole(String uid, String newRole) async {
    await ApiService.post('users.php?action=update', {'uid': uid, 'role': newRole});
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final meta = _rolesMeta[_selectedRole]!;
    final activeColor = Color(meta['color'] as int);
    final activeName = meta['name'] as String;
    final activePerms = _perms[_selectedRole]!;
    final isWide = MediaQuery.of(context).size.width > 800;

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    return SingleChildScrollView(padding: EdgeInsets.all(isWide ? 28 : 14), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      // Header
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        ElevatedButton.icon(onPressed: _save, icon: Icon(_saved ? Icons.check : Icons.save, size: 16), label: Text(_saved ? 'تم الحفظ' : 'حفظ', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)), style: ElevatedButton.styleFrom(backgroundColor: _saved ? C.green : C.pri, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
        Flexible(child: Text('إدارة الصلاحيات', style: GoogleFonts.tajawal(fontSize: isWide ? 24 : 18, fontWeight: FontWeight.w800, color: C.text))),
      ]),
      const SizedBox(height: 24),

      // Role cards — scrollable on mobile
      if (isWide)
        Row(children: _rolesMeta.entries.map((e) {
          final key = e.key; final m = e.value; final color = Color(m['color'] as int);
          final count = _users.where((u) => u['role'] == key).length; final on = _selectedRole == key;
          return Expanded(child: Padding(padding: EdgeInsets.only(left: key == 'employee' ? 0 : 14), child: _roleCard(key, m, color, count, on)));
        }).toList())
      else
        SizedBox(
          height: 140,
          child: ListView(scrollDirection: Axis.horizontal, children: _rolesMeta.entries.map((e) {
            final key = e.key; final m = e.value; final color = Color(m['color'] as int);
            final count = _users.where((u) => u['role'] == key).length; final on = _selectedRole == key;
            return Padding(padding: const EdgeInsets.only(left: 10), child: SizedBox(width: 170, child: _roleCard(key, m, color, count, on)));
          }).toList()),
        ),
      const SizedBox(height: 20),

      // Panels — side by side on web, stacked on mobile
      if (isWide)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(children: [
            _usersInRole(_users, activeColor, activeName),
            if (_selectedRole != 'employee') ...[const SizedBox(height: 14), _addUsersToRole(_users, activeColor, activeName)],
          ])),
          const SizedBox(width: 20),
          Expanded(child: _permissionsPanel(activeColor, activeName, activePerms)),
        ])
      else ...[
        _permissionsPanel(activeColor, activeName, activePerms),
        const SizedBox(height: 14),
        _usersInRole(_users, activeColor, activeName),
        if (_selectedRole != 'employee') ...[const SizedBox(height: 14), _addUsersToRole(_users, activeColor, activeName)],
      ],
    ]));
  }

  Widget _roleCard(String key, Map<String, dynamic> m, Color color, int count, bool on) {
    return InkWell(
      onTap: () => setState(() => _selectedRole = key),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: on ? color.withOpacity(0.06) : C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: on ? color : C.border, width: on ? 2 : 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.vpn_key, size: 16, color: color)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m['name'] as String, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: C.text), overflow: TextOverflow.ellipsis),
              Text('$count مستخدم', style: GoogleFonts.tajawal(fontSize: 10, color: C.muted)),
            ])),
          ]),
          const SizedBox(height: 6),
          Text(m['desc'] as String, style: GoogleFonts.tajawal(fontSize: 10, color: C.sub), maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  Widget _permissionsPanel(Color activeColor, String activeName, Map<String, bool> activePerms) {
    return Container(decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)), child: Column(children: [
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: activeColor.withOpacity(0.04), border: Border(bottom: BorderSide(color: C.div))), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Flexible(child: Text('صلاحيات: $activeName', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: C.text))),
          const SizedBox(width: 8),
          Container(width: 30, height: 30, decoration: BoxDecoration(color: activeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.vpn_key, size: 14, color: activeColor)),
        ]),
        const SizedBox(height: 4),
        Text('فعّل أو عطّل الصلاحيات لهذا الدور', style: GoogleFonts.tajawal(fontSize: 11, color: C.muted)),
      ])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Column(children: _permLabels.entries.map((p) {
        final on = activePerms[p.key] ?? false;
        return Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.div))), child: Row(children: [
          Switch(value: on, activeColor: C.green, onChanged: (v) => setState(() => _perms[_selectedRole]![p.key] = v)),
          const Spacer(),
          Text(p.value, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w500, color: C.text)),
          const SizedBox(width: 8),
          Container(width: 26, height: 26, decoration: BoxDecoration(color: on ? const Color(0xFFECFDF3) : C.div, borderRadius: BorderRadius.circular(7)), child: Icon(_permIcons[p.key], size: 12, color: on ? C.green : C.muted)),
        ]));
      }).toList())),
    ]));
  }

  Widget _usersInRole(List<Map<String, dynamic>> users, Color color, String name) {
    final roleUsers = users.where((u) => u['role'] == _selectedRole).toList();
    return Container(decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)), child: Column(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.div))), child: Row(children: [
        Text('${roleUsers.length} مستخدم', style: GoogleFonts.tajawal(fontSize: 12, color: C.muted)),
        const Spacer(),
        Flexible(child: Text('المستخدمين في دور "$name"', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: C.text))),
      ])),
      if (roleUsers.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text('لا يوجد مستخدمين في هذا الدور', style: GoogleFonts.tajawal(fontSize: 12, color: C.muted))),
      ...roleUsers.map((u) => Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.div))), child: Row(children: [
        InkWell(onTap: () => _updateUserRole(u['uid'] ?? u['id'] ?? '', 'employee'), child: Container(width: 26, height: 26, decoration: BoxDecoration(color: const Color(0xFFFEF3F2), borderRadius: BorderRadius.circular(7), border: Border.all(color: const Color(0xFFFECDCA))), child: const Icon(Icons.close, size: 11, color: C.red))),
        const Spacer(),
        Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(u['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: C.text), overflow: TextOverflow.ellipsis),
          Text('${u['dept'] ?? ''} — ${u['empId'] ?? ''}', style: GoogleFonts.tajawal(fontSize: 10, color: C.muted), overflow: TextOverflow.ellipsis),
        ])),
        const SizedBox(width: 8),
        CircleAvatar(radius: 16, backgroundColor: color.withOpacity(0.1), child: Text((u['name'] ?? 'م').toString().substring(0, 2), style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w700, color: color))),
      ]))),
    ]));
  }

  Widget _addUsersToRole(List<Map<String, dynamic>> users, Color color, String name) {
    final others = users.where((u) => u['role'] != _selectedRole).toList();
    return Container(decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: color)), child: Column(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: color.withOpacity(0.04), border: Border(bottom: BorderSide(color: C.div))), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('إضافة مستخدمين لدور "$name"', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: C.text)),
        Text('اضغط على + لإضافة الموظف لهذا الدور', style: GoogleFonts.tajawal(fontSize: 10, color: C.muted)),
      ])),
      ConstrainedBox(constraints: const BoxConstraints(maxHeight: 200), child: ListView(shrinkWrap: true, children: others.map((u) => Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.div))), child: Row(children: [
        InkWell(onTap: () => _updateUserRole(u['uid'] ?? u['id'] ?? '', _selectedRole), child: Container(width: 26, height: 26, decoration: BoxDecoration(color: const Color(0xFFECFDF3), borderRadius: BorderRadius.circular(7), border: Border.all(color: const Color(0xFFABEFC6))), child: const Icon(Icons.add, size: 11, color: C.green))),
        const Spacer(),
        Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(u['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.text), overflow: TextOverflow.ellipsis),
          Text(u['dept'] ?? '', style: GoogleFonts.tajawal(fontSize: 10, color: C.muted)),
        ])),
        const SizedBox(width: 8),
        CircleAvatar(radius: 14, backgroundColor: C.priLight, child: Text((u['name'] ?? 'م').toString().substring(0, 2), style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w700, color: C.pri))),
      ]))).toList())),
    ]));
  }
}
