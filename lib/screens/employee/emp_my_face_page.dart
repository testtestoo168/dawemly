import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/face_recognition_service.dart';
import '../../l10n/app_locale.dart';

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
        title: Text(L.tr('my_face'), style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w700, color: C.text)),
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
          final photoUrl = data?['photoUrl'] as String? ?? data?['photo_url'] as String?;
          final registeredAtRaw = data?['registeredAt'] ?? data?['registered_at'];
          final registeredAt = _parseTs(registeredAtRaw);

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
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                  border: Border.all(color: C.border),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: registered ? C.greenL : C.orangeL, borderRadius: BorderRadius.circular(20)),
                      child: Text(registered ? L.tr('face_registered') : L.tr('face_not_registered'), style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: registered ? C.green : C.orange)),
                    ),
                    const Spacer(),
                    Text(L.tr('face_status'), style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: C.text)),
                    const SizedBox(width: 8),
                    Icon(Icons.face, size: 22, color: registered ? C.green : C.orange),
                  ]),
                  if (registered && registeredAt != null) ...[
                    const SizedBox(height: 12),
                    Container(height: 1, color: C.div),
                    const SizedBox(height: 12),
                    _infoRow(Icons.calendar_today, L.tr('registration_date'), _formatDate(registeredAt)),
                    const SizedBox(height: 8),
                    _infoRow(Icons.security, L.tr('status'), L.tr('active_enabled')),
                  ],
                  if (!registered) ...[
                    const SizedBox(height: 12),
                    Text(L.tr('face_will_register'), style: GoogleFonts.tajawal(fontSize: 13, color: C.sub, height: 1.6), textAlign: TextAlign.right),
                  ],
                ]),
              ),

              const SizedBox(height: 16),

              // Info notice
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: C.priLight, borderRadius: BorderRadius.circular(DS.radiusMd)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(
                    L.tr('face_info'),
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

  DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is String) { try { return DateTime.parse(v); } catch(_) { return null; } }
    return null;
  }

  String _formatDate(DateTime d) {
    final months = L.months;
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
