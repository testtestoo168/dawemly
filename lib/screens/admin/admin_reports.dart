import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/download_stub.dart'
    if (dart.library.html) '../../services/download_web.dart';

class AdminReports extends StatefulWidget {
  const AdminReports({super.key});
  @override State<AdminReports> createState() => _AdminReportsState();
}

class _AdminReportsState extends State<AdminReports> {
  final _mono = GoogleFonts.ibmPlexMono;
  final _months = const ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
  final _dayNames = const ['الإثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'];

  late int _selMonth, _selYear;
  double _standardHours = 8.0;
  int _startHour = 8, _startMinute = 0;
  bool _exporting = false;
  String _selectedUid = 'الكل';
  List<Map<String, dynamic>> _allUsers = [];
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
      if (settingsRes['success'] == true) {
        final s = settingsRes['settings'] as Map<String, dynamic>? ?? {};
        _standardHours = double.tryParse('${s['generalH'] ?? ''}') ?? 8.0;
        final st = (s['shift1Start'] ?? s['workStart'] ?? '08:00') as String;
        final timeParts = st.replaceAll(RegExp(r'[^\d:]'), '').split(':');
        if (timeParts.length >= 2) {
          _startHour = int.tryParse(timeParts[0]) ?? 8;
          _startMinute = int.tryParse(timeParts[1]) ?? 0;
        }
      }
      final usersRes = await ApiService.get('users.php?action=list');
      if (usersRes['success'] == true) {
        final list = (usersRes['users'] as List? ?? []).cast<Map<String, dynamic>>();
        _allUsers = list.where((u) => (u['name'] ?? '').toString().isNotEmpty && u['role'] != 'admin').toList();
        _allUsers.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
      }
      final recRes = await ApiService.get('attendance.php?action=all_records');
      if (recRes['success'] == true) {
        _allRecords = (recRes['records'] as List? ?? []).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is String) { try { return DateTime.parse(v); } catch(_) { return null; } }
    return null;
  }

  String _fmtTs(dynamic ts) {
    if (ts == null) return '—';
    final dt = _parseTs(ts);
    if (dt == null) return '—';
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'م' : 'ص'}';
  }

  Future<List<Map<String, dynamic>>> _buildReportData() async {
    final monthPrefix = '$_selYear-${_selMonth.toString().padLeft(2, '0')}';
    final attRecords = _allRecords.where((r) {
      final dk = (r['date_key'] ?? r['dateKey'] ?? '').toString();
      if (!dk.startsWith(monthPrefix)) return false;
      if (_selectedUid != 'الكل' && r['uid'] != _selectedUid) return false;
      return true;
    }).toList();

    final rows = <Map<String, dynamic>>[];
    for (final att in attRecords) {
      final user = _allUsers.firstWhere((u) => (u['uid'] ?? u['id']) == att['uid'], orElse: () => {});
      if (user.isEmpty) continue;

      final dateKey = att['date_key'] ?? att['dateKey'] ?? '';
      final parts = dateKey.split('-');
      final dt = parts.length == 3 ? DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])) : DateTime.now();
      final dayName = _dayNames[(dt.weekday - 1) % 7];

      final ci = att['first_check_in'] ?? att['firstCheckIn'] ?? att['check_in'] ?? att['checkIn'];
      final co = att['last_check_out'] ?? att['lastCheckOut'] ?? att['check_out'] ?? att['checkOut'];
      final totalMinRaw = att['total_worked_minutes'] ?? att['totalWorkedMinutes'];
      final totalMin = totalMinRaw != null ? (totalMinRaw is int ? totalMinRaw : int.tryParse('$totalMinRaw') ?? 0) : 0;
      double workedHours = totalMin > 0 ? totalMin / 60.0 : 0;
      double overtime = 0;
      String lateTime = '—';

      // Use stored late_minutes if available, otherwise calculate from check-in
      final storedLate = att['late_minutes'];
      final storedLateMin = storedLate != null ? (storedLate is int ? storedLate : int.tryParse('$storedLate') ?? 0) : 0;

      if (ci != null) {
        final checkIn = _parseTs(ci);
        if (checkIn != null) {
          if (co != null && workedHours == 0) {
            final checkOut = _parseTs(co);
            if (checkOut != null) workedHours = checkOut.difference(checkIn).inMinutes / 60.0;
          }
          if (co != null) overtime = (workedHours - _standardHours).clamp(0, 24);
        }
      }

      if (storedLateMin > 0) {
        lateTime = '$storedLateMin د';
      } else if (ci != null) {
        final checkIn = _parseTs(ci);
        if (checkIn != null) {
          final expectedStart = DateTime(checkIn.year, checkIn.month, checkIn.day, _startHour, _startMinute);
          if (checkIn.isAfter(expectedStart)) {
            final lateMins = checkIn.difference(expectedStart).inMinutes;
            lateTime = '$lateMins د';
          }
        }
      }

      // Early leave
      final storedEarly = att['early_leave_minutes'];
      final storedEarlyMin = storedEarly != null ? (storedEarly is int ? storedEarly : int.tryParse('$storedEarly') ?? 0) : 0;
      String earlyTime = storedEarlyMin > 0 ? '$storedEarlyMin د' : '—';

      rows.add({
        'empId': user['emp_id'] ?? user['empId'] ?? '—',
        'name': user['name'] ?? '—',
        'date': dateKey,
        'day': dayName,
        'checkIn': _fmtTs(ci),
        'checkOut': _fmtTs(co),
        'hours': workedHours.toStringAsFixed(1),
        'late': lateTime,
        'early': earlyTime,
        'overtime': overtime > 0 ? '${overtime.toStringAsFixed(1)}' : '—',
      });
    }
    rows.sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));
    return rows;
  }

  void _exportCSV() async {
    setState(() => _exporting = true);
    try {
      final data = await _buildReportData();
      final headers = ['كود الموظف', 'الاسم', 'التاريخ', 'اليوم', 'الدخول', 'الخروج', 'ساعات العمل', 'التأخير', 'خروج مبكر', 'الأوفرتايم'];
      final csvRows = [headers, ...data.map((r) => [r['empId'], r['name'], r['date'], r['day'], r['checkIn'], r['checkOut'], r['hours'], r['late'], r['early'], r['overtime']])];
      final csv = const ListToCsvConverter().convert(csvRows);
      final bytes = utf8.encode('\uFEFF$csv');
      final empLabel = _selectedUid == 'الكل' ? 'all' : _selectedUid;
      downloadFile(bytes, 'dawemli_${empLabel}_$_selYear-$_selMonth.csv', 'text/csv');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: W.red));
    }
    if (mounted) setState(() => _exporting = false);
  }

  void _exportPDF() async {
    setState(() => _exporting = true);
    try {
      final data = await _buildReportData();

      pw.Font? arabicFont;
      try {
        final fontData = await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
        arabicFont = pw.Font.ttf(fontData);
      } catch (_) {
        try {
          final fontData = await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
          arabicFont = pw.Font.ttf(fontData);
        } catch (_) {
          try {
            final response = await http.get(Uri.parse('https://fonts.gstatic.com/s/tajawal/v9/Iura6YBj_oCad4k1nzGBCw.ttf'));
            if (response.statusCode == 200 && response.bodyBytes.length > 1000) {
              final fontData = ByteData.sublistView(Uint8List.fromList(response.bodyBytes));
              arabicFont = pw.Font.ttf(fontData);
            }
          } catch (_) {}
        }
      }

      final pdf = pw.Document();

      final hasArabic = arabicFont != null;
      final baseStyle = hasArabic ? pw.TextStyle(font: arabicFont, fontSize: 9) : const pw.TextStyle(fontSize: 9);
      final headerStyle = hasArabic ? pw.TextStyle(font: arabicFont, fontSize: 9, fontWeight: pw.FontWeight.bold) : pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
      final titleStyle = hasArabic ? pw.TextStyle(font: arabicFont, fontSize: 16, fontWeight: pw.FontWeight.bold) : pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold);

      final empName = _selectedUid == 'الكل' ? 'All Employees' : (_allUsers.firstWhere((u) => (u['uid'] ?? u['id']) == _selectedUid, orElse: () => {'name': ''})['name'] ?? '');

      final titleAr = hasArabic ? 'تقرير الحضور — ${_months[_selMonth - 1]} $_selYear${_selectedUid != 'الكل' ? ' — $empName' : ''}' : 'Attendance Report - ${_months[_selMonth - 1]} $_selYear - $empName';
      final headersAr = hasArabic
        ? ['الأوفرتايم', 'خروج مبكر', 'التأخير', 'الساعات', 'الخروج', 'الدخول', 'اليوم', 'التاريخ', 'الاسم', 'الكود']
        : ['Overtime', 'Early Leave', 'Late', 'Hours', 'Check Out', 'Check In', 'Day', 'Date', 'Name', 'EmpID'];

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        textDirection: hasArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          pw.Center(child: pw.Text(titleAr, style: titleStyle)),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headerStyle: headerStyle,
            cellStyle: baseStyle,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
            cellAlignment: pw.Alignment.center,
            headerAlignment: pw.Alignment.center,
            headers: headersAr,
            data: data.map((r) => [r['overtime'], r['early'], r['late'], r['hours'], r['checkOut'], r['checkIn'], r['day'], r['date'], r['name'], r['empId']]).toList(),
          ),
        ],
      ));

      final bytes = await pdf.save();
      final empLabel = _selectedUid == 'الكل' ? 'all' : _selectedUid;
      downloadFile(bytes, 'dawemli_${empLabel}_$_selYear-$_selMonth.pdf', 'application/pdf');

      if (!hasArabic && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('⚠ لتصدير PDF بالعربي، ضع ملف Tajawal-Regular.ttf في assets/fonts/', style: GoogleFonts.tajawal()),
          backgroundColor: W.orange, behavior: SnackBarBehavior.floating, duration: Duration(seconds: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في التصدير: $e'), backgroundColor: W.red));
    }
    if (mounted) setState(() => _exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loading ? null : _buildReportData(),
      builder: (context, snap) {
        final data = snap.data ?? [];

        return SingleChildScrollView(padding: EdgeInsets.all(isWide ? 28 : 14), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // Header
          Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.spaceBetween, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              ElevatedButton.icon(onPressed: _exporting ? null : _exportCSV, icon: const Icon(Icons.download, size: 15), label: Text('Excel/CSV', style: GoogleFonts.tajawal(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(backgroundColor: W.white, foregroundColor: W.text, side: BorderSide(color: W.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)))),
              const SizedBox(width: 8),
              ElevatedButton.icon(onPressed: _exporting ? null : _exportPDF, icon: const Icon(Icons.picture_as_pdf, size: 15), label: Text('PDF', style: GoogleFonts.tajawal(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(backgroundColor: W.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)))),
            ]),
            Text('التقارير', style: GoogleFonts.tajawal(fontSize: isWide ? 24 : 18, fontWeight: FontWeight.w800, color: W.text)),
          ]),
          const SizedBox(height: 16),

          // Filters row
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
            child: Column(children: [
              // Month selector
              Row(children: [
                InkWell(onTap: () => setState(() { _selMonth--; if (_selMonth < 1) { _selMonth = 12; _selYear--; } }), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(4)), child: Icon(Icons.chevron_right, size: 18, color: W.sub))),
                const Spacer(),
                Text('${_months[_selMonth - 1]} $_selYear', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: W.text)),
                const Spacer(),
                InkWell(onTap: () => setState(() { _selMonth++; if (_selMonth > 12) { _selMonth = 1; _selYear++; } }), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(4)), child: Icon(Icons.chevron_left, size: 18, color: W.sub))),
              ]),
              const SizedBox(height: 10),
              Container(height: 1, color: W.div),
              const SizedBox(height: 10),
              // Employee selector
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: _selectedUid,
                  isExpanded: true,
                  decoration: InputDecoration(
                    filled: true, fillColor: W.bg, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.border)),
                  ),
                  items: [
                    DropdownMenuItem(value: 'الكل', child: Text('جميع الموظفين', style: GoogleFonts.tajawal(fontSize: 13))),
                    ..._allUsers.map((u) => DropdownMenuItem(value: u['uid'] ?? u['id'] ?? '', child: Text('${u['name']} (${u['emp_id'] ?? u['empId'] ?? ''})', style: GoogleFonts.tajawal(fontSize: 13)))),
                  ],
                  onChanged: (v) => setState(() => _selectedUid = v ?? 'الكل'),
                )),
                const SizedBox(width: 10),
                Text('الموظف', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: W.sub)),
                const SizedBox(width: 6),
                Icon(Icons.person, size: 16, color: W.pri),
              ]),
            ]),
          ),
          const SizedBox(height: 16),

          // Stats
          Wrap(spacing: 10, runSpacing: 10, children: [
            SizedBox(width: isWide ? null : (MediaQuery.of(context).size.width - 38) / 2, child: _stat('إجمالي السجلات', '${data.length}', W.pri)),
            SizedBox(width: isWide ? null : (MediaQuery.of(context).size.width - 38) / 2, child: _stat('متوسط الساعات', data.isNotEmpty ? '${(data.map((r) => double.tryParse(r['hours'] ?? '0') ?? 0).reduce((a, b) => a + b) / data.length).toStringAsFixed(1)}h' : '—', W.green)),
            SizedBox(width: isWide ? null : (MediaQuery.of(context).size.width - 38) / 2, child: _stat('حالات تأخير', '${data.where((r) => r['late'] != '—').length}', W.orange)),
            SizedBox(width: isWide ? null : (MediaQuery.of(context).size.width - 38) / 2, child: _stat('أوفرتايم', '${data.where((r) => r['overtime'] != '—').length}', W.pri)),
          ]),
          const SizedBox(height: 20),

          // Table
          if (_loading || snap.connectionState == ConnectionState.waiting)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(strokeWidth: 2)))
          else if (data.isEmpty)
            Container(width: double.infinity, padding: EdgeInsets.all(50), decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
              child: Center(child: Column(children: [Icon(Icons.bar_chart, size: 48, color: W.hint), SizedBox(height: 12), Text('لا توجد بيانات', style: GoogleFonts.tajawal(fontSize: 14, color: W.muted))])))
          else Container(
            width: double.infinity,
            decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - (isWide ? 56 : 28)),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(W.bg),
                  headingRowHeight: isWide ? 48 : 42,
                  dataRowMinHeight: isWide ? 44 : 36,
                  dataRowMaxHeight: isWide ? 52 : 44,
                  columnSpacing: isWide ? 28 : 14,
                  horizontalMargin: isWide ? 20 : 12,
                  columns: ['الأوفرتايم', 'خروج مبكر', 'التأخير', 'الساعات', 'الخروج', 'الدخول', 'اليوم', 'التاريخ', 'الاسم', 'الكود'].map((h) =>
                    DataColumn(label: Text(h, style: GoogleFonts.tajawal(fontSize: isWide ? 13 : 11, fontWeight: FontWeight.w700, color: W.sub)))).toList(),
                  rows: data.map((r) => DataRow(cells: [
                    DataCell(Text(r['overtime'] ?? '—', style: GoogleFonts.tajawal(fontSize: isWide ? 13 : 12, color: r['overtime'] != '—' ? W.orange : W.muted))),
                    DataCell(Text(r['early'] ?? '—', style: GoogleFonts.tajawal(fontSize: isWide ? 13 : 12, color: r['early'] != '—' ? W.orange : W.muted))),
                    DataCell(Text(r['late'] ?? '—', style: GoogleFonts.tajawal(fontSize: isWide ? 13 : 12, color: r['late'] != '—' ? W.red : W.muted))),
                    DataCell(Text('${r['hours']}h', style: _mono(fontSize: isWide ? 13 : 12, fontWeight: FontWeight.w600, color: W.text))),
                    DataCell(Text(r['checkOut'] ?? '—', style: _mono(fontSize: isWide ? 13 : 12, color: W.text))),
                    DataCell(Text(r['checkIn'] ?? '—', style: _mono(fontSize: isWide ? 13 : 12, color: W.text))),
                    DataCell(Text(r['day'] ?? '', style: GoogleFonts.tajawal(fontSize: isWide ? 13 : 12, color: W.sub))),
                    DataCell(Text(r['date'] ?? '', style: _mono(fontSize: isWide ? 13 : 12, color: W.text))),
                    DataCell(Text(r['name'] ?? '', style: GoogleFonts.tajawal(fontSize: isWide ? 13 : 12, fontWeight: FontWeight.w600, color: W.text))),
                    DataCell(Text(r['empId'] ?? '', style: _mono(fontSize: isWide ? 12 : 11, color: W.muted))),
                  ])).toList(),
                ),
              ),
            ),
          ),
        ]));
      },
    );
  }

  Widget _stat(String label, String val, Color color) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(val, style: _mono(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: GoogleFonts.tajawal(fontSize: 12, color: W.sub)),
    ]),
  );
}
