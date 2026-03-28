import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

class EmpLocationsPage extends StatefulWidget {
  final Map<String, dynamic> user;
  const EmpLocationsPage({super.key, required this.user});

  @override
  State<EmpLocationsPage> createState() => _EmpLocationsPageState();
}

class _EmpLocationsPageState extends State<EmpLocationsPage> {
  List<Map<String, dynamic>> _userLocs = [];
  bool _loading = true;

  TextStyle _tj(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    try {
      final res = await ApiService.get('admin.php?action=get_locations');
      final allLocs = (res['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      final filtered = allLocs.where((data) {
        if (data['active'] != true && data['active'] != 1 && data['active'] != '1') return false;
        final assigned = (data['assignedEmployees'] as List?)?.cast<String>() ?? [];
        return assigned.isEmpty || assigned.contains(widget.user['uid']);
      }).toList();

      if (mounted) {
        setState(() {
          _userLocs = filtered;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _userLocs = [];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: C.white,
        surfaceTintColor: C.white,
        elevation: 0,
        centerTitle: true,
        title: Text('الفرع / الإدارة', style: _tj(17, weight: FontWeight.w700, color: C.text)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: C.text),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: C.border, height: 1)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: C.pri));
    }

    if (_userLocs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_rounded, size: 60, color: C.muted.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text('لا توجد مواقع محددة لك', style: _tj(16, weight: FontWeight.w600, color: C.muted)),
            const SizedBox(height: 4),
            Text('تواصل مع الإدارة لتحديد مواقع العمل', style: _tj(13, color: C.muted)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userLocs.length,
      itemBuilder: (ctx, i) {
        final loc = _userLocs[i];
        final radius = (loc['radius'] ?? 300) as num;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: C.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Radius badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: C.greenL,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${radius.toInt()}م', style: _tj(12, weight: FontWeight.w600, color: C.green)),
              ),
              const Spacer(),
              // Info
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      loc['name'] ?? 'موقع',
                      style: _tj(15, weight: FontWeight.w700, color: C.text),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(loc['lat'] ?? 0).toStringAsFixed(4)}, ${(loc['lng'] ?? 0).toStringAsFixed(4)}',
                      style: GoogleFonts.ibmPlexMono(fontSize: 11, color: C.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Icon
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: C.greenL,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_on_rounded, size: 22, color: C.green),
              ),
            ],
          ),
        );
      },
    );
  }
}
