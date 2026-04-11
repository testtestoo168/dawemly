import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';
import '../../l10n/app_locale.dart';

class AdminRequests extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminRequests({super.key, required this.user});
  @override
  State<AdminRequests> createState() => _AdminRequestsState();
}

class _AdminRequestsState extends State<AdminRequests> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadRequests();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadRequests() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('requests.php?action=all');
      if (res['success'] == true && mounted) {
        setState(() {
          _requests = (res['requests'] as List? ?? []).cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtDate(dynamic ts) {
    if (ts == null) return '—';
    DateTime? dt;
    if (ts is String) { try { dt = DateTime.parse(ts); } catch(_) {} }
    if (dt == null) return '—';
    final months = L.months;
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  /// isApprove: true = approve, false = reject
  void _handleRequest(String docId, bool isApprove) async {
    // Always send Arabic status to server (server expects Arabic)
    final serverStatus = isApprove ? 'تم الموافقة' : 'مرفوض';
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd)),
        title: Text(isApprove ? L.tr('approve_request') : L.tr('reject_request'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w700), textAlign: TextAlign.right),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(L.tr('are_you_sure'), style: GoogleFonts.tajawal(), textAlign: TextAlign.right),
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            textAlign: TextAlign.right,
            maxLines: 2,
            style: GoogleFonts.tajawal(fontSize: 13),
            decoration: InputDecoration(
              hintText: L.tr('note_optional'),
              hintStyle: GoogleFonts.tajawal(color: W.hint),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L.tr('cancel'), style: GoogleFonts.tajawal(color: W.sub))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L.tr('confirm'), style: GoogleFonts.tajawal(color: isApprove ? W.green : W.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ApiService.post('requests.php?action=update_status', {
        'id': docId,
        'status': serverStatus,
        'admin_note': noteCtrl.text.trim(),
        'adminName': widget.user['name'] ?? L.tr('system_admin'),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isApprove ? L.tr('request_approved') : L.tr('request_rejected'), style: GoogleFonts.tajawal()),
          backgroundColor: isApprove ? W.green : W.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd)),
        ));
        _loadRequests();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Column(children: [
      // Tabs
      Container(
        margin: EdgeInsets.fromLTRB(isWide ? 28 : 14, isWide ? 20 : 10, isWide ? 28 : 14, 0),
        decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(DS.radiusMd), border: Border.all(color: W.border)),
        padding: const EdgeInsets.all(3),
        child: TabBar(
          controller: _tabCtrl,
          indicator: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(4), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)]),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: W.pri,
          unselectedLabelColor: W.sub,
          labelStyle: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: L.tr('pending_tab_count', args: {'n': _requests.where((r) => _isPending(r['status'])).length.toString()}), height: 36),
            Tab(text: L.tr('approved_tab_count', args: {'n': _requests.where((r) => _isApproved(r['status'])).length.toString()}), height: 36),
            Tab(text: L.tr('rejected_tab_count', args: {'n': _requests.where((r) => _isRejected(r['status'])).length.toString()}), height: 36),
          ],
        ),
      ),

      Expanded(
        child: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildList(L.tr('pending'), showActions: true),
                _buildList(L.tr('approved')),
                _buildList(L.tr('rejected')),
              ],
            ),
      ),
    ]);
  }

  // Status comparison helpers — handle Arabic source, English, and translated values
  static bool _isPending(dynamic s) => s == 'تحت الإجراء' || s == 'pending' || s == L.tr('pending');
  static bool _isApproved(dynamic s) => s == 'تم الموافقة' || s == 'موافق' || s == 'approved' || s == L.tr('approved');
  static bool _isRejected(dynamic s) => s == 'مرفوض' || s == 'rejected' || s == L.tr('rejected');
  static bool _isLeave(Map<String, dynamic> r) {
    final t = r['request_type'] ?? r['requestType'] ?? '';
    return t == 'إجازة' || t == L.tr('leave_request');
  }

  Widget _buildList(String statusFilter, {bool showActions = false}) {
    var docs = _requests.where((r) {
      final s = r['status'] ?? '';
      if (statusFilter == L.tr('pending')) return _isPending(s);
      if (statusFilter == L.tr('approved')) return _isApproved(s);
      if (statusFilter == L.tr('rejected')) return _isRejected(s);
      return s == statusFilter;
    }).toList();
    docs.sort((a, b) {
      final aT = (a['created_at'] ?? a['createdAt']) as String?;
      final bT = (b['created_at'] ?? b['createdAt']) as String?;
      if (aT == null || bT == null) return 0;
      return bT.compareTo(aT);
    });

    if (docs.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.description_outlined, size: 48, color: W.hint),
        const SizedBox(height: 12),
        Text(L.tr('no_requests'), style: GoogleFonts.tajawal(fontSize: 14, color: W.muted)),
      ]));
    }

    final isWide = MediaQuery.of(context).size.width > 800;
    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.builder(
        padding: EdgeInsets.all(isWide ? 28 : 14),
        itemCount: docs.length,
        itemBuilder: (context, i) => _requestCard(docs[i], docs[i]['id']?.toString() ?? '', showActions),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> r, String docId, bool showActions) {
    final screenW = MediaQuery.of(context).size.width;
    final isSmall = screenW < 400;
    final isLeave = _isLeave(r);
    final typeColor = isLeave ? const Color(0xFF2E90FA) : W.orange;
    final typeIcon = isLeave ? Icons.beach_access : Icons.access_time;

    String desc = '';
    if (isLeave) {
      desc = '${L.serverText(r['leave_type'] ?? r['leaveType'] ?? '')} — ${r['days'] ?? 0} ${L.tr('day_unit')}\n${L.tr('from')} ${_fmtDate(r['start_date'] ?? r['startDate'])} ${L.tr('to')} ${_fmtDate(r['end_date'] ?? r['endDate'])}';
    } else {
      final hours = (r['hours'] as num?)?.toStringAsFixed(1);
      desc = '${L.serverText(r['perm_type'] ?? r['permType'] ?? '')}${hours != null ? ' — $hours ${L.tr('hour')}' : ''}\n${L.tr('from')} ${r['from_time'] ?? r['fromTime'] ?? ''} ${L.tr('to')} ${r['to_time'] ?? r['toTime'] ?? ''}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: DS.cardDecoration(),
      padding: EdgeInsets.all(isSmall ? 12 : 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(children: [
          if (showActions) ...[
            InkWell(
              onTap: () => _handleRequest(docId, false),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: const Color(0xFFFEF3F2), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFFECDCA))),
                child: Icon(Icons.close, size: 14, color: W.red),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () => _handleRequest(docId, true),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: const Color(0xFFECFDF3), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFABEFC6))),
                child: Icon(Icons.check, size: 14, color: W.green),
              ),
            ),
          ],
          if (!showActions) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: isSmall ? 6 : 10, vertical: 3),
              decoration: BoxDecoration(
                color: _isApproved(r['status']) ? W.greenL : W.redL,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _isApproved(r['status']) ? W.greenBd : W.redBd),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(L.serverText(r['status'] ?? ''), style: GoogleFonts.tajawal(fontSize: isSmall ? 10 : 11, fontWeight: FontWeight.w600, color: _isApproved(r['status']) ? W.green : W.red)),
                const SizedBox(width: 3),
                Icon(_isApproved(r['status']) ? Icons.check_circle : Icons.cancel, size: 13, color: _isApproved(r['status']) ? W.green : W.red),
              ]),
            ),
          ],
          const Spacer(),
          Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(L.localName(r), style: GoogleFonts.tajawal(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w700, color: W.text)),
            Text(r['emp_id'] ?? r['empId'] ?? '', style: GoogleFonts.tajawal(fontSize: 11, color: W.muted), overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 8),
          Container(
            width: isSmall ? 34 : 40, height: isSmall ? 34 : 40,
            decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(typeIcon, size: 18, color: typeColor),
          ),
        ]),
        const SizedBox(height: 10),
        Container(width: double.infinity, height: 1, color: W.div),
        const SizedBox(height: 10),
        Text(L.serverText(r['request_type'] ?? r['requestType'] ?? ''), style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: W.text)),
        const SizedBox(height: 4),
        Text(desc, style: GoogleFonts.tajawal(fontSize: 12, color: W.sub, height: 1.5)),
        if ((r['reason'] ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(4)),
            child: Text(L.tr('reason_prefix', args: {'reason': r['reason'] ?? ''}), style: GoogleFonts.tajawal(fontSize: 12, color: W.sub), textAlign: TextAlign.right),
          ),
        ],
      ]),
    );
  }
}
