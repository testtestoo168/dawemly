import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

class SaPlans extends StatefulWidget {
  const SaPlans({super.key});
  @override
  State<SaPlans> createState() => _SaPlansState();
}

class _SaPlansState extends State<SaPlans> {
  bool _loading = true;
  List<Map<String, dynamic>> _plans = [];

  TextStyle _tj(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('superadmin.php?action=plans');
      if (res['success'] == true && mounted) {
        setState(() {
          _plans = (res['plans'] as List? ?? []).cast<Map<String, dynamic>>();
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
          Text('الباقات (${_plans.length})', style: _tj(20, weight: FontWeight.w800, color: W.text)),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _loadPlans,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text('تحديث', style: _tj(12, weight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: W.pri,
              side: BorderSide(color: W.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusSm)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          ),
        ]),
        const SizedBox(height: 24),

        if (_plans.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(children: [
              Icon(Icons.card_membership_rounded, size: 48, color: W.muted.withOpacity(0.4)),
              const SizedBox(height: 12),
              Text('لا توجد باقات', style: _tj(16, color: W.muted)),
            ]),
          ))
        else
          Wrap(spacing: 16, runSpacing: 16, children: _plans.map((plan) => _planCard(plan)).toList()),
      ]),
    );
  }

  Widget _planCard(Map<String, dynamic> plan) {
    final features = <_Feature>[
      _Feature(Icons.people_rounded, 'الحد الأقصى للموظفين', '${plan['max_employees'] ?? '-'}'),
      _Feature(Icons.store_rounded, 'الفروع', '${plan['max_branches'] ?? '-'}'),
      _Feature(Icons.location_on_rounded, 'المواقع', '${plan['max_locations'] ?? '-'}'),
      _Feature(Icons.radar_rounded, 'نطاق GPS', '${plan['max_radius'] ?? '-'} م'),
      _Feature(Icons.supervisor_account_rounded, 'المشرفين', '${plan['max_supervisors'] ?? '-'}'),
    ];

    final boolFeatures = <_BoolFeature>[
      _BoolFeature('بصمة الوجه', plan['allow_face_auth'] == 1 || plan['allow_face_auth'] == true),
      _BoolFeature('تقارير PDF', plan['allow_reports_pdf'] == 1 || plan['allow_reports_pdf'] == true),
      _BoolFeature('تقارير Excel', plan['allow_reports_excel'] == 1 || plan['allow_reports_excel'] == true),
      _BoolFeature('رصيد الإجازات', plan['allow_leave_balance'] == 1 || plan['allow_leave_balance'] == true),
      _BoolFeature('حساب الرواتب', plan['allow_salary_calc'] == 1 || plan['allow_salary_calc'] == true),
      _BoolFeature('الأوفرتايم', plan['allow_overtime'] == 1 || plan['allow_overtime'] == true),
      _BoolFeature('إثبات الحالة', plan['allow_verification'] == 1 || plan['allow_verification'] == true),
      _BoolFeature('الجداول', plan['allow_schedules'] == 1 || plan['allow_schedules'] == true),
    ];

    return SizedBox(
      width: 360,
      child: Container(
        decoration: DS.cardDecoration(radius: DS.radiusLg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Plan header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [const Color(0xFF1A1A2E), const Color(0xFF2A2A42)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(DS.radiusLg)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(plan['name'] ?? '', style: _tj(18, weight: FontWeight.w800, color: Colors.white)),
              if ((plan['name_en'] ?? '').toString().isNotEmpty)
                Text(plan['name_en'], style: _tj(12, color: Colors.white.withOpacity(0.6))),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${plan['price_monthly'] ?? 0}', style: GoogleFonts.ibmPlexMono(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('ر.س / شهر', style: _tj(12, color: Colors.white.withOpacity(0.6))),
                ),
              ]),
              if (plan['price_yearly'] != null) ...[
                const SizedBox(height: 4),
                Text('${plan['price_yearly']} ر.س / سنة', style: _tj(12, color: Colors.white.withOpacity(0.4))),
              ],
            ]),
          ),
          // Features
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('الحدود', style: _tj(13, weight: FontWeight.w700, color: W.sub)),
              const SizedBox(height: 10),
              ...features.map((f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Icon(f.icon, size: 16, color: W.pri),
                  const SizedBox(width: 10),
                  Text(f.label, style: _tj(13, color: W.text)),
                  const Spacer(),
                  Text(f.value, style: _tj(13, weight: FontWeight.w700, color: W.text)),
                ]),
              )),
              const SizedBox(height: 16),
              Text('الميزات', style: _tj(13, weight: FontWeight.w700, color: W.sub)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: boolFeatures.map((bf) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: bf.enabled ? const Color(0xFFECFDF3) : const Color(0xFFFEF3F2),
                  borderRadius: BorderRadius.circular(DS.radiusPill),
                  border: Border.all(color: bf.enabled ? const Color(0xFFABEFC6) : const Color(0xFFFECDCA)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    bf.enabled ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 14,
                    color: bf.enabled ? const Color(0xFF17B26A) : const Color(0xFFF04438),
                  ),
                  const SizedBox(width: 4),
                  Text(bf.label, style: _tj(11, weight: FontWeight.w600,
                    color: bf.enabled ? const Color(0xFF17B26A) : const Color(0xFFF04438))),
                ]),
              )).toList()),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String label;
  final String value;
  const _Feature(this.icon, this.label, this.value);
}

class _BoolFeature {
  final String label;
  final bool enabled;
  const _BoolFeature(this.label, this.enabled);
}
