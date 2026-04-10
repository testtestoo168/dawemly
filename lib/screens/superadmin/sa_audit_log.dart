import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';
import '../../l10n/app_locale.dart';

class SaAuditLog extends StatefulWidget {
  const SaAuditLog({super.key});
  @override
  State<SaAuditLog> createState() => _SaAuditLogState();
}

class _SaAuditLogState extends State<SaAuditLog> {
  bool _loading = true;
  List<Map<String, dynamic>> _logs = [];

  TextStyle _tj(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('superadmin.php?action=audit_log');
      if (res['success'] == true && mounted) {
        setState(() {
          _logs = (res['logs'] as List? ?? []).cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _actionIcon(String action) {
    if (action.contains('delete')) return Icons.delete_outline_rounded;
    if (action.contains('toggle')) return Icons.toggle_on_rounded;
    if (action.contains('assign')) return Icons.card_membership_rounded;
    if (action.contains('reset')) return Icons.lock_reset_rounded;
    return Icons.history_rounded;
  }

  Color _actionColor(String action) {
    if (action.contains('delete')) return const Color(0xFFF04438);
    if (action.contains('toggle')) return const Color(0xFFF79009);
    if (action.contains('assign')) return const Color(0xFF175CD3);
    if (action.contains('reset')) return const Color(0xFF7F56D9);
    return W.sub;
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(children: [
          Text(L.tr('sa_audit_count', args: {'n': _logs.length.toString()}), style: _tj(18, weight: FontWeight.w700, color: W.text)),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _loadLogs,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(L.tr('update'), style: _tj(12, weight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: W.pri,
              side: BorderSide(color: W.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusSm)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ]),
      ),
      if (_loading)
        const Expanded(child: Center(child: CircularProgressIndicator()))
      else if (_logs.isEmpty)
        Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.history_rounded, size: 48, color: W.muted.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text(L.tr('no_operations'), style: _tj(16, color: W.muted)),
        ])))
      else
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: _logs.length,
          itemBuilder: (ctx, i) {
            final log = _logs[i];
            final action = (log['action'] ?? '').toString();
            final color = _actionColor(action);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: DS.cardDecoration(radius: DS.radiusMd),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(DS.radiusSm),
                  ),
                  child: Icon(_actionIcon(action), size: 18, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(log['details'] ?? action, style: _tj(13, weight: FontWeight.w600, color: W.text)),
                  const SizedBox(height: 2),
                  Text(log['target'] ?? '', style: _tj(12, color: W.sub)),
                ])),
                Text(log['created_at'] ?? '', style: _tj(11, color: W.muted)),
              ]),
            );
          },
        )),
    ]);
  }
}
