import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/server_time_service.dart';
import 'emp_locations_page.dart';
import 'emp_schedule_page.dart';
import 'emp_profile_page.dart';
import 'emp_my_face_page.dart';
import 'emp_notifications_page.dart';
import '../onboarding_screen.dart';
import '../../l10n/app_locale.dart';

class EmpMorePage extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  const EmpMorePage({super.key, required this.user, required this.onLogout});
  @override
  State<EmpMorePage> createState() => _EmpMorePageState();
}

class _EmpMorePageState extends State<EmpMorePage> {
  String? _locationName;
  bool _loadingLoc = true;
  int _leaveTotal = 0;
  int _leaveUsed = 0;
  bool _loadingLeave = true;

  TextStyle _tj(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);

  @override
  void initState() {
    super.initState();
    _loadLocation();
    _loadLeaveBalance();
  }

  Future<void> _loadLocation() async {
    try {
      final result = await ApiService.get('admin.php?action=get_locations');
      if (result['success'] == true) {
        final allLocs = (result['locations'] as List? ?? []).cast<Map<String, dynamic>>();
        final uid = widget.user['uid'] ?? '';
        final userLocs = allLocs.where((loc) {
          final active = loc['active'];
          if (active == false || active == 0) return false;
          final assigned = (loc['assignedEmployees'] as List?)?.cast<String>() ??
              (loc['assigned_employees'] as List?)?.cast<String>() ?? [];
          final excluded = (loc['excludedEmployees'] as List?)?.cast<String>() ??
              (loc['excluded_employees'] as List?)?.cast<String>() ?? [];
          if (excluded.contains(uid)) return false;
          return assigned.isEmpty || assigned.contains(uid);
        }).toList();
        if (mounted) {
          setState(() {
            _locationName = userLocs.isNotEmpty ? (L.localName(userLocs.first).isNotEmpty ? L.localName(userLocs.first) : L.tr('organization')) : null;
            _loadingLoc = false;
          });
        }
      } else {
        if (mounted) setState(() => _loadingLoc = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLoc = false);
    }
  }

  Future<void> _loadLeaveBalance() async {
    try {
      final uid = widget.user['uid'] ?? '';
      final year = DateTime.now().year;
      final result = await ApiService.get('leaves.php?action=balance', params: {'uid': uid, 'year': '$year'});
      if (result['success'] == true && mounted) {
        final bal = result['balance'] as Map<String, dynamic>? ?? {};
        setState(() {
          _leaveTotal = (bal['annual_days'] as int?) ?? 21;
          _leaveUsed = (bal['used_days'] as int?) ?? 0;
          _loadingLeave = false;
        });
      } else {
        if (mounted) setState(() => _loadingLeave = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLeave = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ─── Header with user info ───
            Container(
              color: C.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  // Notification bell on left
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(10)),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(Icons.notifications_none_rounded, size: 20, color: C.sub),
                        Positioned(top: 8, right: 8, child: Container(width: 7, height: 7, decoration: BoxDecoration(color: C.red, shape: BoxShape.circle, border: Border.all(color: C.white, width: 1.5)))),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Name and time
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(L.tr('mob_more'), style: _tj(17, weight: FontWeight.w700, color: C.text)),
                      const SizedBox(height: 2),
                      Text(
                        _getCurrentTime(),
                        style: GoogleFonts.ibmPlexMono(fontSize: 11, color: C.muted),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Avatar
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF0F4199), C.pri]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(L.localName(widget.user).isNotEmpty ? L.localName(widget.user) : L.tr('pm')),
                        style: _tj(15, weight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── المنشأة الحالية ───
            _sectionTitle(L.tr('mob_current_org')),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.circular(DS.radiusMd),
                border: Border.all(color: C.border),
              ),
              child: _loadingLoc
                ? const Padding(padding: EdgeInsets.all(16), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: C.priLight, borderRadius: BorderRadius.circular(10)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset('assets/app_icon_192.png', fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_locationName ?? L.tr('no_locations'), style: _tj(14, weight: _locationName != null ? FontWeight.w600 : FontWeight.w400, color: _locationName != null ? C.text : C.muted), maxLines: 2, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
            ),

            const SizedBox(height: 24),

            // ─── رصيد الإجازات ───
            _sectionTitle(L.tr('leave_balance')),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.circular(DS.radiusMd),
                border: Border.all(color: C.border),
              ),
              padding: const EdgeInsets.all(16),
              child: _loadingLeave
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                : Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Row(children: [
                      Text('${_leaveTotal - _leaveUsed}', style: GoogleFonts.ibmPlexMono(fontSize: 28, fontWeight: FontWeight.w800, color: C.pri)),
                      const SizedBox(width: 6),
                      Text(L.tr('remaining_day'), style: _tj(13, color: C.sub)),
                      const Spacer(),
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: C.priLight, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.event_available, size: 20, color: C.pri),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _leaveTotal > 0 ? (_leaveUsed / _leaveTotal).clamp(0.0, 1.0) : 0,
                        minHeight: 8,
                        backgroundColor: C.bg,
                        color: _leaveUsed / (_leaveTotal > 0 ? _leaveTotal : 1) > 0.8 ? C.red : C.pri,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(L.tr('leave_total_label', args: {'total': _leaveTotal.toString()}), style: _tj(11, color: C.muted)),
                      Text(L.tr('leave_used_label', args: {'used': _leaveUsed.toString()}), style: _tj(11, color: C.muted)),
                    ]),
                  ]),
            ),

