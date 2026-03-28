import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/face_recognition_service.dart';

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
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final faceData = await FaceRecognitionService.getFaceRegistrationInfo(_uid);
    final verifications = await FaceRecognitionService.getVerificationHistory(_uid, limit: 30);
    if (mounted) setState(() { _faceData = faceData; _verifications = verifications; _loading = false; });
  }

  void _resetFace() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('إعادة تعيين بصمة الوجه', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700), textAlign: TextAlign.right),
        content: Text('سيتم حذف بصمة الوجه المسجلة وسيُطلب من الموظف تسجيلها من جديد.\n\nهل أنت متأكد؟', style: GoogleFonts.tajawal(fontSize: 14, height: 1.6), textAlign: TextAlign.right),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('إلغاء', style: GoogleFonts.tajawal(color: C.sub))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('إعادة تعيين', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700, color: C.red))),
        ],
      ),
    );
    if (confirm == true) {
      await FaceRecognitionService.resetFaceRegistration(_uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إعادة تعيين بصمة الوجه', style: GoogleFonts.tajawal()), backgroundColor: C.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
        setState(() => _loading = true);
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.employee['name'] ?? '—';
    final empId = widget.employee['empId'] ?? '';
    final registered = _faceData?['registered'] == true;
    final photoUrl = _faceData?['photoUrl'] as String?;
    final registeredAt = _parseDateTime(_faceData?['registeredAt']);

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.white, surfaceTintColor: C.white, elevation: 0, centerTitle: true,
        title: Text('بصمة الوجه — $name', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: C.text), onPressed: () => Navigator.pop(context)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: C.border, height: 1)),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
        : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            // ─── Registration card ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: registered ? C.greenBd : C.border)),
              child: Column(children: [
                Row(children: [
                  // Reset button
                  if (registered) InkWell(
                    onTap: _resetFace,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: C.redL, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.redBd)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.refresh, size: 14, color: C.red),
                        const SizedBox(width: 4),
                        Text('إعادة تعيين', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: C.red)),
                      ]),
                    ),
                  ),
                  const Spacer(),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(name, style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
                    Text(empId, style: GoogleFonts.ibmPlexMono(fontSize: 12, color: C.muted)),
                  ]),
                  const SizedBox(width: 12),
                  // Face photo
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: registered ? C.green : C.border, width: 3),
                    ),
                    child: ClipOval(
                      child: registered && photoUrl != null
                        ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _facePlaceholder())
                        : _facePlaceholder(),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                Container(height: 1, color: C.div),
                const SizedBox(height: 14),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: registered ? C.greenL : C.orangeL, borderRadius: BorderRadius.circular(20)),
                    child: Text(registered ? 'مسجّلة' : 'غير مسجّلة', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: registered ? C.green : C.orange)),
                  ),
                  const Spacer(),
                  Text('حالة البصمة', style: GoogleFonts.tajawal(fontSize: 13, color: C.sub)),
                  const SizedBox(width: 6),
                  Icon(Icons.face, size: 18, color: registered ? C.green : C.orange),
                ]),
                if (registeredAt != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Text(_formatDate(registeredAt), style: GoogleFonts.ibmPlexMono(fontSize: 12, color: C.text)),
                    const Spacer(),
                    Text('تاريخ التسجيل', style: GoogleFonts.tajawal(fontSize: 13, color: C.sub)),
                    const SizedBox(width: 6),
                    const Icon(Icons.calendar_today, size: 14, color: C.muted),
                  ]),
                ],
              ]),
            ),

            const SizedBox(height: 20),

            // ─── Verification history ───
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: C.div, borderRadius: BorderRadius.circular(8)),
                child: Text('${_verifications.length} سجل', style: GoogleFonts.tajawal(fontSize: 11, color: C.muted)),
              ),
              const Spacer(),
              Text('سجل التحقق من الوجه', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
              const SizedBox(width: 8),
              const Icon(Icons.history, size: 20, color: C.pri),
            ]),
            const SizedBox(height: 12),

            if (_verifications.isEmpty)
              Container(
                width: double.infinity, padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
                child: Column(children: [
                  const Icon(Icons.face_outlined, size: 40, color: C.hint),
                  const SizedBox(height: 8),
                  Text('لا يوجد سجلات تحقق بعد', style: GoogleFonts.tajawal(fontSize: 13, color: C.muted)),
                ]),
              )
            else
              ..._verifications.map((v) {
                final matched = v['matched'] == true;
                final similarity = (v['similarity'] as num?)?.toDouble() ?? 0;
                final vPhotoUrl = v['photoUrl'] as String?;
                final ts = _parseDateTime(v['timestamp']);
                final pct = (similarity * 100).toStringAsFixed(0);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: C.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: matched ? C.greenBd : C.redBd),
                  ),
                  child: Row(children: [
                    // Status + similarity
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: matched ? C.greenL : C.redL, borderRadius: BorderRadius.circular(20)),
                        child: Text(matched ? 'مطابق ✓' : 'غير مطابق ✗', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: matched ? C.green : C.red)),
                      ),
                      const SizedBox(height: 4),
                      Text('التطابق: $pct%', style: GoogleFonts.ibmPlexMono(fontSize: 11, fontWeight: FontWeight.w700, color: matched ? C.green : C.red)),
                      if (ts != null) Text(_formatDateTime(ts), style: GoogleFonts.ibmPlexMono(fontSize: 10, color: C.muted)),
                    ]),
                    const Spacer(),
                    // Verification photo
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: matched ? C.greenBd : C.redBd, width: 2),
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

  Widget _facePlaceholder() => Container(color: C.bg, child: const Icon(Icons.face_outlined, size: 24, color: C.hint));

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatDate(DateTime d) {
    final months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _formatDateTime(DateTime d) {
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    return '${d.day}/${d.month} — ${h.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'م' : 'ص'}';
  }
}
