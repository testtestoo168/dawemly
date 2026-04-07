import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

class AdminSalary extends StatefulWidget {
  final Map<String, dynamic>? adminUser;
  const AdminSalary({super.key, this.adminUser});
  @override State<AdminSalary> createState() => _AdminSalaryState();
}

class _AdminSalaryState extends State<AdminSalary> {
  final _mono = GoogleFonts.ibmPlexMono;
  final _months = const ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
  late int _selMonth, _selYear;
  List<Map<String, dynamic>> _records = [];
  Map<String, dynamic> _settings = {};
  bool _loading = true;
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selMonth = now.month;
    _selYear = now.year;
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final settingsRes = await ApiService.get('salary.php?action=get_settings');
      if (settingsRes['success'] == true && mounted) {
        _settings = settingsRes['settings'] as Map<String, dynamic>? ?? {};
      }
      final allRes = await ApiService.get('salary.php?action=all', params: {
        'month': '$_selMonth',
        'year': '$_selYear',
      });
      if (allRes['success'] == true && mounted) {
        _records = (allRes['records'] as List? ?? []).cast<Map<String, dynamic>>();
      }
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _toDouble(dynamic v) => double.tryParse('${v ?? 0}') ?? 0;
  int _toInt(dynamic v) => int.tryParse('${v ?? 0}') ?? 0;

