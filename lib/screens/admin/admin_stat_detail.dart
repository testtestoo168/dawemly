import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_colors.dart';
import '../../services/attendance_service.dart';

class AdminStatDetail extends StatelessWidget {
  final String filter; // 'all', 'present', 'complete', 'absent'
  final String title;
  final Color color;
  const AdminStatDetail({super.key, required this.filter, required this.title, required this.color});

  TextStyle _tj(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.white,
        surfaceTintColor: C.white,
        elevation: 0,
        centerTitle: true,
        title: Text(title, style: _tj(17, weight: FontWeight.w700, color: C.text)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: C.text),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: C.border, height: 1)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (ctx, usersSnap) {
          final allEmpDocs = (usersSnap.data?.docs ?? []).where((d) {
            final m = d.data() as Map<String, dynamic>;
            return (m['name'] ?? '').toString().isNotEmpty && m['role'] != 'admin';
          }).toList();

          final allEmps = allEmpDocs.map((d) {
            final m = d.data() as Map<String, dynamic>;
            m['_docId'] = d.id;
            return m;
          }).toList();

          return StreamBuilder<QuerySnapshot>(
            stream: AttendanceService().getAllTodayRecords(),
            builder: (ctx, attSnap) {
              final attDocs = attSnap.data?.docs ?? [];
              final attMap = <String, Map<String, dynamic>>{};
              for (final doc in attDocs) {
                final data = doc.data() as Map<String, dynamic>;
                final uid = data['uid'] ?? '';
                if (uid.isNotEmpty) attMap[uid] = data;
              }

              // Build filtered list
              List<Map<String, dynamic>> filtered = [];

              if (filter == 'all') {
                filtered = allEmps;
              } else if (filter == 'present') {
                // حاضر = checked in but NOT checked out
                filtered = allEmps.where((emp) {
                  final uid = emp['uid'] ?? emp['_docId'] ?? '';
                  final att = attMap[uid];
                  return att != null && att['checkIn'] != null && att['checkOut'] == null;
                }).toList();
              } else if (filter == 'complete') {
                // مكتمل = checked in AND checked out
                filtered = allEmps.where((emp) {
                  final uid = emp['uid'] ?? emp['_docId'] ?? '';
                  final att = attMap[uid];
                  return att != null && att['checkOut'] != null;
                }).toList();
              } else if (filter == 'absent') {
                // غائب = no attendance record today
                filtered = allEmps.where((emp) {
                  final uid = emp['uid'] ?? emp['_docId'] ?? '';
                  return !attMap.containsKey(uid);
                }).toList();
              }

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline_rounded, size: 60, color: C.muted.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      Text('لا يوجد موظفين', style: _tj(16, weight: FontWeight.w600, color: C.muted)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final emp = filtered[i];
                  final uid = emp['uid'] ?? emp['_docId'] ?? '';
                  final att = attMap[uid];
                  final name = emp['name'] ?? '';
                  final empId = emp['empId'] ?? '';
                  final dept = emp['dept'] ?? '';
                  final initials = name.length >= 2 ? name.substring(0, 2) : (name.isNotEmpty ? name[0] : 'م');

                  // Determine status
                  String status;
                  Color statusColor;
                  Color statusBg;
                  String timeInfo = '';

                  if (att == null) {
                    status = 'غائب';
                    statusColor = C.red;
                    statusBg = C.redL;
                  } else if (att['checkOut'] != null) {
                    status = 'مكتمل';
                    statusColor = C.green;
                    statusBg = C.greenL;
                    final ci = att['checkIn'] as Timestamp?;
                    final co = att['checkOut'] as Timestamp?;
                    if (ci != null && co != null) {
                      timeInfo = '${_fmtTime(ci)} → ${_fmtTime(co)}';
                      final mins = co.toDate().difference(ci.toDate()).inMinutes;
                      final h = mins ~/ 60;
                      final m = mins % 60;
                      timeInfo += '  (${h}س ${m}د)';
                    }
                  } else {
                    status = 'حاضر';
                    statusColor = C.pri;
                    statusBg = C.priLight;
                    final ci = att['checkIn'] as Timestamp?;
                    if (ci != null) {
                      timeInfo = 'دخول: ${_fmtTime(ci)}';
                    }
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: C.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: C.border),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(child: Text(initials, style: _tj(15, weight: FontWeight.w700, color: color))),
                        ),
                        const SizedBox(width: 12),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: _tj(14, weight: FontWeight.w700, color: C.text)),
                              const SizedBox(height: 2),
                              Text('$empId • $dept', style: _tj(11, color: C.muted)),
                              if (timeInfo.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(timeInfo, style: GoogleFonts.ibmPlexMono(fontSize: 10, color: C.sub)),
                              ],
                            ],
                          ),
                        ),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(status, style: _tj(11, weight: FontWeight.w600, color: statusColor)),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _fmtTime(Timestamp ts) {
    final d = ts.toDate();
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    return '${h.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'م' : 'ص'}';
  }
}
