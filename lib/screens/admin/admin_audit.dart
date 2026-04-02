import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

class AdminAudit extends StatefulWidget {
  const AdminAudit({super.key});
  @override
  State<AdminAudit> createState() => _AdminAuditState();
}

class _AdminAuditState extends State<AdminAudit> {
  String _fType = 'الكل';
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  static const _typeMap = {
    'create':   {'l': 'إنشاء',    'c': 0xFF16A34A, 'bg': 0xFFDCFCE7},
    'edit':     {'l': 'تعديل',    'c': 0xFFF59E0B, 'bg': 0xFFFEF9C3},
    'approve':  {'l': 'موافقة',   'c': 0xFF16A34A, 'bg': 0xFFDCFCE7},
    'reject':   {'l': 'رفض',      'c': 0xFFD4183D, 'bg': 0xFFFEE2E2},
    'disable':  {'l': 'تعطيل',    'c': 0xFFD4183D, 'bg': 0xFFFEE2E2},
    'settings': {'l': 'إعدادات',  'c': 0xFF0F3460, 'bg': 0xFFE8EDF2},
    'verify':   {'l': 'إثبات',    'c': 0xFF3B82F6, 'bg': 0xFFDBEAFE},
    'security': {'l': 'أمان',     'c': 0xFFD4183D, 'bg': 0xFFFEE2E2},
    'login':    {'l': 'دخول',     'c': 0xFF0F3460, 'bg': 0xFFE8EDF2},
    'delete':   {'l': 'حذف',      'c': 0xFFD4183D, 'bg': 0xFFFEE2E2},
  };

  static const _typeIcons = {
    'create':   Icons.add_circle_outline,
    'edit':     Icons.edit_outlined,
    'approve':  Icons.check_circle_outline,
    'reject':   Icons.cancel_outlined,
    'disable':  Icons.block_outlined,
    'settings': Icons.settings_outlined,
    'verify':   Icons.verified_outlined,
    'security': Icons.security_outlined,
    'login':    Icons.login_outlined,
    'delete':   Icons.delete_outline,
  };

  @override
  void initState() { super.initState(); _loadLogs(); }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('admin.php?action=get_audit_log');
      if (mounted) setState(() {
        _logs = res['success'] == true ? (res['logs'] as List? ?? []).cast<Map<String, dynamic>>() : [];
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  String _fmtTs(dynamic v) {
    if (v == null) return '—';
    try {
      final dt = DateTime.parse(v.toString());
      final months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final time = '${h.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')} ${dt.hour >= 12 ? 'م' : 'ص'}';
      return '${dt.day} ${months[dt.month-1]} — $time';
    } catch (_) { return '—'; }
  }

  TextStyle _tj(double s, {FontWeight w = FontWeight.w400, Color? color}) =>
      GoogleFonts.tajawal(fontSize: s, fontWeight: w, color: color ?? W.text);

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    final filtered = _fType == 'الكل' ? _logs : _logs.where((l) => l['type'] == _fType).toList();

