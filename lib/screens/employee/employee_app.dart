import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../theme/app_colors.dart';
import 'emp_home.dart';
import 'emp_attendance.dart';
import 'emp_new_request.dart';
import 'emp_requests.dart';
import 'emp_more.dart';

class EmployeeApp extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  const EmployeeApp({super.key, required this.user, required this.onLogout});
  @override
  State<EmployeeApp> createState() => _EmployeeAppState();
}

class _EmployeeAppState extends State<EmployeeApp> {
  int _i = 0;
  final GlobalKey<EmpHomePageState> _homeKey = GlobalKey<EmpHomePageState>();

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _setupFcmHandlers();
  }

  void _setupFcmHandlers() {
    // App in foreground — FCM message arrives
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      if (msg.data['type'] == 'verify_request') {
        _handleVerifyRequest(msg.data);
      } else if (msg.data['type'] == 'request_update') {
        _handleRequestUpdate(msg.data);
      }
    });
    // App in background/killed — user taps notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
      if (msg.data['type'] == 'verify_request') {
        _handleVerifyRequest(msg.data);
      } else if (msg.data['type'] == 'request_update') {
        _handleRequestUpdate(msg.data);
      }
    });
    // App was killed — opened via notification tap
    FirebaseMessaging.instance.getInitialMessage().then((msg) {
      if (msg != null) {
        if (msg.data['type'] == 'verify_request') {
          Future.delayed(const Duration(milliseconds: 800), () => _handleVerifyRequest(msg.data));
        } else if (msg.data['type'] == 'request_update') {
          Future.delayed(const Duration(milliseconds: 800), () => _handleRequestUpdate(msg.data));
        }
      }
    });
  }

  void _handleVerifyRequest(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() => _i = 0); // Switch to home tab
    final verificationId = data['verification_id'];
    _homeKey.currentState?.triggerVerification(verificationId: verificationId);
  }

  void _handleRequestUpdate(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() => _i = 3); // Switch to requests tab
    final status = data['status'] ?? '';
    final isApproved = status == 'تم الموافقة';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        isApproved ? 'تمت الموافقة على طلبك' : 'تم رفض طلبك',
        style: GoogleFonts.tajawal(fontWeight: FontWeight.w600),
        textDirection: TextDirection.rtl,
      ),
      backgroundColor: isApproved ? C.green : C.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusSm)),
      duration: const Duration(seconds: 4),
    ));
  }

  void _goToTab(int tab) {
    if (mounted) setState(() => _i = tab);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      EmpHomePage(key: _homeKey, user: widget.user, onTabChange: _goToTab),
      EmpAttendancePage(user: widget.user),
      EmpNewRequestPage(user: widget.user),
      EmpRequestsPage(user: widget.user),
      EmpMorePage(user: widget.user, onLogout: widget.onLogout),
    ];
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: IndexedStack(index: _i, children: pages),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: C.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              _navItem(0, Icons.home_outlined, Icons.home_rounded, 'الرئيسية'),
              _navItem(1, Icons.date_range_outlined, Icons.date_range_rounded, 'سجل حضوري'),
              _centerNavItem(2),
              _navItem(3, Icons.description_outlined, Icons.description_rounded, 'الطلبات'),
              _navItem(4, Icons.more_horiz_rounded, Icons.more_horiz_rounded, 'المزيد'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int idx, IconData icon, IconData activeIcon, String label) {
    final on = _i == idx;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _i = idx),
        splashColor: C.pri.withOpacity(0.08),
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: on ? 48 : 40,
              height: on ? 30 : 26,
              decoration: BoxDecoration(
                color: on ? C.pri.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(on ? activeIcon : icon, size: on ? 22 : 20, color: on ? C.pri : C.muted),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.tajawal(
                fontSize: 10,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                color: on ? C.pri : C.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _centerNavItem(int idx) {
    final on = _i == idx;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _i = idx),
        splashColor: C.pri.withOpacity(0.08),
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: on ? [C.pri, const Color(0xFF0F4199)] : [C.pri.withOpacity(0.8), C.pri],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: C.pri.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: const Icon(Icons.add_rounded, size: 26, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              'طلب جديد',
              style: GoogleFonts.tajawal(
                fontSize: 10,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                color: on ? C.pri : C.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
