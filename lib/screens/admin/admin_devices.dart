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
  List<Map<String, dynamic>> _users = [];
  Map<String, Map<String, dynamic>> _attMap = {};
  Map<String, Map<String, dynamic>> _sessionMap = {};
  bool _loading = true;
  String _filter = 'all';
  String _search = '';

  TextStyle _tj(double s, {FontWeight w = FontWeight.w400, Color? color}) =>
      GoogleFonts.tajawal(fontSize: s, fontWeight: w, color: color);

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r1 = await ApiService.get('users.php?action=list');
      final r2 = await ApiService.get('attendance.php?action=all_today');
      final r3 = await ApiService.get('admin.php?action=get_sessions');

      final users = (r1['users'] as List? ?? []).cast<Map<String, dynamic>>();
      users.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));

      final attMap = <String, Map<String, dynamic>>{};
      for (final a in (r2['records'] as List? ?? [])) attMap[(a as Map<String, dynamic>)['uid'] ?? ''] = a;

      final sessionMap = <String, Map<String, dynamic>>{};
      for (final s in (r3['sessions'] as List? ?? [])) sessionMap[(s as Map<String, dynamic>)['uid'] ?? ''] = s;

      if (mounted) setState(() { _users = users; _attMap = attMap; _sessionMap = sessionMap; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _users;
    if (_filter == 'online')  list = list.where((u) =>  _sessionMap.containsKey(u['uid'])).toList();
    if (_filter == 'offline') list = list.where((u) => !_sessionMap.containsKey(u['uid'])).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((u) =>
        (u['name'] ?? '').toString().toLowerCase().contains(q) ||
        (u['dept'] ?? '').toString().toLowerCase().contains(q) ||
        (u['last_device_model'] ?? u['lastDeviceModel'] ?? '').toString().toLowerCase().contains(q)
      ).toList();
    }
    return list;
  }

  // ── Device helpers ──
  static IconData _platformIcon(String p) {
    final s = p.toLowerCase();
    if (s.contains('ios') || s.contains('iphone') || s.contains('ipad')) return Icons.phone_iphone_rounded;
    if (s.contains('android')) return Icons.phone_android_rounded;
    if (s.contains('web')) return Icons.language_rounded;
    if (s.contains('windows')) return Icons.laptop_windows_rounded;
    if (s.contains('mac')) return Icons.laptop_mac_rounded;
    return Icons.devices_rounded;
  }

  static Color _platformColor(String p) {
    final s = p.toLowerCase();
    if (s.contains('ios') || s.contains('iphone') || s.contains('ipad')) return const Color(0xFF555555);
    if (s.contains('android')) return const Color(0xFF3DDC84);
    if (s.contains('web')) return const Color(0xFF1D4ED8);
    return const Color(0xFF6B7280);
  }

  static String _platformLabel(String p) {
    final s = p.toLowerCase();
    if (s.contains('ipad')) return 'iPad';
    if (s.contains('ios') || s.contains('iphone')) return 'iPhone / iOS';
    if (s.contains('android')) return 'Android';
    if (s.contains('web')) return 'Web Browser';
    if (s.contains('windows')) return 'Windows';
    if (s.contains('mac')) return 'macOS';
    return p.isNotEmpty ? p : '—';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));

    final isWide = MediaQuery.of(context).size.width > 800;
    final online = _sessionMap.length;
    final total = _users.where((u) => u['role'] != 'superadmin').length;
    final offline = total - online;
    final present = _attMap.length;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isWide ? 28 : 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [

          // ══════ HEADER ══════
          Row(children: [
            GestureDetector(
              onTap: _load,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(9), border: Border.all(color: W.border)),
                child: Icon(Icons.refresh_rounded, size: 16, color: W.sub),
              ),
            ),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('أمان الأجهزة', style: _tj(isWide ? 22 : 18, w: FontWeight.w800, color: W.text)),
              Text('مراقبة وإدارة أجهزة الموظفين', style: _tj(11, color: W.muted)),
            ]),
          ]),
          const SizedBox(height: 20),

          // ══════ STATS ══════
          Row(children: [
            _statCard('متصل الآن', '$online', const Color(0xFF059669), const Color(0xFFD1FAE5), Icons.wifi_rounded),
            const SizedBox(width: 10),
            _statCard('غير متصل', '$offline', W.red, W.redL, Icons.wifi_off_rounded),
            const SizedBox(width: 10),
            _statCard('حاضر اليوم', '$present', W.pri, W.priLight, Icons.how_to_reg_rounded),
            const SizedBox(width: 10),
            _statCard('إجمالي', '$total', W.muted, W.bg, Icons.people_rounded),
          ]),
          const SizedBox(height: 16),

          // ══════ FILTER + SEARCH ══════
          Row(children: [
            // Search
            Expanded(
              child: Container(
                height: 38,
                decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(9), border: Border.all(color: W.border)),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  textAlign: TextAlign.right,
                  style: _tj(12, color: W.text),
                  decoration: InputDecoration(
                    hintText: 'بحث بالاسم أو الجهاز...',
                    hintStyle: _tj(12, color: W.hint),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    suffixIcon: Icon(Icons.search_rounded, size: 16, color: W.hint),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Filter tabs
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(9), border: Border.all(color: W.border)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _filterTab('all', 'الكل'),
                _filterTab('online', 'متصل'),
                _filterTab('offline', 'غير متصل'),
              ]),
            ),
          ]),
          const SizedBox(height: 14),

          // ══════ DEVICES LIST ══════
          Container(
            decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
            child: Column(children: [
              // Table header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                  border: Border(bottom: BorderSide(color: C.div)),
                ),
                child: Row(children: [
                  Expanded(flex: 2, child: Text('الجهاز', style: _tj(11, w: FontWeight.w700, color: W.sub), textAlign: TextAlign.center)),
                  Expanded(flex: 3, child: Text('معلومات الجهاز', style: _tj(11, w: FontWeight.w700, color: W.sub), textAlign: TextAlign.right)),
                  Expanded(flex: 3, child: Text('الموظف', style: _tj(11, w: FontWeight.w700, color: W.sub), textAlign: TextAlign.right)),
                  Expanded(flex: 2, child: Text('الحالة', style: _tj(11, w: FontWeight.w700, color: W.sub), textAlign: TextAlign.center)),
                  if (isWide) Expanded(flex: 2, child: Text('إجراءات', style: _tj(11, w: FontWeight.w700, color: W.sub), textAlign: TextAlign.center)),
                ]),
              ),
              if (_filtered.isEmpty)
                Padding(padding: const EdgeInsets.all(40), child: Column(children: [
                  Icon(Icons.devices_rounded, size: 40, color: W.hint),
                  const SizedBox(height: 10),
                  Text('لا يوجد نتائج', style: _tj(13, color: W.muted)),
                ]))
              else
                ...(_filtered.map((u) => _deviceRow(u, isWide))),
            ]),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _deviceRow(Map<String, dynamic> emp, bool isWide) {
    final uid = (emp['uid'] ?? '').toString();
    final att = _attMap[uid];
    final session = _sessionMap[uid];
    final isOnline = session != null;
    final isPresent = att != null && (att['first_check_in'] ?? att['check_in']) != null;
    final isCheckedIn = att?['is_checked_in'] == 1 || att?['is_checked_in'] == true;
    final hasCheckOut = (att?['last_check_out'] ?? att?['check_out']) != null;
    final multiAllowed = emp['multi_device_allowed'] == 1 || emp['multi_device_allowed'] == true || emp['multiDeviceAllowed'] == true;

    // Device info — prefer session data (live), fallback to last known
    final platform   = (session?['platform'] ?? emp['last_platform'] ?? emp['lastPlatform'] ?? '').toString();
    final model      = (session?['device_model'] ?? session?['deviceModel'] ?? emp['last_device_model'] ?? emp['lastDeviceModel'] ?? '').toString();
    final brand      = (session?['device_brand'] ?? session?['deviceBrand'] ?? emp['last_device_brand'] ?? emp['lastDeviceBrand'] ?? '').toString();
    final osVersion  = (session?['os_version'] ?? session?['osVersion'] ?? emp['last_os_version'] ?? emp['lastOsVersion'] ?? '').toString();
    final appVersion = (session?['app_version'] ?? session?['appVersion'] ?? '').toString();

    final pColor = _platformColor(platform);
    final pIcon  = _platformIcon(platform);
    final pLabel = _platformLabel(platform);

    final name = (emp['name'] ?? '').toString();
    final initials = name.length >= 2 ? name.substring(0, 2) : (name.isNotEmpty ? name[0] : 'م');

    // Status
    String statusLabel;
    Color statusColor;
    Color statusBg;
    if (isOnline && isCheckedIn) { statusLabel = 'حاضر'; statusColor = const Color(0xFF059669); statusBg = const Color(0xFFD1FAE5); }
    else if (isOnline) { statusLabel = 'متصل'; statusColor = W.pri; statusBg = W.priLight; }
    else if (isPresent && !isCheckedIn) { statusLabel = 'خروج'; statusColor = W.muted; statusBg = W.bg; }
    else { statusLabel = 'غير متصل'; statusColor = W.red; statusBg = W.redL; }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isWide ? 14 : 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: C.div))),
      child: isWide ? _wideRow(emp, uid, isOnline, isCheckedIn, hasCheckOut, multiAllowed, platform, model, brand, osVersion, appVersion, pColor, pIcon, pLabel, name, initials, statusLabel, statusColor, statusBg)
                    : _mobileRow(emp, uid, isOnline, isCheckedIn, hasCheckOut, multiAllowed, platform, model, brand, osVersion, appVersion, pColor, pIcon, pLabel, name, initials, statusLabel, statusColor, statusBg),
    );
  }

  Widget _wideRow(Map u, String uid, bool online, bool checkedIn, bool hasOut, bool multi,
      String platform, String model, String brand, String osVer, String appVer,
      Color pColor, IconData pIcon, String pLabel, String name, String initials,
      String statusLabel, Color statusColor, Color statusBg) {
    return Row(children: [
      // Device icon column
      Expanded(flex: 2, child: Center(child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: pColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: pColor.withValues(alpha: 0.2)),
        ),
        child: Icon(pIcon, size: 22, color: pColor),
      ))),

      // Device info
      Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(model.isNotEmpty ? model : pLabel, style: _tj(13, w: FontWeight.w700, color: W.text), overflow: TextOverflow.ellipsis),
        if (brand.isNotEmpty) Text(brand, style: _tj(10, color: W.sub)),
        const SizedBox(height: 3),
        Wrap(spacing: 4, children: [
          _chip(pLabel, pColor),
          if (osVer.isNotEmpty) _chip(osVer, W.muted),
          if (appVer.isNotEmpty) _chip('v$appVer', W.pri),
          if (multi) _chip('متعدد', W.orange),
        ]),
      ])),

      // Employee info
      Expanded(flex: 3, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(name, style: _tj(13, w: FontWeight.w600, color: W.text), overflow: TextOverflow.ellipsis),
          Text('${u['dept'] ?? ''} · ${u['emp_id'] ?? u['empId'] ?? ''}', style: _tj(10, color: W.muted)),
        ]),
        const SizedBox(width: 8),
        CircleAvatar(radius: 16, backgroundColor: W.priLight,
          child: Text(initials, style: _tj(11, w: FontWeight.w700, color: W.pri))),
      ])),

      // Status
      Expanded(flex: 2, child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (online) Container(width: 6, height: 6, margin: const EdgeInsets.only(left: 5), decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
            Text(statusLabel, style: _tj(10, w: FontWeight.w700, color: statusColor)),
          ]),
        ),
      ]))),

      // Actions
      Expanded(flex: 2, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _actionBtn(
          multi ? 'جهاز واحد' : 'متعدد',
          multi ? Icons.phone_android_rounded : Icons.devices_rounded,
          multi ? W.orange : W.pri,
          () async { await ApiService.post('users.php?action=update', {'uid': uid, 'multi_device_allowed': !multi}); _load(); },
        ),
        if (online) ...[
          const SizedBox(width: 6),
          _actionBtn('فصل', Icons.logout_rounded, W.red, () async {
            await ApiService.post('users.php?action=clear_session', {'uid': uid});
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('تم فصل ${u['name']}', style: _tj(13, color: Colors.white)),
              backgroundColor: W.green, behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ));
            _load();
          }),
        ],
      ])),
    ]);
  }

  Widget _mobileRow(Map u, String uid, bool online, bool checkedIn, bool hasOut, bool multi,
      String platform, String model, String brand, String osVer, String appVer,
      Color pColor, IconData pIcon, String pLabel, String name, String initials,
      String statusLabel, Color statusColor, Color statusBg) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Row(children: [
        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (online) Container(width: 6, height: 6, margin: const EdgeInsets.only(left: 5), decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
            Text(statusLabel, style: _tj(10, w: FontWeight.w700, color: statusColor)),
          ]),
        ),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(name, style: _tj(13, w: FontWeight.w600, color: W.text)),
          Text('${u['dept'] ?? ''} · ${u['emp_id'] ?? u['empId'] ?? ''}', style: _tj(10, color: W.muted)),
        ]),
        const SizedBox(width: 8),
        CircleAvatar(radius: 16, backgroundColor: W.priLight,
          child: Text(initials, style: _tj(11, w: FontWeight.w700, color: W.pri))),
      ]),
      const SizedBox(height: 8),
      // Device card
      if (model.isNotEmpty || platform.isNotEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: pColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6), border: Border.all(color: pColor.withValues(alpha: 0.2))),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _actionBtn(multi ? 'جهاز واحد' : 'متعدد', multi ? Icons.phone_android_rounded : Icons.devices_rounded, multi ? W.orange : W.pri,
                () async { await ApiService.post('users.php?action=update', {'uid': uid, 'multi_device_allowed': !multi}); _load(); }),
              if (online) ...[SizedBox(height: 4), _actionBtn('فصل الجلسة', Icons.logout_rounded, W.red, () async {
                await ApiService.post('users.php?action=clear_session', {'uid': uid});
                _load();
              })],
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(model.isNotEmpty ? model : pLabel, style: _tj(12, w: FontWeight.w700, color: W.text)),
                const SizedBox(width: 6),
                Icon(pIcon, size: 16, color: pColor),
              ]),
              if (brand.isNotEmpty) Text(brand, style: _tj(10, color: W.sub)),
              const SizedBox(height: 4),
              Wrap(spacing: 4, alignment: WrapAlignment.end, children: [
                _chip(pLabel, pColor),
                if (osVer.isNotEmpty) _chip(osVer, W.muted),
                if (multi) _chip('متعدد الأجهزة', W.orange),
              ]),
            ]),
          ]),
        ),
    ]);
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: _tj(9, w: FontWeight.w600, color: color)),
  );

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(7), border: Border.all(color: color.withValues(alpha: 0.25))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: _tj(10, w: FontWeight.w600, color: color)),
        ]),
      ),
    );

  Widget _filterTab(String val, String label) {
    final on = _filter == val;
    return GestureDetector(
      onTap: () => setState(() => _filter = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: on ? W.pri : Colors.transparent, borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: _tj(11, w: on ? FontWeight.w700 : FontWeight.w400, color: on ? Colors.white : W.sub)),
      ),
    );
  }

  Widget _statCard(String label, String val, Color color, Color bg, IconData icon) =>
    Expanded(child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 15, color: color)),
        const SizedBox(height: 8),
        Text(val, style: GoogleFonts.ibmPlexMono(fontSize: 20, fontWeight: FontWeight.w800, color: W.text)),
        Text(label, style: _tj(10, color: W.sub)),
      ]),
    ));
}
