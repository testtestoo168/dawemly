import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/attendance_service.dart';
import '../../services/api_service.dart';
import 'admin_dashboard.dart';
import 'admin_employees.dart';
import 'admin_user_mgmt.dart';
import 'admin_roles.dart';
import 'admin_verify.dart';
import 'admin_overtime.dart';
import 'admin_schedules.dart';
import 'admin_requests.dart';
import 'admin_reports.dart';
import 'admin_devices.dart';
import 'admin_notifications.dart';
import 'admin_audit.dart';
import 'admin_settings.dart';
import 'admin_stat_detail.dart';

class AdminApp extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  const AdminApp({super.key, required this.user, required this.onLogout});
  @override State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  String _page = 'dashboard';
  bool _sc = false; // sidebar collapsed
  String _ts = '';
  Timer? _timer;
  int _mTab = 0;

  // URS exact sidebar colors
  static const _sidebarBg = Color(0xFF0F3460);
  static const _sidebarHover = Color(0xFF1A4A7A);
  static const _sidebarActive = Color(0xFF1E5A8E);

  TextStyle _tj(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);

  // Sidebar sections
  static const _navSections = [
    _NavSection('الرئيسية', [
      _NI('dashboard', 'لوحة التحكم', Icons.speed_rounded),
    ]),
    _NavSection('الموظفين', [
      _NI('employees', 'الموظفين', Icons.people_outline_rounded),
      _NI('usermgmt', 'إدارة المستخدمين', Icons.person_add_alt_1_outlined),
      _NI('roles', 'الصلاحيات', Icons.vpn_key_outlined),
    ]),
    _NavSection('الحضور والانصراف', [
      _NI('verify', 'إثبات الحالة', Icons.wifi_tethering_outlined),
      _NI('overtime', 'الأوفرتايم', Icons.more_time_outlined),
      _NI('schedules', 'الجداول والإجازات', Icons.calendar_month_outlined),
      _NI('requests', 'الطلبات', Icons.assignment_outlined),
    ]),
    _NavSection('التقارير والمراقبة', [
      _NI('reports', 'التقارير', Icons.bar_chart_outlined),
      _NI('devices', 'مراقبة الأجهزة', Icons.devices_outlined),
      _NI('notifications', 'الإشعارات', Icons.notifications_outlined),
      _NI('audit', 'سجل التدقيق', Icons.history_outlined),
    ]),
    _NavSection('النظام', [
      _NI('settings', 'الإعدادات', Icons.settings_outlined),
    ]),
  ];

  List<_NI> get _allItems => _navSections.expand((s) => s.items).toList();

  @override
  void initState() { super.initState(); _tick(); _timer = Timer.periodic(const Duration(minutes: 1), (_) => _tick()); }
  @override void dispose() { _timer?.cancel(); super.dispose(); }
  void _tick() { final n = DateTime.now(); final h = n.hour > 12 ? n.hour - 12 : (n.hour == 0 ? 12 : n.hour); if (mounted) setState(() => _ts = '${h.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')} ${n.hour >= 12 ? 'م' : 'ص'}'); }

  Widget _getPage(String k) {
    switch (k) {
      case 'dashboard': return AdminDashboard(user: widget.user, onNav: (p) => setState(() => _page = p));
      case 'employees': return AdminEmployees(user: widget.user);
      case 'usermgmt': return AdminUserMgmt(user: widget.user);
      case 'roles': return const AdminRoles();
      case 'verify': return AdminVerify(user: widget.user);
      case 'overtime': return AdminOvertime(adminUser: widget.user);
      case 'schedules': return AdminSchedules(user: widget.user);
      case 'requests': return AdminRequests(user: widget.user);
      case 'reports': return const AdminReports();
      case 'devices': return AdminDevices(user: widget.user);
      case 'notifications': return const AdminNotifications();
      case 'audit': return const AdminAudit();
      case 'settings': return AdminSettings(user: widget.user);
      default: return AdminDashboard(user: widget.user, onNav: (p) => setState(() => _page = p));
    }
  }

  @override
  Widget build(BuildContext context) => MediaQuery.of(context).size.width > 800 ? _web() : _mobile();

  // ════════════════════════════════════════════
  //  📱 MOBILE — Redesigned with المزيد page
  // ════════════════════════════════════════════
  Widget _mobile() {
    final av = _getInitials(widget.user['name'] ?? 'مد');
    return Scaffold(
      backgroundColor: C.bg,
      appBar: PreferredSize(preferredSize: const Size.fromHeight(56), child: Container(
        decoration: BoxDecoration(color: C.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
        child: SafeArea(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
          GestureDetector(onTap: () => setState(() => _mTab = 3), child: Stack(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.notifications_none_rounded, size: 20, color: C.sub)),
            Positioned(top: 6, right: 6, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: C.red, shape: BoxShape.circle, border: Border.all(color: C.white, width: 1.5)))),
          ])),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_getMobileTitle(), style: _tj(17, weight: FontWeight.w700, color: C.text)),
            Text(_ts, style: GoogleFonts.ibmPlexMono(fontSize: 11, color: C.muted)),
          ]),
        ]))),
      )),
      body: IndexedStack(index: _mTab, children: [
        _mobileHome(),
        AdminEmployees(user: widget.user),
        AdminRequests(user: widget.user),
        const AdminNotifications(),
        _mobileMorePage(),
      ]),
      bottomNavigationBar: _buildMobileBottomNav(),
    );
  }

  String _getMobileTitle() {
    switch (_mTab) {
      case 0: return 'الرئيسية';
      case 1: return 'الحضور';
      case 2: return 'الطلبات';
      case 3: return 'الإشعارات';
      case 4: return 'المزيد';
      default: return 'الرئيسية';
    }
  }

  // ─── Mobile "المزيد" page — رصد style ───
  Widget _mobileMorePage() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 8),
        // ─── المنشأة الحالية ───
        _moreSectionTitle('المنشأة الحالية'),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: C.priLight, borderRadius: BorderRadius.circular(10)),
                  child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/app_icon_192.png', fit: BoxFit.cover)),
                ),
                const SizedBox(width: 12),
                Text('داوِملي — نظام الحضور', style: _tj(14, weight: FontWeight.w600, color: C.text)),
                const Spacer(),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ─── الموظفين ───
        _moreSectionTitle('الموظفين'),
        const SizedBox(height: 8),
        _moreMenuGroup([
          _MoreMenuItem(Icons.people_outline_rounded, C.pri, C.priLight, 'الموظفين', () => _openMobilePage('employees')),
          _MoreMenuItem(Icons.person_add_alt_1_outlined, C.green, C.greenL, 'إدارة المستخدمين', () => _openMobilePage('usermgmt')),
          _MoreMenuItem(Icons.vpn_key_outlined, C.orange, C.orangeL, 'الصلاحيات', () => _openMobilePage('roles')),
        ]),

        const SizedBox(height: 24),

        // ─── الحضور والانصراف ───
        _moreSectionTitle('الحضور والانصراف'),
        const SizedBox(height: 8),
        _moreMenuGroup([
          _MoreMenuItem(Icons.wifi_tethering_outlined, C.teal, const Color(0xFFE0F2FE), 'إثبات الحالة', () => _openMobilePage('verify')),
          _MoreMenuItem(Icons.more_time_outlined, C.purple, C.purpleL, 'الأوفرتايم', () => _openMobilePage('overtime')),
          _MoreMenuItem(Icons.calendar_month_outlined, C.pri, C.priLight, 'الجداول والإجازات', () => _openMobilePage('schedules')),
          _MoreMenuItem(Icons.assignment_outlined, C.orange, C.orangeL, 'الطلبات', () => _openMobilePage('requests')),
        ]),

        const SizedBox(height: 24),

        // ─── التقارير والمراقبة ───
        _moreSectionTitle('التقارير والمراقبة'),
        const SizedBox(height: 8),
        _moreMenuGroup([
          _MoreMenuItem(Icons.bar_chart_outlined, C.green, C.greenL, 'التقارير', () => _openMobilePage('reports')),
          _MoreMenuItem(Icons.devices_outlined, C.sub, C.bg, 'مراقبة الأجهزة', () => _openMobilePage('devices')),
          _MoreMenuItem(Icons.notifications_outlined, C.teal, const Color(0xFFE0F2FE), 'الإشعارات', () => _openMobilePage('notifications')),
          _MoreMenuItem(Icons.history_outlined, C.purple, C.purpleL, 'سجل التدقيق', () => _openMobilePage('audit')),
        ]),

        const SizedBox(height: 24),

        // ─── النظام ───
        _moreSectionTitle('النظام'),
        const SizedBox(height: 8),
        _moreMenuGroup([
          _MoreMenuItem(Icons.settings_outlined, C.sub, C.bg, 'الإعدادات', () => _openMobilePage('settings')),
        ]),

        const SizedBox(height: 16),

        // ─── تسجيل الخروج ───
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(),
              icon: const Icon(Icons.logout_rounded, size: 18, color: C.red),
              label: Text('تسجيل الخروج', style: _tj(14, weight: FontWeight.w700, color: C.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: C.redBd),
                backgroundColor: C.redL,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _openMobilePage(String pageKey) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.white,
        surfaceTintColor: C.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _allItems.firstWhere((n) => n.key == pageKey, orElse: () => _allItems.first).label,
          style: _tj(17, weight: FontWeight.w700, color: C.text),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: C.text),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: C.border, height: 1)),
      ),
      body: _getPage(pageKey),
    )));
  }

  Widget _moreSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(title, style: _tj(14, weight: FontWeight.w700, color: C.sub)),
      ),
    );
  }

  // رصد style
  static const _iconBg = Color(0xFFEDF1F7);
  static const _iconClr = C.pri;

  Widget _moreMenuGroup(List<_MoreMenuItem> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          return Column(
            children: [
              if (i > 0) Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(height: 1, color: C.div),
              ),
              InkWell(
                onTap: item.onTap,
                borderRadius: i == 0
                    ? const BorderRadius.vertical(top: Radius.circular(14))
                    : i == items.length - 1
                        ? const BorderRadius.vertical(bottom: Radius.circular(14))
                        : BorderRadius.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: _iconBg, borderRadius: BorderRadius.circular(12)),
                        child: Icon(item.icon, size: 22, color: _iconClr),
                      ),
                      const SizedBox(width: 14),
                      Text(item.label, style: _tj(15, weight: FontWeight.w600, color: C.text)),
                      const Spacer(),
                      Directionality(textDirection: TextDirection.ltr, child: Icon(Icons.chevron_left_rounded, size: 22, color: C.muted)),
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('تسجيل الخروج', style: _tj(18, weight: FontWeight.w700), textAlign: TextAlign.right),
        content: Text('هل تريد تسجيل الخروج من حسابك؟', style: _tj(14), textAlign: TextAlign.right),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: _tj(14, color: C.sub))),
          TextButton(
            onPressed: () async { Navigator.pop(ctx); await AuthService().logout(); widget.onLogout(); },
            child: Text('تسجيل الخروج', style: _tj(14, weight: FontWeight.w700, color: C.red)),
          ),
        ],
      ),
    );
  }

  // ─── Mobile bottom nav — redesigned like رصد ───
  Widget _buildMobileBottomNav() {
    final items = [
      {'l': 'الرئيسية', 'icon': Icons.home_outlined, 'active': Icons.home_rounded},
      {'l': 'الحضور', 'icon': Icons.fingerprint_outlined, 'active': Icons.fingerprint_rounded},
      {'l': 'الطلبات', 'icon': Icons.assignment_outlined, 'active': Icons.assignment_outlined},
      {'l': 'الإشعارات', 'icon': Icons.notifications_none_rounded, 'active': Icons.notifications_outlined},
      {'l': 'المزيد', 'icon': Icons.more_horiz_rounded, 'active': Icons.more_horiz_rounded},
    ];
    return Container(
      decoration: BoxDecoration(
        color: C.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: List.generate(5, (i) {
              final on = _mTab == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _mTab = i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: on ? 48 : 40,
                        height: on ? 30 : 26,
                        decoration: BoxDecoration(
                          color: on ? C.pri.withOpacity(0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          on ? items[i]['active'] as IconData : items[i]['icon'] as IconData,
                          size: on ? 22 : 20,
                          color: on ? C.pri : C.muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        items[i]['l'] as String,
                        style: _tj(10, weight: on ? FontWeight.w700 : FontWeight.w500, color: on ? C.pri : C.muted),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ─── Mobile Home Page ───
  List<Map<String, dynamic>> _mHomeUsers = [];
  List<Map<String, dynamic>> _mHomeAtt = [];
  List<Map<String, dynamic>> _mHomeRequests = [];
  bool _mHomeLoading = true;

  Future<void> _loadMobileHome() async {
    setState(() => _mHomeLoading = true);
    try {
      final usersRes = await ApiService.get('users.php?action=list');
      final attRes = await AttendanceService().getAllTodayRecords();
      final reqRes = await ApiService.get('requests.php?action=all');
      if (mounted) {
        setState(() {
          _mHomeUsers = (usersRes['users'] as List? ?? []).cast<Map<String, dynamic>>();
          _mHomeAtt = attRes;
          final allReqs = (reqRes['requests'] as List? ?? []).cast<Map<String, dynamic>>();
          _mHomeRequests = allReqs.where((r) => r['status'] == 'تحت الإجراء').toList();
          _mHomeLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _mHomeLoading = false);
    }
  }

  Widget _mobileHome() {
    // Load on first render if not loaded
    if (_mHomeLoading && _mHomeUsers.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadMobileHome());
    }

    final allUsers = _mHomeUsers.where((u) => (u['name'] ?? '').toString().isNotEmpty && u['role'] != 'admin').length;
    final att = _mHomeAtt;
    final complete = att.where((r) => r['checkOut'] != null).length;
    final presentOnly = att.where((r) => r['checkIn'] != null && r['checkOut'] == null).length;
    final totalAttended = att.where((r) => r['checkIn'] != null).length;
    final absent = allUsers > totalAttended ? allUsers - totalAttended : 0;

    return RefreshIndicator(
      onRefresh: _loadMobileHome,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        // ═══ HEADER — Gradient with stats ═══
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0F4199), C.pri]), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('مدارس المروج النموذجية', style: _tj(13, weight: FontWeight.w600, color: Colors.white.withOpacity(0.7))),
            const SizedBox(height: 4),
            Text('نظرة عامة على الحضور', style: _tj(11, color: Colors.white.withOpacity(0.4))),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: _mStatTap('$absent', 'غائب', const Color(0xFFFF6B6B), () => _openStatDetail('absent', 'الغائبين', const Color(0xFFFF6B6B)))),
              const SizedBox(width: 10),
              Expanded(child: _mStatTap('$complete', 'مكتمل', const Color(0xFF74C0FC), () => _openStatDetail('complete', 'المكتملين', const Color(0xFF74C0FC)))),
              const SizedBox(width: 10),
              Expanded(child: _mStatTap('$presentOnly', 'حاضر', const Color(0xFF51CF66), () => _openStatDetail('present', 'الحاضرين', const Color(0xFF51CF66)))),
              const SizedBox(width: 10),
              Expanded(child: _mStatTap('$allUsers', 'الموظفين', Colors.white, () => _openStatDetail('all', 'جميع الموظفين', C.pri))),
            ]),
          ]),
        ),

        // ═══ QUICK ACTIONS ═══
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border)),
            child: Row(children: [
              _quickBtn(Icons.wifi_tethering_outlined, 'إثبات\nالحالة', () => _openMobilePage('verify')),
              _quickBtn(Icons.assignment_outlined, 'الطلبات', () => setState(() => _mTab = 2)),
              _quickBtn(Icons.fingerprint_rounded, 'الحضور', () => setState(() => _mTab = 1)),
              _quickBtn(Icons.bar_chart_outlined, 'التقارير', () => _openMobilePage('reports')),
            ]),
          ),
        ),
        const SizedBox(height: 8),

        // ═══ SECTION: الطلبات المعلقة ═══
        _sectionHeader('الطلبات المعلقة', onTap: () => setState(() => _mTab = 2)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border)),
            child: _mHomeLoading
              ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              : _mHomeRequests.isEmpty
                ? Padding(padding: const EdgeInsets.all(24), child: Center(child: Column(children: [
                    Icon(Icons.check_circle_outline_rounded, size: 40, color: C.green.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    Text('لا توجد طلبات معلقة', style: _tj(13, color: C.muted)),
                  ])))
                : Column(children: _mHomeRequests.take(5).map((r) {
                    final isFirst = r == _mHomeRequests.first;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(border: isFirst ? null : const Border(top: BorderSide(color: Color(0xFFF1F5F9)))),
                      child: Row(children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFFEF9C3), borderRadius: BorderRadius.circular(20)),
                          child: Text('معلق', style: _tj(10, weight: FontWeight.w600, color: const Color(0xFF854D0E)))),
                        const Spacer(),
                        Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(r['name'] ?? '', style: _tj(14, weight: FontWeight.w600, color: C.text), overflow: TextOverflow.ellipsis),
                          Text('${r['requestType'] ?? ''} — ${r['leaveType'] ?? r['permType'] ?? ''}', style: _tj(11, color: C.sub), overflow: TextOverflow.ellipsis),
                        ])),
                        const SizedBox(width: 10),
                        Container(width: 40, height: 40, decoration: BoxDecoration(color: C.priLight, borderRadius: BorderRadius.circular(12)),
                          child: Center(child: Text(_getInitials(r['name'] ?? 'م'), style: _tj(13, weight: FontWeight.w700, color: C.pri)))),
                      ]),
                    );
                  }).toList()),
          ),
        ),
        const SizedBox(height: 8),

        // ═══ SECTION: آخر الحضور ═══
        _sectionHeader('آخر الحضور', onTap: () => setState(() => _mTab = 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border)),
            child: _mHomeLoading
              ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              : att.isEmpty
                ? Padding(padding: const EdgeInsets.all(24), child: Center(child: Column(children: [
                    Icon(Icons.hourglass_empty_rounded, size: 40, color: C.muted.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    Text('لا يوجد حضور اليوم', style: _tj(13, color: C.muted)),
                  ])))
                : Column(children: att.take(6).map((r) {
                    final hasOut = r['checkOut'] != null;
                    final isFirst = r == att.first;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(border: isFirst ? null : const Border(top: BorderSide(color: Color(0xFFF1F5F9)))),
                      child: Row(children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: hasOut ? const Color(0xFFDCFCE7) : C.priLight, borderRadius: BorderRadius.circular(20)),
                          child: Text(hasOut ? 'مكتمل' : 'حاضر', style: _tj(10, weight: FontWeight.w600, color: hasOut ? const Color(0xFF166534) : C.pri))),
                        const Spacer(),
                        Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(r['name'] ?? '', style: _tj(14, weight: FontWeight.w600, color: C.text), overflow: TextOverflow.ellipsis),
                          Text(r['empId'] ?? '', style: _tj(11, color: C.muted)),
                        ])),
                        const SizedBox(width: 10),
                        Container(width: 40, height: 40, decoration: BoxDecoration(color: C.priLight, borderRadius: BorderRadius.circular(12)),
                          child: Center(child: Text(_getInitials(r['name'] ?? 'م'), style: _tj(13, weight: FontWeight.w700, color: C.pri)))),
                      ]),
                    );
                  }).toList()),
          ),
        ),
        const SizedBox(height: 24),
      ])));
  }

  Widget _quickBtn(IconData icon, String label, VoidCallback onTap) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 1))]),
          child: Icon(icon, size: 24, color: C.pri),
        ),
        const SizedBox(height: 8),
        Text(label, style: _tj(11, weight: FontWeight.w600, color: C.text), textAlign: TextAlign.center),
      ]),
    ));
  }

  Widget _sectionHeader(String title, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(children: [
        if (onTap != null) GestureDetector(onTap: onTap, child: Text('عرض الكل', style: _tj(13, weight: FontWeight.w700, color: C.pri))),
        const Spacer(),
        Text(title, style: _tj(16, weight: FontWeight.w700, color: C.text)),
      ]),
    );
  }

  Widget _mStat(String v, String l, Color fg) => Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
    child: Column(children: [Text(v, style: GoogleFonts.ibmPlexMono(fontSize: 26, fontWeight: FontWeight.w800, color: fg)), const SizedBox(height: 2), Text(l, style: _tj(12, color: fg.withOpacity(0.85)))]));

  Widget _mStatTap(String v, String l, Color fg, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [Text(v, style: GoogleFonts.ibmPlexMono(fontSize: 26, fontWeight: FontWeight.w800, color: fg)), const SizedBox(height: 2), Text(l, style: _tj(12, color: fg.withOpacity(0.85)))])),
  );

  void _openStatDetail(String filter, String title, Color color) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AdminStatDetail(filter: filter, title: title, color: color)));
  }
  String _getInitials(String name) {
    if (name.length >= 2) return name.substring(0, 2);
    return name.isNotEmpty ? name[0] : 'م';
  }

  // ════════════════════════════════════════════
  //  🖥️ WEB — Exact URS System Style (unchanged)
  // ════════════════════════════════════════════
  Widget _web() {
    final sideW = _sc ? 60.0 : 250.0;

    return Scaffold(body: Row(textDirection: TextDirection.rtl, children: [
      // ─── Sidebar ───
      AnimatedContainer(
        duration: const Duration(milliseconds: 250), curve: Curves.easeInOut,
        width: sideW, color: _sidebarBg,
        child: Column(children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: _sc ? 10 : 18, vertical: 20),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1)))),
            child: Row(children: [
              Container(
                width: _sc ? 32 : 42, height: _sc ? 32 : 42,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4)]),
                child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/app_icon_192.png', fit: BoxFit.cover)),
              ),
              if (!_sc) ...[const SizedBox(width: 12), Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('داوِملي', style: _tj(18, weight: FontWeight.w800, color: Colors.white)),
                Text('نظام إدارة الحضور والانصراف', style: _tj(10, color: Colors.white.withOpacity(0.5))),
              ]))],
            ]),
          ),
          Expanded(child: ListView(padding: const EdgeInsets.symmetric(vertical: 6), children: [
            for (final section in _navSections) ...[
              if (!_sc) Padding(
                padding: const EdgeInsets.only(right: 18, top: 10, bottom: 4),
                child: Text(section.title, style: _tj(10, weight: FontWeight.w700, color: Colors.white.withOpacity(0.35))),
              ),
              if (_sc) const SizedBox(height: 8),
              for (final item in section.items)
                _sidebarLink(item),
            ],
          ])),
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1)))),
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              _sidebarActionLink(Icons.logout_rounded, 'تسجيل خروج', const Color(0xFFFF6B6B), () async { await AuthService().logout(); widget.onLogout(); }),
              const SizedBox(height: 8),
              if (!_sc) Container(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Container(width: 34, height: 34, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
                    child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/app_icon_192.png', fit: BoxFit.cover))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.user['name'] ?? 'المستخدم', style: _tj(13, color: Colors.white), overflow: TextOverflow.ellipsis),
                    Text('مدير النظام', style: _tj(11, color: Colors.white.withOpacity(0.5))),
                  ])),
                ]),
              ),
              InkWell(onTap: () => setState(() => _sc = !_sc), borderRadius: BorderRadius.circular(6),
                child: Container(width: double.infinity, padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: Colors.white.withOpacity(0.1)), borderRadius: BorderRadius.circular(6)),
                  child: Icon(_sc ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded, size: 16, color: Colors.white.withOpacity(0.4)))),
            ]),
          ),
        ]),
      ),

      // ─── Main ───
      Expanded(child: Column(children: [
        Container(
          height: 56, padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: const Color(0xFFE5E7EB)))),
          child: Row(textDirection: TextDirection.rtl, children: [
            InkWell(
              onTap: () => setState(() => _sc = !_sc),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD1D5DB)), borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.menu, size: 18, color: Color(0xFF374151)),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              _allItems.firstWhere((n) => n.key == _page, orElse: () => _allItems.first).label,
              style: _tj(18, weight: FontWeight.w700, color: const Color(0xFF1F2937)),
            ),
            const Spacer(),
            Container(
              width: 220, height: 38,
              decoration: BoxDecoration(color: const Color(0xFFF9FAFB), border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                const Icon(Icons.search_rounded, size: 16, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 8),
                Text('بحث...', style: _tj(14, color: const Color(0xFF9CA3AF))),
              ]),
            ),
            const SizedBox(width: 16),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))),
                child: Stack(alignment: Alignment.center, children: [
                  const Icon(Icons.notifications_none_rounded, size: 20, color: Color(0xFF374151)),
                  Positioned(top: 8, right: 8, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFFEF4444), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)))),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.store_rounded, size: 14, color: Color(0xFF1D4ED8)),
                const SizedBox(width: 6),
                Text('الفرع الرئيسي', style: _tj(13, weight: FontWeight.w600, color: const Color(0xFF1D4ED8))),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF1D4ED8)),
              ]),
            ),
          ]),
        ),
        Expanded(child: Container(color: const Color(0xFFF4F5F7), child: _getPage(_page))),
      ])),
    ]));
  }

  Widget _sidebarLink(_NI item) {
    final on = _page == item.key;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _page = item.key),
        hoverColor: _sidebarHover,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: _sc ? 0 : 18, vertical: 10),
          decoration: BoxDecoration(
            color: on ? _sidebarActive : Colors.transparent,
            border: Border(right: BorderSide(color: on ? Colors.white : Colors.transparent, width: 3)),
          ),
          child: Row(mainAxisAlignment: _sc ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
            Icon(item.icon, size: 15, color: on ? Colors.white : Colors.white.withOpacity(0.7)),
            if (!_sc) ...[const SizedBox(width: 12), Expanded(child: Text(item.label, style: _tj(13, weight: on ? FontWeight.w500 : FontWeight.w400, color: on ? Colors.white : Colors.white.withOpacity(0.7))))],
          ]),
        ),
      ),
    );
  }

  Widget _sidebarActionLink(IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(color: Colors.transparent, child: InkWell(onTap: onTap, hoverColor: color.withOpacity(0.1),
      child: Container(padding: EdgeInsets.symmetric(horizontal: _sc ? 0 : 18, vertical: 10),
        child: Row(mainAxisAlignment: _sc ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
          Icon(icon, size: 15, color: color.withOpacity(0.7)),
          if (!_sc) ...[const SizedBox(width: 12), Text(label, style: _tj(13, color: color.withOpacity(0.7)))],
        ]))));
  }
}

class _NI { final String key, label; final IconData icon; const _NI(this.key, this.label, this.icon); }
class _NavSection { final String title; final List<_NI> items; const _NavSection(this.title, this.items); }
class _MoreMenuItem { final IconData icon; final Color iconColor; final Color iconBg; final String label; final VoidCallback onTap; const _MoreMenuItem(this.icon, this.iconColor, this.iconBg, this.label, this.onTap); }
