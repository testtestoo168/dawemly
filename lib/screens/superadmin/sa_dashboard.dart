import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

class SADashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  const SADashboard({super.key, required this.user});
  @override
  State<SADashboard> createState() => _SADashboardState();
}

class _SADashboardState extends State<SADashboard> {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _orgs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final statsResult = await ApiService.get('superadmin.php?action=stats');
      final orgsResult = await ApiService.get('superadmin.php?action=organizations');
      if (mounted) setState(() {
        _stats = statsResult['stats'] ?? {};
        _orgs = List<Map<String, dynamic>>.from(orgsResult['organizations'] ?? []);
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('لوحة التحكم الرئيسية', style: GoogleFonts.tajawal(fontSize: 24, fontWeight: FontWeight.w800, color: C.text)),
          const SizedBox(height: 4),
          Text('مرحباً ${widget.user['name']}', style: GoogleFonts.tajawal(fontSize: 14, color: C.sub)),
          const SizedBox(height: 24),

          // Stats Grid
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
            mainAxisSpacing: 12, crossAxisSpacing: 12,
            childAspectRatio: 1.8,
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            children: [
              _stat('المؤسسات', '${_stats['total_organizations'] ?? 0}', Icons.business, const Color(0xFF7F56D9), const Color(0xFFF4F3FF)),
              _stat('النشطة', '${_stats['active_organizations'] ?? 0}', Icons.check_circle, C.green, const Color(0xFFECFDF3)),
              _stat('الموظفين', '${_stats['total_users'] ?? 0}', Icons.people, C.pri, C.priLight),
              _stat('حضور اليوم', '${_stats['today_attendance'] ?? 0}', Icons.fingerprint, const Color(0xFF0BA5EC), const Color(0xFFE8F8FD)),
            ],
          ),
          const SizedBox(height: 24),

          // Organizations list
          Text('المؤسسات', style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w700, color: C.text)),
          const SizedBox(height: 12),
          ..._orgs.map((org) {
            final active = org['active'] == 1 || org['active'] == true;
            final empCount = org['current_employees'] ?? 0;
            final maxEmp = org['max_employees'] ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: active ? C.border : C.redBd)),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: active ? const Color(0xFFECFDF3) : C.redL, borderRadius: BorderRadius.circular(20)),
                  child: Text(active ? 'نشط' : 'معطل', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: active ? C.green : C.red)),
                ),
                const SizedBox(width: 8),
                Text('$empCount/$maxEmp موظف', style: GoogleFonts.ibmPlexMono(fontSize: 11, color: C.muted)),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(org['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: C.text)),
                  Text(org['plan_name'] ?? 'بدون باقة', style: GoogleFonts.tajawal(fontSize: 12, color: C.sub)),
                ]),
                const SizedBox(width: 10),
                Container(width: 40, height: 40, decoration: BoxDecoration(color: C.priLight, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text((org['name'] ?? 'م').toString().substring(0, 1), style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: C.pri)))),
              ]),
            );
          }),
        ]),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: color)),
        const SizedBox(height: 10),
        Text(value, style: GoogleFonts.ibmPlexMono(fontSize: 24, fontWeight: FontWeight.w800, color: C.text)),
        Text(label, style: GoogleFonts.tajawal(fontSize: 12, color: C.sub)),
      ]),
    );
  }
}
