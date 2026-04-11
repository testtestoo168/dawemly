import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';
import '../../l10n/app_locale.dart';

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
      users.sort((a, b) => L.localName(a).compareTo(L.localName(b)));

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
        (u['name_en'] ?? '').toString().toLowerCase().contains(q) ||
        (u['dept'] ?? '').toString().toLowerCase().contains(q) ||
        (u['last_device_model'] ?? u['lastDeviceModel'] ?? '').toString().toLowerCase().contains(q)
      ).toList();
    }
    return list;
  }

  // -- Device helpers --
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

    final width = MediaQuery.of(context).size.width;
    final isWide = width > 800;
    final online = _sessionMap.length;
    final total = _users.where((u) => u['role'] != 'superadmin').length;
    final offline = total - online;
    final present = _attMap.length;
    final dir = L.textDirection;

    // Grid columns: 3 on very wide, 2 on medium-wide, 1 on mobile
    final gridCols = width > 1200 ? 3 : (isWide ? 2 : 1);

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isWide ? 28 : 14),
        child: Directionality(
          textDirection: dir,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // ══════ HEADER ══════
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(L.tr('device_security'), style: _tj(isWide ? 22 : 18, w: FontWeight.w800, color: W.text)),
                  const SizedBox(height: 2),
                  Text(L.tr('device_monitoring_desc'), style: _tj(11, color: W.muted)),
                ]),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: _load,
                borderRadius: BorderRadius.circular(DS.radiusSm),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: W.bg,
                    borderRadius: BorderRadius.circular(DS.radiusSm),
                    border: Border.all(color: W.border),
                  ),
                  child: Icon(Icons.refresh_rounded, size: 16, color: W.sub),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // ══════ STATS ══════
            _buildStats(isWide, online, offline, present, total),
            const SizedBox(height: 16),

            // ══════ FILTER + SEARCH ══════
            isWide ? _buildFilterSearchWide() : _buildFilterSearchMobile(),
            const SizedBox(height: 14),

            // ══════ DEVICES GRID ══════
            if (_filtered.isEmpty)
              Container(
                decoration: DS.cardDecoration(),
                padding: const EdgeInsets.all(48),
                child: Column(children: [
                  Icon(Icons.devices_rounded, size: 48, color: W.hint),
                  const SizedBox(height: 12),
                  Text(L.tr('no_records'), style: _tj(14, color: W.muted)),
                ]),
              )
            else
              _buildDeviceGrid(gridCols, isWide),

            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  // ══════ STATS ROW ══════
  Widget _buildStats(bool isWide, int online, int offline, int present, int total) {
    final stats = [
      _StatData(L.tr('connected_now'), '$online', const Color(0xFF059669), Icons.wifi_rounded),
      _StatData(L.tr('disconnected'), '$offline', W.red, Icons.wifi_off_rounded),
      _StatData(L.tr('checked_in'), '$present', W.pri, Icons.how_to_reg_rounded),
      _StatData(L.tr('total'), '$total', W.muted, Icons.people_rounded),
    ];

    if (isWide) {
      return Row(children: [
        for (int i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _statCard(stats[i])),
        ],
      ]);
    }

    // Mobile: 2x2 grid
    return Column(children: [
      Row(children: [
        Expanded(child: _statCard(stats[0])),
        const SizedBox(width: 10),
        Expanded(child: _statCard(stats[1])),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _statCard(stats[2])),
        const SizedBox(width: 10),
        Expanded(child: _statCard(stats[3])),
      ]),
    ]);
  }

  // ══════ FILTER + SEARCH (WIDE) ══════
  Widget _buildFilterSearchWide() {
    return Row(children: [
      // Filter tabs
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: W.bg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: W.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _filterTab('all', L.tr('all')),
          _filterTab('online', L.tr('connected')),
          _filterTab('offline', L.tr('disconnected')),
        ]),
      ),
      const SizedBox(width: 12),
      // Search
      SizedBox(
        width: 280,
        height: 38,
        child: Container(
          decoration: DS.cardDecoration(radius: DS.radiusSm),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: _tj(12, color: W.text),
            decoration: InputDecoration(
              hintText: L.tr('search_name_device'),
              hintStyle: _tj(12, color: W.hint),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              prefixIcon: Icon(Icons.search_rounded, size: 16, color: W.hint),
            ),
          ),
        ),
      ),
    ]);
  }

  // ══════ FILTER + SEARCH (MOBILE) ══════
  Widget _buildFilterSearchMobile() {
    return Column(children: [
      // Search
      Container(
        height: 38,
        decoration: DS.cardDecoration(radius: DS.radiusSm),
        child: TextField(
          onChanged: (v) => setState(() => _search = v),
          style: _tj(12, color: W.text),
          decoration: InputDecoration(
            hintText: L.tr('search_name_device'),
            hintStyle: _tj(12, color: W.hint),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            prefixIcon: Icon(Icons.search_rounded, size: 16, color: W.hint),
          ),
        ),
      ),
      const SizedBox(height: 8),
      // Filter tabs
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: W.bg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: W.border),
        ),
        child: Row(children: [
          Expanded(child: _filterTab('all', L.tr('all'))),
          Expanded(child: _filterTab('online', L.tr('connected'))),
          Expanded(child: _filterTab('offline', L.tr('disconnected'))),
        ]),
      ),
    ]);
  }

  // ══════ DEVICE GRID ══════
  Widget _buildDeviceGrid(int cols, bool isWide) {
    final items = _filtered;
    if (cols <= 1) {
      // Mobile: simple list
      return Column(children: items.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _deviceCard(e, isWide),
      )).toList());
    }
    // Web: use Wrap for natural flow that respects text direction
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: items.map((e) => SizedBox(
        width: cols == 3 ? (MediaQuery.of(context).size.width - 56 - 28) / 3 : (MediaQuery.of(context).size.width - 56 - 14) / 2,
        child: _deviceCard(e, isWide),
      )).toList(),
    );
  }

  // ══════ DEVICE CARD ══════
  Widget _deviceCard(Map<String, dynamic> emp, bool isWide) {
    final uid = (emp['uid'] ?? '').toString();
    final att = _attMap[uid];
    final session = _sessionMap[uid];
    final isOnline = session != null;
    final isPresent = att != null && (att['first_check_in'] ?? att['check_in']) != null;
    final isCheckedIn = att?['is_checked_in'] == 1 || att?['is_checked_in'] == true;
    final multiAllowed = emp['multi_device_allowed'] == 1 || emp['multi_device_allowed'] == true || emp['multiDeviceAllowed'] == true;

    // Device info
    final platform   = (session?['platform'] ?? emp['last_platform'] ?? emp['lastPlatform'] ?? '').toString();
    final model      = (session?['device_model'] ?? session?['deviceModel'] ?? emp['last_device_model'] ?? emp['lastDeviceModel'] ?? '').toString();
    final brand      = (session?['device_brand'] ?? session?['deviceBrand'] ?? emp['last_device_brand'] ?? emp['lastDeviceBrand'] ?? '').toString();
    final osVersion  = (session?['os_version'] ?? session?['osVersion'] ?? emp['last_os_version'] ?? emp['lastOsVersion'] ?? '').toString();
    final appVersion = (session?['app_version'] ?? session?['appVersion'] ?? '').toString();

    final pColor = _platformColor(platform);
    final pIcon  = _platformIcon(platform);
    final pLabel = _platformLabel(platform);

    final name = L.localName(emp);
    final initials = name.length >= 2 ? name.substring(0, 2) : (name.isNotEmpty ? name[0] : L.tr('pm'));

    // Status
    String statusLabel;
    Color statusColor;
    Color statusBg;
    if (isOnline && isCheckedIn) {
      statusLabel = L.tr('present');
      statusColor = const Color(0xFF059669);
      statusBg = const Color(0xFFD1FAE5);
    } else if (isOnline) {
      statusLabel = L.tr('connected');
      statusColor = W.pri;
      statusBg = W.priLight;
    } else if (isPresent && !isCheckedIn) {
      statusLabel = L.tr('exit_label');
      statusColor = W.muted;
      statusBg = W.bg;
    } else {
      statusLabel = L.tr('disconnected');
      statusColor = W.red;
      statusBg = W.redL;
    }

    return Container(
      decoration: DS.cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── Card header: employee + status ──
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: W.bg.withValues(alpha: 0.5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radiusMd)),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: W.priLight,
              child: Text(initials, style: _tj(12, w: FontWeight.w700, color: W.pri)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  name,
                  style: _tj(13, w: FontWeight.w700, color: W.text),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  '${L.localDept(emp)} · ${emp['emp_id'] ?? emp['empId'] ?? ''}',
                  style: _tj(10, color: W.muted),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ]),
            ),
            const SizedBox(width: 8),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (isOnline) ...[
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                ],
                Text(statusLabel, style: _tj(10, w: FontWeight.w700, color: statusColor)),
              ]),
            ),
          ]),
        ),

        // ── Device info section ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Device model row
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: pColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(DS.radiusSm),
                  border: Border.all(color: pColor.withValues(alpha: 0.2)),
                ),
                child: Icon(pIcon, size: 18, color: pColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    model.isNotEmpty ? model : pLabel,
                    style: _tj(12, w: FontWeight.w600, color: W.text),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  if (brand.isNotEmpty)
                    Text(brand, style: _tj(10, color: W.sub)),
                ]),
              ),
            ]),
            const SizedBox(height: 8),
            // Tags
            Wrap(spacing: 5, runSpacing: 4, children: [
              _chip(pLabel, pColor),
              if (osVersion.isNotEmpty) _chip(osVersion, W.muted),
              if (appVersion.isNotEmpty) _chip('v$appVersion', W.pri),
              if (multiAllowed) _chip(L.tr('multi_device'), W.orange),
            ]),
          ]),
        ),

        // ── Divider ──
        Container(height: 1, color: W.div),

        // ── Actions row ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(children: [
            _actionBtn(
              multiAllowed ? L.tr('one_device') : L.tr('multi_device'),
              multiAllowed ? Icons.phone_android_rounded : Icons.devices_rounded,
              multiAllowed ? W.orange : W.pri,
              () async {
                await ApiService.post('users.php?action=update', {'uid': uid, 'multi_device_allowed': !multiAllowed});
                _load();
              },
            ),
            if (isOnline) ...[
              const SizedBox(width: 8),
              _actionBtn(L.tr('disconnect'), Icons.logout_rounded, W.red, () async {
                await ApiService.post('users.php?action=clear_session', {'uid': uid});
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(L.tr('disconnected_name', args: {'name': L.localName(emp)}), style: _tj(13, color: Colors.white)),
                  backgroundColor: W.green, behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd)),
                ));
                _load();
              }),
            ],
          ]),
        ),
      ]),
    );
  }

  // ══════ REUSABLE WIDGETS ══════

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: _tj(9, w: FontWeight.w600, color: color)),
  );

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) =>
    Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DS.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(DS.radiusSm)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: _tj(10, w: FontWeight.w600, color: color)),
          ]),
        ),
      ),
    );

  Widget _filterTab(String val, String label) {
    final on = _filter == val;
    return InkWell(
      onTap: () => setState(() => _filter = val),
      borderRadius: BorderRadius.circular(DS.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: on ? W.pri : Colors.transparent, borderRadius: BorderRadius.circular(DS.radiusMd)),
        child: Text(label, textAlign: TextAlign.center, style: _tj(11, w: on ? FontWeight.w700 : FontWeight.w400, color: on ? Colors.white : W.sub)),
      ),
    );
  }

  Widget _statCard(_StatData d) => Container(
    padding: const EdgeInsets.all(14),
    decoration: DS.gradientCard(d.color),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: d.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9)),
          child: Icon(d.icon, size: 15, color: d.color),
        ),
        const Spacer(),
        Text(d.value, style: GoogleFonts.ibmPlexMono(fontSize: 20, fontWeight: FontWeight.w800, color: W.text)),
      ]),
      const SizedBox(height: 6),
      Text(d.label, style: _tj(10, color: W.sub)),
    ]),
  );
}

class _StatData {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _StatData(this.label, this.value, this.color, this.icon);
}
