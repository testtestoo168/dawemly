import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/attendance_service.dart';

class AdminStatDetail extends StatefulWidget {
  final String filter; // 'all', 'present', 'complete', 'absent'
  final String title;
  final Color color;
  const AdminStatDetail({super.key, required this.filter, required this.title, required this.color});

  @override
  State<AdminStatDetail> createState() => _AdminStatDetailState();
}

class _AdminStatDetailState extends State<AdminStatDetail> {
  List<Map<String, dynamic>> _allEmps = [];
  Map<String, Map<String, dynamic>> _attMap = {};
  bool _loading = true;

  TextStyle _tj(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final usersResult = await ApiService.get('users.php?action=list');
      final usersList = usersResult['users'] ?? usersResult['data'] ?? [];
      final allEmpsList = (usersList as List).map((e) => Map<String, dynamic>.from(e)).where((m) {
        return (m['name'] ?? '').toString().isNotEmpty && m['role'] != 'admin';
      }).toList();

      final attRecords = await AttendanceService().getAllTodayRecords();
      final attMap = <String, Map<String, dynamic>>{};
      for (final data in attRecords) {
        final uid = (data['uid'] ?? '').toString();
        if (uid.isNotEmpty) attMap[uid] = data;
      }

      if (mounted) {
        setState(() {
          _allEmps = allEmpsList;
          _attMap = attMap;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
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
        title: Text(widget.title, style: _tj(17, weight: FontWeight.w700, color: C.text)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: C.text),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: C.border, height: 1)),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _buildBody(),
    );
  }

  Widget _buildBody() {
    // Build filtered list
    List<Map<String, dynamic>> filtered = [];

    if (widget.filter == 'all') {
      filtered = _allEmps;
    } else if (widget.filter == 'present') {
      // حاضر = checked in but NOT checked out
      filtered = _allEmps.where((emp) {
        final uid = (emp['uid'] ?? emp['_docId'] ?? '').toString();
        final att = _attMap[uid];
        return att != null && att['checkIn'] != null && att['checkOut'] == null;
      }).toList();
    } else if (widget.filter == 'complete') {
      // مكتمل = checked in AND checked out
      filtered = _allEmps.where((emp) {
        final uid = (emp['uid'] ?? emp['_docId'] ?? '').toString();
        final att = _attMap[uid];
        return att != null && att['checkOut'] != null;
      }).toList();
    } else if (widget.filter == 'absent') {
      // غائب = no attendance record today
      filtered = _allEmps.where((emp) {
        final uid = (emp['uid'] ?? emp['_docId'] ?? '').toString();
        return !_attMap.containsKey(uid);
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
        final uid = (emp['uid'] ?? emp['_docId'] ?? '').toString();
        final att = _attMap[uid];
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
          final ci = _parseDateTime(att['checkIn']);
          final co = _parseDateTime(att['checkOut']);
          if (ci != null && co != null) {
            timeInfo = '${_fmtTime(ci)} → ${_fmtTime(co)}';
            final mins = co.difference(ci).inMinutes;
            final h = mins ~/ 60;
            final m = mins % 60;
            timeInfo += '  (${h}س ${m}د)';
          }
        } else {
          status = 'حاضر';
          statusColor = C.pri;
          statusBg = C.priLight;
          final ci = _parseDateTime(att['checkIn']);
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
                  color: widget.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(initials, style: _tj(15, weight: FontWeight.w700, color: widget.color))),
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
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _fmtTime(DateTime d) {
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    return '${h.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'م' : 'ص'}';
  }
}
