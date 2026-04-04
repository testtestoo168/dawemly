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
            decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
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
                  decoration: BoxDecoration(color: W.greenL, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.greenBd)),
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
                  decoration: BoxDecoration(color: _showSettings ? W.priLight : W.bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: _showSettings ? W.pri : W.border)),
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
              Expanded(child: _stat(Icons.trending_down_rounded, 'خصم الغياب', '${totalAbsentDeduction.toStringAsFixed(0)} ر.س', W.red, W.redL, '${_records.fold<int>(0, (s, r) => s + _toInt(r['days_absent']))} يوم غياب')),
              const SizedBox(width: 14),
              Expanded(child: _stat(Icons.access_time, 'خصم التأخير', '${totalLateDeduction.toStringAsFixed(0)} ر.س', W.orange, W.orangeL, '${_records.fold<int>(0, (s, r) => s + _toInt(r['total_late_minutes']))} دقيقة')),
              const SizedBox(width: 14),
              Expanded(child: _stat(Icons.more_time, 'بدل الأوفرتايم', '${totalOvertimeAmt.toStringAsFixed(0)} ر.س', W.green, W.greenL, '${(_records.fold<int>(0, (s, r) => s + _toInt(r['overtime_minutes'])) / 60.0).toStringAsFixed(1)} ساعة')),
              const SizedBox(width: 14),
              Expanded(child: _stat(Icons.receipt_long_rounded, 'إجمالي الخصومات', '${totalDeductions.toStringAsFixed(0)} ر.س', W.purple, W.purpleL, '${_records.length} موظف')),
            ])
          else
            SizedBox(
              height: 130,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                SizedBox(width: isMobile ? 160 : 180, child: _stat(Icons.trending_down_rounded, 'خصم الغياب', '${totalAbsentDeduction.toStringAsFixed(0)} ر.س', W.red, W.redL, '${_records.fold<int>(0, (s, r) => s + _toInt(r['days_absent']))} يوم غياب')),
                const SizedBox(width: 10),
                SizedBox(width: isMobile ? 160 : 180, child: _stat(Icons.access_time, 'خصم التأخير', '${totalLateDeduction.toStringAsFixed(0)} ر.س', W.orange, W.orangeL, '${_records.fold<int>(0, (s, r) => s + _toInt(r['total_late_minutes']))} دقيقة')),
                const SizedBox(width: 10),
                SizedBox(width: isMobile ? 160 : 180, child: _stat(Icons.more_time, 'بدل الأوفرتايم', '${totalOvertimeAmt.toStringAsFixed(0)} ر.س', W.green, W.greenL, '${(_records.fold<int>(0, (s, r) => s + _toInt(r['overtime_minutes'])) / 60.0).toStringAsFixed(1)} ساعة')),
                const SizedBox(width: 10),
                SizedBox(width: isMobile ? 160 : 180, child: _stat(Icons.receipt_long_rounded, 'إجمالي الخصومات', '${totalDeductions.toStringAsFixed(0)} ر.س', W.purple, W.purpleL, '${_records.length} موظف')),
              ]),
            ),
          const SizedBox(height: 20),

          // ─── Employee salary list ───
          if (_records.isEmpty)
            Container(
              width: double.infinity, padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
              child: Center(child: Column(children: [
                Icon(Icons.account_balance_wallet_outlined, size: 36, color: W.hint),
                const SizedBox(height: 10),
                Text('لا يوجد بيانات رواتب في هذا الشهر', style: GoogleFonts.tajawal(fontSize: 13, color: W.muted)),
              ])),
            )
          else
            ..._records.map((emp) => _salaryCard(emp, isMobile)),

          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ─── Settings panel ───
  Widget _buildSettingsPanel() {
    final lateCtrl = TextEditingController(text: '${_settings['late_deduction_per_minute'] ?? 1}');
    final absentCtrl = TextEditingController(text: '${_settings['absent_deduction_per_day'] ?? 100}');
    final overtimeCtrl = TextEditingController(text: '${_settings['overtime_rate'] ?? 1.5}');
    final graceCtrl = TextEditingController(text: '${_settings['late_grace_minutes'] ?? 15}');
    final hoursCtrl = TextEditingController(text: '${_settings['standard_hours'] ?? 8}');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.pri.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(children: [
          InkWell(
            onTap: () => setState(() => _showSettings = false),
            child: Icon(Icons.close, size: 18, color: W.muted),
          ),
          const Spacer(),
          Text('إعدادات الرواتب', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: W.text)),
          const SizedBox(width: 8),
          Icon(Icons.settings_outlined, size: 18, color: W.pri),
        ]),
        const SizedBox(height: 16),
        _settingsField('خصم التأخير (لكل دقيقة)', 'ر.س', lateCtrl),
        const SizedBox(height: 12),
        _settingsField('خصم الغياب (لكل يوم)', 'ر.س', absentCtrl),
        const SizedBox(height: 12),
        _settingsField('معامل الأوفرتايم', 'x', overtimeCtrl),
        const SizedBox(height: 12),
        _settingsField('فترة السماح (تأخير)', 'دقيقة', graceCtrl),
        const SizedBox(height: 12),
        _settingsField('ساعات العمل اليومية', 'ساعة', hoursCtrl),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              final body = {
                'late_deduction_per_minute': double.tryParse(lateCtrl.text.trim()) ?? 1,
                'absent_deduction_per_day': double.tryParse(absentCtrl.text.trim()) ?? 100,
                'overtime_rate': double.tryParse(overtimeCtrl.text.trim()) ?? 1.5,
                'late_grace_minutes': int.tryParse(graceCtrl.text.trim()) ?? 15,
                'standard_hours': int.tryParse(hoursCtrl.text.trim()) ?? 8,
              };
              final res = await ApiService.post('salary.php?action=save_settings', body);
              if (mounted) {
                if (res['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('تم حفظ الإعدادات بنجاح', style: GoogleFonts.tajawal()),
                    backgroundColor: W.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ));
                  _loadAll();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(res['error'] ?? 'فشل حفظ الإعدادات', style: GoogleFonts.tajawal()),
                    backgroundColor: W.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ));
                }
              }
            },
            icon: const Icon(Icons.save, size: 16),
            label: Text('حفظ الإعدادات', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: W.pri,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
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

  // ─── Salary card per employee ───
  Widget _salaryCard(Map<String, dynamic> emp, bool isMobile) {
    final name = emp['name'] ?? '---';
    final empId = emp['emp_id'] ?? '';
    final dept = emp['dept'] ?? '';
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
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: W.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        // ─── Header: name + net effect badge ───
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Net effect badge (left side in RTL)
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: 6),
            decoration: BoxDecoration(
              color: netEffect >= 0 ? W.greenL : W.redL,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(children: [
              Text(
                '${netEffect >= 0 ? '+' : ''}${netEffect.toStringAsFixed(0)}',
                style: _mono(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w700, color: netEffect >= 0 ? W.green : W.red),
              ),
              Text('ر.س', style: GoogleFonts.tajawal(fontSize: 9, color: W.muted)),
            ]),
          ),
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
        const SizedBox(height: 12),

        // ─── Attendance row ───
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(6)),
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
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(children: [
            Text(
              '${totalDeductions.toStringAsFixed(0)} ر.س',
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
            decoration: BoxDecoration(color: W.greenL, borderRadius: BorderRadius.circular(6)),
            child: Row(children: [
              Text(
                '+${overtimeAmt.toStringAsFixed(0)} ر.س',
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
        '${isPositive ? '+' : '-'}${amount.toStringAsFixed(0)} ر.س',
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
      decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)), child: Icon(icon, size: 16, color: color)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
              decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(6)),
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
              decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
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
