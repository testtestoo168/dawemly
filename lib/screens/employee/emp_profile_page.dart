import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_locale.dart';

class EmpProfilePage extends StatelessWidget {
  final Map<String, dynamic> user;
  const EmpProfilePage({super.key, required this.user});

  TextStyle _tj(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);

  @override
  Widget build(BuildContext context) {
    final roleLabels = {'admin': L.tr('system_admin'), 'moderator': L.tr('role_supervisor'), 'employee': L.tr('employee_unit')};
    final roleColors = {'admin': C.red, 'moderator': C.purple, 'employee': C.pri};
    final roleBgs = {'admin': C.redL, 'moderator': C.purpleL, 'employee': C.priLight};
    final role = user['role'] ?? 'employee';

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.white,
        surfaceTintColor: C.white,
        elevation: 0,
        centerTitle: true,
        title: Text(L.tr('profile'), style: _tj(17, weight: FontWeight.w700, color: C.text)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: C.text),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: C.border, height: 1)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Avatar Card ───
          Container(
            decoration: BoxDecoration(
              color: C.white,
              borderRadius: BorderRadius.circular(DS.radiusMd),
              border: Border.all(color: C.border),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0F4199), C.pri]),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(L.localName(user).isNotEmpty ? L.localName(user) : L.tr('pm')),
                      style: _tj(26, weight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(L.localName(user), style: _tj(18, weight: FontWeight.w700, color: C.text)),
                const SizedBox(height: 4),
                Text(user['empId'] ?? '', style: _tj(13, color: C.sub)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: roleBgs[role] ?? C.priLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    roleLabels[role] ?? L.tr('employee_unit'),
                    style: _tj(12, weight: FontWeight.w600, color: roleColors[role] ?? C.pri),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ─── Info Cards ───
          _infoCard(Icons.mail_outline_rounded, L.tr('email'), user['email'] ?? '—'),
          _infoCard(Icons.apartment_rounded, L.tr('department'), L.localDept(user).isNotEmpty ? L.localDept(user) : '—'),
          _infoCard(Icons.badge_outlined, L.tr('employee_id'), user['empId'] ?? '—'),
          _infoCard(Icons.phone_outlined, L.tr('phone_number'), user['phone'] ?? '—'),
          _infoCard(Icons.fingerprint_rounded, L.tr('auth_method'), L.tr('fingerprint_face')),
          _infoCard(Icons.calendar_today_rounded, L.tr('appointment_date'), user['joinDate'] ?? '—'),
        ],
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        border: Border.all(color: C.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(label, style: _tj(12, color: C.muted)),
                const SizedBox(height: 3),
                Text(value, style: _tj(14, weight: FontWeight.w600, color: C.text)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: C.priLight, borderRadius: BorderRadius.circular(DS.radiusSm)),
            child: Icon(icon, size: 18, color: C.pri),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.length >= 2) return name.substring(0, 2);
    return name.isNotEmpty ? name[0] : L.tr('pm');
  }
}
