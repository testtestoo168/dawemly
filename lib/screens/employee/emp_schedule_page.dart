import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_colors.dart';

class EmpSchedulePage extends StatelessWidget {
  final Map<String, dynamic> user;
  const EmpSchedulePage({super.key, required this.user});

  TextStyle _tj(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);

  static const _daysFull = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
  static const _daysShort = ['أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];

  static const _shifts = [
    {'id': 1, 'name': 'الفترة الأولى', 'start': '08:00', 'end': '16:00', 'hours': '08:00', 'type': 'افتراضي ثابت'},
    {'id': 2, 'name': 'الفترة الثانية', 'start': '13:00', 'end': '21:00', 'hours': '08:00', 'type': 'افتراضي ثابت'},
    {'id': 3, 'name': 'الفترة الثالثة', 'start': '16:00', 'end': '00:00', 'hours': '08:00', 'type': 'افتراضي ثابت'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: C.white,
        surfaceTintColor: C.white,
        elevation: 0,
        centerTitle: true,
        title: Text('جدول العمل', style: _tj(17, weight: FontWeight.w700, color: C.text)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: C.text),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: C.border, height: 1)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('schedules').snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: C.pri));
          }

          final allSchedules = snap.data?.docs ?? [];
          // Find schedules assigned to this employee
          Map<String, dynamic>? assignedSchedule;
          String scheduleName = 'الجدول الافتراضي';

          for (final doc in allSchedules) {
            final data = doc.data() as Map<String, dynamic>;
            final empIds = (data['empIds'] as List?)?.cast<String>() ?? [];
            if (empIds.contains(user['uid']) || empIds.contains(user['empId'])) {
              assignedSchedule = data;
              scheduleName = data['name'] ?? 'الجدول الافتراضي';
              break;
            }
          }

          // If no specific assignment, use the first schedule (default)
          if (assignedSchedule == null && allSchedules.isNotEmpty) {
            assignedSchedule = allSchedules.first.data() as Map<String, dynamic>;
            scheduleName = assignedSchedule['name'] ?? 'الجدول الافتراضي';
          }

          final shiftId = assignedSchedule?['shiftId'] ?? 1;
          final workDays = (assignedSchedule?['days'] as List?)?.cast<String>() ?? ['أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس'];
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '$scheduleName (أساسي)',
                    style: _tj(15, weight: FontWeight.w700, color: C.pri),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ─── Days Schedule — like image 3 ───
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
                              '$periodCount فترة',
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
                            borderRadius: BorderRadius.circular(12),
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
                                    '(${shift['hours']} ساعة)',
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
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: C.border.withOpacity(0.5)),
                          ),
                          child: Center(
                            child: Text(
                              'إجازة',
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
