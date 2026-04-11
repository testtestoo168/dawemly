import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/server_time_service.dart';
import 'sa_dashboard.dart';
import 'sa_organizations.dart';
import 'sa_plans.dart';
import 'sa_audit_log.dart';
import '../../l10n/app_locale.dart';

class SuperadminApp extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  const SuperadminApp({super.key, required this.user, required this.onLogout});
  @override
  State<SuperadminApp> createState() => _SuperadminAppState();
}

class _SuperadminAppState extends State<SuperadminApp> {
  String _page = 'dashboard';
  bool _sc = false;
  String _ts = '';
  Timer? _timer;

  static const _sidebarBg = Color(0xFF1A1A2E);
  static const _sidebarHover = Color(0xFF2A2A42);
  static const _sidebarActive = Color(0xFF3A3A55);

  TextStyle _tj(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);

  static List<_NI> get _navItems => [
    _NI('dashboard', L.tr('statistics'), Icons.speed_rounded),
    _NI('organizations', L.tr('sa_organizations'), Icons.business_rounded),
    _NI('plans', L.tr('sa_plans'), Icons.card_membership_rounded),
    _NI('audit', L.tr('operations_log'), Icons.history_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    final n = ServerTimeService().now;
    final h = n.hour > 12 ? n.hour - 12 : (n.hour == 0 ? 12 : n.hour);
    if (mounted) setState(() => _ts = '${h.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')} ${n.hour >= 12 ? L.tr('pm') : L.tr('am')}');
  }

  Widget _getPage(String k) {
    switch (k) {
      case 'dashboard':
        return const SaDashboard();
      case 'organizations':
        return const SaOrganizations();
      case 'plans':
        return const SaPlans();
      case 'audit':
        return const SaAuditLog();
      default:
        return const SaDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sideW = _sc ? 60.0 : 250.0;

    return Scaffold(body: Row(textDirection: L.textDirection, children: [
      // ─── Sidebar ───
      AnimatedContainer(
        duration: const Duration(milliseconds: 250), curve: Curves.easeInOut,
        width: sideW, color: _sidebarBg,
        child: Column(children: [
          // ─── Logo ───
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
                Text(L.tr('sa_dashboard'), style: _tj(10, color: Colors.white.withOpacity(0.5))),
              ]))],
            ]),
          ),

          // ─── Nav items ───
          Expanded(child: ListView(padding: const EdgeInsets.symmetric(vertical: 12), children: [
            if (!_sc) Padding(
              padding: const EdgeInsets.only(right: 18, top: 6, bottom: 8),
              child: Text(L.tr('list_view'), style: _tj(10, weight: FontWeight.w700, color: Colors.white.withOpacity(0.35))),
            ),
            if (_sc) const SizedBox(height: 8),
            for (final item in _navItems)
              _sidebarLink(item),
          ])),

          // ─── Footer ───
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1)))),
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              _sidebarActionLink(Icons.logout_rounded, L.tr('check_out_action'), const Color(0xFFFF6B6B), () async {
                await AuthService().logout();
                widget.onLogout();
              }),
              const SizedBox(height: 8),
              if (!_sc) Container(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Container(width: 34, height: 34,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF7F56D9), Color(0xFF9E77ED)]),
                      borderRadius: BorderRadius.circular(DS.radiusMd),
                    ),
                    child: Center(child: Text('SA', style: _tj(12, weight: FontWeight.w700, color: Colors.white))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(L.localName(widget.user).isNotEmpty ? L.localName(widget.user) : 'Super Admin', style: _tj(13, color: Colors.white), overflow: TextOverflow.ellipsis),
                    Text(L.tr('higher_admin'), style: _tj(11, color: Colors.white.withOpacity(0.5))),
                  ])),
                ]),
              ),
              InkWell(
                onTap: () => setState(() => _sc = !_sc),
                borderRadius: BorderRadius.circular(DS.radiusMd),
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(border: Border.all(color: Colors.white.withOpacity(0.1)), borderRadius: BorderRadius.circular(DS.radiusMd)),
                  child: Icon(_sc ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded, size: 16, color: Colors.white.withOpacity(0.4)),
                ),
              ),
            ]),
          ),
        ]),
      ),

      // ─── Main content ───
      Expanded(child: Column(children: [
        // Top bar
        Container(
          height: 56, padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: W.border))),
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
              _navItems.firstWhere((n) => n.key == _page, orElse: () => _navItems.first).label,
              style: _tj(18, weight: FontWeight.w700, color: const Color(0xFF1F2937)),
            ),
            const Spacer(),
            Text(_ts, style: GoogleFonts.ibmPlexMono(fontSize: 13, color: W.muted)),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFF4F3FF), borderRadius: BorderRadius.circular(4)),
              child: Row(children: [
                const Icon(Icons.admin_panel_settings_rounded, size: 14, color: Color(0xFF7F56D9)),
                const SizedBox(width: 6),
                Text('Super Admin', style: _tj(13, weight: FontWeight.w600, color: const Color(0xFF7F56D9))),
              ]),
            ),
          ]),
        ),
        // Content
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

class _NI {
  final String key, label;
  final IconData icon;
  const _NI(this.key, this.label, this.icon);
}
