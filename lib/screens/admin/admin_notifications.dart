import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

class AdminNotifications extends StatefulWidget {
  const AdminNotifications({super.key});
  @override
  State<AdminNotifications> createState() => _AdminNotificationsState();
}

class _AdminNotificationsState extends State<AdminNotifications> {
  String _fType = 'الكل';
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  final _typeColor = const {'alert': Color(0xFFF04438), 'urgent': Color(0xFFF04438), 'warning': Color(0xFFF79009), 'security': Color(0xFF7F56D9), 'info': Color(0xFF175CD3)};
  final _typeIcon = const {'alert': Icons.warning_amber, 'urgent': Icons.notifications_active, 'warning': Icons.warning_amber, 'security': Icons.lock, 'info': Icons.notifications};
  final _typeLabel = const {'alert': 'تنبيه', 'urgent': 'مستعجل', 'warning': 'تحذير', 'security': 'أمان', 'info': 'معلومات'};

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final res = await ApiService.get('admin.php?action=get_notifications');
      final list = res['data'];
      if (list is List) {
        setState(() {
          _notifications = list.cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String _fmtTime(dynamic ts) {
    if (ts == null) return '—';
    DateTime? dt;
    if (ts is DateTime) dt = ts;
    else if (ts is String) dt = DateTime.tryParse(ts);
    if (dt == null) return '—';
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'م' : 'ص'}';
  }

  String _fmtDate(dynamic ts) {
    if (ts == null) return '—';
    DateTime? dt;
    if (ts is DateTime) dt = ts;
    else if (ts is String) dt = DateTime.tryParse(ts);
    if (dt == null) return '—';
    final months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  void _markAllRead() async {
    try {
      await ApiService.post('admin.php?action=mark_read');
      setState(() {
        for (final n in _notifications) {
          n['read'] = true;
        }
      });
    } catch (_) {}
  }

  void _markRead(String docId) async {
    try {
      await ApiService.post('admin.php?action=mark_read', body: {'id': docId});
      setState(() {
        final idx = _notifications.indexWhere((n) => n['id'].toString() == docId);
        if (idx != -1) _notifications[idx]['read'] = true;
      });
    } catch (_) {}
  }

  void _deleteNotif(String docId) {
    setState(() {
      _notifications.removeWhere((n) => n['id'].toString() == docId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final allNotifs = _notifications;
    final unread = allNotifs.where((n) => n['read'] == false).length;
    final filtered = _fType == 'الكل' ? allNotifs : allNotifs.where((n) => n['type'] == _fType).toList();

    return SingleChildScrollView(padding: EdgeInsets.all(MediaQuery.of(context).size.width > 800 ? 28 : 14), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        TextButton(onPressed: _markAllRead, child: Text('✓ تحديد الكل كمقروء', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: C.sub))),
        Row(children: [
          Text('الإشعارات', style: GoogleFonts.tajawal(fontSize: 24, fontWeight: FontWeight.w800, color: C.text)),
          if (unread > 0) ...[const SizedBox(width: 10), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: C.red, borderRadius: BorderRadius.circular(10)), child: Text('$unread غير مقروء', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)))],
        ]),
      ]),
      const SizedBox(height: 18),
      // Type filters
      Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end, children: [
        _filterChip('الكل', _fType == 'الكل', () => setState(() => _fType = 'الكل')),
        ...['alert', 'urgent', 'warning', 'security', 'info'].map((t) => _filterChip('${_typeLabel[t]} (${allNotifs.where((n) => n['type'] == t).length})', _fType == t, () => setState(() => _fType = t), color: _typeColor[t], icon: _typeIcon[t])),
      ]),
      const SizedBox(height: 18),

      if (_loading && allNotifs.isEmpty)
        const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
      else if (filtered.isEmpty)
        Container(padding: const EdgeInsets.all(50), decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
          child: Center(child: Column(children: [
            const Icon(Icons.notifications_off, size: 40, color: C.hint),
            const SizedBox(height: 12),
            Text('لا توجد إشعارات', style: GoogleFonts.tajawal(fontSize: 14, color: C.muted)),
          ])))
      else
        ...filtered.map((n) {
          final color = _typeColor[n['type']] ?? C.muted;
          final isRead = n['read'] == true;
          final docId = n['id'].toString();
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isRead ? C.border : color.withOpacity(0.25))),
            child: Opacity(opacity: isRead ? 0.65 : 1, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16), child: Row(children: [
              Row(children: [
                InkWell(onTap: () => _deleteNotif(docId), child: Container(width: 24, height: 24, decoration: BoxDecoration(color: C.div, borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.close, size: 10, color: C.muted))),
                if (!isRead) ...[const SizedBox(width: 4), InkWell(onTap: () => _markRead(docId), child: Container(width: 24, height: 24, decoration: BoxDecoration(color: const Color(0xFFECFDF3), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.check, size: 10, color: C.green)))],
                const SizedBox(width: 8),
                Text(_fmtTime(n['timestamp']), style: GoogleFonts.ibmPlexMono(fontSize: 11, color: C.muted)),
                const SizedBox(width: 6),
                Text(_fmtDate(n['timestamp']), style: GoogleFonts.tajawal(fontSize: 10, color: C.hint)),
              ]),
              const Spacer(),
              Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (!isRead) Container(width: 8, height: 8, margin: const EdgeInsets.only(left: 6), decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  _badge(_typeLabel[n['type']] ?? 'معلومات', color, color.withOpacity(0.08)),
                  const SizedBox(width: 6),
                  Flexible(child: Text(n['title'] ?? '', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: isRead ? FontWeight.w500 : FontWeight.w700, color: C.text), overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 2),
                Text(n['body'] ?? '', style: GoogleFonts.tajawal(fontSize: 12, color: C.sub), textAlign: TextAlign.right),
              ])),
              const SizedBox(width: 14),
              Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: Icon(_typeIcon[n['type']] ?? Icons.info, size: 18, color: color)),
            ]))),
          );
        }),
    ]));
  }

  Widget _filterChip(String label, bool on, VoidCallback onTap, {Color? color, IconData? icon}) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), decoration: BoxDecoration(color: on ? C.pri : C.white, borderRadius: BorderRadius.circular(8), border: on ? null : Border.all(color: C.border)), child: Row(mainAxisSize: MainAxisSize.min, children: [if (icon != null) ...[Icon(icon, size: 12, color: on ? Colors.white : color), const SizedBox(width: 4)], Text(label, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: on ? Colors.white : C.sub))])));
  Widget _badge(String text, Color color, Color bg) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)), child: Text(text, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: color)));
}
