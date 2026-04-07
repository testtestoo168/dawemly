import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

class EmpNotificationsPage extends StatefulWidget {
  final Map<String, dynamic> user;
  const EmpNotificationsPage({super.key, required this.user});
  @override
  State<EmpNotificationsPage> createState() => _EmpNotificationsPageState();
}

class _EmpNotificationsPageState extends State<EmpNotificationsPage> {
  List<Map<String, dynamic>> _notifs = [];
  bool _loading = true;

  TextStyle _tj(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);

  final _typeColor = const {
    'alert': C.red,
    'urgent': C.red,
    'warning': C.orange,
    'security': C.purple,
    'info': C.pri,
    'verify_request': C.orange,
    'verify': C.orange,
  };
  final _typeIcon = const {
    'alert': Icons.warning_amber,
    'urgent': Icons.notifications_active,
    'warning': Icons.warning_amber,
    'security': Icons.lock,
    'info': Icons.notifications,
    'verify_request': Icons.wifi_tethering,
    'verify': Icons.wifi_tethering,
  };
  final _typeLabel = const {
    'alert': 'تنبيه',
    'urgent': 'مستعجل',
    'warning': 'تحذير',
    'security': 'أمان',
    'info': 'معلومات',
    'verify_request': 'تحقق',
    'verify': 'تحقق',
  };

  @override
  void initState() {
    super.initState();
    _loadNotifs();
  }

  Future<void> _loadNotifs() async {
    setState(() => _loading = true);
    try {
      final uid = widget.user['uid'] ?? '';
      final res = await ApiService.get('admin.php?action=get_notifications');
      if (res['success'] == true) {
        final all = (res['notifications'] as List? ?? []).cast<Map<String, dynamic>>();
        final mine = all.where((n) => n['uid'] == uid).toList();
        mine.sort((a, b) {
          final aT = _parseTs(a['timestamp']);
          final bT = _parseTs(b['timestamp']);
          if (aT == null || bT == null) return 0;
          return bT.compareTo(aT);
        });
        if (mounted) setState(() { _notifs = mine; _loading = false; });
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
    if (dt == null) return '';
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'م' : 'ص'}';
  }

  String _fmtDate(dynamic ts) {
    final dt = _parseTs(ts);
    if (dt == null) return '';
    final months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  String _relativeTime(dynamic ts) {
    final dt = _parseTs(ts);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return _fmtDate(ts);
  }

  Future<void> _markRead(String id) async {
    await ApiService.post('admin.php?action=mark_read', {'id': id});
    await _loadNotifs();
  }

  Future<void> _markAllRead() async {
    final unreadIds = _notifs
        .where((n) => n['read'] == false || n['is_read'] == false)
        .map((n) => n['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    for (final id in unreadIds) {
      await ApiService.post('admin.php?action=mark_read', {'id': id});
    }
    await _loadNotifs();
  }

  bool _isRead(Map<String, dynamic> n) {
    return n['read'] == true || n['is_read'] == true;
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifs.where((n) => !_isRead(n)).length;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.white,
        surfaceTintColor: C.white,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('إشعاراتي', style: _tj(17, weight: FontWeight.w700, color: C.text)),
            if (unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: C.red, borderRadius: BorderRadius.circular(10)),
                child: Text('$unread', style: _tj(11, weight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: C.text),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text('قراءة الكل', style: _tj(12, weight: FontWeight.w600, color: C.pri)),
            ),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: C.border, height: 1)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifs,
        child: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: C.pri))
          : _notifs.isEmpty
            ? _emptyState()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _notifs.length,
                itemBuilder: (ctx, i) => _notifCard(_notifs[i]),
              ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: C.bg, shape: BoxShape.circle),
            child: const Icon(Icons.notifications_off_outlined, size: 40, color: C.hint),
          ),
          const SizedBox(height: 16),
          Text('لا توجد إشعارات', style: _tj(16, weight: FontWeight.w600, color: C.sub)),
          const SizedBox(height: 6),
          Text('ستظهر الإشعارات هنا عند وصولها', style: _tj(13, color: C.muted)),
        ],
      ),
    );
  }

  Widget _notifCard(Map<String, dynamic> n) {
    final type = (n['type'] ?? 'info').toString();
    final color = _typeColor[type] ?? C.pri;
    final icon = _typeIcon[type] ?? Icons.notifications;
    final label = _typeLabel[type] ?? 'معلومات';
    final read = _isRead(n);
    final id = (n['id'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        boxShadow: read ? DS.shadowSm : DS.shadowMd,
      ),
      child: Opacity(
        opacity: read ? 0.65 : 1.0,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (!read && id.isNotEmpty) _markRead(id);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mark read button
                if (!read && id.isNotEmpty) ...[
                  InkWell(
                    onTap: () => _markRead(id),
                    borderRadius: BorderRadius.circular(DS.radiusSm),
                    child: Container(
                      width: 24, height: 24,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(color: C.greenL, borderRadius: BorderRadius.circular(DS.radiusSm)),
                      child: const Icon(Icons.check, size: 12, color: C.green),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Type badge + unread dot
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!read) Container(
                            width: 7, height: 7,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(DS.radiusSm),
                            ),
                            child: Text(label, style: _tj(10, weight: FontWeight.w600, color: color)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Title
                      Text(
                        n['title'] ?? '',
                        style: _tj(14, weight: read ? FontWeight.w500 : FontWeight.w700, color: C.text),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 3),
                      // Body
                      Text(
                        n['body'] ?? '',
                        style: _tj(12, color: C.sub),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 8),
                      // Timestamp
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(_fmtTime(n['timestamp']), style: GoogleFonts.ibmPlexMono(fontSize: 10, color: C.muted)),
                          const SizedBox(width: 6),
                          Text(_relativeTime(n['timestamp']), style: _tj(10, color: C.hint)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Icon
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
