import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

class AdminDevices extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminDevices({super.key, required this.user});
  @override State<AdminDevices> createState() => _AdminDevicesState();
}

class _AdminDevicesState extends State<AdminDevices> {
  final _mono = GoogleFonts.ibmPlexMono;
  String _filter = 'all';

  // All data loaded once
  List<Map<String, dynamic>> _users = [];
  Map<String, Map<String, dynamic>> _attMap = {};
  Map<String, Map<String, dynamic>> _sessionMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final usersRes = await ApiService.get('users.php?action=list');
      final attRes = await ApiService.get('attendance.php?action=all_today');
      final sessRes = await ApiService.get('admin.php?action=get_sessions');

      final users = (usersRes['users'] as List? ?? []).cast<Map<String, dynamic>>();
      users.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));

      final attMap = <String, Map<String, dynamic>>{};
      for (final a in (attRes['records'] as List? ?? [])) {
        final m = (a as Map<String, dynamic>);
        attMap[m['uid'] ?? ''] = m;
      }

      final sessionMap = <String, Map<String, dynamic>>{};
      for (final s in (sessRes['sessions'] as List? ?? [])) {
        final m = (s as Map<String, dynamic>);
        sessionMap[m['uid'] ?? ''] = m;
      }

      if (mounted) {
        setState(() {
          _users = users;
          _attMap = attMap;
          _sessionMap = sessionMap;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _deviceIcon(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('ios') || p.contains('iphone') || p.contains('ipad')) return Icons.phone_iphone;
    if (p.contains('android')) return Icons.phone_android;
    if (p.contains('web') || p.contains('windows') || p.contains('mac')) return Icons.computer;
    return Icons.devices;
  }

  String _deviceLabel(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('ios') || p.contains('iphone')) return 'iPhone';
    if (p.contains('ipad')) return 'iPad';
    if (p.contains('android')) return 'Android';
    if (p.contains('web')) return 'Web';
    if (p.contains('windows')) return 'Windows';
    if (p.contains('mac')) return 'macOS';
    return platform.isNotEmpty ? platform : 'غير معروف';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));

    final totalUsers = _users.length;
    final presentCount = _attMap.length;
    final activeDevices = _sessionMap.length;
    final withLocation = _attMap.values.where((a) => a['checkInLat'] ?? a['check_in_lat'] ?? a['firstCheckInLat'] ?? a['first_check_in_lat'] != null).length;

    List<Map<String, dynamic>> displayUsers = _users;
    if (_filter == 'online') {
      displayUsers = _users.where((u) => _sessionMap.containsKey(u['uid'] ?? u['_id'])).toList();
    } else if (_filter == 'offline') {
      displayUsers = _users.where((u) => !_sessionMap.containsKey(u['uid'] ?? u['_id'])).toList();
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width > 800 ? 28 : 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('مراقبة الأجهزة والمواقع', style: GoogleFonts.tajawal(fontSize: 24, fontWeight: FontWeight.w800, color: C.text)),
        const SizedBox(height: 4),
        Text('متابعة أجهزة الموظفين ومواقع تسجيل الحضور', style: GoogleFonts.tajawal(fontSize: 13, color: C.sub)),
        const SizedBox(height: 20),

        // Stats row
        Row(children: [
          _stat('إجمالي', '$totalUsers', C.pri, C.priLight, Icons.people),
          const SizedBox(width: 10),
          _stat('حاضر', '$presentCount', C.green, C.greenL, Icons.check_circle_outline),
          const SizedBox(width: 10),
          _stat('أجهزة نشطة', '$activeDevices', const Color(0xFF0BA5EC), const Color(0xFFE8F8FD), Icons.phone_android),
          const SizedBox(width: 10),
          _stat('مع موقع', '$withLocation', C.orange, C.orangeL, Icons.location_on),
        ]),
        const SizedBox(height: 16),

        // Filter + refresh
        Row(children: [
          InkWell(
            onTap: () { setState(() => _loading = true); _loadAll(); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.border)),
              child: const Icon(Icons.refresh, size: 16, color: C.sub),
            ),
          ),
          const SizedBox(width: 8),
          ...['all', 'online', 'offline'].map((f) {
            final label = f == 'all' ? 'الكل' : f == 'online' ? 'متصل' : 'غير متصل';
            final sel = _filter == f;
            return Padding(padding: const EdgeInsets.only(left: 6), child: InkWell(
              onTap: () => setState(() => _filter = f),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(color: sel ? C.pri : C.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: sel ? C.pri : C.border)),
                child: Text(label, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : C.sub)),
              ),
            ));
          }),
          const Spacer(),
          const Icon(Icons.filter_list, size: 18, color: C.pri),
          const SizedBox(width: 6),
          Text('فلترة', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: C.text)),
        ]),
        const SizedBox(height: 14),

        // Employee list
        Container(
          width: double.infinity,
          decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: C.div, borderRadius: BorderRadius.circular(8)),
                child: Text('${displayUsers.length} موظف', style: GoogleFonts.tajawal(fontSize: 12, color: C.muted))),
              Row(children: [
                Text('سجلات اليوم', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: C.text)),
                const SizedBox(width: 8),
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle)),
              ]),
            ])),
            Container(height: 1, color: C.div),
            if (displayUsers.isEmpty)
              Padding(padding: const EdgeInsets.all(40), child: Text('لا يوجد نتائج', style: GoogleFonts.tajawal(color: C.muted))),
            ...displayUsers.map((emp) => _buildEmpRow(emp)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildEmpRow(Map<String, dynamic> emp) {
    final uid = emp['uid'] ?? emp['_id'] ?? '';
    final att = _attMap[uid];
    final session = _sessionMap[uid];
    final isPresent = att != null && (att['firstCheckIn'] ?? att['first_check_in'] ?? att['checkIn'] ?? att['check_in']) != null;
    final hasCheckOut = (att?['checkOut'] ?? att?['check_out'] ?? att?['lastCheckOut'] ?? att?['last_check_out']) != null;
    final hasLoc = (att?['checkInLat'] ?? att?['check_in_lat'] ?? att?['firstCheckInLat'] ?? att?['first_check_in_lat']) != null;
    final lat = att?['firstCheckInLat'] ?? att?['first_check_in_lat'] ?? att?['checkInLat'] ?? att?['check_in_lat'];
    final lng = att?['firstCheckInLng'] ?? att?['first_check_in_lng'] ?? att?['checkInLng'] ?? att?['check_in_lng'];
    final av = (emp['name'] ?? 'م').toString().length >= 2 ? (emp['name'] ?? 'م').toString().substring(0, 2) : 'م';

    final hasActiveSession = session != null;
    final deviceModel = (session?['deviceModel'] ?? session?['device_model'] ?? emp['lastDeviceModel'] ?? emp['last_device_model'] ?? '').toString();
    final platform = (session?['platform'] ?? emp['lastPlatform'] ?? emp['last_platform'] ?? '').toString();
    final osVersion = (session?['osVersion'] ?? session?['os_version'] ?? emp['lastOsVersion'] ?? emp['last_os_version'] ?? '').toString();
    final deviceBrand = (session?['deviceBrand'] ?? session?['device_brand'] ?? emp['lastDeviceBrand'] ?? emp['last_device_brand'] ?? '').toString();
    final multiDeviceAllowed = emp['multiDeviceAllowed'] == true || emp['multi_device_allowed'] == 1 || emp['multi_device_allowed'] == true;

    final statusText = hasActiveSession ? (hasCheckOut ? 'مكتمل — متصل' : isPresent ? 'حاضر — متصل' : 'متصل') : (hasCheckOut ? 'مكتمل' : isPresent ? 'حاضر' : 'غائب');
    final statusColor = hasCheckOut ? C.green : isPresent ? C.pri : (hasActiveSession ? const Color(0xFF0BA5EC) : C.muted);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.div))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        // Top row: avatar + name + status
        Row(children: [
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (hasActiveSession) Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 4), decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle)),
              Text(statusText, style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
            ]),
          ),
          const Spacer(),
          // Name + dept
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(emp['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: C.text)),
              if (multiDeviceAllowed) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: C.orangeL, borderRadius: BorderRadius.circular(4), border: Border.all(color: C.orangeBd)),
                  child: Text('متعدد', style: GoogleFonts.tajawal(fontSize: 8, fontWeight: FontWeight.w700, color: C.orange)),
                ),
              ],
            ]),
            Text('${emp['dept'] ?? ''} • ${emp['empId'] ?? ''}', style: GoogleFonts.tajawal(fontSize: 11, color: C.muted)),
          ]),
          const SizedBox(width: 10),
          Container(width: 34, height: 34, decoration: BoxDecoration(color: statusColor.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(av, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)))),
        ]),

        // Location
        if (hasLoc) Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('${lat?.toStringAsFixed(4)}, ${lng?.toStringAsFixed(4)}', style: _mono(fontSize: 10, color: C.muted)),
            const SizedBox(width: 4),
            const Icon(Icons.location_on, size: 12, color: C.green),
          ]),
        ),

        // Device info card
        if (deviceModel.isNotEmpty || platform.isNotEmpty) Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF0F9FF), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFBAE6FD))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  deviceModel.isNotEmpty ? deviceModel : _deviceLabel(platform),
                  style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.text),
                ),
                const SizedBox(width: 6),
                Icon(_deviceIcon(platform), size: 14, color: const Color(0xFF0BA5EC)),
              ]),
              if (osVersion.isNotEmpty) Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(osVersion, style: GoogleFonts.tajawal(fontSize: 10, color: C.sub)),
              ),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (deviceBrand.isNotEmpty) Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4)),
                  child: Text(deviceBrand, style: GoogleFonts.tajawal(fontSize: 9, fontWeight: FontWeight.w600, color: C.sub)),
                ),
                if (platform.isNotEmpty) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFFE8F8FD), borderRadius: BorderRadius.circular(4)),
                  child: Text(_deviceLabel(platform), style: GoogleFonts.tajawal(fontSize: 9, fontWeight: FontWeight.w600, color: const Color(0xFF0BA5EC))),
                ),
              ]),
            ]),
          ),
        ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            InkWell(
              onTap: () async {
                await ApiService.post('users.php?action=update', {'uid': uid, 'multiDeviceAllowed': !multiDeviceAllowed});
                _loadAll();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: multiDeviceAllowed ? C.orangeL : C.priLight, borderRadius: BorderRadius.circular(6), border: Border.all(color: multiDeviceAllowed ? C.orangeBd : C.pri.withOpacity(0.3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(multiDeviceAllowed ? 'تقييد لجهاز واحد' : 'السماح بأكثر من جهاز', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: multiDeviceAllowed ? C.orange : C.pri)),
                  const SizedBox(width: 4),
                  Icon(multiDeviceAllowed ? Icons.phone_android : Icons.devices, size: 12, color: multiDeviceAllowed ? C.orange : C.pri),
                ]),
              ),
            ),
            if (hasActiveSession) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () async {
                  await ApiService.post('users.php?action=clear_session', {'uid': uid});
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إنهاء جلسة ${emp['name']}', style: GoogleFonts.tajawal()), backgroundColor: C.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                  _loadAll();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: C.redL, borderRadius: BorderRadius.circular(6), border: Border.all(color: C.redBd)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('إنهاء الجلسة', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: C.red)),
                    const SizedBox(width: 4),
                    const Icon(Icons.logout, size: 12, color: C.red),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _stat(String label, String val, Color color, Color bg, IconData icon) => Expanded(child: Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Container(width: 32, height: 32, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 14, color: color)),
      const SizedBox(height: 8),
      Text(val, style: _mono(fontSize: 20, fontWeight: FontWeight.w800, color: C.text)),
      Text(label, style: GoogleFonts.tajawal(fontSize: 11, color: C.sub)),
    ]),
  ));
}
