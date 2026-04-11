import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';
import '../../l10n/app_locale.dart';

class EmpSchedulePage extends StatefulWidget {
  final Map<String, dynamic> user;
  const EmpSchedulePage({super.key, required this.user});
  @override
  State<EmpSchedulePage> createState() => _EmpSchedulePageState();
}

class _EmpSchedulePageState extends State<EmpSchedulePage> {
  TextStyle _tj(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);

  static List<String> get _daysFull => L.dayNamesFull;
  static List<String> get _daysShort => L.dayNamesShort;

  static List<Map<String, dynamic>> get _shifts => [
    {'id': 1, 'name': L.tr('period_1'), 'start': '08:00', 'end': '16:00', 'hours': '08:00', 'type': L.tr('default_fixed')},
    {'id': 2, 'name': L.tr('period_2'), 'start': '13:00', 'end': '21:00', 'hours': '08:00', 'type': L.tr('default_fixed')},
    {'id': 3, 'name': L.tr('period_3'), 'start': '16:00', 'end': '00:00', 'hours': '08:00', 'type': L.tr('default_fixed')},
  ];

  Future<List<Map<String, dynamic>>> _loadSchedules() async {
    final result = await ApiService.get('admin.php?action=get_schedules');
    if (result['success'] == true) {
      return (result['schedules'] as List? ?? []).cast<Map<String, dynamic>>();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.white,
        surfaceTintColor: C.white,
        elevation: 0,
        centerTitle: true,
        title: Text(L.tr('work_schedule'), style: _tj(17, weight: FontWeight.w700, color: C.text)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: C.text),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: C.border, height: 1)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadSchedules(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: C.pri));
          }

          final allSchedules = snap.data ?? [];
          // Find schedules assigned to this employee
          Map<String, dynamic>? assignedSchedule;
          String scheduleName = L.tr('default_schedule');

          for (final data in allSchedules) {
            final empIds = ((data['empIds'] ?? data['emp_ids']) as List? ?? []).map((e) => e.toString()).toList();
            if (empIds.contains(widget.user['uid']) || empIds.contains(widget.user['empId'])) {
              assignedSchedule = data;
              scheduleName = L.localName(data).isNotEmpty ? L.localName(data) : L.tr('default_schedule');
              break;
            }
          }

          // If no specific assignment, use the first schedule (default)
          if (assignedSchedule == null && allSchedules.isNotEmpty) {
            assignedSchedule = allSchedules.first;
            scheduleName = L.localName(assignedSchedule!).isNotEmpty ? L.localName(assignedSchedule) : L.tr('default_schedule');
          }

          final shiftId = int.tryParse('${assignedSchedule?['shiftId'] ?? assignedSchedule?['shift_id'] ?? 1}') ?? 1;
          // days can be int indices [0,1,2,3,4] or Arabic names ['أحد','إثنين',...]
          final rawDays = (assignedSchedule?['days'] as List?) ?? [];
          final workDays = rawDays.map((d) {
            if (d is int && d >= 0 && d < _daysShort.length) return _daysShort[d];
            return d.toString();
          }).toList();
          final shift = _shifts.firstWhere((s) => s['id'] == shiftId, orElse: () => _shifts[0]);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ─── Schedule Name Badge ───
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: C.priLight,
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                ),
                child: Center(
                  child: Text(
                    L.tr('schedule_primary', args: {'name': scheduleName}),
                    style: _tj(15, weight: FontWeight.w700, color: C.pri),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ─── Days Schedule ───
              ..._daysFull.map((dayFull) {
                final dayShort = _daysShort[_daysFull.indexOf(dayFull)];
                final isWorkDay = workDays.contains(dayShort);
                final periodCount = isWorkDay ? 1 : 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Day header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            Text(
                              L.tr('n_periods', args: {'n': periodCount.toString()}),
                              style: _tj(12, color: C.muted),
                            ),
                            const Spacer(),
                            Text(
                              dayFull,
                              style: _tj(16, weight: FontWeight.w800, color: C.text),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (isWorkDay)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: C.white,
                            borderRadius: BorderRadius.circular(DS.radiusMd),
                            border: Border.all(color: C.border),
                          ),
                          child: Column(
                            children: [
                              Text(
                                shift['type'] as String,
                                style: _tj(14, weight: FontWeight.w600, color: C.text),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    L.tr('n_hours_bracket', args: {'n': shift['hours'].toString()}),
                                    style: _tj(13, color: C.muted),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    shift['end'] as String,
                                    style: _tj(15, weight: FontWeight.w700, color: C.pri),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Icon(Icons.arrow_back_rounded, size: 16, color: C.muted),
                                  ),
                                  Text(
                                    shift['start'] as String,
                                    style: _tj(15, weight: FontWeight.w700, color: C.pri),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: C.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(DS.radiusMd),
                            border: Border.all(color: C.border),
                          ),
                          child: Center(
                            child: Text(
                              L.tr('leave_request'),
                              style: _tj(14, weight: FontWeight.w600, color: C.muted),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}
