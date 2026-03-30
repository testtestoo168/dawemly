import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/requests_service.dart';

class EmpRequestsPage extends StatefulWidget {
  final Map<String, dynamic> user;
  const EmpRequestsPage({super.key, required this.user});
  @override
  State<EmpRequestsPage> createState() => _EmpRequestsPageState();
}

class _EmpRequestsPageState extends State<EmpRequestsPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _svc = RequestsService();
  List<Map<String, dynamic>>? _requests;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadRequests();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadRequests() async {
    setState(() => _loading = true);
    final reqs = await _svc.getMyRequests(widget.user['uid'] ?? '');
    if (mounted) setState(() { _requests = reqs; _loading = false; });
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    DateTime? dt;
    if (v is String) { try { dt = DateTime.parse(v); } catch(_) {} }
    if (dt == null) return v.toString();
    final months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الطلبات', style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w700, color: C.text)),
        centerTitle: true,
        backgroundColor: C.white,
        surfaceTintColor: C.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: C.sub),
            onPressed: _loadRequests,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Column(children: [
            Container(color: C.border, height: 1),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
              padding: const EdgeInsets.all(3),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)]),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: C.pri,
                unselectedLabelColor: C.sub,
                labelStyle: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600),
                tabs: const [Tab(text: 'طلباتي', height: 34), Tab(text: 'الطلبات الواردة', height: 34)],
              ),
            ),
          ]),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // ─── طلباتي ───
          RefreshIndicator(
            onRefresh: _loadRequests,
            child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : (_requests == null || _requests!.isEmpty)
                ? ListView(children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.description_outlined, size: 48, color: C.hint),
                        const SizedBox(height: 12),
                        Text('لا توجد طلبات', style: GoogleFonts.tajawal(fontSize: 14, color: C.muted)),
                        const SizedBox(height: 4),
                        Text('أنشئ طلب جديد من زر "طلب جديد"', style: GoogleFonts.tajawal(fontSize: 12, color: C.hint)),
                      ])),
                    ),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: _requests!.length,
                    itemBuilder: (context, i) => _requestCard(_requests![i]),
                  ),
          ),

          // ─── الطلبات الواردة ───
          Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.description_outlined, size: 48, color: C.hint),
            const SizedBox(height: 12),
            Text('لا توجد طلبات واردة', style: GoogleFonts.tajawal(fontSize: 14, color: C.muted)),
          ])),
        ],
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> r) {
    final status = r['status'] ?? '';
    final isLeave = r['requestType'] == 'إجازة' || r['request_type'] == 'إجازة';
    Color stColor;
    Color stBg;
    Color stBd;

    if (status == 'تم الموافقة') {
      stColor = C.green; stBg = const Color(0xFFECFDF3); stBd = const Color(0xFFABEFC6);
    } else if (status == 'مرفوض') {
      stColor = C.red; stBg = const Color(0xFFFEF3F2); stBd = const Color(0xFFFECDCA);
    } else {
      stColor = C.orange; stBg = const Color(0xFFFFFAEB); stBd = const Color(0xFFFEDF89);
    }

    final statusIcon = status == 'تم الموافقة' ? Icons.check_circle : status == 'مرفوض' ? Icons.cancel : Icons.hourglass_bottom;

    final typeIcon = isLeave ? Icons.beach_access : Icons.access_time;
    final typeColor = isLeave ? const Color(0xFF2E90FA) : const Color(0xFFF79009);

    final requestType = r['requestType'] ?? r['request_type'] ?? '';
    final leaveType = r['leaveType'] ?? r['leave_type'] ?? '';
    final permType = r['permType'] ?? r['perm_type'] ?? '';
    final fromTime = r['fromTime'] ?? r['from_time'] ?? '';
    final toTime = r['toTime'] ?? r['to_time'] ?? '';
    final startDate = r['startDate'] ?? r['start_date'];
    final endDate = r['endDate'] ?? r['end_date'];
    final days = r['days'] ?? 0;
    final hours = (r['hours'] as num?)?.toStringAsFixed(1);
    final adminNote = r['adminNote'] ?? r['admin_note'] ?? '';

    String desc = '';
    if (isLeave) {
      desc = '$leaveType — $days يوم';
      final start = _fmtDate(startDate);
      final end = _fmtDate(endDate);
      desc += '\nمن $start إلى $end';
    } else {
      desc = '$permType';
      desc += '${hours != null ? ' — $hours ساعة' : ''}';
      desc += '\nمن $fromTime إلى $toTime';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: stBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: stBd)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(status, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: stColor)),
              const SizedBox(width: 4),
              Icon(statusIcon, size: 14, color: stColor),
            ]),
          ),
          Row(children: [
            Text('$requestType', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: C.text)),
            const SizedBox(width: 8),
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(typeIcon, size: 16, color: typeColor),
            ),
          ]),
        ]),
        const SizedBox(height: 8),
        Text(desc, style: GoogleFonts.tajawal(fontSize: 12, color: C.sub, height: 1.5)),
        if ((r['reason'] ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('السبب: ${r['reason']}', style: GoogleFonts.tajawal(fontSize: 11, color: C.muted)),
        ],
        if (adminNote.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(6)),
            child: Text('ملاحظة الإدارة: $adminNote', style: GoogleFonts.tajawal(fontSize: 11, color: C.sub), textAlign: TextAlign.right),
          ),
        ],
      ]),
    );
  }
}
