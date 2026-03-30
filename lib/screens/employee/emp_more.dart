import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';
import 'emp_locations_page.dart';
import 'emp_schedule_page.dart';
import 'emp_profile_page.dart';
import 'emp_my_face_page.dart';

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

  TextStyle _tj(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);

  @override
  void initState() {
    super.initState();
    _loadLocation();
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
          return assigned.isEmpty || assigned.contains(uid);
        }).toList();
        if (mounted) {
          setState(() {
            _locationName = userLocs.isNotEmpty ? (userLocs.first['name'] ?? 'المنشأة') : null;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
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
                      Text('المزيد', style: _tj(17, weight: FontWeight.w700, color: C.text)),
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
                        _getInitials(widget.user['name'] ?? 'م'),
                        style: _tj(15, weight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── المنشأة الحالية ───
            _sectionTitle('المنشأة الحالية'),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.circular(14),
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
                        Text(_locationName ?? 'لا توجد مواقع محددة', style: _tj(14, weight: _locationName != null ? FontWeight.w600 : FontWeight.w400, color: _locationName != null ? C.text : C.muted)),
                        const Spacer(),
                      ],
                    ),
                  ),
            ),

            const SizedBox(height: 24),

            // ─── الخدمات ───
            _sectionTitle('الخدمات'),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: C.border),
              ),
              child: Column(
                children: [
                  _menuItem(
                    icon: Icons.location_on_outlined,
                    label: 'المواقع والفرع',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmpLocationsPage(user: widget.user))),
                  ),
                  _divider(),
                  _menuItem(
                    icon: Icons.calendar_month_outlined,
                    label: 'جدول العمل',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmpSchedulePage(user: widget.user))),
                  ),
                  _divider(),
                  _menuItem(
                    icon: Icons.person_outline_rounded,
                    label: 'الملف الشخصي',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmpProfilePage(user: widget.user))),
                  ),
                  _divider(),
                  _menuItem(
                    icon: Icons.face_outlined,
                    label: 'بصمتي',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmpMyFacePage(user: widget.user))),
                  ),
                  _divider(),
                  _menuItem(
                    icon: Icons.info_outline_rounded,
                    label: 'جولة تعريفية للتطبيق',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── إدارة الحساب ───
            _sectionTitle('إدارة الحساب'),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: C.border),
              ),
              child: _menuItem(
                icon: Icons.settings_outlined,
                label: 'الإعدادات',
                onTap: () {},
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
    return name.isNotEmpty ? name[0] : 'م';
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    final h = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    return '${h.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'م' : 'ص'}';
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('تسجيل الخروج', style: _tj(18, weight: FontWeight.w700), textAlign: TextAlign.right),
        content: Text('هل تريد تسجيل الخروج من حسابك؟', style: _tj(14), textAlign: TextAlign.right),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: _tj(14, color: C.sub)),
          ),
          TextButton(
            onPressed: () { Navigator.pop(ctx); widget.onLogout(); },
            child: Text('تسجيل الخروج', style: _tj(14, weight: FontWeight.w700, color: C.red)),
          ),
        ],
      ),
    );
  }
}
