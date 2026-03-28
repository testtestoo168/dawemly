import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_colors.dart';

class AdminAudit extends StatefulWidget {
  const AdminAudit({super.key});
  @override
  State<AdminAudit> createState() => _AdminAuditState();
}

class _AdminAuditState extends State<AdminAudit> {
  final _db = FirebaseFirestore.instance;
  String _fType = 'الكل';
  int? _expandedIdx;

  final _typeMap = const {
    'create': {'l': 'إنشاء', 'c': 0xFF17B26A, 'bg': 0xFFECFDF3},
    'edit': {'l': 'تعديل', 'c': 0xFFF79009, 'bg': 0xFFFFFAEB},
    'approve': {'l': 'موافقة', 'c': 0xFF17B26A, 'bg': 0xFFECFDF3},
    'reject': {'l': 'رفض', 'c': 0xFFF04438, 'bg': 0xFFFEF3F2},
    'disable': {'l': 'تعطيل', 'c': 0xFFF04438, 'bg': 0xFFFEF3F2},
    'settings': {'l': 'إعدادات', 'c': 0xFF175CD3, 'bg': 0xFFE7EFFF},
    'verify': {'l': 'إثبات', 'c': 0xFF7F56D9, 'bg': 0xFFF4F3FF},
    'security': {'l': 'أمان', 'c': 0xFFF04438, 'bg': 0xFFFEF3F2},
    'login': {'l': 'دخول', 'c': 0xFF175CD3, 'bg': 0xFFE7EFFF},
    'delete': {'l': 'حذف', 'c': 0xFFF04438, 'bg': 0xFFFEF3F2},
  };

  String _fmtTime(Timestamp? ts) {
    if (ts == null) return '—';
    final dt = ts.toDate();
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'م' : 'ص'}';
  }

  String _fmtDate(Timestamp? ts) {
    if (ts == null) return '—';
    final dt = ts.toDate();
    final months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final types = ['الكل', 'create', 'edit', 'approve', 'reject', 'disable', 'settings', 'verify', 'security', 'login', 'delete'];

    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('audit_log').orderBy('timestamp', descending: true).limit(100).snapshots(),
      builder: (context, snap) {
        final allDocs = snap.data?.docs ?? [];
        final allLogs = allDocs.map((d) {
          final m = d.data() as Map<String, dynamic>;
          m['_id'] = d.id;
          return m;
        }).toList();

        final filtered = _fType == 'الكل' ? allLogs : allLogs.where((l) => l['type'] == _fType).toList();

        return SingleChildScrollView(padding: EdgeInsets.all(MediaQuery.of(context).size.width > 800 ? 28 : 14), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: C.div, borderRadius: BorderRadius.circular(8)), child: Text('${filtered.length} سجل', style: GoogleFonts.tajawal(fontSize: 12, color: C.muted))),
            Text('سجل التدقيق', style: GoogleFonts.tajawal(fontSize: 24, fontWeight: FontWeight.w800, color: C.text)),
          ]),
          const SizedBox(height: 18),
          Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end, children: types.map((t) {
            final on = _fType == t;
            final tm = _typeMap[t];
            return InkWell(onTap: () => setState(() => _fType = t), borderRadius: BorderRadius.circular(8), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), decoration: BoxDecoration(color: on ? C.pri : C.white, borderRadius: BorderRadius.circular(8), border: on ? null : Border.all(color: C.border)), child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (t != 'الكل') Container(width: 8, height: 8, margin: const EdgeInsets.only(left: 4), decoration: BoxDecoration(color: on ? Colors.white : Color(tm!['c'] as int), shape: BoxShape.circle)),
              Text(t == 'الكل' ? 'الكل (${allLogs.length})' : (tm?['l'] as String? ?? t), style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: on ? Colors.white : C.sub)),
            ])));
          }).toList()),
          const SizedBox(height: 18),

          if (snap.connectionState == ConnectionState.waiting && allLogs.isEmpty)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else if (filtered.isEmpty)
            Container(padding: const EdgeInsets.all(50), decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
              child: Center(child: Column(children: [
                const Icon(Icons.timeline, size: 48, color: C.hint),
                const SizedBox(height: 12),
                Text('لا توجد سجلات', style: GoogleFonts.tajawal(fontSize: 14, color: C.muted)),
                const SizedBox(height: 4),
                Text('ستظهر هنا تلقائياً عند إجراء أي عملية في النظام', style: GoogleFonts.tajawal(fontSize: 12, color: C.hint)),
              ])))
          else
            ...List.generate(filtered.length, (i) {
              final log = filtered[i];
              final typeKey = log['type'] ?? 'edit';
              final tm = _typeMap[typeKey] ?? {'l': '—', 'c': 0xFF9DA4AE, 'bg': 0xFFF0F2F5};
              final color = Color(tm['c'] as int);
              final bg = Color(tm['bg'] as int);
              final isExp = _expandedIdx == i;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isExp ? color.withOpacity(0.25) : C.border)),
                child: InkWell(
                  onTap: () => setState(() => _expandedIdx = isExp ? null : i),
                  borderRadius: BorderRadius.circular(14),
                  child: Column(children: [
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16), child: Row(children: [
                      Row(children: [
                        Icon(Icons.expand_more, size: 14, color: C.muted),
                        const SizedBox(width: 8),
                        Text(_fmtTime(log['timestamp']), style: GoogleFonts.ibmPlexMono(fontSize: 12, color: C.muted)),
                        const SizedBox(width: 6),
                        Text(_fmtDate(log['timestamp']), style: GoogleFonts.tajawal(fontSize: 11, color: C.hint)),
                      ]),
                      const Spacer(),
                      Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)), child: Text(tm['l'] as String, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: color))),
                          const SizedBox(width: 6),
                          Flexible(child: Text(log['action'] ?? '', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600, color: C.text), overflow: TextOverflow.ellipsis)),
                        ]),
                        const SizedBox(height: 2),
                        Text('بواسطة: ${log['user'] ?? '—'} — ${log['target'] ?? ''}', style: GoogleFonts.tajawal(fontSize: 12, color: C.sub), overflow: TextOverflow.ellipsis),
                      ])),
                      const SizedBox(width: 12),
                      Container(width: 36, height: 36, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.show_chart, size: 16, color: color)),
                    ])),
                    if (isExp) Container(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(10)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('التفاصيل', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: C.text)),
                          const SizedBox(height: 8),
                          Text(log['details'] ?? 'لا توجد تفاصيل', style: GoogleFonts.tajawal(fontSize: 13, color: C.sub, height: 1.7)),
                          const SizedBox(height: 10),
                          Wrap(spacing: 16, runSpacing: 8, alignment: WrapAlignment.end, children: [
                            _detailChip('التوقيت', '${_fmtTime(log['timestamp'])} — ${_fmtDate(log['timestamp'])}'),
                            if (log['ip'] != null && log['ip'] != '') _detailChip('IP', log['ip']),
                            if (log['device'] != null && log['device'] != '') _detailChip('الجهاز', log['device']),
                          ]),
                        ]),
                      ),
                    ),
                  ]),
                ),
              );
            }),
        ]));
      },
    );
  }

  Widget _detailChip(String label, String value) => Row(mainAxisSize: MainAxisSize.min, children: [
    Text(value, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: C.text)),
    const SizedBox(width: 4),
    Text('$label:', style: GoogleFonts.tajawal(fontSize: 11, color: C.muted)),
  ]);
}