            const SizedBox(height: 24),

            // ─── الخدمات ───
            _sectionTitle(L.tr('services')),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.circular(DS.radiusMd),
                border: Border.all(color: C.border),
              ),
              child: Column(
                children: [
                  _menuItem(
                    icon: Icons.notifications_outlined,
                    label: L.tr('my_notifications'),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmpNotificationsPage(user: widget.user))),
                  ),
                  _divider(),
                  _menuItem(
                    icon: Icons.location_on_outlined,
                    label: L.tr('locations_branch'),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmpLocationsPage(user: widget.user))),
                  ),
                  _divider(),
                  _menuItem(
                    icon: Icons.calendar_month_outlined,
                    label: L.tr('work_schedule'),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmpSchedulePage(user: widget.user))),
                  ),
                  _divider(),
                  _menuItem(
                    icon: Icons.person_outline_rounded,
                    label: L.tr('profile'),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmpProfilePage(user: widget.user))),
                  ),
                  _divider(),
                  _menuItem(
                    icon: Icons.face_outlined,
                    label: L.tr('my_face'),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmpMyFacePage(user: widget.user))),
                  ),
                  _divider(),
                  _menuItem(
                    icon: Icons.info_outline_rounded,
                    label: L.tr('onboarding_tour'),
                    onTap: () => _showOnboardingTour(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── إدارة الحساب ───
            _sectionTitle(L.tr('account_mgmt')),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.circular(DS.radiusMd),
                border: Border.all(color: C.border),
              ),
              child: _menuItem(
                icon: Icons.settings_outlined,
                label: L.tr('settings'),
                onTap: () => _showChangePasswordDialog(),
              ),
            ),

            const SizedBox(height: 16),

            // ─── تسجيل الخروج ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showLogoutDialog(context),
                  icon: const Icon(Icons.logout_rounded, size: 18, color: C.red),
                  label: Text(L.tr('logout'), style: _tj(14, weight: FontWeight.w700, color: C.red)),
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
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(title, style: _tj(14, weight: FontWeight.w700, color: C.sub)),
      ),
    );
  }

  // ─── Menu item: Icon on RIGHT, chevron on LEFT (RTL layout) ───
  static const _iconBg = Color(0xFFEDF1F7);
  static const _iconColor = C.pri;

  Widget _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icon on RIGHT (first in RTL)
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: _iconColor),
            ),
            const SizedBox(width: 14),
            // Label
            Text(label, style: _tj(15, weight: FontWeight.w600, color: C.text)),
            const Spacer(),
            // Chevron on LEFT (last in RTL)
            Directionality(textDirection: TextDirection.ltr, child: Icon(Icons.chevron_left_rounded, size: 22, color: C.muted)),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(height: 1, color: C.div),
    );
  }

  String _getInitials(String name) {
    if (name.length >= 2) return name.substring(0, 2);
    return name.isNotEmpty ? name[0] : L.tr('pm');
  }

  String _getCurrentTime() {
    final now = ServerTimeService().now;
    final h = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    return '${h.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? L.tr('pm') : L.tr('am')}';
  }

  void _showOnboardingTour() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => OnboardingScreen(onComplete: () {
        Navigator.pop(context);
      }),
    ));
  }

  void _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(L.tr('change_password'), style: _tj(18, weight: FontWeight.w700, color: C.text)),
              const SizedBox(width: 8),
              const Icon(Icons.lock_outline_rounded, size: 20, color: C.pri),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentCtrl,
                    obscureText: obscureCurrent,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      labelText: L.tr('current_password'),
                      labelStyle: _tj(13, color: C.sub),
                      prefixIcon: IconButton(
                        icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility, size: 18, color: C.muted),
                        onPressed: () => setDState(() => obscureCurrent = !obscureCurrent),
                      ),
                      suffixIcon: const Icon(Icons.lock, size: 18, color: C.muted),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.pri)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? L.tr('required') : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: newCtrl,
                    obscureText: obscureNew,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      labelText: L.tr('new_password'),
                      labelStyle: _tj(13, color: C.sub),
                      prefixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 18, color: C.muted),
                        onPressed: () => setDState(() => obscureNew = !obscureNew),
                      ),
                      suffixIcon: const Icon(Icons.lock_open, size: 18, color: C.muted),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.pri)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return L.tr('required');
                      if (v.length < 6) return L.tr('password_min_6');
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: confirmCtrl,
                    obscureText: obscureConfirm,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      labelText: L.tr('confirm_password'),
                      labelStyle: _tj(13, color: C.sub),
                      prefixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 18, color: C.muted),
                        onPressed: () => setDState(() => obscureConfirm = !obscureConfirm),
                      ),
                      suffixIcon: const Icon(Icons.lock_open, size: 18, color: C.muted),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.pri)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return L.tr('required');
                      if (v != newCtrl.text) return L.tr('password_mismatch');
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(L.tr('cancel'), style: _tj(14, color: C.sub)),
            ),
            ElevatedButton(
              onPressed: loading ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setDState(() => loading = true);
                try {
                  final success = await AuthService().changePassword(currentCtrl.text, newCtrl.text);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(L.tr('password_changed'), style: _tj(13, color: Colors.white)),
                      backgroundColor: C.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(L.tr('current_password_wrong'), style: _tj(13, color: Colors.white)),
                      backgroundColor: C.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ));
                  }
                } catch (_) {
                  if (!ctx.mounted) return;
                  setDState(() => loading = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(L.tr('generic_error'), style: _tj(13, color: Colors.white)),
                    backgroundColor: C.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: C.pri,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              child: loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(L.tr('change'), style: _tj(14, weight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      currentCtrl.dispose();
      newCtrl.dispose();
      confirmCtrl.dispose();
    });
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(L.tr('logout'), style: _tj(18, weight: FontWeight.w700), textAlign: TextAlign.right),
        content: Text(L.tr('logout_confirm_msg'), style: _tj(14), textAlign: TextAlign.right),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(L.tr('cancel'), style: _tj(14, color: C.sub)),
          ),
          TextButton(
            onPressed: () { Navigator.pop(ctx); widget.onLogout(); },
            child: Text(L.tr('logout'), style: _tj(14, weight: FontWeight.w700, color: C.red)),
          ),
        ],
      ),
    );
  }
}
