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
import '../../services/attendance_service.dart';
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
  String _selectedUid = 'الكل'; // 'الكل' or specific uid
  List<Map<String, dynamic>> _allUsers = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selMonth = now.month;
    _selYear = now.year;
    _loadSettings();
    _loadUsers();
  }

  void _loadSettings() async {
    try {
      final result = await ApiService.get('admin.php?action=get_settings');
      final d = result['settings'] != null ? Map<String, dynamic>.from(result['settings']) : result;
      if (mounted) {
        setState(() {
          _standardHours = (d['generalH'] as num?)?.toDouble() ?? 8.0;
          // Parse start time like "08:00 ص"
          final st = (d['shift1Start'] ?? d['workStart'] ?? '08:00') as String;
          final timeParts = st.replaceAll(RegExp(r'[^\d:]'), '').split(':');
          if (timeParts.length >= 2) {
            _startHour = int.tryParse(timeParts[0]) ?? 8;
            _startMinute = int.tryParse(timeParts[1]) ?? 0;
          }
        });
      }
    } catch (_) {}
  }

  void _loadUsers() async {
    try {
      final result = await ApiService.get('users.php?action=list');
      final list = result['users'] ?? result['data'] ?? [];
      if (mounted) setState(() {
        _allUsers = (list as List).map((u) => Map<String, dynamic>.from(u))
          .where((u) => (u['name'] ?? '').toString().isNotEmpty && u['role'] != 'admin').toList();
        _allUsers.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
      });
    } catch (_) {}
  }

  String _fmtTs(dynamic ts) {
    if (ts == null) return '—';
    DateTime? dt;
    if (ts is DateTime) {
      dt = ts;
    } else if (ts is String && ts.isNotEmpty && ts != '—') {
      dt = DateTime.tryParse(ts);
    }
    if (dt == null) return '—';
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'م' : 'ص'}';
  }

  DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val is String && val.isNotEmpty) return DateTime.tryParse(val);
    return null;
  }

  Future<List<Map<String, dynamic>>> _buildReportData() async {
    final monthPrefix = '$_selYear-${_selMonth.toString().padLeft(2, '0')}';
    final attRecords = await AttendanceService().getAllRecords();
    final filtered = attRecords.where((r) {
      final dk = (r['dateKey'] ?? r['date_key'] ?? '').toString();
      if (!dk.startsWith(monthPrefix)) return false;
      if (_selectedUid != 'الكل' && r['uid'] != _selectedUid) return false;
      return true;
    }).toList();

    final rows = <Map<String, dynamic>>[];
    for (final att in filtered) {
      final user = _allUsers.firstWhere((u) => (u['uid'] ?? u['_id'] ?? u['id']) == att['uid'], orElse: () => {});
      if (user.isEmpty) continue;

      final dateKey = (att['dateKey'] ?? att['date_key'] ?? '').toString();
      final parts = dateKey.split('-');
      final dt = parts.length == 3 ? DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])) : DateTime.now();
      final dayName = _dayNames[(dt.weekday - 1) % 7];

      final ci = att['firstCheckIn'] ?? att['checkIn'] ?? att['first_check_in'] ?? att['check_in'];
      final co = att['lastCheckOut'] ?? att['checkOut'] ?? att['last_check_out'] ?? att['check_out'];
      final totalMin = (att['totalWorkedMinutes'] ?? att['total_worked_minutes'] ?? 0);
      final totalMinInt = totalMin is int ? totalMin : (int.tryParse(totalMin.toString()) ?? 0);
      double workedHours = totalMinInt > 0 ? totalMinInt / 60.0 : 0;
      double overtime = 0;
      String lateTime = '—';

      final checkIn = _parseDateTime(ci);
      if (checkIn != null) {
        final checkOut = _parseDateTime(co);
        if (checkOut != null) {
          if (workedHours == 0) {
            workedHours = checkOut.difference(checkIn).inMinutes / 60.0;
          }
          overtime = (workedHours - _standardHours).clamp(0, 24);
        }
        // Late calculation
        final expectedStart = DateTime(checkIn.year, checkIn.month, checkIn.day, _startHour, _startMinute);
        if (checkIn.isAfter(expectedStart)) {
          final lateMins = checkIn.difference(expectedStart).inMinutes;
          lateTime = '$lateMins د';
        }
      }

      rows.add({
        'empId': user['empId'] ?? user['emp_id'] ?? '—',
        'name': user['name'] ?? '—',
        'date': dateKey,
        'day': dayName,
        'checkIn': _fmtTs(ci),
        'checkOut': _fmtTs(co),
        'hours': workedHours.toStringAsFixed(1),
        'late': lateTime,
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
      final headers = ['كود الموظف', 'الاسم', 'التاريخ', 'اليوم', 'الدخول', 'الخروج', 'ساعات العمل', 'التأخير', 'الأوفرتايم'];
      final csvRows = [headers, ...data.map((r) => [r['empId'], r['name'], r['date'], r['day'], r['checkIn'], r['checkOut'], r['hours'], r['late'], r['overtime']])];
      final csv = const ListToCsvConverter().convert(csvRows);
      final bytes = utf8.encode('\uFEFF$csv');
      final empLabel = _selectedUid == 'الكل' ? 'all' : _selectedUid;
      downloadFile(bytes, 'dawemli_${empLabel}_$_selYear-$_selMonth.csv', 'text/csv');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: C.red));
    }
    if (mounted) setState(() => _exporting = false);
  }

  void _exportPDF() async {
    setState(() => _exporting = true);
    try {
      final data = await _buildReportData();

      // Load Arabic font from asset or download from Google Fonts
      pw.Font? arabicFont;
      try {
        final fontData = await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
        arabicFont = pw.Font.ttf(fontData);
      } catch (_) {
        try {
          final fontData = await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
          arabicFont = pw.Font.ttf(fontData);
        } catch (_) {
          // Try downloading from Google Fonts API at runtime
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

      // If no Arabic font available, export with LTR layout and English-safe Arabic
      final hasArabic = arabicFont != null;
      final baseStyle = hasArabic ? pw.TextStyle(font: arabicFont, fontSize: 9) : const pw.TextStyle(fontSize: 9);
      final headerStyle = hasArabic ? pw.TextStyle(font: arabicFont, fontSize: 9, fontWeight: pw.FontWeight.bold) : pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
      final titleStyle = hasArabic ? pw.TextStyle(font: arabicFont, fontSize: 16, fontWeight: pw.FontWeight.bold) : pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold);

      final empName = _selectedUid == 'الكل' ? 'All Employees' : (_allUsers.firstWhere((u) => (u['uid'] ?? u['_id']) == _selectedUid, orElse: () => {'name': ''})['name'] ?? '');

      final titleAr = hasArabic ? 'تقرير الحضور — ${_months[_selMonth - 1]} $_selYear${_selectedUid != 'الكل' ? ' — $empName' : ''}' : 'Attendance Report - ${_months[_selMonth - 1]} $_selYear - $empName';
      final headersAr = hasArabic
        ? ['الأوفرتايم', 'التأخير', 'الساعات', 'الخروج', 'الدخول', 'اليوم', 'التاريخ', 'الاسم', 'الكود']
        : ['Overtime', 'Late', 'Hours', 'Check Out', 'Check In', 'Day', 'Date', 'Name', 'EmpID'];

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
            data: data.map((r) => [r['overtime'], r['late'], r['hours'], r['checkOut'], r['checkIn'], r['day'], r['date'], r['name'], r['empId']]).toList(),
          ),
        ],
      ));

      final bytes = await pdf.save();
      final empLabel = _selectedUid == 'الكل' ? 'all' : _selectedUid;
      downloadFile(bytes, 'dawemli_${empLabel}_$_selYear-$_selMonth.pdf', 'application/pdf');

      if (!hasArabic && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('⚠ لتصدير PDF بالعربي، ضع ملف Tajawal-Regular.ttf في assets/fonts/', style: GoogleFonts.tajawal()),
          backgroundColor: C.orange, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في التصدير: $e'), backgroundColor: C.red));
    }
    if (mounted) setState(() => _exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _buildReportData(),
      builder: (context, snap) {
        final data = snap.data ?? [];

        return SingleChildScrollView(padding: EdgeInsets.all(isWide ? 28 : 14), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // Header
          Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.spaceBetween, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              ElevatedButton.icon(onPressed: _exporting ? null : _exportCSV, icon: const Icon(Icons.download, size: 15), label: Text('Excel/CSV', style: GoogleFonts.tajawal(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(backgroundColor: C.white, foregroundColor: C.text, side: const BorderSide(color: C.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
              const SizedBox(width: 8),
              ElevatedButton.icon(onPressed: _exporting ? null : _exportPDF, icon: const Icon(Icons.picture_as_pdf, size: 15), label: Text('PDF', style: GoogleFonts.tajawal(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(backgroundColor: C.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
            ]),
            Text('التقارير', style: GoogleFonts.tajawal(fontSize: isWide ? 24 : 18, fontWeight: FontWeight.w800, color: C.text)),
          ]),
          const SizedBox(height: 16),

          // Filters row
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
            child: Column(children: [
              // Month selector
              Row(children: [
                InkWell(onTap: () => setState(() { _selMonth--; if (_selMonth < 1) { _selMonth = 12; _selYear--; } }), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.chevron_right, size: 18, color: C.sub))),
                const Spacer(),
                Text('${_months[_selMonth - 1]} $_selYear', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
                const Spacer(),
                InkWell(onTap: () => setState(() { _selMonth++; if (_selMonth > 12) { _selMonth = 1; _selYear++; } }), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.chevron_left, size: 18, color: C.sub))),
              ]),
              const SizedBox(height: 10),
              Container(height: 1, color: C.div),
              const SizedBox(height: 10),
              // Employee selector
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: _selectedUid,
                  isExpanded: true,
                  decoration: InputDecoration(
                    filled: true, fillColor: C.bg, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.border)),
                  ),
                  items: [
                    DropdownMenuItem(value: 'الكل', child: Text('جميع الموظفين', style: GoogleFonts.tajawal(fontSize: 13))),
                    ..._allUsers.map((u) => DropdownMenuItem(value: u['uid'] ?? u['_id'] ?? '', child: Text('${u['name']} (${u['empId'] ?? ''})', style: GoogleFonts.tajawal(fontSize: 13)))),
                  ],
                  onChanged: (v) => setState(() => _selectedUid = v ?? 'الكل'),
                )),
                const SizedBox(width: 10),
                Text('الموظف', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: C.sub)),
                const SizedBox(width: 6),
                const Icon(Icons.person, size: 16, color: C.pri),
              ]),
            ]),
          ),
          const SizedBox(height: 16),

          // Stats
          Wrap(spacing: 10, runSpacing: 10, children: [
            SizedBox(width: isWide ? null : (MediaQuery.of(context).size.width - 38) / 2, child: _stat('إجمالي السجلات', '${data.length}', C.pri)),
            SizedBox(width: isWide ? null : (MediaQuery.of(context).size.width - 38) / 2, child: _stat('متوسط الساعات', data.isNotEmpty ? '${(data.map((r) => double.tryParse(r['hours'] ?? '0') ?? 0).reduce((a, b) => a + b) / data.length).toStringAsFixed(1)}h' : '—', C.green)),
            SizedBox(width: isWide ? null : (MediaQuery.of(context).size.width - 38) / 2, child: _stat('حالات تأخير', '${data.where((r) => r['late'] != '—').length}', C.orange)),
            SizedBox(width: isWide ? null : (MediaQuery.of(context).size.width - 38) / 2, child: _stat('أوفرتايم', '${data.where((r) => r['overtime'] != '—').length}', C.pri)),
          ]),
          const SizedBox(height: 20),

          // Table
          if (snap.connectionState == ConnectionState.waiting)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(strokeWidth: 2)))
          else if (data.isEmpty)
            Container(width: double.infinity, padding: const EdgeInsets.all(50), decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
              child: Center(child: Column(children: [const Icon(Icons.bar_chart, size: 48, color: C.hint), const SizedBox(height: 12), Text('لا توجد بيانات', style: GoogleFonts.tajawal(fontSize: 14, color: C.muted))])))
          else Container(width: double.infinity, decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
            child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
              headingRowColor: WidgetStateProperty.all(C.bg), headingRowHeight: 42, columnSpacing: 14,
              columns: ['الأوفرتايم', 'التأخير', 'الساعات', 'الخروج', 'الدخول', 'اليوم', 'التاريخ', 'الاسم', 'الكود'].map((h) =>
                DataColumn(label: Text(h, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: C.sub)))).toList(),
              rows: data.map((r) => DataRow(cells: [
                DataCell(Text(r['overtime'] ?? '—', style: GoogleFonts.tajawal(fontSize: 12, color: r['overtime'] != '—' ? C.orange : C.muted))),
                DataCell(Text(r['late'] ?? '—', style: GoogleFonts.tajawal(fontSize: 12, color: r['late'] != '—' ? C.red : C.muted))),
                DataCell(Text('${r['hours']}h', style: _mono(fontSize: 12, fontWeight: FontWeight.w600, color: C.text))),
                DataCell(Text(r['checkOut'] ?? '—', style: _mono(fontSize: 12, color: C.text))),
                DataCell(Text(r['checkIn'] ?? '—', style: _mono(fontSize: 12, color: C.text))),
                DataCell(Text(r['day'] ?? '', style: GoogleFonts.tajawal(fontSize: 12, color: C.sub))),
                DataCell(Text(r['date'] ?? '', style: _mono(fontSize: 12, color: C.text))),
                DataCell(Text(r['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.text))),
                DataCell(Text(r['empId'] ?? '', style: _mono(fontSize: 11, color: C.muted))),
              ])).toList(),
            ))),
        ]));
      },
    );
  }

  Widget _stat(String label, String val, Color color) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(val, style: _mono(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: GoogleFonts.tajawal(fontSize: 12, color: C.sub)),
    ]),
  );
}
