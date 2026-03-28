import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_colors.dart';
import '../../services/requests_service.dart';

class AdminRequests extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminRequests({super.key, required this.user});
  @override
  State<AdminRequests> createState() => _AdminRequestsState();
}

class _AdminRequestsState extends State<AdminRequests> with SingleTickerProviderStateMixin {
  final _svc = RequestsService();
  late TabController _tabCtrl;

  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  String _fmtDate(Timestamp? ts) {
    if (ts == null) return '—';
    final dt = ts.toDate();
    final months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  void _handleRequest(String docId, String action) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(action == 'تم الموافقة' ? 'موافقة على الطلب' : 'رفض الطلب', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700), textAlign: TextAlign.right),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('هل أنت متأكد؟', style: GoogleFonts.tajawal(), textAlign: TextAlign.right),
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            textAlign: TextAlign.right,
            maxLines: 2,
            style: GoogleFonts.tajawal(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'ملاحظة (اختياري)...',
              hintStyle: GoogleFonts.tajawal(color: C.hint),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('إلغاء', style: GoogleFonts.tajawal(color: C.sub))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('تأكيد', style: GoogleFonts.tajawal(color: action == 'تم الموافقة' ? C.green : C.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _svc.updateRequestStatus(docId, action, adminNote: noteCtrl.text.trim());
      
      // Write audit log
      await FirebaseFirestore.instance.collection('audit_log').add({
        'user': widget.user['name'] ?? 'مدير النظام',
        'action': action == 'تم الموافقة' ? 'موافقة على طلب' : 'رفض طلب',
        'target': 'طلب #${docId.substring(0, 6)}',
        'details': 'تم ${action == 'تم الموافقة' ? 'الموافقة على' : 'رفض'} الطلب${noteCtrl.text.trim().isNotEmpty ? ' — ملاحظة: ${noteCtrl.text.trim()}' : ''}',
        'timestamp': FieldValue.serverTimestamp(),
        'type': action == 'تم الموافقة' ? 'approve' : 'reject',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'تم الموافقة' ? 'تمت الموافقة على الطلب' : 'تم رفض الطلب', style: GoogleFonts.tajawal()),
          backgroundColor: action == 'تم الموافقة' ? C.green : C.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
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
          tabs: const [Tab(text: 'معلقة', height: 36), Tab(text: 'تمت الموافقة', height: 36), Tab(text: 'مرفوضة', height: 36)],
        ),
      ),

      Expanded(
        child: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildList('تحت الإجراء', showActions: true),
            _buildList('تم الموافقة'),
            _buildList('مرفوض'),
          ],
        ),
      ),
    ]);
  }

  Widget _buildList(String statusFilter, {bool showActions = false}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('requests').where('status', isEqualTo: statusFilter).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('خطأ في تحميل البيانات', style: GoogleFonts.tajawal(fontSize: 13, color: C.red)));
        }
        final docs = snap.data?.docs ?? [];
        if (snap.connectionState == ConnectionState.waiting && docs.isEmpty) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (docs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.description_outlined, size: 48, color: C.hint),
            const SizedBox(height: 12),
            Text('لا توجد طلبات', style: GoogleFonts.tajawal(fontSize: 14, color: C.muted)),
          ]));
        }
        // Sort locally instead of orderBy (avoids needing composite index)
        docs.sort((a, b) {
          final aT = (a.data() as Map)['createdAt'] as Timestamp?;
          final bT = (b.data() as Map)['createdAt'] as Timestamp?;
          if (aT == null || bT == null) return 0;
          return bT.compareTo(aT);
        });

        final isWide = MediaQuery.of(context).size.width > 800;

        return ListView.builder(
          padding: EdgeInsets.all(isWide ? 28 : 14),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final r = doc.data() as Map<String, dynamic>;
            return _requestCard(r, doc.id, showActions);
          },
        );
      },
    );
  }

  Widget _requestCard(Map<String, dynamic> r, String docId, bool showActions) {
    final isLeave = r['requestType'] == 'إجازة';
    final typeColor = isLeave ? const Color(0xFF2E90FA) : C.orange;
    final typeIcon = isLeave ? Icons.beach_access : Icons.access_time;

    String desc = '';
    if (isLeave) {
      desc = '${r['leaveType'] ?? ''} — ${r['days'] ?? 0} يوم\nمن ${_fmtDate(r['startDate'])} إلى ${_fmtDate(r['endDate'])}';
    } else {
      final hours = (r['hours'] as num?)?.toStringAsFixed(1);
      desc = '${r['permType'] ?? ''}${hours != null ? ' — $hours ساعة' : ''}\nمن ${r['fromTime'] ?? ''} إلى ${r['toTime'] ?? ''}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(children: [
          if (showActions) ...[
            InkWell(
              onTap: () => _handleRequest(docId, 'مرفوض'),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: const Color(0xFFFEF3F2), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFECDCA))),
                child: const Icon(Icons.close, size: 16, color: C.red),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () => _handleRequest(docId, 'تم الموافقة'),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: const Color(0xFFECFDF3), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFABEFC6))),
                child: const Icon(Icons.check, size: 16, color: C.green),
              ),
            ),
          ],
          if (!showActions) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: r['status'] == 'تم الموافقة' ? C.greenL : C.redL,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: r['status'] == 'تم الموافقة' ? C.greenBd : C.redBd),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(r['status'] ?? '', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: r['status'] == 'تم الموافقة' ? C.green : C.red)),
                const SizedBox(width: 4),
                Icon(r['status'] == 'تم الموافقة' ? Icons.check_circle : Icons.cancel, size: 14, color: r['status'] == 'تم الموافقة' ? C.green : C.red),
              ]),
            ),
          ],
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(r['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: C.text)),
            Text(r['empId'] ?? '', style: GoogleFonts.tajawal(fontSize: 11, color: C.muted)),
          ]),
          const SizedBox(width: 10),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(typeIcon, size: 20, color: typeColor),
          ),
        ]),
        const SizedBox(height: 10),
        Container(width: double.infinity, height: 1, color: C.div),
        const SizedBox(height: 10),
        Text('${r['requestType'] ?? ''}', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: C.text)),
        const SizedBox(height: 4),
        Text(desc, style: GoogleFonts.tajawal(fontSize: 12, color: C.sub, height: 1.5)),
        if ((r['reason'] ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(8)),
            child: Text('السبب: ${r['reason']}', style: GoogleFonts.tajawal(fontSize: 12, color: C.sub), textAlign: TextAlign.right),
          ),
        ],
      ]),
    );
  }
}
