import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/attendance_service.dart';
import '../../l10n/app_locale.dart';

class AdminStatDetail extends StatefulWidget {
  final String filter;
  final String title;
  final Color color;
  const AdminStatDetail({super.key, required this.filter, required this.title, required this.color});
  @override State<AdminStatDetail> createState() => _AdminStatDetailState();
}

class _AdminStatDetailState extends State<AdminStatDetail> {
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  TextStyle _tj(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final usersRes = await ApiService.get('users.php?action=list');
      final attList = await AttendanceService().getAllTodayRecords();
      final allUsers = ((usersRes['users'] as List?) ?? []).cast<Map<String, dynamic>>()
          .where((u) => (u['name'] ?? '').toString().isNotEmpty && u['role'] != 'admin').toList();
      final attMap = <String, Map<String, dynamic>>{};
      for (final r in attList) attMap[r['uid'] ?? ''] = r;

      // Attach attendance record to each user
      final allUsersWithAtt = allUsers.map((u) {
        final att = attMap[u['uid'] ?? ''];
        return {...u, if (att != null) '_att': att};
      }).toList();

      List<Map<String, dynamic>> filtered = [];
      if (widget.filter == 'all') {
        filtered = allUsersWithAtt;
      } else if (widget.filter == 'present') {
        filtered = allUsersWithAtt.where((u) {
          final att = attMap[u['uid'] ?? ''];
          return att != null && (att['is_checked_in'] == 1 || att['is_checked_in'] == true);
        }).toList();
      } else if (widget.filter == 'complete') {
        filtered = allUsersWithAtt.where((u) {
          final att = attMap[u['uid'] ?? ''];
          return att != null && (att['is_checked_in'] == 0 || att['is_checked_in'] == false) && (att['check_in'] ?? att['first_check_in']) != null;
        }).toList();
      } else if (widget.filter == 'absent') {
        filtered = allUsersWithAtt.where((u) {
          final att = attMap[u['uid'] ?? ''];
          return att == null || (att['is_checked_in'] == 0 || att['is_checked_in'] == false) && (att['check_in'] ?? att['first_check_in']) == null;
        }).toList();
      }

      if (mounted) setState(() { _filtered = filtered; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is String) { try { return DateTime.parse(v); } catch (_) { return null; } }
    return null;
  }

  String _fmtTime(dynamic v) {
    final d = _parseTs(v);
    if (d == null) return '';
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    return '${h.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? L.tr('pm') : L.tr('am')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: W.bg,
      appBar: AppBar(
        backgroundColor: W.white, surfaceTintColor: W.white, elevation: 0, centerTitle: true,
        title: Text(widget.title, style: _tj(17, weight: FontWeight.w700, color: W.text)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: W.text), onPressed: () => Navigator.pop(context)),
        bottom: PreferredSize(preferredSize: Size.fromHeight(1), child: Container(color: W.border, height: 1)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _filtered.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.people_outline_rounded, size: 60, color: W.muted.withOpacity(0.4)),
                  const SizedBox(height: 12),
                  Text(L.tr('no_employees'), style: _tj(16, weight: FontWeight.w600, color: W.muted)),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) {
                      final emp = _filtered[i];
                      final uid = emp['uid'] ?? '';
                      final name = L.localName(emp);
                      final empId = emp['empId'] ?? emp['emp_id'] ?? '';
                      final dept = L.localDept(emp);
                      final initials = name.length >= 2 ? name.substring(0, 2) : (name.isNotEmpty ? name[0] : L.tr('pm'));
                      final att = emp['_att'] as Map<String, dynamic>?;

                      String status; Color statusColor; Color statusBg; String timeInfo = '';
                      if (att == null) {
                        status = L.tr('absent'); statusColor = W.red; statusBg = W.redL;
                      } else if ((att['checkOut'] ?? att['last_check_out']) != null) {
                        status = L.tr('complete'); statusColor = W.green; statusBg = W.greenL;
                        final ci = att['checkIn'] ?? att['first_check_in'];
                        final co = att['checkOut'] ?? att['last_check_out'];
                        final ciDt = _parseTs(ci); final coDt = _parseTs(co);
                        if (ciDt != null && coDt != null) {
                          timeInfo = '${_fmtTime(ci)} → ${_fmtTime(co)}';
                          final mins = coDt.difference(ciDt).inMinutes;
                          timeInfo += '  (${L.tr('h_m_format', args: {'h': (mins ~/ 60).toString(), 'm': (mins % 60).toString()})})';
                        }
                      } else {
                        status = L.tr('present'); statusColor = W.green; statusBg = W.greenL;
                        final ci = att['checkIn'] ?? att['first_check_in'];
                        if (ci != null) timeInfo = L.tr('entry_time', args: {'time': _fmtTime(ci)});
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: DS.cardDecoration(),
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          Container(width: 44, height: 44,
                            decoration: BoxDecoration(color: widget.color.withOpacity(0.1), borderRadius: BorderRadius.circular(DS.radiusMd)),
                            child: Center(child: Text(initials, style: _tj(15, weight: FontWeight.w700, color: widget.color)))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(name, style: _tj(14, weight: FontWeight.w700, color: W.text)),
                            const SizedBox(height: 2),
                            Text('$empId • $dept', style: _tj(11, color: W.muted)),
                            if (timeInfo.isNotEmpty) ...[SizedBox(height: 4), Text(timeInfo, style: GoogleFonts.ibmPlexMono(fontSize: 10, color: W.sub))],
                          ])),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
                            child: Text(status, style: _tj(11, weight: FontWeight.w600, color: statusColor)),
                          ),
                        ]),
                      );
                    },
                  ),
                ),
    );
  }
}
