import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
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
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final settingsRes = await ApiService.get('admin.php?action=get_settings');
      if (settingsRes['success'] == true && mounted) {
        final s = settingsRes['settings'] as Map<String, dynamic>? ?? {};
        _standardHours = double.tryParse('${s['generalH'] ?? ''}') ?? 8.0;
      }
      final recRes = await ApiService.get('attendance.php?action=all_records');
      if (recRes['success'] == true && mounted) {
        final list = (recRes['records'] as List? ?? []).cast<Map<String, dynamic>>();
        setState(() { _allRecords = list; _loading = false; });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isWide = screenW > 800;
    final isMobile = screenW < 500;
    final monthPrefix = '$_selYear-${_selMonth.toString().padLeft(2, '0')}';

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final records = _allRecords.where((r) => (r['date_key'] ?? '').toString().startsWith(monthPrefix)).toList();

    final withOT = <Map<String, dynamic>>[];
    double totalOT = 0;
    for (final r in records) {
      final ci = r['first_check_in'] ?? r['check_in'];
      final co = r['last_check_out'] ?? r['check_out'];
      if (ci != null && co != null) {
        final totalMin = (r['total_worked_minutes'] is int)
            ? r['total_worked_minutes'] as int
            : int.tryParse('${r['total_worked_minutes'] ?? ''}') ?? 0;
        double hours;
        if (totalMin > 0) {
          hours = totalMin / 60.0;
        } else {
          final ciDt = _parseTs(ci);
          final coDt = _parseTs(co);
          hours = (ciDt != null && coDt != null) ? coDt.difference(ciDt).inMinutes / 60.0 : 0;
        }
        final otManualRaw = r['overtime_manual_minutes'];
        final otManual = otManualRaw != null ? (otManualRaw is int ? otManualRaw : int.tryParse('$otManualRaw')) : null;
        final otCancelled = r['overtime_cancelled'] == true;

        double ot;
        if (otCancelled) {
          ot = 0;
        } else if (otManual != null) {
          ot = otManual / 60.0;
        } else {
          ot = (hours - _standardHours).clamp(0.0, 24.0);
        }

        if (ot > 0 || otCancelled || otManual != null) {
          withOT.add({...r, 'workH': hours, 'overtime': ot, 'otCancelled': otCancelled, 'otReason': r['overtime_reason'] ?? ''});
          totalOT += ot;
        }
      }
    }
    withOT.sort((a, b) => (b['overtime'] as double).compareTo(a['overtime'] as double));

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: SingleChildScrollView(padding: EdgeInsets.all(isWide ? 28 : 14), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('سجل الأوفرتايم', style: GoogleFonts.tajawal(fontSize: isWide ? 24 : 18, fontWeight: FontWeight.w800, color: W.text)),
        const SizedBox(height: 4),
        Text('ساعات العمل الإضافية', style: GoogleFonts.tajawal(fontSize: 12, color: W.sub)),
        const SizedBox(height: 16),

        // Month selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
          child: Row(children: [
            InkWell(onTap: () => setState(() { _selMonth--; if (_selMonth < 1) { _selMonth = 12; _selYear--; } }), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(4)), child: Icon(Icons.chevron_right, size: 18, color: W.sub))),
            const Spacer(),
            Text('${_months[_selMonth - 1]} $_selYear', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: W.text)),
            const Spacer(),
            InkWell(onTap: () => setState(() { _selMonth++; if (_selMonth > 12) { _selMonth = 1; _selYear++; } }), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(4)), child: Icon(Icons.chevron_left, size: 18, color: W.sub))),
          ]),
        ),

        if (isWide)
          Row(children: [
            Expanded(child: _stat(Icons.more_time, 'إجمالي الأوفرتايم', '${totalOT.toStringAsFixed(1)}h', W.orange, Color(0xFFFFFAEB), 'ساعات إضافية')),
            const SizedBox(width: 14),
            Expanded(child: _stat(Icons.people, 'عدد الموظفين', '${withOT.where((e) => (e['overtime'] as double) > 0).length}', W.pri, W.priLight, 'من ${records.length} موظف')),
            const SizedBox(width: 14),
            Expanded(child: _stat(Icons.access_time, 'أعلى أوفرتايم', withOT.isNotEmpty && (withOT.first['overtime'] as double) > 0 ? '${withOT.first['overtime'].toStringAsFixed(1)}h' : '—', W.green, Color(0xFFECFDF3), withOT.isNotEmpty && (withOT.first['overtime'] as double) > 0 ? withOT.first['name'] ?? '' : '—')),
          ])
        else
          SizedBox(height: 130, child: ListView(scrollDirection: Axis.horizontal, children: [
            SizedBox(width: isMobile ? 160 : 180, child: _stat(Icons.more_time, 'إجمالي الأوفرتايم', '${totalOT.toStringAsFixed(1)}h', W.orange, Color(0xFFFFFAEB), 'ساعات إضافية')),
            const SizedBox(width: 10),
            SizedBox(width: isMobile ? 140 : 160, child: _stat(Icons.people, 'عدد الموظفين', '${withOT.where((e) => (e['overtime'] as double) > 0).length}', W.pri, W.priLight, 'من ${records.length} موظف')),
            const SizedBox(width: 10),
            SizedBox(width: isMobile ? 160 : 180, child: _stat(Icons.access_time, 'أعلى أوفرتايم', withOT.isNotEmpty && (withOT.first['overtime'] as double) > 0 ? '${withOT.first['overtime'].toStringAsFixed(1)}h' : '—', W.green, Color(0xFFECFDF3), withOT.isNotEmpty && (withOT.first['overtime'] as double) > 0 ? withOT.first['name'] ?? '' : '—')),
          ])),
        const SizedBox(height: 20),

        if (withOT.isEmpty)
          Container(width: double.infinity, padding: EdgeInsets.all(40), decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
            child: Center(child: Column(children: [Icon(Icons.more_time, size: 36, color: W.hint), SizedBox(height: 10), Text('لا يوجد أوفرتايم في هذا الشهر', style: GoogleFonts.tajawal(fontSize: 13, color: W.muted))])))
        else
          ...withOT.map((emp) => _overtimeCard(emp, isMobile)),

        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
          child: Column(children: [
            Container(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: W.div))),
              child: Align(alignment: Alignment.centerRight, child: Text('ساعات العمل لجميع الموظفين', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: W.text)))),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
              columnSpacing: isMobile ? 16 : 56,
              headingRowColor: WidgetStateProperty.all(W.bg),
              columns: ['الأوفرتايم', 'ساعات العمل', 'الحالة', 'الموظف'].map((h) => DataColumn(label: Text(h, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.sub)))).toList(),
              rows: records.where((r) => (r['first_check_in'] ?? r['check_in']) != null).map((r) {
                final ci = r['first_check_in'] ?? r['check_in'];
                double workH = 0; double ot = 0;
                if (ci != null) {
                  final co = r['last_check_out'] ?? r['check_out'];
                  final totalMin = (r['total_worked_minutes'] is int)
                      ? r['total_worked_minutes'] as int
                      : int.tryParse('${r['total_worked_minutes'] ?? ''}') ?? 0;
                  if (totalMin > 0) {
                    workH = totalMin / 60.0;
                  } else if (co != null) {
                    final ciDt = _parseTs(ci);
                    final coDt = _parseTs(co);
                    if (ciDt != null && coDt != null) workH = coDt.difference(ciDt).inMinutes / 60.0;
                  }
                  ot = (workH - 8.0).clamp(0.0, 24.0);
                }
                final hasOut = (r['last_check_out'] ?? r['check_out']) != null;
                return DataRow(cells: [
                  DataCell(ot > 0 ? Text('+${ot.toStringAsFixed(1)}h', style: _mono(fontSize: 12, fontWeight: FontWeight.w600, color: W.orange)) : Text('—', style: GoogleFonts.tajawal(color: W.muted))),
                  DataCell(Text('${workH.toStringAsFixed(1)}h', style: _mono(fontSize: 12))),
                  DataCell(_badge(hasOut ? 'مكتمل' : 'حاضر', hasOut ? W.green : W.pri, hasOut ? Color(0xFFECFDF3) : W.priLight)),
                  DataCell(ConstrainedBox(constraints: BoxConstraints(maxWidth: isMobile ? 100 : 200), child: Text(r['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.text), overflow: TextOverflow.ellipsis))),
                ]);
              }).toList(),
            )),
          ]),
        ),
      ])),
    );
  }

  DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is String) { try { return DateTime.parse(v); } catch(_) { return null; } }
    return null;
  }

  Widget _overtimeCard(Map<String, dynamic> emp, bool isMobile) {
    final name = emp['name'] ?? '—';
    final ot = emp['overtime'] as double;
    final workH = emp['workH'] as double;
    final otCancelled = emp['otCancelled'] == true;
    final otReason = emp['otReason'] ?? '';
    final docId = emp['id']?.toString() ?? emp['_docId']?.toString() ?? '';
    final dateKey = emp['dateKey'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10), padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: otCancelled ? W.red.withOpacity(0.3) : W.border)),
      child: Column(children: [
        // Top: OT badge + name on the right
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Action buttons (left side in RTL)
          Flexible(
            flex: 0,
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              InkWell(onTap: () => _editOvertimeDialog(docId, name, emp),
                child: Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: W.orangeL, borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.edit, size: 12, color: W.orange), SizedBox(width: 4), Text('تعديل', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: W.orange))]))),
              if (!otCancelled) InkWell(onTap: () => _cancelOvertimeDialog(docId, name),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFFEF3F2), borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.cancel, size: 12, color: W.red), SizedBox(width: 4), Text('إلغاء', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: W.red))])))
              else Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFFEF3F2), borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.cancel, size: 12, color: W.red), SizedBox(width: 4), Text('ملغي', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: W.red))])),
            ]),
          ),
          const Spacer(),
          // Name + date
          Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(name, style: GoogleFonts.tajawal(fontSize: isMobile ? 13 : 14, fontWeight: FontWeight.w700, color: otCancelled ? W.muted : W.text), overflow: TextOverflow.ellipsis, maxLines: 1),
            Text('$dateKey  •  ${workH.toStringAsFixed(1)}h عمل', style: _mono(fontSize: 10, color: W.sub)),
          ])),
          const SizedBox(width: 8),
          // OT badge
          Container(padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: 6), decoration: BoxDecoration(color: otCancelled ? const Color(0xFFFEF3F2) : const Color(0xFFFFFAEB), borderRadius: BorderRadius.circular(6)),
            child: Column(children: [
              Text(otCancelled ? 'ملغي' : '+${ot.toStringAsFixed(1)}h', style: _mono(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w700, color: otCancelled ? W.red : W.orange)),
              Text('أوفرتايم', style: GoogleFonts.tajawal(fontSize: 9, color: W.muted)),
            ])),
        ]),
        if (otReason.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(width: double.infinity, padding: EdgeInsets.all(8), decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Flexible(child: Text(otReason, style: GoogleFonts.tajawal(fontSize: 11, color: W.sub), textAlign: TextAlign.right)),
              SizedBox(width: 6), Icon(Icons.comment, size: 12, color: W.muted),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(width: min(380, MediaQuery.of(context).size.width - 40), padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Flexible(child: Text('تعديل الأوفرتايم', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: W.text))),
            SizedBox(width: 8), Icon(Icons.edit, size: 18, color: W.orange),
          ]),
          const SizedBox(height: 4),
          Text(empName, style: GoogleFonts.tajawal(fontSize: 13, color: W.sub), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Flexible(child: Text('عدد ساعات الأوفرتايم', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub))),
              SizedBox(width: 4), Icon(Icons.access_time, size: 14, color: W.orange),
            ]),
            const SizedBox(height: 4),
            TextField(controller: hoursCtrl, textAlign: TextAlign.center, textDirection: TextDirection.ltr, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: _mono(fontSize: 18, fontWeight: FontWeight.w700),
              decoration: InputDecoration(hintText: '0.0', suffixText: 'ساعة', filled: true, fillColor: W.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.orange, width: 2)))),
          ]),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: Text('السبب', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub))),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end, children: reasons.map((r) => InkWell(onTap: () => reasonCtrl.text = r,
            child: Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: W.border)),
              child: Text(r, style: GoogleFonts.tajawal(fontSize: 10, color: W.sub))))).toList()),
          const SizedBox(height: 8),
          TextField(controller: reasonCtrl, textAlign: TextAlign.right, maxLines: 2, style: GoogleFonts.tajawal(fontSize: 13),
            decoration: InputDecoration(hintText: 'اكتب السبب أو اختر من الأعلى...', hintStyle: GoogleFonts.tajawal(color: W.hint, fontSize: 12), filled: true, fillColor: W.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.border)))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () async {
              final hours = double.tryParse(hoursCtrl.text.trim()) ?? 0;
              await ApiService.post('attendance.php?action=update_record', {
                'id': docId,
                'overtimeManualMinutes': (hours * 60).round(),
                'overtimeCancelled': false,
                'overtimeReason': reasonCtrl.text.trim(),
                'overtimeEditedBy': widget.adminUser?['name'] ?? 'مدير النظام',
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تعديل الأوفرتايم لـ $empName', style: GoogleFonts.tajawal()), backgroundColor: W.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))));
                _loadAll();
              }
            },
            icon: const Icon(Icons.save, size: 16), label: Text('حفظ التعديل', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(backgroundColor: W.orange, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))))),
          const SizedBox(height: 6),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.tajawal(fontSize: 13, color: W.muted))),
        ]))),
    ));
  }

  void _cancelOvertimeDialog(String docId, String empName) {
    final reasonCtrl = TextEditingController();
    final reasons = ['نسي بصمة الخروج', 'خطأ في البيانات', 'لم يعمل فعلياً', 'أخرى'];

    showDialog(context: context, builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(width: min(360, MediaQuery.of(context).size.width - 40), padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Flexible(child: Text('إلغاء الأوفرتايم', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: W.red))),
            SizedBox(width: 8), Icon(Icons.cancel, size: 18, color: W.red),
          ]),
          const SizedBox(height: 4),
          Text(empName, style: GoogleFonts.tajawal(fontSize: 13, color: W.sub), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),
          Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end, children: reasons.map((r) => InkWell(onTap: () => reasonCtrl.text = r,
            child: Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: W.border)),
              child: Text(r, style: GoogleFonts.tajawal(fontSize: 10, color: W.sub))))).toList()),
          const SizedBox(height: 8),
          TextField(controller: reasonCtrl, textAlign: TextAlign.right, style: GoogleFonts.tajawal(fontSize: 13),
            decoration: InputDecoration(hintText: 'سبب الإلغاء...', hintStyle: GoogleFonts.tajawal(color: W.hint, fontSize: 12), filled: true, fillColor: W.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.border)))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () async {
              await ApiService.post('attendance.php?action=update_record', {
                'id': docId,
                'overtimeCancelled': true,
                'overtimeManualMinutes': 0,
                'overtimeReason': reasonCtrl.text.trim(),
                'overtimeEditedBy': widget.adminUser?['name'] ?? 'مدير النظام',
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إلغاء الأوفرتايم لـ $empName', style: GoogleFonts.tajawal()), backgroundColor: W.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))));
                _loadAll();
              }
            },
            icon: const Icon(Icons.cancel, size: 16), label: Text('تأكيد الإلغاء', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(backgroundColor: W.red, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))))),
          const SizedBox(height: 6),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('رجوع', style: GoogleFonts.tajawal(fontSize: 13, color: W.muted))),
        ]))),
    ));
  }

  Widget _stat(IconData icon, String label, String value, Color color, Color bg, String sub) {
    return Container(padding: EdgeInsets.all(14), decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Container(width: 34, height: 34, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)), child: Icon(icon, size: 16, color: color)),
      const SizedBox(height: 8),
      Text(value, style: _mono(fontSize: 20, fontWeight: FontWeight.w800, color: W.text)),
      const SizedBox(height: 4),
      Text(label, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w500, color: W.sub), overflow: TextOverflow.ellipsis, maxLines: 1),
      if (sub.isNotEmpty) Text(sub, style: GoogleFonts.tajawal(fontSize: 10, color: W.muted), overflow: TextOverflow.ellipsis, maxLines: 1),
    ]));
  }

  Widget _badge(String text, Color color, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );
}
