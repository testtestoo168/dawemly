import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/requests_service.dart';
import '../../services/server_time_service.dart';
import '../../l10n/app_locale.dart';

class EmpRequestsPage extends StatefulWidget {
  final Map<String, dynamic> user;
  const EmpRequestsPage({super.key, required this.user});
  @override
  State<EmpRequestsPage> createState() => _EmpRequestsPageState();
}

class _EmpRequestsPageState extends State<EmpRequestsPage> {
  final _svc = RequestsService();
  List<Map<String, dynamic>>? _requests;
  bool _loading = true;

  final _months = L.months;

  late int _selMonth;
  late int _selYear;

  @override
  void initState() {
    super.initState();
    final now = ServerTimeService().now;
    _selMonth = now.month;
    _selYear  = now.year;
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _loading = true);
    final reqs = await _svc.getMyRequests(widget.user['uid'] ?? '');
    if (mounted) setState(() { _requests = reqs; _loading = false; });
  }

  List<Map<String, dynamic>> get _filtered {
    if (_requests == null) return [];
    return _requests!.where((r) {
      final raw = r['createdAt'] ?? r['created_at'] ?? r['startDate'] ?? r['start_date'];
      if (raw == null) return false;
      try {
        final dt = DateTime.parse(raw.toString());
        return dt.month == _selMonth && dt.year == _selYear;
      } catch (_) { return false; }
    }).toList();
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    DateTime? dt;
    if (v is String) { try { dt = DateTime.parse(v); } catch(_) {} }
    if (dt == null) return v.toString();
    return '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final now = ServerTimeService().now;
    return Scaffold(
      appBar: AppBar(
        title: Text(L.tr('mob_requests'), style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w700, color: C.text)),
        centerTitle: true,
        backgroundColor: C.white,
        surfaceTintColor: C.white,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.refresh, color: C.sub), onPressed: _loadRequests)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Column(children: [
            Container(color: C.border, height: 1),

            // ─── Month/Year filter ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(children: [
                // Year picker
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(DS.radiusSm), border: Border.all(color: C.border)),
                  child: DropdownButtonHideUnderline(child: DropdownButton<int>(
                    value: _selYear,
                    style: GoogleFonts.ibmPlexMono(fontSize: 13, color: C.text),
                    items: List.generate(3, (i) => now.year - i).map((y) =>
                      DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                    onChanged: (v) => setState(() { _selYear = v!; }),
                  )),
                ),
                const SizedBox(width: 8),
                // Month picker
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(DS.radiusSm), border: Border.all(color: C.border)),
                    child: DropdownButtonHideUnderline(child: DropdownButton<int>(
                      value: _selMonth,
                      isExpanded: true,
                      style: GoogleFonts.tajawal(fontSize: 13, color: C.text),
                      items: List.generate(12, (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(_months[i]),
                      )).toList(),
                      onChanged: (v) => setState(() { _selMonth = v!; }),
                    )),
                  ),
                ),
                const SizedBox(width: 8),
                // Results count badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: C.priLight, borderRadius: BorderRadius.circular(DS.radiusSm)),
                  child: Text('${_filtered.length}', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: C.pri)),
                ),
              ]),
            ),
          ]),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        child: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _filtered.isEmpty
            ? ListView(children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.45,
                  child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.description_outlined, size: 48, color: C.hint),
                    const SizedBox(height: 12),
                    Text(L.tr('no_requests_in_month', args: {'month': _months[_selMonth - 1], 'year': _selYear.toString()}),
                      style: GoogleFonts.tajawal(fontSize: 14, color: C.muted), textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(L.tr('create_from_new_btn'),
                      style: GoogleFonts.tajawal(fontSize: 12, color: C.hint)),
                  ])),
                ),
              ])
            : ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: _filtered.length,
                itemBuilder: (context, i) => _requestCard(_filtered[i]),
              ),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> r) {
    final status = r['status'] ?? '';
    final isLeave = r['requestType'] == L.tr('leave_request') || r['request_type'] == L.tr('leave_request');
    Color stColor, stBg, stBd;

    if (status == L.tr('approved')) {
      stColor = C.green; stBg = C.greenL; stBd = C.greenBd;
    } else if (status == L.tr('rejected')) {
      stColor = C.red; stBg = C.redL; stBd = C.redBd;
    } else {
      stColor = C.orange; stBg = C.orangeL; stBd = C.orangeBd;
    }

    final requestType = r['requestType'] ?? r['request_type'] ?? '';
    final leaveType   = r['leaveType']   ?? r['leave_type']   ?? '';
    final permType    = r['permType']    ?? r['perm_type']    ?? '';
    final fromTime    = r['fromTime']    ?? r['from_time']    ?? '';
    final toTime      = r['toTime']      ?? r['to_time']      ?? '';
    final startDate   = r['startDate']   ?? r['start_date'];
    final endDate     = r['endDate']     ?? r['end_date'];
    final days        = r['days'] ?? 0;
    final hours       = (r['hours'] as num?)?.toStringAsFixed(1);
    final adminNote   = r['adminNote']   ?? r['admin_note']   ?? '';
    final createdAt   = r['createdAt']   ?? r['created_at'];

    String desc = '';
    if (isLeave) {
      desc = '$leaveType — $days ${L.tr('day_unit')}\n${L.tr('from')} ${_fmtDate(startDate)} ${L.tr('to')} ${_fmtDate(endDate)}';
    } else {
      desc = '$permType${hours != null ? ' — $hours ${L.tr('hour')}' : ''}\n${L.tr('from')} $fromTime ${L.tr('to')} $toTime';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(DS.radiusMd), border: Border.all(color: C.border)),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: stBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: stBd)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(status, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: stColor)),
              const SizedBox(width: 4),
              Icon(status == L.tr('approved') ? Icons.check_circle : status == L.tr('rejected') ? Icons.cancel : Icons.hourglass_bottom, size: 14, color: stColor),
            ]),
          ),
          Row(children: [
            Text(requestType, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: C.text)),
            const SizedBox(width: 8),
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: (isLeave ? C.teal : C.orange).withOpacity(0.1), borderRadius: BorderRadius.circular(DS.radiusSm)),
              child: Icon(isLeave ? Icons.beach_access : Icons.access_time, size: 16, color: isLeave ? C.teal : C.orange),
            ),
          ]),
        ]),
        const SizedBox(height: 8),
        Text(desc, style: GoogleFonts.tajawal(fontSize: 12, color: C.sub, height: 1.5)),
        if ((r['reason'] ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(L.tr('reason_prefix', args: {'reason': r['reason'] ?? ''}), style: GoogleFonts.tajawal(fontSize: 11, color: C.muted)),
        ],
        if (adminNote.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(DS.radiusSm)),
            child: Text(L.tr('admin_note', args: {'note': adminNote}), style: GoogleFonts.tajawal(fontSize: 11, color: C.sub), textAlign: TextAlign.right),
          ),
        ],
        if (createdAt != null) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(_fmtDate(createdAt), style: GoogleFonts.ibmPlexMono(fontSize: 10, color: C.hint)),
          ),
        ],
      ]),
    );
  }
}
