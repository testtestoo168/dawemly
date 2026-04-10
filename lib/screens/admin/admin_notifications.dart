import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';
import '../../l10n/app_locale.dart';

class AdminNotifications extends StatefulWidget {
  const AdminNotifications({super.key});
  @override
  State<AdminNotifications> createState() => _AdminNotificationsState();
}

class _AdminNotificationsState extends State<AdminNotifications> {
  String _fType = L.tr('all');
  List<Map<String, dynamic>> _notifs = [];
  bool _loading = true;

  final _typeColor = const {'alert': Color(0xFFF04438), 'urgent': Color(0xFFF04438), 'warning': Color(0xFFF79009), 'security': Color(0xFF7F56D9), 'info': Color(0xFF175CD3)};
  final _typeIcon = const {'alert': Icons.warning_amber, 'urgent': Icons.notifications_active, 'warning': Icons.warning_amber, 'security': Icons.lock, 'info': Icons.notifications};
  final _typeLabel = {'alert': L.tr('alert'), 'urgent': L.tr('urgent'), 'warning': L.tr('warning'), 'security': L.tr('security_label'), 'info': L.tr('info')};

  @override
  void initState() {
    super.initState();
    _loadNotifs();
  }

  Future<void> _loadNotifs() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('admin.php?action=get_notifications');
      if (res['success'] == true) {
        final list = (res['notifications'] as List? ?? []).cast<Map<String, dynamic>>();
        if (mounted) setState(() { _notifs = list; _loading = false; });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is String) { try { return DateTime.parse(v); } catch (_) { return null; } }
    return null;
  }

  String _fmtTime(dynamic ts) {
    final dt = _parseTs(ts);
    if (dt == null) return '—';
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? L.tr('pm') : L.tr('am')}';
  }

  String _fmtDate(dynamic ts) {
    final dt = _parseTs(ts);
    if (dt == null) return '—';
    final months = L.months;
    return '${dt.day} ${months[dt.month - 1]}';
  }

  void _markAllRead() async {
    final unreadIds = _notifs.where((n) => n['read'] == false).map((n) => n['id']?.toString() ?? '').where((id) => id.isNotEmpty).toList();
    for (final id in unreadIds) {
      await ApiService.post('admin.php?action=mark_read', {'id': id});
    }
    await _loadNotifs();
  }

  void _markRead(String id) async {
    await ApiService.post('admin.php?action=mark_read', {'id': id});
    await _loadNotifs();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isSmall = screenW < 400;
    final allNotifs = _notifs;
    final unread = allNotifs.where((n) => n['read'] == false).length;
    final filtered = _fType == L.tr('all') ? allNotifs : allNotifs.where((n) => n['type'] == _fType).toList();

    return RefreshIndicator(
      onRefresh: _loadNotifs,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(screenW > 800 ? 28 : 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // Header - stack vertically on small screens
          isSmall
            ? Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(L.tr('mob_notifications'), style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w800, color: W.text)),
                  if (unread > 0) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: W.red, borderRadius: BorderRadius.circular(DS.radiusMd)), child: Text('$unread', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)))],
                ]),
                const SizedBox(height: 6),
                InkWell(onTap: _markAllRead, child: Text(L.tr('mark_all_read'), style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub))),
              ])
            : Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                TextButton(onPressed: _markAllRead, child: Text(L.tr('mark_all_read'), style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: W.sub))),
                Row(children: [
                  Text(L.tr('mob_notifications'), style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w800, color: W.text)),
                  if (unread > 0) ...[const SizedBox(width: 10), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: W.red, borderRadius: BorderRadius.circular(DS.radiusMd)), child: Text(L.tr('n_unread', args: {'n': unread.toString()}), style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)))],
                ]),
              ]),
          const SizedBox(height: 14),
          // Type filters
          Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end, children: [
            _filterChip(L.tr('all'), _fType == L.tr('all'), () => setState(() => _fType = L.tr('all'))),
            ...['alert', 'urgent', 'warning', 'security', 'info'].map((t) => _filterChip('${_typeLabel[t]} (${allNotifs.where((n) => n['type'] == t).length})', _fType == t, () => setState(() => _fType = t), color: _typeColor[t], icon: _typeIcon[t])),
          ]),
          const SizedBox(height: 14),

          if (_loading)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else if (filtered.isEmpty)
            Container(padding: const EdgeInsets.all(40), decoration: DS.cardDecoration(),
              child: Center(child: Column(children: [
                Icon(Icons.notifications_off, size: 36, color: W.hint),
                const SizedBox(height: 12),
                Text(L.tr('no_notifications'), style: GoogleFonts.tajawal(fontSize: 14, color: W.muted)),
              ])))
          else
            ...filtered.map((n) {
              final color = _typeColor[n['type']] ?? W.muted;
              final isRead = n['read'] == true;
              final id = (n['id'] ?? '').toString();
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(DS.radiusMd), border: Border.all(color: isRead ? W.border : color.withOpacity(0.25))),
                child: Opacity(opacity: isRead ? 0.65 : 1, child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 22, vertical: isSmall ? 10 : 16),
                  child: isSmall
                    // Mobile layout: stack vertically
                    ? Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Row(children: [
                          if (!isRead && id.isNotEmpty) InkWell(onTap: () => _markRead(id), child: Container(width: 22, height: 22, decoration: BoxDecoration(color: const Color(0xFFECFDF3), borderRadius: BorderRadius.circular(DS.radiusMd)), child: Icon(Icons.check, size: 10, color: W.green))),
                          const Spacer(),
                          if (!isRead) Container(width: 7, height: 7, margin: const EdgeInsets.only(left: 6), decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          _badge(_typeLabel[n['type']] ?? L.tr('info'), color, color.withOpacity(0.08)),
                          const SizedBox(width: 6),
                          Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: Icon(_typeIcon[n['type']] ?? Icons.info, size: 16, color: color)),
                        ]),
                        const SizedBox(height: 6),
                        Text(n['title'] ?? '', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: isRead ? FontWeight.w500 : FontWeight.w700, color: W.text), textAlign: TextAlign.right),
                        const SizedBox(height: 2),
                        Text(n['body'] ?? '', style: GoogleFonts.tajawal(fontSize: 12, color: W.sub), textAlign: TextAlign.right),
                        const SizedBox(height: 4),
                        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                          Text(_fmtTime(n['timestamp']), style: GoogleFonts.ibmPlexMono(fontSize: 10, color: W.muted)),
                          const SizedBox(width: 6),
                          Text(_fmtDate(n['timestamp']), style: GoogleFonts.tajawal(fontSize: 10, color: W.hint)),
                        ]),
                      ])
                    // Wide layout: horizontal row
                    : Row(children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          if (!isRead && id.isNotEmpty) ...[const SizedBox(width: 4), InkWell(onTap: () => _markRead(id), child: Container(width: 24, height: 24, decoration: BoxDecoration(color: const Color(0xFFECFDF3), borderRadius: BorderRadius.circular(DS.radiusMd)), child: Icon(Icons.check, size: 10, color: W.green)))],
                          const SizedBox(width: 8),
                          Text(_fmtTime(n['timestamp']), style: GoogleFonts.ibmPlexMono(fontSize: 11, color: W.muted)),
                          const SizedBox(width: 6),
                          Text(_fmtDate(n['timestamp']), style: GoogleFonts.tajawal(fontSize: 10, color: W.hint)),
                        ]),
                        const Spacer(),
                        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                            if (!isRead) Container(width: 8, height: 8, margin: const EdgeInsets.only(left: 6), decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                            _badge(_typeLabel[n['type']] ?? L.tr('info'), color, color.withOpacity(0.08)),
                            const SizedBox(width: 6),
                            Flexible(child: Text(n['title'] ?? '', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: isRead ? FontWeight.w500 : FontWeight.w700, color: W.text))),
                          ]),
                          const SizedBox(height: 2),
                          Text(n['body'] ?? '', style: GoogleFonts.tajawal(fontSize: 12, color: W.sub), textAlign: TextAlign.right),
                        ])),
                        const SizedBox(width: 14),
                        Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: Icon(_typeIcon[n['type']] ?? Icons.info, size: 18, color: color)),
                      ]),
                )),
              );
            }),
        ]),
      ),
    );
  }

  Widget _filterChip(String label, bool on, VoidCallback onTap, {Color? color, IconData? icon}) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(4), child: Container(padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7), decoration: BoxDecoration(color: on ? W.pri : W.white, borderRadius: BorderRadius.circular(4), border: on ? null : Border.all(color: W.border)), child: Row(mainAxisSize: MainAxisSize.min, children: [if (icon != null) ...[Icon(icon, size: 12, color: on ? Colors.white : color), SizedBox(width: 4)], Text(label, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: on ? Colors.white : W.sub))])));
  Widget _badge(String text, Color color, Color bg) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)), child: Text(text, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: color)));
}
