import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

class SaDashboard extends StatefulWidget {
  const SaDashboard({super.key});
  @override
  State<SaDashboard> createState() => _SaDashboardState();
}

class _SaDashboardState extends State<SaDashboard> {
  bool _loading = true;
  Map<String, dynamic> _stats = {};

  TextStyle _tj(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('superadmin.php?action=stats');
      if (res['success'] == true && mounted) {
        setState(() {
          _stats = (res['stats'] as Map<String, dynamic>?) ?? {};
          _loading = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('نظرة عامة', style: _tj(24, weight: FontWeight.w800, color: W.text)),
            const SizedBox(height: 4),
            Text('إحصائيات النظام الشاملة', style: _tj(14, color: W.sub)),
          ])),
          OutlinedButton.icon(
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text('تحديث', style: _tj(13, weight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: W.pri,
              side: BorderSide(color: W.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusSm)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ]),
        const SizedBox(height: 24),

        // Stat cards
        Wrap(spacing: 16, runSpacing: 16, children: [
          _statCard(
            'إجمالي المؤسسات',
            '${_stats['total_organizations'] ?? 0}',
            Icons.business_rounded,
            const Color(0xFF175CD3),
            const Color(0xFFE7EFFF),
          ),
          _statCard(
            'المؤسسات النشطة',
            '${_stats['active_organizations'] ?? 0}',
            Icons.check_circle_rounded,
            const Color(0xFF17B26A),
            const Color(0xFFECFDF3),
          ),
          _statCard(
            'إجمالي المستخدمين',
            '${_stats['total_users'] ?? 0}',
            Icons.people_rounded,
            const Color(0xFF7F56D9),
            const Color(0xFFF4F3FF),
          ),
          _statCard(
            'حضور اليوم',
            '${_stats['today_attendance'] ?? 0}',
            const Color(0xFFF79009),
            const Color(0xFFFFFAEB),
          ),
        ]),
      ]),
    );
  }

  Widget _statCard(String label, String value, dynamic iconOrColor, Color iconBg, [Color? cardIconBg]) {
    final IconData icon;
    final Color iconColor;
    if (iconOrColor is IconData) {
      icon = iconOrColor;
      iconColor = cardIconBg ?? const Color(0xFF175CD3);
    } else {
      icon = Icons.trending_up_rounded;
      iconColor = iconOrColor as Color;
    }
    final bgColor = cardIconBg ?? iconBg;

    return SizedBox(
      width: 260,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: DS.cardDecoration(radius: DS.radiusMd),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(DS.radiusMd)),
            child: Icon(icon, size: 24, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: _tj(13, color: W.sub)),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.ibmPlexMono(fontSize: 28, fontWeight: FontWeight.w800, color: W.text)),
          ])),
        ]),
      ),
    );
  }
}
