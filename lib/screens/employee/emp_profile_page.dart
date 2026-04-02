import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';

class EmpProfilePage extends StatelessWidget {
  final Map<String, dynamic> user;
  const EmpProfilePage({super.key, required this.user});

  TextStyle _tj(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);

  @override
  Widget build(BuildContext context) {
    final roleLabels = {'admin': 'مدير النظام', 'moderator': 'مشرف', 'employee': 'موظف'};
    final roleColors = {'admin': C.red, 'moderator': C.purple, 'employee': C.pri};
    final roleBgs = {'admin': C.redL, 'moderator': C.purpleL, 'employee': C.priLight};
    final role = user['role'] ?? 'employee';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: C.white,
        surfaceTintColor: C.white,
        elevation: 0,
        centerTitle: true,
        title: Text('الملف الشخصي', style: _tj(17, weight: FontWeight.w700, color: C.text)),
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
              borderRadius: BorderRadius.circular(6),
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
                      _getInitials(user['name'] ?? 'م'),
                      style: _tj(26, weight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(user['name'] ?? '', style: _tj(18, weight: FontWeight.w700, color: C.text)),
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
                    roleLabels[role] ?? 'موظف',
                    style: _tj(12, weight: FontWeight.w600, color: roleColors[role] ?? C.pri),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ─── Info Cards ───
          _infoCard(Icons.mail_outline_rounded, 'البريد الإلكتروني', user['email'] ?? '—'),
          _infoCard(Icons.apartment_rounded, 'القسم / الإدارة', user['dept'] ?? '—'),
          _infoCard(Icons.badge_outlined, 'الرقم الوظيفي', user['empId'] ?? '—'),
          _infoCard(Icons.phone_outlined, 'رقم الجوال', user['phone'] ?? '—'),
          _infoCard(Icons.fingerprint_rounded, 'طريقة المصادقة', 'بصمة + التعرف على الوجه'),
          _infoCard(Icons.calendar_today_rounded, 'تاريخ التعيين', user['joinDate'] ?? '—'),
        ],
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(6),
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
            decoration: BoxDecoration(color: C.priLight, borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, size: 18, color: C.pri),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.length >= 2) return name.substring(0, 2);
    return name.isNotEmpty ? name[0] : 'م';
  }
}
