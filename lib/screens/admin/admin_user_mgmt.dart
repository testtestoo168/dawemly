import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/face_recognition_service.dart';
import 'admin_face_detail.dart';

class AdminUserMgmt extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminUserMgmt({super.key, required this.user});
  @override
  State<AdminUserMgmt> createState() => _AdminUserMgmtState();
}

class _AdminUserMgmtState extends State<AdminUserMgmt> {
  final _db = FirebaseFirestore.instance;
  final _auth = AuthService();
  String _search = '';
  String _fRole = 'الكل';
  String _fActive = 'الكل';

  final _depts = ['تكنولوجيا المعلومات', 'الموارد البشرية', 'المالية', 'التسويق', 'خدمة العملاء'];

  void _showAddEditDialog({Map<String, dynamic>? existing, String? docId}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final emailCtrl = TextEditingController(text: existing?['email'] ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone'] ?? '');
    final passCtrl = TextEditingController();
    final roleCtrl = TextEditingController(text: existing?['jobTitle'] ?? '');
    String dept = existing?['dept'] ?? 'تكنولوجيا المعلومات';
    if (!_depts.contains(dept)) dept = _depts.first;
    String userRole = existing?['role'] ?? 'employee';
    if (!['employee', 'moderator', 'admin'].contains(userRole)) userRole = 'employee';
    int shift = (existing?['shift'] is int) ? existing!['shift'] : int.tryParse('${existing?['shift']}') ?? 1;
    if (![1, 2, 3].contains(shift)) shift = 1;
    bool loading = false;
    // Custom work schedule
    String workStart = existing?['workStart'] ?? '08:00 ص';
    String workEnd = existing?['workEnd'] ?? '04:00 م';
    bool customSchedule = existing?['customSchedule'] ?? false;
    String scheduleType = existing?['scheduleType'] ?? 'دائم'; // دائم أو مؤقت
    String scheduleUntil = existing?['scheduleUntil'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDState) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Container(
            width: 520,
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [C.priDark, C.pri]),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  InkWell(onTap: () => Navigator.pop(ctx), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.close, size: 16, color: Colors.white))),
                  Text(existing == null ? 'إضافة مستخدم جديد' : 'تعديل بيانات المستخدم', style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                ]),
              ),
              // Form
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    _formField('الاسم الكامل *', nameCtrl),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _formField('رقم الهاتف', phoneCtrl, hint: '05xxxxxxxx', isLtr: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _formField('البريد الإلكتروني *', emailCtrl, hint: 'user@dawemli.sa', isLtr: true)),
                    ]),
                    if (existing == null) ...[
                      const SizedBox(height: 12),
                      _formField('كلمة المرور *', passCtrl, hint: '••••••••', isPass: true),
                    ],
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('القسم', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.sub)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: dept,
                          items: _depts.map((d) => DropdownMenuItem(value: d, child: Text(d, style: GoogleFonts.tajawal(fontSize: 13)))).toList(),
                          onChanged: (v) => setDState(() => dept = v!),
                          decoration: _dropDecor(),
                        ),
                      ])),
                      const SizedBox(width: 12),
                      Expanded(child: _formField('المسمى الوظيفي', roleCtrl)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('الفترة', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.sub)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<int>(
                          value: shift,
                          items: [1, 2, 3].map((s) => DropdownMenuItem(value: s, child: Text('فترة $s', style: GoogleFonts.tajawal(fontSize: 13)))).toList(),
                          onChanged: (v) => setDState(() => shift = v!),
                          decoration: _dropDecor(),
                        ),
                      ])),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('الصلاحية', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.sub)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: userRole,
                          items: [
                            DropdownMenuItem(value: 'employee', child: Text('موظف', style: GoogleFonts.tajawal(fontSize: 13))),
                            DropdownMenuItem(value: 'moderator', child: Text('مشرف', style: GoogleFonts.tajawal(fontSize: 13))),
                            DropdownMenuItem(value: 'admin', child: Text('مدير النظام', style: GoogleFonts.tajawal(fontSize: 13))),
                          ],
                          onChanged: (v) => setDState(() => userRole = v!),
                          decoration: _dropDecor(),
                        ),
                      ])),
                    ]),
                    const SizedBox(height: 16),
                    // ─── Custom Work Schedule ───
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Row(children: [
                          Switch(value: customSchedule, activeColor: C.green, onChanged: (v) => setDState(() => customSchedule = v)),
                          const Spacer(),
                          Text('دوام مخصص لهذا الموظف', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: C.text)),
                          const SizedBox(width: 6),
                          const Icon(Icons.schedule, size: 16, color: C.orange),
                        ]),
                        if (customSchedule) ...[
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(child: _formField('وقت الخروج', TextEditingController(text: workEnd), hint: '04:00 م', isLtr: true, onChanged: (v) => workEnd = v)),
                            const SizedBox(width: 12),
                            Expanded(child: _formField('وقت الحضور', TextEditingController(text: workStart), hint: '08:00 ص', isLtr: true, onChanged: (v) => workStart = v)),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text('نوع الدوام', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.sub)),
                              const SizedBox(height: 4),
                              Row(children: ['دائم', 'مؤقت'].map((t) => Expanded(child: Padding(
                                padding: EdgeInsets.only(left: t == 'مؤقت' ? 0 : 8),
                                child: InkWell(onTap: () => setDState(() => scheduleType = t),
                                  child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: scheduleType == t ? C.orange.withOpacity(0.1) : C.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: scheduleType == t ? C.orange : C.border)),
                                    child: Center(child: Text(t, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: scheduleType == t ? C.orange : C.sub))))),
                              ))).toList()),
                            ])),
                          ]),
                          if (scheduleType == 'مؤقت') ...[
                            const SizedBox(height: 10),
                            _formField('حتى تاريخ', TextEditingController(text: scheduleUntil), hint: '2026-04-30', isLtr: true, onChanged: (v) => scheduleUntil = v),
                          ],
                        ],
                      ]),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600, color: C.sub))),
                      const SizedBox(width: 10),
                      Expanded(child: ElevatedButton(
                        onPressed: loading ? null : () async {
                          if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty) return;
                          setDState(() => loading = true);
                          try {
                            if (existing == null) {
                              // Create new user
                              await _auth.registerWithEmail(emailCtrl.text.trim(), passCtrl.text, {
                                'name': nameCtrl.text.trim(),
                                'dept': dept,
                                'role': userRole,
                                'phone': phoneCtrl.text.trim(),
                                'jobTitle': roleCtrl.text.trim(),
                                'shift': shift,
                                'customSchedule': customSchedule,
                                'workStart': workStart,
                                'workEnd': workEnd,
                                'scheduleType': scheduleType,
                                'scheduleUntil': scheduleUntil,
                              });
                              await _db.collection('audit_log').add({
                                'user': widget.user['name'] ?? 'مدير النظام',
                                'action': 'إضافة مستخدم',
                                'target': '${nameCtrl.text.trim()} (${emailCtrl.text.trim()})',
                                'details': 'تم إضافة مستخدم جديد — القسم: $dept — الصلاحية: $userRole',
                                'timestamp': FieldValue.serverTimestamp(),
                                'type': 'create',
                              });
                            } else {
                              // Update existing
                              await _db.collection('users').doc(docId).update({
                                'name': nameCtrl.text.trim(),
                                'email': emailCtrl.text.trim(),
                                'phone': phoneCtrl.text.trim(),
                                'dept': dept,
                                'role': userRole,
                                'jobTitle': roleCtrl.text.trim(),
                                'shift': shift,
                                'customSchedule': customSchedule,
                                'workStart': workStart,
                                'workEnd': workEnd,
                                'scheduleType': scheduleType,
                                'scheduleUntil': scheduleUntil,
                              });
                              await _db.collection('audit_log').add({
                                'user': widget.user['name'] ?? 'مدير النظام',
                                'action': 'تعديل مستخدم',
                                'target': '${nameCtrl.text.trim()}',
                                'details': 'تم تعديل بيانات المستخدم — القسم: $dept — الصلاحية: $userRole',
                                'timestamp': FieldValue.serverTimestamp(),
                                'type': 'edit',
                              });
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            setDState(() => loading = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        child: loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(existing == null ? '✓ إضافة المستخدم' : '✓ حفظ التعديلات', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700)),
                      )),
                    ]),
                  ]),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  InputDecoration _dropDecor() => InputDecoration(
    filled: true, fillColor: C.bg,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.border)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );

  Widget _formField(String label, TextEditingController ctrl, {String? hint, bool isLtr = false, bool isPass = false, Function(String)? onChanged}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(label, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.sub)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        obscureText: isPass,
        textAlign: isLtr ? TextAlign.left : TextAlign.right,
        textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
        style: GoogleFonts.tajawal(fontSize: 13, color: C.text),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.tajawal(color: C.hint),
          filled: true, fillColor: C.bg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: C.pri, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width > 800 ? 28 : 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        // Header
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          ElevatedButton.icon(
            onPressed: () => _showAddEditDialog(),
            icon: const Icon(Icons.person_add, size: 16),
            label: Text('إضافة مستخدم', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(backgroundColor: C.pri, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
          Text('إدارة المستخدمين', style: GoogleFonts.tajawal(fontSize: 24, fontWeight: FontWeight.w800, color: C.text)),
        ]),
        const SizedBox(height: 20),

        // Stats
        StreamBuilder<QuerySnapshot>(
          stream: _db.collection('users').snapshots(),
          builder: (context, snap) {
            final docs = snap.data?.docs ?? [];
            final active = docs.where((d) => (d.data() as Map)['active'] == true).length;
            final admins = docs.where((d) => (d.data() as Map)['role'] == 'admin' || (d.data() as Map)['role'] == 'moderator').length;
            final isWide = MediaQuery.of(context).size.width > 700;
            if (isWide) {
              return Row(children: [
                _stat(Icons.people, 'إجمالي', '${docs.length}', C.pri, C.priLight),
                const SizedBox(width: 14),
                _stat(Icons.check_circle, 'نشط', '$active', C.green, const Color(0xFFECFDF3)),
                const SizedBox(width: 14),
                _stat(Icons.block, 'معطّل', '${docs.length - active}', C.red, const Color(0xFFFEF3F2)),
                const SizedBox(width: 14),
                _stat(Icons.vpn_key, 'مشرفين ومدراء', '$admins', const Color(0xFF7F56D9), const Color(0xFFF4F3FF)),
              ]);
            } else {
              final halfW = (MediaQuery.of(context).size.width - 36) / 2;
              return Wrap(spacing: 8, runSpacing: 8, children: [
                SizedBox(width: halfW, child: _statBox(Icons.people, 'إجمالي', '${docs.length}', C.pri, C.priLight)),
                SizedBox(width: halfW, child: _statBox(Icons.check_circle, 'نشط', '$active', C.green, const Color(0xFFECFDF3))),
                SizedBox(width: halfW, child: _statBox(Icons.block, 'معطّل', '${docs.length - active}', C.red, const Color(0xFFFEF3F2))),
                SizedBox(width: halfW, child: _statBox(Icons.vpn_key, 'مشرفين ومدراء', '$admins', const Color(0xFF7F56D9), const Color(0xFFF4F3FF))),
              ]);
            }
          },
        ),
        const SizedBox(height: 20),

        // Filters
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: [
          DropdownButton<String>(
            value: _fActive,
            items: ['الكل', 'نشط', 'معطّل'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.tajawal(fontSize: 13)))).toList(),
            onChanged: (v) => setState(() => _fActive = v!),
            underline: const SizedBox(),
          ),
          DropdownButton<String>(
            value: _fRole,
            items: ['الكل', 'admin', 'moderator', 'employee'].map((s) => DropdownMenuItem(value: s, child: Text(s == 'الكل' ? s : s == 'admin' ? 'مدير' : s == 'moderator' ? 'مشرف' : 'موظف', style: GoogleFonts.tajawal(fontSize: 13)))).toList(),
            onChanged: (v) => setState(() => _fRole = v!),
            underline: const SizedBox(),
          ),
          SizedBox(
            width: MediaQuery.of(context).size.width > 700 ? 260 : double.infinity,
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              textAlign: TextAlign.right,
              style: GoogleFonts.tajawal(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو الإيميل...',
                hintStyle: GoogleFonts.tajawal(color: C.hint),
                prefixIcon: const Icon(Icons.search, size: 18, color: C.muted),
                filled: true, fillColor: C.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: C.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: C.border)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 14),

        // Table / Cards
        Container(
          width: double.infinity,
          decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('users').snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
              var docs = snap.data?.docs ?? [];
              // Filter
              docs = docs.where((d) {
                final r = d.data() as Map<String, dynamic>;
                if (_search.isNotEmpty && !(r['name'] ?? '').toString().contains(_search) && !(r['email'] ?? '').toString().contains(_search)) return false;
                if (_fRole != 'الكل' && r['role'] != _fRole) return false;
                if (_fActive == 'نشط' && r['active'] != true) return false;
                if (_fActive == 'معطّل' && r['active'] != false) return false;
                return true;
              }).toList();

              final isWide = MediaQuery.of(context).size.width > 700;

              if (isWide) {
                // ─── Desktop: DataTable ───
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(C.bg),
                    columns: ['الإجراءات', 'الحالة', 'الصلاحية', 'الفترة', 'القسم', 'الهاتف', 'الإيميل', 'المستخدم'].map((h) => DataColumn(label: Text(h, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: C.sub)))).toList(),
                    rows: docs.map((doc) {
                      final r = doc.data() as Map<String, dynamic>;
                      final active = r['active'] ?? true;
                      final role = r['role'] ?? 'employee';
                      final roleLabel = {'admin': 'مدير', 'moderator': 'مشرف', 'employee': 'موظف'};
                      final roleColor = {'admin': C.red, 'moderator': const Color(0xFF7F56D9), 'employee': C.pri};

                      return DataRow(cells: [
                        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                          _actionBtn(Icons.edit, C.pri, C.priLight, () => _showAddEditDialog(existing: r, docId: doc.id)),
                          const SizedBox(width: 4),
                          _actionBtn(Icons.face, const Color(0xFF7F56D9), const Color(0xFFF4F3FF), () {
                            final emp = Map<String, dynamic>.from(r);
                            emp['_id'] = doc.id;
                            Navigator.push(context, MaterialPageRoute(builder: (_) => AdminFaceDetail(employee: emp)));
                          }),
                          const SizedBox(width: 4),
                          _actionBtn(active ? Icons.block : Icons.check_circle, active ? C.orange : C.green, active ? const Color(0xFFFFFAEB) : const Color(0xFFECFDF3), () => _db.collection('users').doc(doc.id).update({'active': !active})),
                          const SizedBox(width: 4),
                          _actionBtn(Icons.delete_outline, C.red, const Color(0xFFFEF3F2), () async {
                            final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                              title: Text('حذف المستخدم', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700), textAlign: TextAlign.right),
                              content: Text('هل تريد حذف ${r['name']}؟', style: GoogleFonts.tajawal(), textAlign: TextAlign.right),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('إلغاء', style: GoogleFonts.tajawal())),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('حذف', style: GoogleFonts.tajawal(color: C.red, fontWeight: FontWeight.w700))),
                              ],
                            ));
                            if (ok == true) await _db.collection('users').doc(doc.id).delete();
                          }),
                        ])),
                        DataCell(_badge(active ? 'نشط' : 'معطّل', active ? C.green : C.red, active ? const Color(0xFFECFDF3) : const Color(0xFFFEF3F2))),
                        DataCell(_badge(roleLabel[role] ?? 'موظف', roleColor[role] ?? C.pri, role == 'admin' ? const Color(0xFFFEF3F2) : role == 'moderator' ? const Color(0xFFF4F3FF) : C.priLight)),
                        DataCell(_badge('فترة ${r['shift'] ?? 1}', r['shift'] == 2 ? const Color(0xFF7F56D9) : r['shift'] == 3 ? const Color(0xFF0BA5EC) : C.pri, r['shift'] == 2 ? const Color(0xFFF4F3FF) : r['shift'] == 3 ? const Color(0xFFE8F8FD) : C.priLight)),
                        DataCell(Text(r['dept'] ?? '—', style: GoogleFonts.tajawal(fontSize: 12, color: C.sub))),
                        DataCell(Text(r['phone'] ?? '—', style: GoogleFonts.ibmPlexMono(fontSize: 12, color: C.sub))),
                        DataCell(Text(r['email'] ?? '—', style: GoogleFonts.tajawal(fontSize: 12, color: C.sub))),
                        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(r['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: C.text)),
                            Text(r['empId'] ?? '', style: GoogleFonts.tajawal(fontSize: 10, color: C.muted)),
                          ]),
                          const SizedBox(width: 8),
                          CircleAvatar(radius: 17, backgroundColor: active ? C.priLight : const Color(0xFFFEF3F2),
                            backgroundImage: (r['facePhotoUrl'] as String?) != null ? NetworkImage(r['facePhotoUrl']) : null,
                            child: (r['facePhotoUrl'] as String?) == null ? Text((r['name'] ?? 'م').toString().substring(0, 2), style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w700, color: active ? C.pri : C.red)) : null),
                        ])),
                      ]);
                    }).toList(),
                  ),
                );
              } else {
                // ─── Mobile: Card list ───
                if (docs.isEmpty) return Padding(padding: const EdgeInsets.all(30), child: Center(child: Text('لا يوجد مستخدمين', style: GoogleFonts.tajawal(fontSize: 14, color: C.muted))));
                return Column(children: docs.map((doc) {
                  final r = doc.data() as Map<String, dynamic>;
                  final active = r['active'] ?? true;
                  final role = r['role'] ?? 'employee';
                  final roleLabel = {'admin': 'مدير', 'moderator': 'مشرف', 'employee': 'موظف'};
                  final roleColor = {'admin': C.red, 'moderator': const Color(0xFF7F56D9), 'employee': C.pri};
                  final name = r['name'] ?? '—';
                  final av = name.length >= 2 ? name.substring(0, 2) : 'م';

                  return InkWell(
                    onTap: () => _showUserDetailSheet(context, r, doc.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.border.withOpacity(0.5)))),
                      child: Row(children: [
                        // Actions
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          _actionBtn(Icons.edit, C.pri, C.priLight, () => _showAddEditDialog(existing: r, docId: doc.id)),
                          const SizedBox(width: 4),
                          _actionBtn(Icons.face, const Color(0xFF7F56D9), const Color(0xFFF4F3FF), () {
                            final emp = Map<String, dynamic>.from(r);
                            emp['_id'] = doc.id;
                            Navigator.push(context, MaterialPageRoute(builder: (_) => AdminFaceDetail(employee: emp)));
                          }),
                          const SizedBox(width: 4),
                          _actionBtn(active ? Icons.block : Icons.check_circle, active ? C.orange : C.green, active ? const Color(0xFFFFFAEB) : const Color(0xFFECFDF3), () => _db.collection('users').doc(doc.id).update({'active': !active})),
                          const SizedBox(width: 4),
                          _actionBtn(Icons.delete_outline, C.red, const Color(0xFFFEF3F2), () async {
                            final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                              title: Text('حذف المستخدم', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700), textAlign: TextAlign.right),
                              content: Text('هل تريد حذف ${r['name']}؟', style: GoogleFonts.tajawal(), textAlign: TextAlign.right),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('إلغاء', style: GoogleFonts.tajawal())),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('حذف', style: GoogleFonts.tajawal(color: C.red, fontWeight: FontWeight.w700))),
                              ],
                            ));
                            if (ok == true) await _db.collection('users').doc(doc.id).delete();
                          }),
                        ]),
                        const Spacer(),
                        // Name + badges
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(name, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: C.text)),
                          const SizedBox(height: 3),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            _badge(active ? 'نشط' : 'معطّل', active ? C.green : C.red, active ? const Color(0xFFECFDF3) : const Color(0xFFFEF3F2)),
                            const SizedBox(width: 4),
                            _badge(roleLabel[role] ?? 'موظف', roleColor[role] ?? C.pri, role == 'admin' ? const Color(0xFFFEF3F2) : role == 'moderator' ? const Color(0xFFF4F3FF) : C.priLight),
                            const SizedBox(width: 4),
                            _badge('فترة ${r['shift'] ?? 1}', C.pri, C.priLight),
                          ]),
                        ]),
                        const SizedBox(width: 10),
                        CircleAvatar(radius: 20, backgroundColor: active ? C.priLight : const Color(0xFFFEF3F2),
                          backgroundImage: (r['facePhotoUrl'] as String?) != null ? NetworkImage(r['facePhotoUrl']) : null,
                          child: (r['facePhotoUrl'] as String?) == null ? Text(av, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: active ? C.pri : C.red)) : null),
                      ]),
                    ),
                  );
                }).toList());
              }
            },
          ),
        ),
      ]),
    );
  }

  void _showUserDetailSheet(BuildContext context, Map<String, dynamic> r, String docId) {
    final active = r['active'] ?? true;
    final role = r['role'] ?? 'employee';
    final roleLabel = {'admin': 'مدير النظام', 'moderator': 'مشرف', 'employee': 'موظف'};
    final roleColor = {'admin': C.red, 'moderator': const Color(0xFF7F56D9), 'employee': C.pri};
    final name = r['name'] ?? '—';
    final av = name.length >= 2 ? name.substring(0, 2) : 'م';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        decoration: const BoxDecoration(color: C.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 10), decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(2))),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              InkWell(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.close, size: 20, color: C.muted)),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(name, style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w700, color: C.text)),
                Text(r['empId'] ?? '', style: GoogleFonts.tajawal(fontSize: 12, color: C.muted)),
              ]),
              const SizedBox(width: 12),
              CircleAvatar(radius: 24, backgroundColor: active ? C.priLight : const Color(0xFFFEF3F2),
                backgroundImage: (r['facePhotoUrl'] as String?) != null ? NetworkImage(r['facePhotoUrl']) : null,
                child: (r['facePhotoUrl'] as String?) == null ? Text(av, style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: active ? C.pri : C.red)) : null),
            ]),
          ),
          Container(height: 1, color: C.border),
          // Details
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              _detailRow(Icons.email, 'البريد الإلكتروني', r['email'] ?? '—'),
              _detailRow(Icons.phone, 'رقم الهاتف', r['phone'] ?? '—'),
              _detailRow(Icons.business, 'القسم', r['dept'] ?? '—'),
              _detailRow(Icons.work, 'المسمى الوظيفي', r['jobTitle'] ?? '—'),
              _detailRow(Icons.schedule, 'الفترة', 'فترة ${r['shift'] ?? 1}'),
              _detailRow(Icons.vpn_key, 'الصلاحية', roleLabel[role] ?? 'موظف'),
              _detailRow(Icons.circle, 'الحالة', active ? 'نشط' : 'معطّل'),
              if (r['customSchedule'] == true) ...[
                _detailRow(Icons.access_time, 'وقت الحضور', r['workStart'] ?? '—'),
                _detailRow(Icons.access_time_filled, 'وقت الخروج', r['workEnd'] ?? '—'),
              ],
              const SizedBox(height: 20),
              // Action buttons
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showAddEditDialog(existing: r, docId: docId);
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text('تعديل', style: GoogleFonts.tajawal(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(foregroundColor: C.pri, side: const BorderSide(color: C.pri), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                )),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    final emp = Map<String, dynamic>.from(r);
                    emp['_id'] = docId;
                    Navigator.push(context, MaterialPageRoute(builder: (_) => AdminFaceDetail(employee: emp)));
                  },
                  icon: const Icon(Icons.face, size: 16),
                  label: Text('بصمة الوجه', style: GoogleFonts.tajawal(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF7F56D9), side: const BorderSide(color: Color(0xFF7F56D9)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                )),
              ]),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.border.withOpacity(0.3)))),
      child: Row(children: [
        Expanded(child: Text(value, style: GoogleFonts.tajawal(fontSize: 13, color: C.text), textAlign: TextAlign.left, textDirection: TextDirection.ltr)),
        const SizedBox(width: 10),
        Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text(label, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.sub)),
          const SizedBox(width: 6),
          Icon(icon, size: 16, color: C.muted),
        ])),
      ]),
    );
  }

  Widget _stat(IconData icon, String label, String value, Color color, Color bg) {
    return Expanded(child: _statBox(icon, label, value, color, bg));
  }

  Widget _statBox(IconData icon, String label, String value, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 16, color: color)),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.ibmPlexMono(fontSize: 22, fontWeight: FontWeight.w800, color: C.text)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.tajawal(fontSize: 11, color: C.sub)),
      ]),
    );
  }

  Widget _badge(String text, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: bg)),
      child: Text(text, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _actionBtn(IconData icon, Color color, Color bg, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(width: 28, height: 28, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.3))), child: Icon(icon, size: 12, color: color)),
    );
  }
}
