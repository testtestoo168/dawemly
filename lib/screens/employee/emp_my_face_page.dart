import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_colors.dart';
import '../../services/face_recognition_service.dart';

class EmpMyFacePage extends StatelessWidget {
  final Map<String, dynamic> user;
  const EmpMyFacePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final uid = user['uid'] ?? '';
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.white,
        surfaceTintColor: C.white,
        elevation: 0,
        centerTitle: true,
        title: Text('بصمتي', style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w700, color: C.text)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: C.text), onPressed: () => Navigator.pop(context)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: C.border, height: 1)),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: FaceRecognitionService.getFaceRegistrationInfo(uid),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          final data = snap.data;
          final registered = data?['registered'] == true;
          final photoUrl = data?['photoUrl'] as String?;
          final registeredAt = data?['registeredAt'] as Timestamp?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              const SizedBox(height: 20),
              // Face photo
              Container(
                width: 180, height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: registered ? C.green : C.border, width: 4),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 6))],
                ),
                child: ClipOval(
                  child: registered && photoUrl != null
                    ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
                ),
              ),
              const SizedBox(height: 20),
              Text(user['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 20, fontWeight: FontWeight.w700, color: C.text)),
              const SizedBox(height: 4),
              Text(user['empId'] ?? '', style: GoogleFonts.ibmPlexMono(fontSize: 13, color: C.muted)),

              const SizedBox(height: 24),

              // Status card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: C.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: registered ? C.greenBd : C.border),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: registered ? C.greenL : C.orangeL, borderRadius: BorderRadius.circular(20)),
                      child: Text(registered ? 'مسجّلة' : 'غير مسجّلة', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: registered ? C.green : C.orange)),
                    ),
                    const Spacer(),
                    Text('حالة بصمة الوجه', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: C.text)),
                    const SizedBox(width: 8),
                    Icon(Icons.face, size: 22, color: registered ? C.green : C.orange),
                  ]),
                  if (registered && registeredAt != null) ...[
                    const SizedBox(height: 12),
                    Container(height: 1, color: C.div),
                    const SizedBox(height: 12),
                    _infoRow(Icons.calendar_today, 'تاريخ التسجيل', _formatDate(registeredAt)),
                    const SizedBox(height: 8),
                    _infoRow(Icons.security, 'الحالة', 'نشطة ومفعّلة'),
                  ],
                  if (!registered) ...[
                    const SizedBox(height: 12),
                    Text('لم يتم تسجيل بصمة الوجه بعد. سيُطلب منك التسجيل عند أول بصمة حضور.', style: GoogleFonts.tajawal(fontSize: 13, color: C.sub, height: 1.6), textAlign: TextAlign.right),
                  ],
                ]),
              ),

              const SizedBox(height: 16),

              // Info notice
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: C.priLight, borderRadius: BorderRadius.circular(12)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(
                    'بصمة الوجه تُستخدم للتحقق من هويتك عند تسجيل الحضور والانصراف. لا يمكنك تعديل أو حذف البصمة — تواصل مع المدير لإعادة التسجيل.',
                    style: GoogleFonts.tajawal(fontSize: 12, color: C.pri, height: 1.6),
                    textAlign: TextAlign.right,
                  )),
                  const SizedBox(width: 10),
                  const Icon(Icons.info_outline, size: 18, color: C.pri),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _placeholder() => Container(color: C.bg, child: const Icon(Icons.face_outlined, size: 60, color: C.hint));

  Widget _infoRow(IconData icon, String label, String value) => Row(children: [
    Text(value, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: C.text)),
    const Spacer(),
    Text(label, style: GoogleFonts.tajawal(fontSize: 13, color: C.sub)),
    const SizedBox(width: 6),
    Icon(icon, size: 16, color: C.muted),
  ]);

  String _formatDate(Timestamp ts) {
    final d = ts.toDate();
    final months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
