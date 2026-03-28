import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

class SAOrganizations extends StatefulWidget {
  final Map<String, dynamic> user;
  const SAOrganizations({super.key, required this.user});
  @override
  State<SAOrganizations> createState() => _SAOrganizationsState();
}

class _SAOrganizationsState extends State<SAOrganizations> {
  List<Map<String, dynamic>> _orgs = [];
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final orgsResult = await ApiService.get('superadmin.php?action=organizations');
      final plansResult = await ApiService.get('superadmin.php?action=plans');
      if (mounted) setState(() {
        _orgs = List<Map<String, dynamic>>.from(orgsResult['organizations'] ?? []);
        _plans = List<Map<String, dynamic>>.from(plansResult['plans'] ?? []);
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _showAddEditDialog({Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final emailCtrl = TextEditingController(text: existing?['email'] ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone'] ?? '');
    final adminEmailCtrl = TextEditingController();
    final adminPassCtrl = TextEditingController();
    final adminNameCtrl = TextEditingController();
    int? selectedPlan = existing?['plan_id'];
    bool loading = false;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDState) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          width: 500,
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)]), borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                InkWell(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.close, color: Colors.white70, size: 20)),
                Text(existing == null ? 'إضافة مؤسسة جديدة' : 'تعديل المؤسسة', style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
            Flexible(child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                _field('اسم المؤسسة *', nameCtrl),
                const SizedBox(height: 12),
                _field('البريد الإلكتروني', emailCtrl, isLtr: true),
                const SizedBox(height: 12),
                _field('رقم الهاتف', phoneCtrl, isLtr: true),
                const SizedBox(height: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('الباقة', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.sub)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<int>(
                    value: selectedPlan,
                    items: _plans.map((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text('${p['name']} (${p['max_employees']} موظف)', style: GoogleFonts.tajawal(fontSize: 13)))).toList(),
                    onChanged: (v) => setDState(() => selectedPlan = v),
                    decoration: InputDecoration(filled: true, fillColor: C.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.border)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  ),
                ]),
                if (existing == null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: C.priLight, borderRadius: BorderRadius.circular(12)),
                    child: Column(children: [
                      Text('حساب مدير المؤسسة', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: C.pri)),
                      const SizedBox(height: 8),
                      _field('اسم المدير', adminNameCtrl),
                      const SizedBox(height: 8),
                      _field('بريد المدير *', adminEmailCtrl, isLtr: true),
                      const SizedBox(height: 8),
                      _field('كلمة المرور *', adminPassCtrl, isPass: true),
                    ]),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: loading ? null : () async {
                    if (nameCtrl.text.isEmpty) return;
                    setDState(() => loading = true);
                    try {
                      await ApiService.post('superadmin.php?action=save_organization', body: {
                        if (existing != null) 'id': existing['id'],
                        'name': nameCtrl.text.trim(),
                        'email': emailCtrl.text.trim(),
                        'phone': phoneCtrl.text.trim(),
                        'plan_id': selectedPlan,
                        if (existing == null) 'admin_email': adminEmailCtrl.text.trim(),
                        if (existing == null) 'admin_password': adminPassCtrl.text,
                        if (existing == null) 'admin_name': adminNameCtrl.text.trim(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    } catch (e) { setDState(() => loading = false); }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: C.pri, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(existing == null ? 'إنشاء المؤسسة' : 'حفظ التعديلات', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
                )),
              ]),
            )),
          ]),
        ),
      );
    }));
  }

  Widget _field(String label, TextEditingController ctrl, {bool isLtr = false, bool isPass = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(label, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.sub)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl, obscureText: isPass,
        textAlign: isLtr ? TextAlign.left : TextAlign.right,
        textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
        style: GoogleFonts.tajawal(fontSize: 13),
        decoration: InputDecoration(filled: true, fillColor: C.bg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.border)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
      ),
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
              onPressed: () => _showAddEditDialog(),
              icon: const Icon(Icons.add, size: 16),
              label: Text('إضافة مؤسسة', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: C.pri, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
            Text('إدارة المؤسسات', style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w800, color: C.text)),
          ]),
          const SizedBox(height: 20),

          ..._orgs.map((org) {
            final active = org['active'] == 1 || org['active'] == true;
            final empCount = org['current_employees'] ?? 0;
            final maxEmp = org['max_employees'] ?? '∞';
            final branchCount = org['current_branches'] ?? 0;
            final maxBranch = org['max_branches'] ?? '∞';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: active ? C.border : C.redBd)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(children: [
                  // Actions
                  InkWell(onTap: () async { await ApiService.post('superadmin.php?action=toggle_org', body: {'id': org['id']}); _load(); },
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: active ? C.redL : const Color(0xFFECFDF3), borderRadius: BorderRadius.circular(8)),
                      child: Text(active ? 'تعطيل' : 'تفعيل', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: active ? C.red : C.green)))),
                  const SizedBox(width: 6),
                  InkWell(onTap: () => _showAddEditDialog(existing: org),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: C.priLight, borderRadius: BorderRadius.circular(8)),
                      child: Text('تعديل', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: C.pri)))),
                  const Spacer(),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(org['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
                    Text('باقة: ${org['plan_name'] ?? 'غير محددة'}', style: GoogleFonts.tajawal(fontSize: 12, color: C.sub)),
                  ]),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _usageBadge('موظفين', '$empCount/$maxEmp', C.pri),
                  const SizedBox(width: 8),
                  _usageBadge('فروع', '$branchCount/$maxBranch', const Color(0xFF7F56D9)),
                  const SizedBox(width: 8),
                  _usageBadge(active ? 'نشط' : 'معطل', '', active ? C.green : C.red),
                ]),
              ]),
            );
          }),
        ]),
      ),
    );
  }

  Widget _usageBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Text(value.isEmpty ? label : '$label: $value', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
