import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';
import 'sa_dashboard.dart';
import 'sa_organizations.dart';
import 'sa_plans.dart';

class SuperAdminApp extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  const SuperAdminApp({super.key, required this.user, required this.onLogout});
  @override
  State<SuperAdminApp> createState() => _SuperAdminAppState();
}

class _SuperAdminAppState extends State<SuperAdminApp> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Row(children: [
          const Spacer(),
          Text('داوملي — Super Admin', style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(width: 12),
          Container(width: 36, height: 36, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
            child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/app_icon_192.png', fit: BoxFit.cover))),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70, size: 20),
            onPressed: () async {
              await ApiService.clearSession();
              widget.onLogout();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: _tab, children: [
        SADashboard(user: widget.user),
        SAOrganizations(user: widget.user),
        SAPlans(user: widget.user),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.business), label: 'المؤسسات'),
          NavigationDestination(icon: Icon(Icons.workspace_premium), label: 'الباقات'),
        ],
      ),
    );
  }
}
