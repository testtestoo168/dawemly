import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import 'leave_request_page.dart';
import 'permission_request_page.dart';

class EmpNewRequestPage extends StatelessWidget {
  final Map<String, dynamic> user;
  const EmpNewRequestPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final items = [
      {'name': 'طلب إذن', 'desc': 'انصراف مبكر أو تأخير عن الحضور', 'color': const Color(0xFFF79009), 'bg': const Color(0xFFFFFAEB), 'icon': Icons.access_time, 'type': 'permission'},
      {'name': 'طلب إجازة', 'desc': 'سنوية، مرضية، طارئة، أو بدون راتب', 'color': const Color(0xFF2E90FA), 'bg': const Color(0xFFEFF8FF), 'icon': Icons.beach_access, 'type': 'leave'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('إنشاء طلب جديد', style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w700, color: C.text)),
        centerTitle: true,
        backgroundColor: C.white,
        surfaceTintColor: C.white,
        elevation: 0,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: C.border, height: 1)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: C.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: C.border),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: InkWell(
              onTap: () {
                if (item['type'] == 'leave') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => LeaveRequestPage(user: user)));
                } else if (item['type'] == 'permission') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => PermissionRequestPage(user: user)));
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                child: Row(children: [
                  Icon(Icons.chevron_left, size: 18, color: C.hint),
                  const Spacer(),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(item['name'] as String, style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: C.text)),
                    const SizedBox(height: 2),
                    Text(item['desc'] as String, style: GoogleFonts.tajawal(fontSize: 11, color: C.sub)),
                  ]),
                  const SizedBox(width: 14),
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: item['bg'] as Color, borderRadius: BorderRadius.circular(12)),
                    child: Icon(item['icon'] as IconData, size: 22, color: item['color'] as Color),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}
