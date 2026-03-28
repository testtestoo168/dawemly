import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

class SAPlans extends StatefulWidget {
  final Map<String, dynamic> user;
  const SAPlans({super.key, required this.user});
  @override
  State<SAPlans> createState() => _SAPlansState();
}

class _SAPlansState extends State<SAPlans> {
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final result = await ApiService.get('superadmin.php?action=plans');
      if (mounted) setState(() { _plans = List<Map<String, dynamic>>.from(result['plans'] ?? []); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _showEditPlan({Map<String, dynamic>? plan}) {
    final nameCtrl = TextEditingController(text: plan?['name'] ?? '');
    final nameEnCtrl = TextEditingController(text: plan?['name_en'] ?? '');
    final maxEmpCtrl = TextEditingController(text: '${plan?['max_employees'] ?? 20}');
    final maxBranchCtrl = TextEditingController(text: '${plan?['max_branches'] ?? 1}');
    final maxLocCtrl = TextEditingController(text: '${plan?['max_locations'] ?? 2}');
    final maxRadiusCtrl = TextEditingController(text: '${plan?['max_radius'] ?? 500}');
    final maxSupCtrl = TextEditingController(text: '${plan?['max_supervisors'] ?? 0}');
    final priceMonthCtrl = TextEditingController(text: '${plan?['price_monthly'] ?? 0}');
    final priceYearCtrl = TextEditingController(text: '${plan?['price_yearly'] ?? 0}');

    bool faceAuth = (plan?['allow_face_auth'] ?? 0) == 1;
    bool reportsPdf = (plan?['allow_reports_pdf'] ?? 0) == 1;
    bool reportsExcel = (plan?['allow_reports_excel'] ?? 0) == 1;
    bool leaveBalance = (plan?['allow_leave_balance'] ?? 0) == 1;
    bool salaryCalc = (plan?['allow_salary_calc'] ?? 0) == 1;
    bool overtime = (plan?['allow_overtime'] ?? 0) == 1;
    bool verification = (plan?['allow_verification'] ?? 0) == 1;
    bool loading = false;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          width: 520, constraints: const BoxConstraints(maxHeight: 650),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF7F56D9), Color(0xFF9E77ED)]), borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                InkWell(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.close, color: Colors.white70, size: 20)),
                Text(plan == null ? 'إضافة باقة' : 'تعديل الباقة', style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
            Flexible(child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Row(children: [
                  Expanded(child: _f('الاسم بالإنجليزي', nameEnCtrl, isLtr: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _f('اسم الباقة *', nameCtrl)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _f('أقصى فروع', maxBranchCtrl, isNum: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _f('أقصى موظفين', maxEmpCtrl, isNum: true)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _f('أقصى نطاق (م)', maxRadiusCtrl, isNum: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _f('أقصى مواقع', maxLocCtrl, isNum: true)),
                ]),
                const SizedBox(height: 12),
                _f('أقصى مشرفين', maxSupCtrl, isNum: true),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _f('سعر سنوي', priceYearCtrl, isNum: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _f('سعر شهري', priceMonthCtrl, isNum: true)),
                ]),
                const SizedBox(height: 16),
                Text('الصلاحيات', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: C.text)),
                const SizedBox(height: 8),
                _toggle('بصمة الوجه', faceAuth, (v) => ss(() => faceAuth = v)),
                _toggle('تقارير PDF', reportsPdf, (v) => ss(() => reportsPdf = v)),
                _toggle('تصدير Excel', reportsExcel, (v) => ss(() => reportsExcel = v)),
                _toggle('أرصدة الإجازات', leaveBalance, (v) => ss(() => leaveBalance = v)),
                _toggle('حساب الرواتب', salaryCalc, (v) => ss(() => salaryCalc = v)),
                _toggle('الأوفرتايم', overtime, (v) => ss(() => overtime = v)),
                _toggle('إثبات الحالة', verification, (v) => ss(() => verification = v)),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: loading ? null : () async {
                    if (nameCtrl.text.isEmpty) return;
                    ss(() => loading = true);
                    try {
                      await ApiService.post('superadmin.php?action=save_plan', body: {
                        if (plan != null) 'id': plan['id'],
                        'name': nameCtrl.text.trim(), 'name_en': nameEnCtrl.text.trim(),
                        'max_employees': int.tryParse(maxEmpCtrl.text) ?? 20,
                        'max_branches': int.tryParse(maxBranchCtrl.text) ?? 1,
                        'max_locations': int.tryParse(maxLocCtrl.text) ?? 2,
                        'max_radius': int.tryParse(maxRadiusCtrl.text) ?? 500,
                        'max_supervisors': int.tryParse(maxSupCtrl.text) ?? 0,
                        'allow_face_auth': faceAuth ? 1 : 0, 'allow_reports_pdf': reportsPdf ? 1 : 0,
                        'allow_reports_excel': reportsExcel ? 1 : 0, 'allow_leave_balance': leaveBalance ? 1 : 0,
                        'allow_salary_calc': salaryCalc ? 1 : 0, 'allow_overtime': overtime ? 1 : 0,
                        'allow_verification': verification ? 1 : 0, 'allow_schedules': 1,
                        'price_monthly': double.tryParse(priceMonthCtrl.text) ?? 0,
                        'price_yearly': double.tryParse(priceYearCtrl.text) ?? 0,
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    } catch (_) { ss(() => loading = false); }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7F56D9), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('حفظ', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
                )),
              ]),
            )),
          ]),
        ),
      );
    }));
  }

  Widget _f(String label, TextEditingController ctrl, {bool isLtr = false, bool isNum = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(label, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.sub)),
      const SizedBox(height: 4),
      TextField(controller: ctrl, textAlign: isLtr || isNum ? TextAlign.left : TextAlign.right,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        style: GoogleFonts.tajawal(fontSize: 13),
        decoration: InputDecoration(filled: true, fillColor: C.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.border)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
    ]);
  }

  Widget _toggle(String label, bool value, Function(bool) onChanged) {
    return Row(children: [
      Switch(value: value, activeColor: const Color(0xFF7F56D9), onChanged: onChanged),
      const Spacer(),
      Text(label, style: GoogleFonts.tajawal(fontSize: 13, color: C.text)),
    ]);
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
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            ElevatedButton.icon(
              onPressed: () => _showEditPlan(),
              icon: const Icon(Icons.add, size: 16),
              label: Text('إضافة باقة', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7F56D9), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
            Text('إدارة الباقات', style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w800, color: C.text)),
          ]),
          const SizedBox(height: 20),

          ..._plans.map((plan) {
            final features = <String>[];
            if (plan['allow_face_auth'] == 1) features.add('بصمة وجه');
            if (plan['allow_reports_pdf'] == 1) features.add('PDF');
            if (plan['allow_reports_excel'] == 1) features.add('Excel');
            if (plan['allow_leave_balance'] == 1) features.add('إجازات');
            if (plan['allow_salary_calc'] == 1) features.add('رواتب');
            if (plan['allow_overtime'] == 1) features.add('أوفرتايم');
            if (plan['allow_verification'] == 1) features.add('إثبات');

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(children: [
                  InkWell(onTap: () => _showEditPlan(plan: plan),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: C.priLight, borderRadius: BorderRadius.circular(8)),
                      child: Text('تعديل', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: C.pri)))),
                  const Spacer(),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(plan['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
                    Text('${plan['price_monthly']} ر.س / شهري', style: GoogleFonts.ibmPlexMono(fontSize: 12, color: C.sub)),
                  ]),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _badge('${plan['max_employees']} موظف', C.pri),
                  const SizedBox(width: 6),
                  _badge('${plan['max_branches']} فرع', const Color(0xFF7F56D9)),
                  const SizedBox(width: 6),
                  _badge('${plan['max_radius']}م نطاق', const Color(0xFF0BA5EC)),
                ]),
                if (features.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 4, runSpacing: 4, alignment: WrapAlignment.end,
                    children: features.map((f) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFECFDF3), borderRadius: BorderRadius.circular(6)),
                      child: Text(f, style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: C.green)),
                    )).toList()),
                ],
              ]),
            );
          }),
        ]),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