  /// Format number with commas: 12500 -> 12,500
  String _fmtNum(double v) {
    if (v == 0) return '0';
    final s = v.toStringAsFixed(0);
    final result = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (s[i] == '-') { result.write('-'); break; }
      if (count > 0 && count % 3 == 0) result.write(',');
      result.write(s[i]);
      count++;
    }
    return result.toString().split('').reversed.join();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isWide = screenW > 800;
    final isMobile = screenW < 500;

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    // Compute totals
    double totalDeductions = 0;
    double totalOvertimeAmt = 0;
    double totalLateDeduction = 0;
    double totalAbsentDeduction = 0;
    for (final r in _records) {
      totalDeductions += _toDouble(r['total_deductions']);
      totalOvertimeAmt += _toDouble(r['overtime_amount']);
      totalLateDeduction += _toDouble(r['deduction_late']);
      totalAbsentDeduction += _toDouble(r['deduction_absent']);
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isWide ? 28 : 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const SizedBox(height: 4),

          // ─── Month selector ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: DS.cardDecoration(),
            child: Row(children: [
              InkWell(
                onTap: () => setState(() { _selMonth--; if (_selMonth < 1) { _selMonth = 12; _selYear--; } _loadAll(); }),
                child: Container(width: 32, height: 32, decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(4)), child: Icon(Icons.chevron_right, size: 18, color: W.sub)),
              ),
              const Spacer(),
              Text('${_months[_selMonth - 1]} $_selYear', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: W.text)),
              const Spacer(),
              InkWell(
                onTap: () => setState(() { _selMonth++; if (_selMonth > 12) { _selMonth = 1; _selYear++; } _loadAll(); }),
                child: Container(width: 32, height: 32, decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(4)), child: Icon(Icons.chevron_left, size: 18, color: W.sub)),
              ),
            ]),
          ),

          // ─── Action buttons row ───
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(children: [
              InkWell(
                onTap: () => _exportCSV(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: W.greenL, borderRadius: BorderRadius.circular(DS.radiusMd), border: Border.all(color: W.greenBd)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.download_rounded, size: 14, color: W.green),
                    const SizedBox(width: 6),
                    Text('تصدير CSV', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.green)),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => setState(() => _showSettings = !_showSettings),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: _showSettings ? W.priLight : W.bg, borderRadius: BorderRadius.circular(DS.radiusMd), border: Border.all(color: _showSettings ? W.pri : W.border)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.settings_outlined, size: 14, color: _showSettings ? W.pri : W.sub),
                    const SizedBox(width: 6),
                    Text('الإعدادات', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: _showSettings ? W.pri : W.sub)),
                  ]),
                ),
              ),
              const Spacer(),
              Text('كشف الرواتب', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: W.text)),
            ]),
          ),

          // ─── Settings panel (collapsible) ───
          if (_showSettings) _buildSettingsPanel(),

          // ─── Summary cards ───
          if (isWide)
            Row(children: [
              Expanded(child: _stat(Icons.trending_down_rounded, 'خصم الغياب', '${_fmtNum(totalAbsentDeduction)} ر.س', W.red, W.redL, '${_records.fold<int>(0, (s, r) => s + _toInt(r['days_absent']))} يوم غياب')),
              const SizedBox(width: 14),
              Expanded(child: _stat(Icons.access_time, 'خصم التأخير', '${_fmtNum(totalLateDeduction)} ر.س', W.orange, W.orangeL, '${_records.fold<int>(0, (s, r) => s + _toInt(r['total_late_minutes']))} دقيقة')),
              const SizedBox(width: 14),
              Expanded(child: _stat(Icons.more_time, 'بدل الأوفرتايم', '${_fmtNum(totalOvertimeAmt)} ر.س', W.green, W.greenL, '${(_records.fold<int>(0, (s, r) => s + _toInt(r['overtime_minutes'])) / 60.0).toStringAsFixed(1)} ساعة')),
              const SizedBox(width: 14),
              Expanded(child: _stat(Icons.receipt_long_rounded, 'إجمالي الخصومات', '${_fmtNum(totalDeductions)} ر.س', W.purple, W.purpleL, '${_records.length} موظف')),
            ])
          else
            SizedBox(
              height: 130,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                SizedBox(width: isMobile ? 160 : 180, child: _stat(Icons.trending_down_rounded, 'خصم الغياب', '${_fmtNum(totalAbsentDeduction)} ر.س', W.red, W.redL, '${_records.fold<int>(0, (s, r) => s + _toInt(r['days_absent']))} يوم غياب')),
                const SizedBox(width: 10),
                SizedBox(width: isMobile ? 160 : 180, child: _stat(Icons.access_time, 'خصم التأخير', '${_fmtNum(totalLateDeduction)} ر.س', W.orange, W.orangeL, '${_records.fold<int>(0, (s, r) => s + _toInt(r['total_late_minutes']))} دقيقة')),
                const SizedBox(width: 10),
                SizedBox(width: isMobile ? 160 : 180, child: _stat(Icons.more_time, 'بدل الأوفرتايم', '${_fmtNum(totalOvertimeAmt)} ر.س', W.green, W.greenL, '${(_records.fold<int>(0, (s, r) => s + _toInt(r['overtime_minutes'])) / 60.0).toStringAsFixed(1)} ساعة')),
                const SizedBox(width: 10),
                SizedBox(width: isMobile ? 160 : 180, child: _stat(Icons.receipt_long_rounded, 'إجمالي الخصومات', '${_fmtNum(totalDeductions)} ر.س', W.purple, W.purpleL, '${_records.length} موظف')),
              ]),
            ),
          const SizedBox(height: 20),

          // ─── Employee salary list ───
          if (_records.isEmpty)
            Container(
              width: double.infinity, padding: const EdgeInsets.all(40),
              decoration: DS.cardDecoration(),
              child: Center(child: Column(children: [
                Icon(Icons.account_balance_wallet_outlined, size: 36, color: W.hint),
                const SizedBox(height: 10),
                Text('لا يوجد بيانات رواتب في هذا الشهر', style: GoogleFonts.tajawal(fontSize: 13, color: W.muted)),
              ])),
            )
          else if (isWide)
            // Grid layout for web: 2 columns (3 if very wide)
            Builder(builder: (context) {
              final cols = screenW > 1200 ? 3 : 2;
              final rows = (_records.length / cols).ceil();
              return Column(children: List.generate(rows, (row) {
                final start = row * cols;
                final end = (start + cols).clamp(0, _records.length);
                final items = _records.sublist(start, end);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < items.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(child: _salaryCard(items[i], false)),
                      ],
                      // Fill remaining space if last row is incomplete
                      for (int i = items.length; i < cols; i++) ...[
                        const SizedBox(width: 10),
                        const Expanded(child: SizedBox()),
                      ],
                    ],
                  ),
                );
              }));
            })
          else
            ..._records.map((emp) => _salaryCard(emp, isMobile)),

          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ─── Settings panel ───
  Widget _buildSettingsPanel() {
    final overtimeCtrl = TextEditingController(text: '${_settings['overtime_rate'] ?? 1.5}');
    final graceCtrl = TextEditingController(text: '${_settings['late_grace_minutes'] ?? 15}');
    final hoursCtrl = TextEditingController(text: '${_settings['standard_hours'] ?? 8}');

    // Per-occurrence deductions (4 fields each, 4th repeats)
    final existingLate = (_settings['late_deductions'] as List?)?.cast<dynamic>() ?? [50, 100, 150, 200];
    final existingAbsent = (_settings['absent_deductions'] as List?)?.cast<dynamic>() ?? [100, 150, 200, 300];
    final lateCtrls = List.generate(4, (i) => TextEditingController(text: i < existingLate.length ? '${existingLate[i]}' : ''));
    final absentCtrls = List.generate(4, (i) => TextEditingController(text: i < existingAbsent.length ? '${existingAbsent[i]}' : ''));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(DS.radiusMd), border: Border.all(color: W.pri.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(children: [
          InkWell(onTap: () => setState(() => _showSettings = false), child: Icon(Icons.close, size: 18, color: W.muted)),
          const Spacer(),
          Text('إعدادات الرواتب (للكل)', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: W.text)),
          const SizedBox(width: 8),
          Icon(Icons.settings_outlined, size: 18, color: W.pri),
        ]),
        const SizedBox(height: 16),

        // General settings
        _settingsField('معامل الأوفرتايم', 'x', overtimeCtrl),
        const SizedBox(height: 10),
        _settingsField('فترة السماح (تأخير)', 'دقيقة', graceCtrl),
        const SizedBox(height: 10),
        _settingsField('ساعات العمل اليومية', 'ساعة', hoursCtrl),

        const SizedBox(height: 16),
        Container(height: 1, color: W.border),
        const SizedBox(height: 16),

        // Late deductions per occurrence
        Text('خصومات التأخير (تطبق على الكل)', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: W.text)),
        const SizedBox(height: 4),
        Text('المرة الرابعة تتكرر تلقائياً لكل مرة بعدها', style: GoogleFonts.tajawal(fontSize: 10, color: W.muted)),
        const SizedBox(height: 8),
        Row(children: List.generate(4, (i) => Expanded(child: Padding(
          padding: EdgeInsets.only(left: i < 3 ? 6 : 0),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: i < 2 ? W.greenL : i < 3 ? W.orangeL : W.redL, borderRadius: BorderRadius.circular(4)),
              child: Text('المرة ${i + 1}${i == 3 ? '+' : ''}', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: i < 2 ? W.green : i < 3 ? W.orange : W.red)),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: lateCtrls[i],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center, textDirection: TextDirection.ltr,
              style: _mono(fontSize: 14, fontWeight: FontWeight.w700),
              decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), suffixText: 'ر.س', suffixStyle: GoogleFonts.tajawal(fontSize: 8, color: W.muted), filled: true, fillColor: W.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(DS.radiusMd), borderSide: BorderSide(color: W.border))),
            ),
          ]),
        )))),

        const SizedBox(height: 16),

        // Absent deductions per occurrence
        Text('خصومات الغياب (تطبق على الكل)', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: W.text)),
        const SizedBox(height: 4),
        Text('اليوم الرابع يتكرر تلقائياً لكل يوم بعده', style: GoogleFonts.tajawal(fontSize: 10, color: W.muted)),
        const SizedBox(height: 8),
        Row(children: List.generate(4, (i) => Expanded(child: Padding(
          padding: EdgeInsets.only(left: i < 3 ? 6 : 0),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: i < 2 ? W.orangeL : W.redL, borderRadius: BorderRadius.circular(4)),
              child: Text('اليوم ${i + 1}${i == 3 ? '+' : ''}', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: i < 2 ? W.orange : W.red)),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: absentCtrls[i],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center, textDirection: TextDirection.ltr,
              style: _mono(fontSize: 14, fontWeight: FontWeight.w700),
              decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), suffixText: 'ر.س', suffixStyle: GoogleFonts.tajawal(fontSize: 8, color: W.muted), filled: true, fillColor: W.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(DS.radiusMd), borderSide: BorderSide(color: W.border))),
            ),
          ]),
        )))),

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              final lateList = lateCtrls.map((c) => double.tryParse(c.text.trim()) ?? 0).toList();
              final absentList = absentCtrls.map((c) => double.tryParse(c.text.trim()) ?? 0).toList();
              final body = {
                'use_progressive': true,
                'overtime_rate': double.tryParse(overtimeCtrl.text.trim()) ?? 1.5,
                'late_grace_minutes': int.tryParse(graceCtrl.text.trim()) ?? 15,
                'standard_hours': int.tryParse(hoursCtrl.text.trim()) ?? 8,
                'late_deductions': lateList,
                'absent_deductions': absentList,
              };
              final res = await ApiService.post('salary.php?action=save_settings', body);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(res['success'] == true ? 'تم حفظ الإعدادات للكل' : 'فشل الحفظ', style: GoogleFonts.tajawal()),
                  backgroundColor: res['success'] == true ? W.green : W.red,
                  behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd)),
                ));
                _loadAll();
              }
            },
            icon: const Icon(Icons.save, size: 16),
            label: Text('حفظ (تطبق على الكل)', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(backgroundColor: W.pri, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd))),
          ),
        ),
      ]),
    );
  }

  Widget _settingsField(String label, String suffix, TextEditingController ctrl) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(label, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: _mono(fontSize: 16, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          suffixText: suffix,
          suffixStyle: GoogleFonts.tajawal(fontSize: 12, color: W.muted),
          filled: true,
          fillColor: W.bg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.pri, width: 2)),
        ),
      ),
    ]);
  }

  // ─── Edit base salary dialog ───
  void _editBaseSalaryDialog(String uid, String name, double currentSalary) {
    final ctrl = TextEditingController(text: currentSalary > 0 ? currentSalary.toStringAsFixed(0) : '');
    showDialog(context: context, builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: min(400, MediaQuery.of(context).size.width - 40),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('تحديد الراتب الأساسي', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: W.text)),
          const SizedBox(height: 4),
          Text(name, style: GoogleFonts.tajawal(fontSize: 13, color: W.sub)),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: _mono(fontSize: 24, fontWeight: FontWeight.w800, color: W.pri),
            decoration: InputDecoration(
              hintText: '0',
              suffixText: 'ر.س',
              suffixStyle: GoogleFonts.tajawal(fontSize: 14, color: W.muted),
              filled: true, fillColor: W.bg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: W.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: W.pri, width: 2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.tajawal(color: W.muted))),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () async {
                final val = double.tryParse(ctrl.text.trim()) ?? 0;
                await ApiService.post('salary.php?action=set_base_salary', {'uid': uid, 'base_salary': val});
                if (ctx.mounted) Navigator.pop(ctx);
                _loadAll();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تحديد الراتب: $val ر.س', style: GoogleFonts.tajawal()), backgroundColor: W.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd))));
              },
              icon: const Icon(Icons.save, size: 16),
              label: Text('حفظ', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: W.pri, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
          ]),
        ]),
      ),
    ));
  }

  // ─── Edit per-employee deduction dialog ───
  void _editEmployeeDeductionDialog(String uid, String name) async {
    // Load current override
    final res = await ApiService.get('salary.php?action=get_employee_deduction', params: {'uid': uid});
    final override = (res['override'] as Map<String, dynamic>?) ?? {};
    final hasOverride = override['has_override'] == true;
    final currentLate = (override['late_deductions'] as List?)?.cast<dynamic>() ?? [];
    final currentAbsent = (override['absent_deductions'] as List?)?.cast<dynamic>() ?? [];

    // Controllers for each occurrence (4 fields, 4th repeats)
    final lateControllers = List.generate(4, (i) =>
      TextEditingController(text: i < currentLate.length ? '${currentLate[i]}' : ''));
    final absentControllers = List.generate(4, (i) =>
      TextEditingController(text: i < currentAbsent.length ? '${currentAbsent[i]}' : ''));

    if (!mounted) return;
    showDialog(context: context, builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: min(450, MediaQuery.of(context).size.width - 32),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: W.priLight, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
            child: Row(children: [
              InkWell(onTap: () => Navigator.pop(ctx), child: Icon(Icons.close, size: 18, color: W.sub)),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('خصومات فردية', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: W.text)),
                Text(name, style: GoogleFonts.tajawal(fontSize: 12, color: W.sub)),
              ]),
              const SizedBox(width: 8),
              Icon(Icons.person_outline, size: 20, color: W.pri),
            ]),
          ),
          // Body
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (hasOverride) Container(
                width: double.infinity, padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: W.orangeL, borderRadius: BorderRadius.circular(DS.radiusMd)),
                child: Text('هذا الموظف لديه خصومات فردية مختلفة عن الإعدادات العامة', style: GoogleFonts.tajawal(fontSize: 11, color: W.orange), textAlign: TextAlign.right),
              ),
              // Late deductions
              Text('خصومات التأخير (لكل مرة)', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: W.text)),
              const SizedBox(height: 4),
              Text('المرة الرابعة تتكرر تلقائياً لكل مرة بعدها', style: GoogleFonts.tajawal(fontSize: 11, color: W.muted)),
              const SizedBox(height: 10),
              ...List.generate(4, (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  SizedBox(width: 90, child: TextField(
                    controller: lateControllers[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center, textDirection: TextDirection.ltr,
                    style: _mono(fontSize: 15, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), suffixText: 'ر.س', suffixStyle: GoogleFonts.tajawal(fontSize: 10, color: W.muted), filled: true, fillColor: W.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(DS.radiusMd), borderSide: BorderSide(color: W.border))),
                  )),
                  const Spacer(),
                  Text('المرة ${i + 1}${i == 3 ? '+' : ''}', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: i < 2 ? W.green : i < 3 ? W.orange : W.red)),
                  const SizedBox(width: 8),
                  Container(width: 28, height: 28, decoration: BoxDecoration(color: (i < 2 ? W.greenL : i < 3 ? W.orangeL : W.redL), borderRadius: BorderRadius.circular(DS.radiusMd)),
                    child: Center(child: Text('${i + 1}${i == 3 ? '+' : ''}', style: _mono(fontSize: 12, fontWeight: FontWeight.w700, color: i < 2 ? W.green : i < 3 ? W.orange : W.red)))),
                ]),
              )),

              const SizedBox(height: 16),
              Container(height: 1, color: W.border),
              const SizedBox(height: 16),

              // Absent deductions
              Text('خصومات الغياب (لكل يوم)', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: W.text)),
              const SizedBox(height: 4),
              Text('اليوم الرابع يتكرر تلقائياً لكل يوم بعده', style: GoogleFonts.tajawal(fontSize: 11, color: W.muted)),
              const SizedBox(height: 10),
              ...List.generate(4, (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  SizedBox(width: 90, child: TextField(
                    controller: absentControllers[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center, textDirection: TextDirection.ltr,
                    style: _mono(fontSize: 15, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), suffixText: 'ر.س', suffixStyle: GoogleFonts.tajawal(fontSize: 10, color: W.muted), filled: true, fillColor: W.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(DS.radiusMd), borderSide: BorderSide(color: W.border))),
                  )),
                  const Spacer(),
                  Text('اليوم ${i + 1}${i == 3 ? '+' : ''}', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: i < 2 ? W.orange : W.red)),
                ]),
              )),
            ]),
          )),
          // Save button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              TextButton(onPressed: () async {
                await ApiService.post('salary.php?action=set_employee_deduction', {'uid': uid, 'has_override': false, 'late_deductions': [], 'absent_deductions': []});
                if (ctx.mounted) Navigator.pop(ctx);
                _loadAll();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إزالة الخصومات الفردية — يستخدم الإعدادات العامة', style: GoogleFonts.tajawal()), backgroundColor: W.orange, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd))));
              }, child: Text('إزالة الفردي', style: GoogleFonts.tajawal(fontSize: 12, color: W.red))),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () async {
                  final lateList = lateControllers.map((c) => double.tryParse(c.text.trim()) ?? 0).where((v) => v > 0).toList();
                  final absentList = absentControllers.map((c) => double.tryParse(c.text.trim()) ?? 0).where((v) => v > 0).toList();
                  await ApiService.post('salary.php?action=set_employee_deduction', {'uid': uid, 'late_deductions': lateList, 'absent_deductions': absentList});
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadAll();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ الخصومات الفردية لـ $name', style: GoogleFonts.tajawal()), backgroundColor: W.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd))));
                },
                icon: const Icon(Icons.save, size: 16),
                label: Text('حفظ', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(backgroundColor: W.pri, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
            ]),
          ),
        ]),
      ),
    ));
  }

  // ─── Salary card per employee ───
  Widget _salaryCard(Map<String, dynamic> emp, bool isMobile) {
    final name = emp['name'] ?? '---';
    final uid = emp['uid'] ?? '';
    final empId = emp['emp_id'] ?? '';
    final dept = emp['dept'] ?? '';
    final baseSalary = _toDouble(emp['base_salary']);
    final netSalary = _toDouble(emp['net_salary']);
    final workingDays = _toInt(emp['working_days']);
    final daysPresent = _toInt(emp['days_present']);
    final daysAbsent = _toInt(emp['days_absent']);
    final lateMin = _toInt(emp['total_late_minutes']);
    final lateCount = _toInt(emp['late_count']);
    final overtimeMin = _toInt(emp['overtime_minutes']);
    final overtimeAmt = _toDouble(emp['overtime_amount']);
    final deductionAbsent = _toDouble(emp['deduction_absent']);
    final deductionLate = _toDouble(emp['deduction_late']);
    final totalDeductions = _toDouble(emp['total_deductions']);
    final netEffect = overtimeAmt - totalDeductions;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: W.white,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        border: Border.all(color: W.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        // ─── Header: name + salary info ───
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Action buttons
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              onTap: () => _editBaseSalaryDialog(uid, name, baseSalary),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(DS.radiusMd), border: Border.all(color: W.border)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.edit, size: 12, color: W.sub), const SizedBox(width: 4), Text('الراتب', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: W.sub))])),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _editEmployeeDeductionDialog(uid, name),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(DS.radiusMd), border: Border.all(color: W.border)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.tune, size: 12, color: W.sub), const SizedBox(width: 4), Text('خصومات', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: W.sub))])),
            ),
          ]),
          const Spacer(),
          // Name + info
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(name, style: GoogleFonts.tajawal(fontSize: isMobile ? 13 : 14, fontWeight: FontWeight.w700, color: W.text)),
              if (empId.isNotEmpty || dept.isNotEmpty)
                Text('${dept.isNotEmpty ? '$dept  •  ' : ''}$empId', style: _mono(fontSize: 10, color: W.sub)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        // ─── Base salary + Net salary ───
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [W.priLight, W.white]),
            borderRadius: BorderRadius.circular(DS.radiusMd), border: Border.all(color: W.border),
          ),
          child: Row(children: [
            Expanded(child: Column(children: [
              Text(_fmtNum(netSalary), style: _mono(fontSize: 18, fontWeight: FontWeight.w800, color: netSalary >= 0 ? W.green : W.red)),
              Text('صافي الراتب', style: GoogleFonts.tajawal(fontSize: 9, color: W.muted)),
            ])),
            Container(width: 1, height: 30, color: W.border),
            Expanded(child: Column(children: [
              Text(baseSalary > 0 ? _fmtNum(baseSalary) : 'غير محدد', style: _mono(fontSize: baseSalary > 0 ? 18 : 12, fontWeight: FontWeight.w800, color: baseSalary > 0 ? W.pri : W.red)),
              Text('الراتب الأساسي', style: GoogleFonts.tajawal(fontSize: 9, color: W.muted)),
            ])),
          ]),
        ),
        const SizedBox(height: 12),

        // ─── Attendance row ───
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(DS.radiusMd)),
          child: Row(children: [
            _miniStat('$lateCount', 'مرة تأخير', W.orange),
            _miniStatSep(),
            _miniStat('$daysAbsent', 'غياب', W.red),
            _miniStatSep(),
            _miniStat('$daysPresent', 'حضور', W.green),
            _miniStatSep(),
            _miniStat('$workingDays', 'أيام العمل', W.sub),
          ]),
        ),
        const SizedBox(height: 10),

        // ─── Deductions breakdown ───
        _deductionRow(Icons.event_busy_outlined, 'خصم الغياب', '$daysAbsent يوم', deductionAbsent, W.red),
        const SizedBox(height: 6),
        _deductionRow(Icons.access_time, 'خصم التأخير', '$lateMin دقيقة', deductionLate, W.orange),
        const SizedBox(height: 6),
        _deductionRow(Icons.more_time, 'بدل الأوفرتايم', '${(overtimeMin / 60.0).toStringAsFixed(1)} ساعة', overtimeAmt, W.green, isPositive: true),

        // ─── Totals ───
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: totalDeductions > 0 ? W.redL : W.greenL,
            borderRadius: BorderRadius.circular(DS.radiusMd),
          ),
          child: Row(children: [
            Text(
              '${_fmtNum(totalDeductions)} ر.س',
              style: _mono(fontSize: 13, fontWeight: FontWeight.w700, color: W.red),
            ),
            const Spacer(),
            Text('إجمالي الخصومات', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.red)),
            const SizedBox(width: 6),
            Icon(Icons.remove_circle_outline, size: 14, color: W.red),
          ]),
        ),
        if (overtimeAmt > 0) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: W.greenL, borderRadius: BorderRadius.circular(DS.radiusMd)),
            child: Row(children: [
              Text(
                '+${_fmtNum(overtimeAmt)} ر.س',
                style: _mono(fontSize: 13, fontWeight: FontWeight.w700, color: W.green),
              ),
              const Spacer(),
              Text('بدل الأوفرتايم', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.green)),
              const SizedBox(width: 6),
              Icon(Icons.add_circle_outline, size: 14, color: W.green),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _deductionRow(IconData icon, String label, String detail, double amount, Color color, {bool isPositive = false}) {
    return Row(children: [
      Text(
        '${isPositive ? '+' : '-'}${_fmtNum(amount)} ر.س',
        style: _mono(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
      const SizedBox(width: 8),
      Text(detail, style: _mono(fontSize: 10, color: W.muted)),
      const Spacer(),
      Text(label, style: GoogleFonts.tajawal(fontSize: 12, color: W.sub)),
      const SizedBox(width: 6),
      Icon(icon, size: 14, color: color),
    ]);
  }

  Widget _miniStat(String value, String label, Color color) {
    return Expanded(
      child: Column(children: [
        Text(value, style: _mono(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.tajawal(fontSize: 9, color: W.muted)),
      ]),
    );
  }

  Widget _miniStatSep() => Container(width: 1, height: 28, color: W.border);

  Widget _stat(IconData icon, String label, String value, Color color, Color bg, String sub) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: DS.gradientCard(color),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(DS.radiusMd)), child: Icon(icon, size: 16, color: color)),
        const SizedBox(height: 8),
        Text(value, style: _mono(fontSize: 18, fontWeight: FontWeight.w800, color: W.text)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w500, color: W.sub)),
        if (sub.isNotEmpty) Text(sub, style: GoogleFonts.tajawal(fontSize: 10, color: W.muted)),
      ]),
    );
  }

  // ─── CSV Export ───
  void _exportCSV() {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('لا يوجد بيانات للتصدير', style: GoogleFonts.tajawal()),
        backgroundColor: W.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd)),
      ));
      return;
    }

    final headers = [
      'الاسم', 'الرقم الوظيفي', 'القسم',
      'أيام العمل', 'أيام الحضور', 'أيام الغياب',
      'دقائق التأخير', 'مرات التأخير',
      'دقائق الأوفرتايم', 'بدل الأوفرتايم',
      'خصم الغياب', 'خصم التأخير', 'إجمالي الخصومات',
    ];

    final rows = <List<String>>[headers];
    for (final r in _records) {
      rows.add([
        '${r['name'] ?? ''}',
        '${r['emp_id'] ?? ''}',
        '${r['dept'] ?? ''}',
        '${r['working_days'] ?? 0}',
        '${r['days_present'] ?? 0}',
        '${r['days_absent'] ?? 0}',
        '${r['total_late_minutes'] ?? 0}',
        '${r['late_count'] ?? 0}',
        '${r['overtime_minutes'] ?? 0}',
        '${r['overtime_amount'] ?? 0}',
        '${r['deduction_absent'] ?? 0}',
        '${r['deduction_late'] ?? 0}',
        '${r['total_deductions'] ?? 0}',
      ]);
    }

    final csv = rows.map((r) => r.join(',')).join('\n');
    final filename = 'salary_${_selYear}_${_selMonth.toString().padLeft(2, '0')}.csv';

    _showExportDialog(csv, filename);
  }

  void _showExportDialog(String csv, String filename) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: min(400, MediaQuery.of(context).size.width - 40),
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Flexible(child: Text('تصدير كشف الرواتب', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: W.text))),
              const SizedBox(width: 8),
              Icon(Icons.download_rounded, size: 18, color: W.green),
            ]),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(DS.radiusMd)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(filename, style: _mono(fontSize: 12, fontWeight: FontWeight.w600, color: W.text)),
                const SizedBox(height: 4),
                Text('${_records.length} موظف  •  ${_months[_selMonth - 1]} $_selYear', style: GoogleFonts.tajawal(fontSize: 11, color: W.muted)),
              ]),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity, height: 200,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(DS.radiusMd), border: Border.all(color: W.border)),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: SelectableText(csv, style: _mono(fontSize: 10, color: W.text)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('انسخ البيانات من المربع أعلاه والصقها في ملف CSV', style: GoogleFonts.tajawal(fontSize: 12, color: W.muted), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إغلاق', style: GoogleFonts.tajawal(fontSize: 13, color: W.muted)),
            ),
          ]),
        ),
      ),
    );
  }
}