    return RefreshIndicator(
      onRefresh: _loadLogs,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isWide ? 28 : 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [

          // ── Header ──
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: W.div, borderRadius: BorderRadius.circular(4), border: Border.all(color: W.border)),
              child: Text('${filtered.length} سجل', style: _tj(12, color: W.muted)),
            ),
            const Spacer(),
            Text('سجل التدقيق', style: _tj(22, w: FontWeight.w800)),
          ]),
          const SizedBox(height: 20),

          // ── Filter tabs ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
            child: Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end, children: [
              _filterTab('الكل', null, _logs.length),
              ..._typeMap.entries.map((e) {
                final count = _logs.where((l) => l['type'] == e.key).length;
                return _filterTab(e.key, e.value, count);
              }),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Table ──
          if (_loading)
            Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: W.pri)))
          else if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(50),
              decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
              child: Center(child: Column(children: [
                Icon(Icons.history_rounded, size: 48, color: W.hint),
                const SizedBox(height: 12),
                Text('لا توجد سجلات', style: _tj(14, color: W.muted)),
                const SizedBox(height: 4),
                Text('ستظهر هنا تلقائياً عند إجراء أي عملية', style: _tj(12, color: W.hint)),
              ])),
            )
          else
            Container(
              decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
              child: Column(children: [
                // Table header
                if (isWide) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: W.div,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    border: Border(bottom: BorderSide(color: W.border)),
                  ),
                  child: Row(children: [
                    Expanded(flex: 2, child: Text('التوقيت', style: _tj(11, w: FontWeight.w700, color: W.sub))),
                    Expanded(flex: 2, child: Text('النوع', style: _tj(11, w: FontWeight.w700, color: W.sub), textAlign: TextAlign.center)),
                    Expanded(flex: 3, child: Text('العملية', style: _tj(11, w: FontWeight.w700, color: W.sub), textAlign: TextAlign.right)),
                    Expanded(flex: 3, child: Text('بواسطة / الهدف', style: _tj(11, w: FontWeight.w700, color: W.sub), textAlign: TextAlign.right)),
                    if (isWide) Expanded(flex: 2, child: Text('IP', style: _tj(11, w: FontWeight.w700, color: W.sub), textAlign: TextAlign.center)),
                  ]),
                ),
                // Rows
                ...filtered.asMap().entries.map((entry) {
                  final i = entry.key;
                  final log = entry.value;
                  final typeKey = (log['type'] ?? 'edit').toString();
                  final tm = _typeMap[typeKey] ?? {'l': '—', 'c': 0xFF94A3B8, 'bg': 0xFFE8EDF2};
                  final color = Color(tm['c'] as int);
                  final bg = Color(tm['bg'] as int);
                  final icon = _typeIcons[typeKey] ?? Icons.circle_outlined;
                  final isLast = i == filtered.length - 1;

                  return Container(
                    decoration: BoxDecoration(
                      border: Border(top: i == 0 && !isWide ? BorderSide.none : BorderSide(color: W.div)),
                      borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(6)) : BorderRadius.zero,
                    ),
                    child: isWide
                      ? _wideRow(log, color, bg, icon, tm, isLast)
                      : _mobileRow(log, color, bg, icon, tm),
                  );
                }),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _wideRow(Map log, Color color, Color bg, IconData icon, Map tm, bool isLast) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: [
        // Timestamp
        Expanded(flex: 2, child: Text(_fmtTs(log['timestamp']),
          style: GoogleFonts.ibmPlexMono(fontSize: 11, color: W.muted))),
        // Type badge
        Expanded(flex: 2, child: Center(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
            Text(tm['l'] as String, style: _tj(11, w: FontWeight.w600, color: color)),
          ]),
        ))),
        // Action
        Expanded(flex: 3, child: Text(log['action'] ?? '—',
          style: _tj(13, w: FontWeight.w600), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
        // User / target
        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(log['user'] ?? '—', style: _tj(12, w: FontWeight.w600), overflow: TextOverflow.ellipsis),
          if ((log['target'] ?? '').toString().isNotEmpty)
            Text(log['target'].toString(), style: _tj(11, color: W.muted), overflow: TextOverflow.ellipsis),
        ])),
        // IP
        Expanded(flex: 2, child: Center(child: Text(log['ip'] ?? '—',
          style: GoogleFonts.ibmPlexMono(fontSize: 10, color: W.hint)))),
      ]),
    );
  }

  Widget _mobileRow(Map log, Color color, Color bg, IconData icon, Map tm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_fmtTs(log['timestamp']), style: GoogleFonts.ibmPlexMono(fontSize: 10, color: W.muted)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
            child: Text(tm['l'] as String, style: _tj(10, w: FontWeight.w600, color: color)),
          ),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(log['action'] ?? '—', style: _tj(13, w: FontWeight.w600), overflow: TextOverflow.ellipsis),
          Text('${log['user'] ?? '—'} — ${log['target'] ?? ''}',
            style: _tj(11, color: W.sub), overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }

  Widget _filterTab(String key, Map? tm, int count) {
    final on = _fType == key;
    final color = tm != null ? Color(tm['c'] as int) : W.pri;
    final bg = tm != null ? Color(tm['bg'] as int) : W.priLight;
    final label = tm != null ? tm['l'] as String : 'الكل';
    return GestureDetector(
      onTap: () => setState(() => _fType = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: on ? (tm != null ? bg : W.pri) : W.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: on ? color.withOpacity(0.4) : W.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$count', style: _tj(10, w: FontWeight.w700, color: on ? color : W.muted)),
          const SizedBox(width: 5),
          Text(label, style: _tj(12, w: on ? FontWeight.w700 : FontWeight.w400,
            color: on ? (tm != null ? color : Colors.white) : W.sub)),
        ]),
      ),
    );
  }
}
