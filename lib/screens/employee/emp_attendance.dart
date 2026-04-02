import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/attendance_service.dart';

class EmpAttendancePage extends StatefulWidget {
  final Map<String, dynamic> user;
  const EmpAttendancePage({super.key, required this.user});
  @override
  State<EmpAttendancePage> createState() => _EmpAttendancePageState();
}

class _EmpAttendancePageState extends State<EmpAttendancePage> {
  final _months = const ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
  final _dayNames = const ['الأحد','الإثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت'];

  late int _selMonth;
  late int _selYear;

  // Track which day card is expanded
  String? _expandedDateKey;
  List<Map<String, dynamic>>? _expandedPunches;
  bool _loadingPunches = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selMonth = now.month;
    _selYear = now.year;
  }

  DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is String) { try { return DateTime.parse(v); } catch(_) { return null; } }
    return null;
  }

  String _fmtTime(dynamic ts) {
    if (ts == null) return '—';
    DateTime? dt;
    if (ts is DateTime) {
      dt = ts;
    } else if (ts is String) {
      dt = _parseTs(ts);
    }
    if (dt == null) return '—';
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'م' : 'ص'}';
  }

  String _fmtWorkedTime(int totalMinutes) {
    if (totalMinutes <= 0) return '—';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h > 0 && m > 0) return '${h} س ${m} د';
    if (h > 0) return '${h} ساعة';
    return '${m} دقيقة';
  }

  void _prevMonth() {
    setState(() {
      _selMonth--;
      if (_selMonth < 1) { _selMonth = 12; _selYear--; }
      _expandedDateKey = null;
      _expandedPunches = null;
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_selYear == now.year && _selMonth >= now.month) return;
    setState(() {
      _selMonth++;
      if (_selMonth > 12) { _selMonth = 1; _selYear++; }
      _expandedDateKey = null;
      _expandedPunches = null;
    });
  }

  // Load punches for a day when tapped
  void _toggleDay(String dateKey) async {
    if (_expandedDateKey == dateKey) {
      // Collapse
      setState(() {
        _expandedDateKey = null;
        _expandedPunches = null;
      });
      return;
    }

    setState(() {
      _expandedDateKey = dateKey;
      _expandedPunches = null;
      _loadingPunches = true;
    });

    final svc = AttendanceService();
    final punches = await svc.getDayPunches(widget.user['uid'] ?? '', dateKey);

    if (mounted) {
      setState(() {
        _expandedPunches = punches;
        _loadingPunches = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = AttendanceService();
    final now = DateTime.now();
    final isCurrentMonth = _selYear == now.year && _selMonth == now.month;

    return Scaffold(
      appBar: AppBar(
        title: Text('سجل حضوري', style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w700, color: C.text)),
        centerTitle: true, backgroundColor: C.white, surfaceTintColor: C.white, elevation: 0,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: C.border, height: 1)),
      ),
      body: Column(children: [
        // ─── Month/Year Selector ───
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(color: C.white, border: Border(bottom: BorderSide(color: C.border))),
          child: Row(children: [
            InkWell(onTap: _prevMonth, child: Container(width: 36, height: 36, decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(4)), child: const Icon(Icons.chevron_right, size: 20, color: C.sub))),
            const Spacer(),
            GestureDetector(
              onTap: () async {
                final years = List.generate(5, (i) => now.year - i);
                await showDialog(context: context, builder: (ctx) => SimpleDialog(
                  title: Text('اختر السنة', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                  children: years.map((y) => SimpleDialogOption(
                    onPressed: () { setState(() => _selYear = y); Navigator.pop(ctx); },
                    child: Center(child: Text('$y', style: GoogleFonts.ibmPlexMono(fontSize: 18, fontWeight: _selYear == y ? FontWeight.w800 : FontWeight.w400, color: _selYear == y ? C.pri : C.text))),
                  )).toList(),
                ));
              },
              child: Column(children: [
                Text('${_months[_selMonth - 1]} $_selYear', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
                Text('اضغط لتغيير السنة', style: GoogleFonts.tajawal(fontSize: 10, color: C.muted)),
              ]),
            ),
            const Spacer(),
            InkWell(onTap: isCurrentMonth ? null : _nextMonth, child: Container(width: 36, height: 36, decoration: BoxDecoration(color: isCurrentMonth ? C.div : C.bg, borderRadius: BorderRadius.circular(4)), child: Icon(Icons.chevron_left, size: 20, color: isCurrentMonth ? C.hint : C.sub))),
          ]),
        ),

        // ─── Records ───
        Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
          future: svc.getMonthlyAttendance(widget.user['uid'] ?? '', _selYear, _selMonth),
          builder: (context, snap) {
            final records = List<Map<String, dynamic>>.from(snap.data ?? []);
            records.sort((a, b) {
              final ak = (a['dateKey'] ?? a['date_key'] ?? '').toString();
              final bk = (b['dateKey'] ?? b['date_key'] ?? '').toString();
              return bk.compareTo(ak);
            });
            final present = records.where((r) => (r['firstCheckIn'] ?? r['first_check_in'] ?? r['checkIn'] ?? r['check_in']) != null).length;
            final complete = records.where((r) => (r['lastCheckOut'] ?? r['last_check_out'] ?? r['checkOut'] ?? r['check_out']) != null).length;

            // Calculate total worked hours for the month
            int totalMonthMinutes = 0;
            for (final r in records) {
              totalMonthMinutes += (r['totalWorkedMinutes'] as int?) ?? (r['total_worked_minutes'] as int?) ?? 0;
            }

            return ListView(padding: const EdgeInsets.all(14), children: [
              // Stats
              Container(
                decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(6), border: Border.all(color: C.border)),
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  _stat('مكتمل', '$complete', C.green),
                  const SizedBox(width: 8),
                  _stat('حاضر', '$present', C.pri),
                  const SizedBox(width: 8),
                  _stat('إجمالي ساعات', _fmtWorkedTime(totalMonthMinutes), C.orange),
                ]),
              ),
              const SizedBox(height: 12),

              if (snap.connectionState == ConnectionState.waiting && records.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(strokeWidth: 2)))
              else if (records.isEmpty)
                Padding(padding: const EdgeInsets.all(40), child: Column(children: [
                  Icon(Icons.calendar_today_outlined, size: 48, color: C.hint),
                  const SizedBox(height: 12),
                  Text('لا توجد بيانات حضور في ${_months[_selMonth - 1]} $_selYear', style: GoogleFonts.tajawal(fontSize: 14, color: C.muted)),
                  Text('سجّل حضورك من الصفحة الرئيسية', style: GoogleFonts.tajawal(fontSize: 12, color: C.hint)),
                ]))
              else
                ...records.map((r) => _buildDayCard(r)),
            ]);
          },
        )),
      ]),
    );
  }

  Widget _buildDayCard(Map<String, dynamic> r) {
    final dateKey = r['dateKey'] ?? r['date_key'] ?? '';
    final parts = dateKey.split('-');
    final day = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
    final month = parts.length > 1 ? int.tryParse(parts[1]) ?? _selMonth : _selMonth;
    final year = parts.isNotEmpty ? int.tryParse(parts[0]) ?? _selYear : _selYear;
    final dt = parts.length == 3 ? DateTime(year, month, day) : DateTime.now();
    final dayName = _dayNames[dt.weekday % 7];

    // Use new fields with fallback to legacy and snake_case
    final firstIn = r['firstCheckIn'] ?? r['first_check_in'] ?? r['checkIn'] ?? r['check_in'];
    final lastOut = r['lastCheckOut'] ?? r['last_check_out'] ?? r['checkOut'] ?? r['check_out'];
    final hasOut = lastOut != null;
    final stColor = hasOut ? C.green : C.pri;
    final totalMinutes = (r['totalWorkedMinutes'] as int?) ?? 0;
    final sessions = (r['sessions'] as int?) ?? 1;
    final isExpanded = _expandedDateKey == dateKey;

    return GestureDetector(
      onTap: () => _toggleDay(dateKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isExpanded ? C.pri.withOpacity(0.4) : C.border),
          boxShadow: isExpanded ? [BoxShadow(color: C.pri.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))] : [],
        ),
        child: Column(children: [
          // ═══ Summary row (always visible) ═══
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              // Left side: status + checkout
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: stColor.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                  child: Text(hasOut ? 'مكتمل' : 'حاضر', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: stColor)),
                ),
                const SizedBox(height: 4),
                Text('خروج: ${_fmtTime(lastOut)}', style: GoogleFonts.ibmPlexMono(fontSize: 10, color: C.muted)),
                if (totalMinutes > 0) ...[
                  const SizedBox(height: 2),
                  Text(_fmtWorkedTime(totalMinutes), style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: C.green)),
                ],
              ]),
              const Spacer(),
              // Right side: day name, first check-in
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('$dayName $day ${_months[month - 1]}', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: C.text)),
                Text('حضور: ${_fmtTime(firstIn)}', style: GoogleFonts.ibmPlexMono(fontSize: 11, color: C.sub)),
                if (sessions > 1) ...[
                  const SizedBox(height: 2),
                  Text('$sessions فترات عمل', style: GoogleFonts.tajawal(fontSize: 9, color: C.pri)),
                ],
              ]),
              const SizedBox(width: 10),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: stColor.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                child: Icon(
                  isExpanded ? Icons.expand_less : (hasOut ? Icons.check_circle_outline : Icons.access_time),
                  size: 16, color: stColor,
                ),
              ),
            ]),
          ),

          // ═══ Expanded detail section ═══
          if (isExpanded) ...[
            Container(height: 1, color: C.border),
            _buildExpandedSection(dateKey),
          ],
        ]),
      ),
    );
  }

  Widget _buildExpandedSection(String dateKey) {
    if (_loadingPunches) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    final punches = _expandedPunches;
    if (punches == null || punches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(child: Text('لا توجد تفاصيل', style: GoogleFonts.tajawal(fontSize: 12, color: C.muted))),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: C.bg.withOpacity(0.5),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(children: [
          Text('${punches.length} بصمة', style: GoogleFonts.tajawal(fontSize: 10, color: C.muted)),
          const Spacer(),
          Text('تفاصيل البصمات', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w700, color: C.text)),
          const SizedBox(width: 6),
          const Icon(Icons.fingerprint, size: 16, color: C.pri),
        ]),
        const SizedBox(height: 10),

        // Timeline of punches
        ...List.generate(punches.length, (i) {
          final punch = punches[i];
          final isCheckIn = punch['type'] == 'checkIn';
          final color = isCheckIn ? C.pri : C.red;
          final icon = isCheckIn ? Icons.login_rounded : Icons.logout_rounded;
          final label = isCheckIn ? 'تسجيل دخول' : 'تسجيل خروج';
          final time = punch['localTime'] ?? punch['timestamp'];
          final isLast = i == punches.length - 1;

          return IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Time
              SizedBox(
                width: 70,
                child: Text(_fmtTime(time), style: GoogleFonts.ibmPlexMono(fontSize: 11, fontWeight: FontWeight.w600, color: C.text)),
              ),

              // Timeline line + dot
              SizedBox(
                width: 30,
                child: Column(children: [
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                    ),
                  ),
                  if (!isLast) Expanded(child: Container(width: 2, color: C.border)),
                ]),
              ),

              // Info
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: C.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                      child: Icon(icon, size: 14, color: color),
                    ),
                    const SizedBox(width: 8),
                    Text(label, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.text)),
                  ]),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _stat(String label, String val, Color color) {
    return Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: color.withOpacity(0.04), borderRadius: BorderRadius.circular(4)), child: Column(children: [
      Text(val, style: GoogleFonts.ibmPlexMono(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.tajawal(fontSize: 9, fontWeight: FontWeight.w600, color: C.muted)),
    ])));
  }
}
