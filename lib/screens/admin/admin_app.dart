import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/attendance_service.dart';
import '../../services/api_service.dart';
import '../../services/server_time_service.dart';
import 'admin_dashboard.dart';
import 'admin_employees.dart';
import 'admin_user_mgmt.dart';
import 'admin_roles.dart';
import 'admin_verify.dart';
import 'admin_overtime.dart';
import 'admin_schedules.dart';
import 'admin_requests.dart';
import 'admin_reports.dart';
import 'admin_notifications.dart';
import 'admin_audit.dart';
import 'admin_settings.dart';
import 'admin_salary.dart';
import 'admin_stat_detail.dart';
import '../../l10n/app_locale.dart';

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

  // Org feature flags are stored in ApiService.orgFeatures (global access)

  // URS exact sidebar colors
  static const _sidebarBg = Color(0xFF0F3460);
  static const _sidebarHover = Color(0xFF1A4A7A);
  static const _sidebarActive = Color(0xFF1E5A8E);

  TextStyle _tj(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);

  // Sidebar sections — filtered by org features
  List<_NavSection> get _navSections {
    return [
      _NavSection(L.tr('mob_home'), [
        _NI('dashboard', L.tr('nav_dashboard'), Icons.speed_rounded),
      ]),
      _NavSection(L.tr('nav_employees'), [
        _NI('employees', L.tr('nav_employees'), Icons.people_outline_rounded),
        _NI('usermgmt', L.tr('nav_user_mgmt'), Icons.person_add_alt_1_outlined),
        _NI('roles', L.tr('nav_roles'), Icons.vpn_key_outlined),
      ]),
      _NavSection(L.tr('nav_attendance_section'), [
        if (_feat('allow_verification')) _NI('verify', L.tr('nav_verify'), Icons.wifi_tethering_outlined),
        if (_feat('allow_overtime')) _NI('overtime', L.tr('overtime'), Icons.more_time_outlined),
        if (_feat('allow_schedules')) _NI('schedules', L.tr('nav_schedules'), Icons.calendar_month_outlined),
        _NI('requests', L.tr('mob_requests'), Icons.assignment_outlined),
        if (_feat('allow_salary_calc')) _NI('salary', L.tr('nav_salary'), Icons.payments_outlined),
      ]),
      _NavSection(L.tr('nav_reports_section'), [
        _NI('reports', L.tr('reports'), Icons.bar_chart_outlined),
        _NI('notifications', L.tr('mob_notifications'), Icons.notifications_outlined),
        _NI('audit', L.tr('audit_log'), Icons.history_outlined),
      ]),
      _NavSection(L.tr('nav_system_section'), [
        _NI('settings', L.tr('settings'), Icons.settings_outlined),
      ]),
    ].where((s) => s.items.isNotEmpty).toList();
  }

  List<_NI> get _allItems => _navSections.expand((s) => s.items).toList();

  @override
  void initState() { super.initState(); _tick(); _loadOrgFeatures(); _timer = Timer.periodic(const Duration(minutes: 1), (_) { _tick(); if (_mTab == 0) _loadMobileHome(); }); }

  void _loadOrgFeatures() async {
    try {
      final res = await ApiService.get('admin.php?action=get_settings');
      if (res['success'] == true && mounted) {
        final settings = res['settings'] as Map<String, dynamic>? ?? {};
        ApiService.orgFeatures = (settings['org_features'] as Map<String, dynamic>?) ?? {};
        setState(() {}); // rebuild nav with new features
      }
    } catch (_) {}
  }

  bool _feat(String key) => ApiService.hasFeature(key);
  @override void dispose() { _timer?.cancel(); super.dispose(); }
  void _tick() { final n = ServerTimeService().now; final h = n.hour > 12 ? n.hour - 12 : (n.hour == 0 ? 12 : n.hour); if (mounted) setState(() => _ts = '${h.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')} ${n.hour >= 12 ? L.tr('pm') : L.tr('am')}'); }

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
      case 'notifications': return const AdminNotifications();
      case 'audit': return const AdminAudit();
      case 'salary': return AdminSalary(adminUser: widget.user);
      case 'settings': return AdminSettings(user: widget.user);
      default: return AdminDashboard(user: widget.user, onNav: (p) => setState(() => _page = p));
    }
  }

  @override
  Widget build(BuildContext context) => kIsWeb ? _web() : _mobile();

  // ════════════════════════════════════════════
  //  📱 MOBILE — Redesigned with المزيد page
  // ════════════════════════════════════════════
  Widget _mobile() {
    final av = _getInitials(widget.user['name'] ?? L.tr('app_name'));
    return Scaffold(
      backgroundColor: W.bg,
      appBar: PreferredSize(preferredSize: const Size.fromHeight(56), child: Container(
        decoration: BoxDecoration(color: W.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: Offset(0, 2))]),
        child: SafeArea(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
          InkWell(onTap: () => setState(() => _mTab = 3), borderRadius: BorderRadius.circular(DS.radiusMd), child: Stack(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(DS.radiusMd)), child: Icon(Icons.notifications_none_rounded, size: 20, color: W.sub)),
            Positioned(top: 6, right: 6, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: W.red, shape: BoxShape.circle, border: Border.all(color: W.white, width: 1.5)))),
          ])),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_getMobileTitle(), style: _tj(17, weight: FontWeight.w700, color: W.text)),
            Text(_ts, style: GoogleFonts.ibmPlexMono(fontSize: 11, color: W.muted)),
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
      case 0: return L.tr('mob_home');
      case 1: return L.tr('mob_attendance');
      case 2: return L.tr('mob_requests');
      case 3: return L.tr('mob_notifications');
      case 4: return L.tr('mob_more');
      default: return L.tr('mob_home');
    }
  }

  // ─── Mobile "المزيد" page — رصد style ───
  Widget _mobileMorePage() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 8),
        // ─── المنشأة الحالية ───
        _moreSectionTitle(L.tr('mob_current_org')),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: DS.cardDecoration(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: W.priLight, borderRadius: BorderRadius.circular(DS.radiusMd)),
                  child: ClipRRect(borderRadius: BorderRadius.circular(DS.radiusMd), child: Image.asset('assets/app_icon_192.png', fit: BoxFit.cover)),
                ),
                const SizedBox(width: 12),
                Flexible(child: Text(L.tr('dawemly_attendance'), style: _tj(14, weight: FontWeight.w600, color: W.text), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ─── الموظفين ───
        _moreSectionTitle(L.tr('nav_employees')),
        const SizedBox(height: 8),
        _moreMenuGroup([
          _MoreMenuItem(Icons.people_outline_rounded, W.pri, W.priLight, L.tr('nav_employees'), () => _openMobilePage('employees')),
          _MoreMenuItem(Icons.person_add_alt_1_outlined, W.green, W.greenL, L.tr('nav_user_mgmt'), () => _openMobilePage('usermgmt')),
          _MoreMenuItem(Icons.vpn_key_outlined, W.orange, W.orangeL, L.tr('nav_roles'), () => _openMobilePage('roles')),
        ]),

        const SizedBox(height: 24),

        // ─── الحضور والانصراف ───
        _moreSectionTitle(L.tr('nav_attendance_section')),
        const SizedBox(height: 8),
        _moreMenuGroup([
          if (_feat('allow_verification')) _MoreMenuItem(Icons.wifi_tethering_outlined, W.teal, Color(0xFFE0F2FE), L.tr('nav_verify'), () => _openMobilePage('verify')),
          if (_feat('allow_overtime')) _MoreMenuItem(Icons.more_time_outlined, W.purple, W.purpleL, L.tr('overtime'), () => _openMobilePage('overtime')),
          if (_feat('allow_schedules')) _MoreMenuItem(Icons.calendar_month_outlined, W.pri, W.priLight, L.tr('nav_schedules'), () => _openMobilePage('schedules')),
          _MoreMenuItem(Icons.assignment_outlined, W.orange, W.orangeL, L.tr('mob_requests'), () => _openMobilePage('requests')),
          if (_feat('allow_salary_calc')) _MoreMenuItem(Icons.payments_outlined, W.green, W.greenL, L.tr('nav_salary'), () => _openMobilePage('salary')),
        ]),

        const SizedBox(height: 24),

        // ─── التقارير والمراقبة ───
        _moreSectionTitle(L.tr('nav_reports_section')),
        const SizedBox(height: 8),
        _moreMenuGroup([
          _MoreMenuItem(Icons.bar_chart_outlined, W.green, W.greenL, L.tr('reports'), () => _openMobilePage('reports')),
          _MoreMenuItem(Icons.notifications_outlined, W.teal, Color(0xFFE0F2FE), L.tr('mob_notifications'), () => _openMobilePage('notifications')),
          _MoreMenuItem(Icons.history_outlined, W.purple, W.purpleL, L.tr('audit_log'), () => _openMobilePage('audit')),
        ]),

        const SizedBox(height: 24),

        // ─── النظام ───
        _moreSectionTitle(L.tr('nav_system_section')),
        const SizedBox(height: 8),
        _moreMenuGroup([
          _MoreMenuItem(Icons.settings_outlined, W.sub, W.bg, L.tr('settings'), () => _openMobilePage('settings')),
        ]),

        const SizedBox(height: 16),

        // ─── تسجيل الخروج ───
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(),
              icon: Icon(Icons.logout_rounded, size: 18, color: W.red),
              label: Text(L.tr('logout'), style: _tj(14, weight: FontWeight.w700, color: W.red)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: W.redBd),
                backgroundColor: W.redL,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd)),
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
      backgroundColor: W.bg,
      appBar: AppBar(
        backgroundColor: W.white,
        surfaceTintColor: W.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _allItems.firstWhere((n) => n.key == pageKey, orElse: () => _allItems.first).label,
          style: _tj(17, weight: FontWeight.w700, color: W.text),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: W.text),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(preferredSize: Size.fromHeight(1), child: Container(color: W.border, height: 1)),
      ),
      body: _getPage(pageKey),
    )));
  }

  Widget _moreSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(title, style: _tj(14, weight: FontWeight.w700, color: W.sub)),
      ),
    );
  }

  static const _iconBg = Color(0xFFEDF1F7);
  static Color get _iconClr => W.pri;

  Widget _moreMenuGroup(List<_MoreMenuItem> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: DS.cardDecoration(),
      child: Column(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          return Column(
            children: [
              if (i > 0) Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(height: 1, color: W.div),
              ),
              InkWell(
                onTap: item.onTap,
                borderRadius: i == 0
                    ? const BorderRadius.vertical(top: Radius.circular(6))
                    : i == items.length - 1
                        ? const BorderRadius.vertical(bottom: Radius.circular(6))
                        : BorderRadius.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: _iconBg, borderRadius: BorderRadius.circular(10)),
                        child: Icon(item.icon, size: 20, color: _iconClr),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(item.label, style: _tj(14, weight: FontWeight.w600, color: W.text), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      Directionality(textDirection: TextDirection.ltr, child: Icon(Icons.chevron_left_rounded, size: 20, color: W.muted)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd)),
        title: Text(L.tr('logout'), style: _tj(18, weight: FontWeight.w700), textAlign: TextAlign.right),
        content: Text(L.tr('logout_confirm_msg'), style: _tj(14), textAlign: TextAlign.right),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(L.tr('cancel'), style: _tj(14, color: W.sub))),
          TextButton(
            onPressed: () async { Navigator.pop(ctx); await AuthService().logout(); widget.onLogout(); },
            child: Text(L.tr('logout'), style: _tj(14, weight: FontWeight.w700, color: W.red)),
          ),
        ],
      ),
    );
  }

  // ─── Mobile bottom nav — redesigned like رصد ───
  Widget _buildMobileBottomNav() {
    final items = [
      {'l': L.tr('mob_home'), 'icon': Icons.home_outlined, 'active': Icons.home_rounded},
      {'l': L.tr('mob_attendance'), 'icon': Icons.fingerprint_outlined, 'active': Icons.fingerprint_rounded},
      {'l': L.tr('mob_requests'), 'icon': Icons.assignment_outlined, 'active': Icons.assignment_outlined},
      {'l': L.tr('mob_notifications'), 'icon': Icons.notifications_none_rounded, 'active': Icons.notifications_outlined},
      {'l': L.tr('mob_more'), 'icon': Icons.more_horiz_rounded, 'active': Icons.more_horiz_rounded},
    ];
    return Container(
      decoration: BoxDecoration(
        color: W.white,
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
                  onTap: () { if (i == 0 && _mTab != 0) _loadMobileHome(); setState(() => _mTab = i); },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: on ? 48 : 40,
                        height: on ? 30 : 26,
                        decoration: BoxDecoration(
                          color: on ? W.pri.withOpacity(0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(DS.radiusMd),
                        ),
                        child: Icon(
                          on ? items[i]['active'] as IconData : items[i]['icon'] as IconData,
                          size: on ? 22 : 20,
                          color: on ? W.pri : W.muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        items[i]['l'] as String,
                        style: _tj(10, weight: on ? FontWeight.w700 : FontWeight.w500, color: on ? W.pri : W.muted),
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
          _mHomeRequests = allReqs.where((r) {
            final s = r['status'] ?? '';
            return s == 'تحت الإجراء' || s == 'pending' || s == L.tr('pending');
          }).toList();
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

    final allUsers = _mHomeUsers.where((u) => (u['name'] ?? '').toString().isNotEmpty && u['role'] != 'admin' && u['role'] != 'superadmin').length;
    final att = _mHomeAtt;
    final presentOnly = att.where((r) => r['is_checked_in'] == 1 || r['is_checked_in'] == true).length;
    final complete = att.where((r) => (r['is_checked_in'] == 0 || r['is_checked_in'] == false) && (r['check_in'] ?? r['first_check_in']) != null).length;
    final totalAttended = att.where((r) => (r['check_in'] ?? r['first_check_in']) != null).length;
    final absent = (allUsers - presentOnly).clamp(0, allUsers);

    return RefreshIndicator(
      onRefresh: _loadMobileHome,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        // ═══ HEADER — Gradient with stats ═══
        Container(
          width: double.infinity,
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0F4199), W.pri]), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(L.tr('school_name'), style: _tj(13, weight: FontWeight.w600, color: Colors.white.withOpacity(0.7))),
            const SizedBox(height: 4),
            Text(L.tr('attendance_overview'), style: _tj(11, color: Colors.white.withOpacity(0.4))),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: _mStatTap('$absent', L.tr('exit_label'), const Color(0xFFFF6B6B), () => _openStatDetail('absent', L.tr('check_out_col'), const Color(0xFFFF6B6B)))),
              const SizedBox(width: 10),
              Expanded(child: _mStatTap('$presentOnly', L.tr('present'), const Color(0xFF51CF66), () => _openStatDetail('present', L.tr('present_list'), const Color(0xFF51CF66)))),
            ]),
          ]),
        ),

        // ═══ QUICK ACTIONS ═══
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: DS.cardDecoration(),
            child: Row(children: [
              _quickBtn(Icons.wifi_tethering_outlined, L.tr('quick_verify'), () => _openMobilePage('verify')),
              _quickBtn(Icons.assignment_outlined, L.tr('mob_requests'), () => setState(() => _mTab = 2)),
              _quickBtn(Icons.fingerprint_rounded, L.tr('mob_attendance'), () => setState(() => _mTab = 1)),
              _quickBtn(Icons.bar_chart_outlined, L.tr('reports'), () => _openMobilePage('reports')),
            ]),
          ),
        ),
        const SizedBox(height: 8),

        // ═══ SECTION: الطلبات المعلقة ═══
        _sectionHeader(L.tr('pending_requests_action'), onTap: () => setState(() => _mTab = 2)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: DS.cardDecoration(),
            child: _mHomeLoading
              ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              : _mHomeRequests.isEmpty
                ? Padding(padding: const EdgeInsets.all(24), child: Center(child: Column(children: [
                    Icon(Icons.check_circle_outline_rounded, size: 40, color: W.green.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    Text(L.tr('no_pending_requests'), style: _tj(13, color: W.muted)),
                  ])))
                : Column(children: _mHomeRequests.take(5).map((r) {
                    final isFirst = r == _mHomeRequests.first;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(border: isFirst ? null : const Border(top: BorderSide(color: Color(0xFFF1F5F9)))),
                      child: Row(children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFFEF9C3), borderRadius: BorderRadius.circular(20)),
                          child: Text(L.tr('pending'), style: _tj(10, weight: FontWeight.w600, color: const Color(0xFF854D0E)))),
                        const Spacer(),
                        Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(r['name'] ?? '', style: _tj(14, weight: FontWeight.w600, color: W.text), overflow: TextOverflow.ellipsis),
                          Text('${L.serverText(r['requestType'] ?? '')} — ${L.serverText(r['leaveType'] ?? r['permType'] ?? '')}', style: _tj(11, color: W.sub), overflow: TextOverflow.ellipsis),
                        ])),
                        const SizedBox(width: 10),
                        Container(width: 40, height: 40, decoration: BoxDecoration(color: W.priLight, borderRadius: BorderRadius.circular(DS.radiusMd)),
                          child: Center(child: Text(_getInitials(r['name'] ?? L.tr('pm')), style: _tj(13, weight: FontWeight.w700, color: W.pri)))),
                      ]),
                    );
                  }).toList()),
          ),
        ),
        const SizedBox(height: 8),

        // ═══ SECTION: حضور الموظفين ═══
        _sectionHeader(L.tr('employee_attendance'), onTap: () => setState(() => _mTab = 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: DS.cardDecoration(),
            child: _mHomeLoading
              ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              : _mHomeUsers.isEmpty
                ? Padding(padding: const EdgeInsets.all(24), child: Center(child: Column(children: [
                    Icon(Icons.hourglass_empty_rounded, size: 40, color: W.muted.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    Text(L.tr('no_employees_msg'), style: _tj(13, color: W.muted)),
                  ])))
                : Column(children: () {
                    // Build merged list: all non-admin employees with their attendance status
                    final employees = _mHomeUsers.where((u) =>
                      (u['name'] ?? '').toString().isNotEmpty &&
                      u['role'] != 'admin' && u['role'] != 'superadmin'
                    ).toList();
                    // Sort: حاضر first
                    final attByUid = <String, Map<String, dynamic>>{};
                    for (final a in att) {
                      final uid = (a['uid'] ?? a['emp_uid'] ?? '').toString();
                      if (uid.isNotEmpty) attByUid[uid] = a;
                    }
                    employees.sort((a, b) {
                      final aUid = (a['uid'] ?? '').toString();
                      final bUid = (b['uid'] ?? '').toString();
                      final aPresent = attByUid[aUid]?['is_checked_in'] == 1 || attByUid[aUid]?['is_checked_in'] == true;
                      final bPresent = attByUid[bUid]?['is_checked_in'] == 1 || attByUid[bUid]?['is_checked_in'] == true;
                      if (aPresent && !bPresent) return -1;
                      if (!aPresent && bPresent) return 1;
                      return 0;
                    });
                    return employees.map((emp) {
                      final uid = (emp['uid'] ?? '').toString();
                      final attRec = attByUid[uid];
                      final isPresent = attRec?['is_checked_in'] == 1 || attRec?['is_checked_in'] == true;
                      final isFirst = emp == employees.first;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(border: isFirst ? null : const Border(top: BorderSide(color: Color(0xFFF1F5F9)))),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isPresent ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isPresent ? L.tr('present') : L.tr('exit_label'),
                              style: _tj(10, weight: FontWeight.w600, color: isPresent ? const Color(0xFF166534) : const Color(0xFF991B1B)),
                            ),
                          ),
                          const Spacer(),
                          Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(emp['name'] ?? '', style: _tj(14, weight: FontWeight.w600, color: W.text), overflow: TextOverflow.ellipsis),
                            Text(emp['empId'] ?? emp['emp_id'] ?? '', style: _tj(11, color: W.muted)),
                          ])),
                          const SizedBox(width: 10),
                          Container(width: 40, height: 40, decoration: BoxDecoration(color: isPresent ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(DS.radiusMd)),
                            child: Center(child: Text(_getInitials(emp['name'] ?? L.tr('pm')), style: _tj(13, weight: FontWeight.w700, color: isPresent ? Color(0xFF166534) : W.muted)))),
                        ]),
                      );
                    }).toList();
                  }()),
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
          decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(DS.radiusMd), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: Offset(0, 1))]),
          child: Icon(icon, size: 24, color: W.pri),
        ),
        const SizedBox(height: 8),
        Text(label, style: _tj(11, weight: FontWeight.w600, color: W.text), textAlign: TextAlign.center),
      ]),
    ));
  }

  Widget _sectionHeader(String title, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(children: [
        if (onTap != null) GestureDetector(onTap: onTap, child: Text(L.tr('show_all'), style: _tj(13, weight: FontWeight.w700, color: W.pri))),
        const Spacer(),
        Text(title, style: _tj(16, weight: FontWeight.w700, color: W.text)),
      ]),
    );
  }

  Widget _mStat(String v, String l, Color fg) => Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(DS.radiusMd)),
    child: Column(children: [Text(v, style: GoogleFonts.ibmPlexMono(fontSize: 26, fontWeight: FontWeight.w800, color: fg)), const SizedBox(height: 2), Text(l, style: _tj(12, color: fg.withOpacity(0.85)))]));

  Widget _mStatTap(String v, String l, Color fg, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(DS.radiusMd)),
      child: Column(children: [Text(v, style: GoogleFonts.ibmPlexMono(fontSize: 26, fontWeight: FontWeight.w800, color: fg)), const SizedBox(height: 2), Text(l, style: _tj(12, color: fg.withOpacity(0.85)))])),
  );

  void _openStatDetail(String filter, String title, Color color) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AdminStatDetail(filter: filter, title: title, color: color)));
  }
  String _getInitials(String name) {
    if (name.length >= 2) return name.substring(0, 2);
    return name.isNotEmpty ? name[0] : L.tr('pm');
  }

  // ════════════════════════════════════════════
  //  🖥️ WEB — Exact URS System Style (unchanged)
  // ════════════════════════════════════════════
  Widget _web() {
    final sideW = _sc ? 60.0 : 250.0;

    return Scaffold(body: Row(textDirection: L.textDirection, children: [
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
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(DS.radiusMd), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4)]),
                child: ClipRRect(borderRadius: BorderRadius.circular(DS.radiusMd), child: Image.asset('assets/app_icon_192.png', fit: BoxFit.cover)),
              ),
              if (!_sc) ...[const SizedBox(width: 12), Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(L.tr('app_name'), style: _tj(18, weight: FontWeight.w800, color: Colors.white)),
                Text(L.tr('app_subtitle'), style: _tj(10, color: Colors.white.withOpacity(0.5))),
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
              _sidebarActionLink(Icons.logout_rounded, L.tr('check_out_action'), const Color(0xFFFF6B6B), () async { await AuthService().logout(); widget.onLogout(); }),
              const SizedBox(height: 8),
              if (!_sc) Container(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Container(width: 34, height: 34, decoration: BoxDecoration(borderRadius: BorderRadius.circular(DS.radiusMd)),
                    child: ClipRRect(borderRadius: BorderRadius.circular(DS.radiusMd), child: Image.asset('assets/app_icon_192.png', fit: BoxFit.cover))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.user['name'] ?? L.tr('name'), style: _tj(13, color: Colors.white), overflow: TextOverflow.ellipsis),
                    Text(L.tr('system_admin'), style: _tj(11, color: Colors.white.withOpacity(0.5))),
                  ])),
                ]),
              ),
              InkWell(onTap: () => setState(() => _sc = !_sc), borderRadius: BorderRadius.circular(DS.radiusMd),
                child: Container(width: double.infinity, padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: Colors.white.withOpacity(0.1)), borderRadius: BorderRadius.circular(DS.radiusMd)),
                  child: Icon(_sc ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded, size: 16, color: Colors.white.withOpacity(0.4)))),
            ]),
          ),
        ]),
      ),

      // ─── Main ───
      Expanded(child: Column(children: [
        Container(
          height: 56, padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: W.border)),
          child: Row(textDirection: L.textDirection, children: [
            InkWell(
              onTap: () => setState(() => _sc = !_sc),
              borderRadius: BorderRadius.circular(DS.radiusMd),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD1D5DB)), borderRadius: BorderRadius.circular(DS.radiusMd)),
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
              decoration: BoxDecoration(color: const Color(0xFFF9FAFB), border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(4)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                const Icon(Icons.search_rounded, size: 16, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 8),
                Text(L.tr('search'), style: _tj(14, color: const Color(0xFF9CA3AF))),
              ]),
            ),
            const SizedBox(width: 16),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFE5E7EB))),
                child: Stack(alignment: Alignment.center, children: [
                  const Icon(Icons.notifications_none_rounded, size: 20, color: Color(0xFF374151)),
                  Positioned(top: 8, right: 8, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFFEF4444), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)))),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
              child: Row(children: [
                const Icon(Icons.store_rounded, size: 14, color: Color(0xFF1D4ED8)),
                const SizedBox(width: 6),
                Text(L.tr('main_branch'), style: _tj(13, weight: FontWeight.w600, color: const Color(0xFF1D4ED8))),
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
