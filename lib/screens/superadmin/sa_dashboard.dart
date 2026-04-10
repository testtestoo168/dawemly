import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';
import '../../l10n/app_locale.dart';

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

    final expiringOrgs = (_stats['expiring_soon'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final atCapacity = (_stats['at_capacity'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final growth = (_stats['growth'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(L.tr('overview'), style: _tj(24, weight: FontWeight.w800, color: W.text)),
            const SizedBox(height: 4),
            Text(L.tr('system_stats_desc'), style: _tj(14, color: W.sub)),
          ])),
          OutlinedButton.icon(
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(L.tr('update'), style: _tj(13, weight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: W.pri,
              side: BorderSide(color: W.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusSm)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ]),
        const SizedBox(height: 24),

        // Main stat cards
        Wrap(spacing: 16, runSpacing: 16, children: [
          _statCard(L.tr('total_orgs'), '${_stats['total_organizations'] ?? 0}', Icons.business_rounded, const Color(0xFF175CD3), const Color(0xFFE7EFFF)),
          _statCard(L.tr('active_orgs'), '${_stats['active_organizations'] ?? 0}', Icons.check_circle_rounded, const Color(0xFF17B26A), const Color(0xFFECFDF3)),
          _statCard(L.tr('total_employees'), '${_stats['total_employees'] ?? 0}', Icons.people_rounded, const Color(0xFF7F56D9), const Color(0xFFF4F3FF)),
          _statCard(L.tr('sa_today_attendance'), '${_stats['today_attendance'] ?? 0}', Icons.fingerprint_rounded, const Color(0xFFF79009), const Color(0xFFFFFAEB)),
          _statCard(L.tr('monthly_revenue'), '${_stats['mrr'] ?? 0} ${L.tr("sar")}', Icons.payments_rounded, const Color(0xFF0BA5EC), const Color(0xFFF0F9FF)),
          _statCard(L.tr('new_orgs_month'), '${_stats['new_this_month'] ?? 0}', Icons.trending_up_rounded, const Color(0xFFEE46BC), const Color(0xFFFDF2FA)),
        ]),
        const SizedBox(height: 32),

        // Alerts row
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Expiring subscriptions
          Expanded(child: _alertCard(
            L.tr('expiring_subs'),
            Icons.warning_amber_rounded,
            const Color(0xFFF79009),
            const Color(0xFFFFFAEB),
            expiringOrgs.isEmpty
              ? [Padding(padding: const EdgeInsets.all(16), child: Text(L.tr('no_expiring'), style: _tj(13, color: W.muted)))]
              : expiringOrgs.map((o) => _alertRow(
                  o['name'] ?? '',
                  L.tr('sa_sub_end', args: {'date': (o['subscription_end'] ?? '-').toString()}),
                  Icons.schedule_rounded,
                  const Color(0xFFF79009),
                )).toList(),
          )),
          const SizedBox(width: 16),
          // At capacity
          Expanded(child: _alertCard(
            L.tr('sa_maxed_orgs'),
            Icons.group_off_rounded,
            const Color(0xFFF04438),
            const Color(0xFFFEF3F2),
            atCapacity.isEmpty
              ? [Padding(padding: const EdgeInsets.all(16), child: Text(L.tr('sa_no_maxed'), style: _tj(13, color: W.muted)))]
              : atCapacity.map((o) => _alertRow(
                  o['name'] ?? '',
                  L.tr('sa_emp_of_max', args: {'current': (o['current_employees'] ?? 0).toString(), 'max': (o['max_employees'] ?? 0).toString()}),
                  Icons.people_rounded,
                  const Color(0xFFF04438),
                )).toList(),
          )),
        ]),

        if ((_stats['expired_subscriptions'] ?? 0) > 0) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3F2),
              borderRadius: BorderRadius.circular(DS.radiusMd),
              border: Border.all(color: const Color(0xFFFECDCA)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFF04438), size: 20),
              const SizedBox(width: 12),
              Text(L.tr('sa_expired_subs', args: {'n': (_stats['expired_subscriptions'] ?? 0).toString()}), style: _tj(14, weight: FontWeight.w600, color: const Color(0xFFF04438))),
            ]),
          ),
        ],

        // Growth chart (simple bar)
        if (growth.isNotEmpty) ...[
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: DS.cardDecoration(radius: DS.radiusMd),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(L.tr('sa_org_growth'), style: _tj(15, weight: FontWeight.w700, color: W.text)),
              const SizedBox(height: 20),
              SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: growth.map((g) {
                    final count = (g['count'] as num?)?.toInt() ?? 0;
                    final maxCount = growth.fold<int>(1, (mx, item) {
                      final c = (item['count'] as num?)?.toInt() ?? 0;
                      return c > mx ? c : mx;
                    });
                    final height = maxCount > 0 ? (count / maxCount * 80.0) : 0.0;
                    return Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text('$count', style: _tj(12, weight: FontWeight.w700, color: W.pri)),
                      const SizedBox(height: 4),
                      Container(
                        width: 32, height: height.clamp(4.0, 80.0),
                        decoration: BoxDecoration(
                          color: W.pri,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text((g['month'] ?? '').toString().substring(5), style: _tj(11, color: W.muted)),
                    ]));
                  }).toList(),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color iconColor, Color bgColor) {
    return SizedBox(
      width: 240,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: DS.cardDecoration(radius: DS.radiusMd),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(DS.radiusMd)),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: _tj(12, color: W.sub)),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.ibmPlexMono(fontSize: 22, fontWeight: FontWeight.w800, color: W.text)),
          ])),
        ]),
      ),
    );
  }

  Widget _alertCard(String title, IconData icon, Color color, Color bgColor, List<Widget> children) {
    return Container(
      decoration: DS.cardDecoration(radius: DS.radiusMd),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(DS.radiusMd)),
          ),
          child: Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(title, style: _tj(14, weight: FontWeight.w700, color: color)),
          ]),
        ),
        ...children,
      ]),
    );
  }

  Widget _alertRow(String name, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: W.div))),
      child: Row(children: [
        Icon(icon, size: 16, color: color.withOpacity(0.6)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: _tj(13, weight: FontWeight.w600, color: W.text)),
          Text(subtitle, style: _tj(11, color: W.muted)),
        ])),
      ]),
    );
  }
}
