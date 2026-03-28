import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/attendance_service.dart';
import '../../services/api_service.dart';

class AdminOvertime extends StatefulWidget {
  final Map<String, dynamic>? adminUser;
  const AdminOvertime({super.key, this.adminUser});
  @override State<AdminOvertime> createState() => _AdminOvertimeState();
}

class _AdminOvertimeState extends State<AdminOvertime> {
  final _mono = GoogleFonts.ibmPlexMono;
  final _months = const ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
  late int _selMonth, _selYear;
  double _standardHours = 8.0;
  List<Map<String, dynamic>> _allRecords = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selMonth = now.month;
    _selYear = now.year;
    _loadSettings();
    _loadRecords();
  }

  void _loadSettings() async {
    try {
      final result = await ApiService.get('admin.php?action=get_settings');
      final settings = result['settings'] != null ? Map<String, dynamic>.from(result['settings']) : result;
      if (mounted) setState(() => _standardHours = (settings['generalH'] as num?)?.toDouble() ?? 8.0);
    } catch (_) {}
  }

  void _loadRecords() async {
    try {
      final records = await AttendanceService().getAllRecords();
      if (mounted) setState(() { _allRecords = records; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    final monthPrefix = '$_selYear-${_selMonth.toString().padLeft(2, '0')}';

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final records = _allRecords.where((r) => (r['dateKey'] ?? '').toString().startsWith(monthPrefix)).toList();

    final withOT = <Map<String, dynamic>>[];
    double totalOT = 0;
    for (final r in records) {
      final ci = r['firstCheckIn'] ?? r['checkIn'];
      final co = r['lastCheckOut'] ?? r['checkOut'];
      if (ci != null && co != null) {
        final ciDt = _parseDateTime(ci);
        final coDt = _parseDateTime(co);
        final totalMin = (r['totalWorkedMinutes'] as int?) ?? (ciDt != null && coDt != null ? coDt.difference(ciDt).inMinutes : 0);
        final hours = totalMin / 60.0;
        final otManual = r['overtimeManualMinutes'] as int?;
        final otCancelled = r['overtimeCancelled'] == true;

        double ot;
        if (otCancelled) {
          ot = 0;
        } else if (otManual != null) {
          ot = otManual / 60.0;
        } else {
          ot = (hours - _standardHours).clamp(0.0, 24.0);
        }

        if (ot > 0 || otCancelled || otManual != null) {
          withOT.add({...r, 'workH': hours, 'overtime': ot, 'otCancelled': otCancelled, 'otReason': r['overtimeReason'] ?? ''});
          totalOT += ot;
        }
      }
    }
    withOT.sort((a, b) => (b['overtime'] as double).compareTo(a['overtime'] as double));

    return SingleChildScrollView(padding: EdgeInsets.all(isWide ? 28 : 14), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('سجل الأوفرتايم', style: GoogleFonts.tajawal(fontSize: isWide ? 24 : 18, fontWeight: FontWeight.w800, color: C.text)),
      const SizedBox(height: 4),
      Text('ساعات العمل الإضافية', style: GoogleFonts.tajawal(fontSize: 12, color: C.sub)),
      const SizedBox(height: 16),

      // Month selector
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
        child: Row(children: [
          InkWell(onTap: () => setState(() { _selMonth--; if (_selMonth < 1) { _selMonth = 12; _selYear--; } }), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.chevron_right, size: 18, color: C.sub))),
          const Spacer(),
          Text('${_months[_selMonth - 1]} $_selYear', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: C.text)),
          const Spacer(),
          InkWell(onTap: () => setState(() { _selMonth++; if (_selMonth > 12) { _selMonth = 1; _selYear++; } }), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.chevron_left, size: 18, color: C.sub))),
        ]),
      ),

      if (isWide)
        Row(children: [
          _stat(Icons.more_time, 'إجمالي الأوفرتايم', '${totalOT.toStringAsFixed(1)}h', C.orange, const Color(0xFFFFFAEB), 'ساعات إضافية'),
          const SizedBox(width: 14),
          _stat(Icons.people, 'عدد الموظفين', '${withOT.where((e) => (e['overtime'] as double) > 0).length}', C.pri, C.priLight, 'من ${records.length} موظف'),
          const SizedBox(width: 14),
          _stat(Icons.access_time, 'أعلى أوفرتايم', withOT.isNotEmpty && (withOT.first['overtime'] as double) > 0 ? '${withOT.first['overtime'].toStringAsFixed(1)}h' : '—', C.green, const Color(0xFFECFDF3), withOT.isNotEmpty && (withOT.first['overtime'] as double) > 0 ? withOT.first['name'] ?? '' : '—'),
        ])
      else
        SizedBox(height: 130, child: ListView(scrollDirection: Axis.horizontal, children: [
          SizedBox(width: 180, child: _stat(Icons.more_time, 'إجمالي الأوفرتايم', '${totalOT.toStringAsFixed(1)}h', C.orange, const Color(0xFFFFFAEB), 'ساعات إضافية')),
          const SizedBox(width: 10),
          SizedBox(width: 160, child: _stat(Icons.people, 'عدد الموظفين', '${withOT.where((e) => (e['overtime'] as double) > 0).length}', C.pri, C.priLight, 'من ${records.length} موظف')),
          const SizedBox(width: 10),
          SizedBox(width: 180, child: _stat(Icons.access_time, 'أعلى أوفرتايم', withOT.isNotEmpty && (withOT.first['overtime'] as double) > 0 ? '${withOT.first['overtime'].toStringAsFixed(1)}h' : '—', C.green, const Color(0xFFECFDF3), withOT.isNotEmpty && (withOT.first['overtime'] as double) > 0 ? withOT.first['name'] ?? '' : '—')),
        ])),
      const SizedBox(height: 20),

      if (withOT.isEmpty)
        Container(width: double.infinity, padding: const EdgeInsets.all(40), decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
          child: Center(child: Column(children: [const Icon(Icons.more_time, size: 36, color: C.hint), const SizedBox(height: 10), Text('لا يوجد أوفرتايم في هذا الشهر', style: GoogleFonts.tajawal(fontSize: 13, color: C.muted))])))
      else
        ...withOT.map((emp) => _overtimeCard(emp)),

      const SizedBox(height: 20),
      Container(
        decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
        child: Column(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.div))),
            child: Align(alignment: Alignment.centerRight, child: Text('ساعات العمل لجميع الموظفين', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: C.text)))),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
            headingRowColor: WidgetStateProperty.all(C.bg),
            columns: ['الأوفرتايم', 'ساعات العمل', 'الحالة', 'الموظف'].map((h) => DataColumn(label: Text(h, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: C.sub)))).toList(),
            rows: records.where((r) => (r['firstCheckIn'] ?? r['checkIn']) != null).map((r) {
              final ci = r['firstCheckIn'] ?? r['checkIn'];
              double workH = 0; double ot = 0;
              if (ci != null) {
                final co = r['lastCheckOut'] ?? r['checkOut'];
                final ciDt = _parseDateTime(ci);
                final coDt = _parseDateTime(co);
                final totalMin = (r['totalWorkedMinutes'] as int?) ?? (ciDt != null && coDt != null ? coDt.difference(ciDt).inMinutes : (ciDt != null ? DateTime.now().difference(ciDt).inMinutes : 0));
                workH = totalMin / 60.0;
                ot = (workH - 8.0).clamp(0.0, 24.0);
              }
              final hasOut = (r['lastCheckOut'] ?? r['checkOut']) != null;
              return DataRow(cells: [
                DataCell(ot > 0 ? Text('+${ot.toStringAsFixed(1)}h', style: _mono(fontSize: 12, fontWeight: FontWeight.w600, color: C.orange)) : Text('—', style: GoogleFonts.tajawal(color: C.muted))),
                DataCell(Text('${workH.toStringAsFixed(1)}h', style: _mono(fontSize: 12))),
                DataCell(_badge(hasOut ? 'مكتمل' : 'حاضر', hasOut ? C.green : C.pri, hasOut ? const Color(0xFFECFDF3) : C.priLight)),
                DataCell(Text(r['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.text))),
              ]);
            }).toList(),
          )),
        ]),
      ),
    ]));
  }

  Widget _overtimeCard(Map<String, dynamic> emp) {
    final name = emp['name'] ?? '—';
    final ot = emp['overtime'] as double;
    final workH = emp['workH'] as double;
    final otCancelled = emp['otCancelled'] == true;
    final otReason = emp['otReason'] ?? '';
    final docId = emp['id']?.toString() ?? '';
    final dateKey = emp['dateKey'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: otCancelled ? C.red.withOpacity(0.3) : C.border)),
      child: Column(children: [
        Row(children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            InkWell(onTap: () => _editOvertimeDialog(docId, name, emp),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: C.orangeL, borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.edit, size: 12, color: C.orange), const SizedBox(width: 4), Text('تعديل', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: C.orange))]))),
            const SizedBox(width: 6),
            if (!otCancelled) InkWell(onTap: () => _cancelOvertimeDialog(docId, name),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFFEF3F2), borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cancel, size: 12, color: C.red), const SizedBox(width: 4), Text('إلغاء', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: C.red))])))
            else Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFFEF3F2), borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cancel, size: 12, color: C.red), const SizedBox(width: 4), Text('ملغي', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: C.red))])),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(name, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: otCancelled ? C.muted : C.text)),
            Text('$dateKey  •  ${workH.toStringAsFixed(1)}h عمل', style: _mono(fontSize: 10, color: C.sub)),
          ]),
          const SizedBox(width: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: otCancelled ? const Color(0xFFFEF3F2) : const Color(0xFFFFFAEB), borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              Text(otCancelled ? 'ملغي' : '+${ot.toStringAsFixed(1)}h', style: _mono(fontSize: 16, fontWeight: FontWeight.w700, color: otCancelled ? C.red : C.orange)),
              Text('أوفرتايم', style: GoogleFonts.tajawal(fontSize: 9, color: C.muted)),
            ])),
        ]),
        if (otReason.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(width: double.infinity, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Flexible(child: Text(otReason, style: GoogleFonts.tajawal(fontSize: 11, color: C.sub), textAlign: TextAlign.right)),
              const SizedBox(width: 6), const Icon(Icons.comment, size: 12, color: C.muted),
            ])),
        ],
      ]),
    );
  }

  void _editOvertimeDialog(String docId, String empName, Map<String, dynamic> emp) {
    final currentOT = emp['overtime'] as double;
    final hoursCtrl = TextEditingController(text: currentOT.toStringAsFixed(1));
    final reasonCtrl = TextEditingController(text: emp['otReason'] ?? '');
    final reasons = ['نسي بصمة الخروج', 'عمل إضافي مطلوب', 'خطأ في النظام', 'تعديل إداري', 'أخرى'];

    showDialog(context: context, builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(width: 380, padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text('تعديل الأوفرتايم', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
            const SizedBox(width: 8), const Icon(Icons.edit, size: 18, color: C.orange),
          ]),
          const SizedBox(height: 4),
          Text(empName, style: GoogleFonts.tajawal(fontSize: 13, color: C.sub)),
          const SizedBox(height: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('عدد ساعات الأوفرتايم', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.sub)),
              const SizedBox(width: 4), const Icon(Icons.access_time, size: 14, color: C.orange),
            ]),
            const SizedBox(height: 4),
            TextField(controller: hoursCtrl, textAlign: TextAlign.center, textDirection: TextDirection.ltr, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: _mono(fontSize: 18, fontWeight: FontWeight.w700),
              decoration: InputDecoration(hintText: '0.0', suffixText: 'ساعة', filled: true, fillColor: C.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: C.orange, width: 2)))),
          ]),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: Text('السبب', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.sub))),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end, children: reasons.map((r) => InkWell(onTap: () => reasonCtrl.text = r,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.border)),
              child: Text(r, style: GoogleFonts.tajawal(fontSize: 10, color: C.sub))))).toList()),
          const SizedBox(height: 8),
          TextField(controller: reasonCtrl, textAlign: TextAlign.right, maxLines: 2, style: GoogleFonts.tajawal(fontSize: 13),
            decoration: InputDecoration(hintText: 'اكتب السبب أو اختر من الأعلى...', hintStyle: GoogleFonts.tajawal(color: C.hint, fontSize: 12), filled: true, fillColor: C.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.border)))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () async {
              final hours = double.tryParse(hoursCtrl.text.trim()) ?? 0;
              await ApiService.post('attendance.php?action=update_overtime', body: {'id': docId, 'overtimeManualMinutes': (hours * 60).round(), 'overtimeCancelled': false, 'overtimeReason': reasonCtrl.text.trim(), 'overtimeEditedBy': widget.adminUser?['name'] ?? 'مدير النظام'});
              if (ctx.mounted) Navigator.pop(ctx);
              _loadRecords();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تعديل الأوفرتايم لـ $empName', style: GoogleFonts.tajawal()), backgroundColor: C.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
            },
            icon: const Icon(Icons.save, size: 16), label: Text('حفظ التعديل', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(backgroundColor: C.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
          const SizedBox(height: 6),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.tajawal(fontSize: 13, color: C.muted))),
        ]))),
    ));
  }

  void _cancelOvertimeDialog(String docId, String empName) {
    final reasonCtrl = TextEditingController();
    final reasons = ['نسي بصمة الخروج', 'خطأ في البيانات', 'لم يعمل فعلياً', 'أخرى'];

    showDialog(context: context, builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(width: 360, padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text('إلغاء الأوفرتايم', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: C.red)),
            const SizedBox(width: 8), const Icon(Icons.cancel, size: 18, color: C.red),
          ]),
          const SizedBox(height: 4),
          Text(empName, style: GoogleFonts.tajawal(fontSize: 13, color: C.sub)),
          const SizedBox(height: 16),
          Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end, children: reasons.map((r) => InkWell(onTap: () => reasonCtrl.text = r,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.border)),
              child: Text(r, style: GoogleFonts.tajawal(fontSize: 10, color: C.sub))))).toList()),
          const SizedBox(height: 8),
          TextField(controller: reasonCtrl, textAlign: TextAlign.right, style: GoogleFonts.tajawal(fontSize: 13),
            decoration: InputDecoration(hintText: 'سبب الإلغاء...', hintStyle: GoogleFonts.tajawal(color: C.hint, fontSize: 12), filled: true, fillColor: C.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.border)))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () async {
              await ApiService.post('attendance.php?action=update_overtime', body: {'id': docId, 'overtimeCancelled': true, 'overtimeManualMinutes': 0, 'overtimeReason': reasonCtrl.text.trim(), 'overtimeEditedBy': widget.adminUser?['name'] ?? 'مدير النظام'});
              if (ctx.mounted) Navigator.pop(ctx);
              _loadRecords();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إلغاء الأوفرتايم لـ $empName', style: GoogleFonts.tajawal()), backgroundColor: C.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
            },
            icon: const Icon(Icons.cancel, size: 16), label: Text('تأكيد الإلغاء', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(backgroundColor: C.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
          const SizedBox(height: 6),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('رجوع', style: GoogleFonts.tajawal(fontSize: 13, color: C.muted))),
        ])),
    ));
  }

  Widget _stat(IconData icon, String label, String value, Color color, Color bg, String sub) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Container(width: 38, height: 38, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: color)),
      const SizedBox(height: 10),
      Text(value, style: _mono(fontSize: 22, fontWeight: FontWeight.w800, color: C.text)),
      const SizedBox(height: 4),
      Text(label, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w500, color: C.sub)),
      if (sub.isNotEmpty) Text(sub, style: GoogleFonts.tajawal(fontSize: 10, color: C.muted)),
    ]));
  }

  Widget _badge(String text, Color color, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );
}
