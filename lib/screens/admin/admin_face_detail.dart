import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/face_recognition_service.dart';
import '../../l10n/app_locale.dart';

class AdminFaceDetail extends StatefulWidget {
  final Map<String, dynamic> employee;
  const AdminFaceDetail({super.key, required this.employee});
  @override State<AdminFaceDetail> createState() => _AdminFaceDetailState();
}

class _AdminFaceDetailState extends State<AdminFaceDetail> {
  Map<String, dynamic>? _faceData;
  List<Map<String, dynamic>> _verifications = [];
  bool _loading = true;

  String get _uid => widget.employee['uid'] ?? widget.employee['_id'] ?? '';

  @override
  void initState() { super.initState(); _load(); }

  void _load() async {
    final faceData = await FaceRecognitionService.getFaceRegistrationInfo(_uid);
    final verifications = await FaceRecognitionService.getVerificationHistory(_uid, limit: 30);
    if (mounted) setState(() { _faceData = faceData; _verifications = verifications; _loading = false; });
  }

  void _resetFace() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd)),
        title: Text(L.tr('reset_face'), style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700), textAlign: TextAlign.right),
        content: Text(L.tr('reset_face_confirm'), style: GoogleFonts.tajawal(fontSize: 14, height: 1.6), textAlign: TextAlign.right),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L.tr('cancel'), style: GoogleFonts.tajawal(color: W.sub))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(L.tr('reset'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w700, color: W.red))),
        ],
      ),
    );
    if (confirm == true) {
      await FaceRecognitionService.resetFaceRegistration(_uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L.tr('face_reset_done'), style: GoogleFonts.tajawal()), backgroundColor: W.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd))));
        setState(() => _loading = true);
        _load();
      }
    }
  }

  DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is String) { try { return DateTime.parse(v); } catch (_) { return null; } }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.employee['name'] ?? '—';
    final empId = widget.employee['empId'] ?? '';
    final registered = _faceData?['registered'] == true;
    final photoUrl = _faceData?['photoUrl'] as String?;
    final registeredAtStr = _faceData?['registeredAt'];
    final registeredAt = _parseTs(registeredAtStr);

    return Scaffold(
      backgroundColor: W.bg,
      appBar: AppBar(
        backgroundColor: W.white, surfaceTintColor: W.white, elevation: 0, centerTitle: true,
        title: Text(L.tr('face_punch_name', args: {'name': name}), style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: W.text)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: W.text), onPressed: () => Navigator.pop(context)),
        bottom: PreferredSize(preferredSize: Size.fromHeight(1), child: Container(color: W.border, height: 1)),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
        : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(DS.radiusMd), border: Border.all(color: registered ? W.greenBd : W.border)),
              child: Column(children: [
                Row(children: [
                  if (registered) InkWell(
                    onTap: _resetFace,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: W.redL, borderRadius: BorderRadius.circular(4), border: Border.all(color: W.redBd)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.refresh, size: 14, color: W.red),
                        const SizedBox(width: 4),
                        Text(L.tr('reset'), style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.red)),
                      ]),
                    ),
                  ),
                  const Spacer(),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(name, style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: W.text)),
                    Text(empId, style: GoogleFonts.ibmPlexMono(fontSize: 12, color: W.muted)),
                  ]),
                  const SizedBox(width: 12),
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: registered ? W.green : W.border, width: 3)),
                    child: ClipOval(
                      child: registered && photoUrl != null
                        ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _facePlaceholder())
                        : _facePlaceholder(),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                Container(height: 1, color: W.div),
                const SizedBox(height: 14),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: registered ? W.greenL : W.orangeL, borderRadius: BorderRadius.circular(20)),
                    child: Text(registered ? L.tr('face_registered') : L.tr('face_not_registered'), style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: registered ? W.green : W.orange)),
                  ),
                  const Spacer(),
                  Text(L.tr('face_status_label'), style: GoogleFonts.tajawal(fontSize: 13, color: W.sub)),
                  const SizedBox(width: 6),
                  Icon(Icons.face, size: 18, color: registered ? W.green : W.orange),
                ]),
                if (registeredAt != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Text(_formatDate(registeredAt), style: GoogleFonts.ibmPlexMono(fontSize: 12, color: W.text)),
                    const Spacer(),
                    Text(L.tr('registration_date'), style: GoogleFonts.tajawal(fontSize: 13, color: W.sub)),
                    const SizedBox(width: 6),
                    Icon(Icons.calendar_today, size: 14, color: W.muted),
                  ]),
                ],
              ]),
            ),

            const SizedBox(height: 20),

            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: W.div, borderRadius: BorderRadius.circular(4)),
                child: Text(L.tr('n_record', args: {'n': _verifications.length.toString()}), style: GoogleFonts.tajawal(fontSize: 11, color: W.muted)),
              ),
              const Spacer(),
              Text(L.tr('face_verify_log'), style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: W.text)),
              const SizedBox(width: 8),
              Icon(Icons.history, size: 20, color: W.pri),
            ]),
            const SizedBox(height: 12),

            if (_verifications.isEmpty)
              Container(
                width: double.infinity, padding: const EdgeInsets.all(40),
                decoration: DS.cardDecoration(),
                child: Column(children: [
                  Icon(Icons.face_outlined, size: 40, color: W.hint),
                  const SizedBox(height: 8),
                  Text(L.tr('no_face_records'), style: GoogleFonts.tajawal(fontSize: 13, color: W.muted)),
                ]),
              )
            else
              ..._verifications.map((v) {
                final matched = v['matched'] == true;
                final similarity = (v['similarity'] as num?)?.toDouble() ?? 0;
                final vPhotoUrl = v['photoUrl'] as String?;
                final ts = _parseTs(v['timestamp']);
                final pct = (similarity * 100).toStringAsFixed(0);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: W.white,
                    borderRadius: BorderRadius.circular(DS.radiusMd),
                    border: Border.all(color: matched ? W.greenBd : W.redBd),
                  ),
                  child: Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: matched ? W.greenL : W.redL, borderRadius: BorderRadius.circular(20)),
                        child: Text(matched ? L.tr('match_ok') : L.tr('match_fail'), style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: matched ? W.green : W.red)),
                      ),
                      const SizedBox(height: 4),
                      Text(L.tr('match_pct', args: {'pct': pct.toString()}), style: GoogleFonts.ibmPlexMono(fontSize: 11, fontWeight: FontWeight.w700, color: matched ? W.green : W.red)),
                      if (ts != null) Text(_formatDateTime(ts), style: GoogleFonts.ibmPlexMono(fontSize: 10, color: W.muted)),
                    ]),
                    const Spacer(),
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(DS.radiusMd),
                        border: Border.all(color: matched ? W.greenBd : W.redBd, width: 2),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: vPhotoUrl != null
                        ? Image.network(vPhotoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _facePlaceholder())
                        : _facePlaceholder(),
                    ),
                  ]),
                );
              }),
          ])),
    );
  }

  Widget _facePlaceholder() => Container(color: W.bg, child: Icon(Icons.face_outlined, size: 24, color: W.hint));

  String _formatDate(DateTime d) {
    final months = L.months;
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _formatDateTime(DateTime d) {
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    return '${d.day}/${d.month} — ${h.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? L.tr('pm') : L.tr('am')}';
  }
}
