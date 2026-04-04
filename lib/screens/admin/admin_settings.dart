import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

class AdminSettings extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminSettings({super.key, required this.user});
  @override
  State<AdminSettings> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettings> {
  String _tab = 'shifts';
  List<Map<String, dynamic>> _settingsUsers = [];
  List<Map<String, dynamic>> _settingsLocations = [];
  List<Map<String, dynamic>> _settingsSessions = [];
  bool _saved = false;

  // ═══ فترات العمل ═══
  final List<Map<String, dynamic>> _shifts = [
    {'id': 1, 'name': 'الفترة الأولى', 'start': '08:00 ص', 'end': '04:00 م', 'color': const Color(0xFF175CD3), 'active': true},
    {'id': 2, 'name': 'الفترة الثانية', 'start': '01:00 م', 'end': '09:00 م', 'color': const Color(0xFF7F56D9), 'active': true},
    {'id': 3, 'name': 'الفترة الثالثة', 'start': '04:00 م', 'end': '12:00 ص', 'color': const Color(0xFF0BA5EC), 'active': true},
  ];
  bool _showAddShift = false;
  final _shiftName = TextEditingController();
  final _shiftStart = TextEditingController();
  final _shiftEnd = TextEditingController();

  // ═══ أوفرتايم ═══
  double _generalH = 8;
  double _overtimeRate = 1.5;
  bool _overtimeActive = true;

  // ═══ تأخير ═══
  int _lateGraceMinutes = 15; // سماحية التأخير بالدقائق

  // ═══ مصادقة ═══
  bool _authFace = true, _authFinger = true, _authLoc = true;

  // ═══ أمان ═══
  bool _twoFA = true, _loginNotify = true, _failedNotify = true, _ipWhitelist = false;
  double _sessionTimeout = 30, _maxAttempts = 5, _forcePassChange = 90;

  // ═══ مظهر ═══
  String _primaryColor = '#175CD3', _orgName = 'مدارس المروج النموذجية الأهلية', _logo = 'داوِملي', _fontSize = 'medium';
  bool _darkMode = false, _compactMode = false;

  // ═══ بصمة مخصصة ═══
  final List<Map<String, dynamic>> _customAtt = [
    {'id': 1, 'empName': 'محمد فهد الشمري', 'date': '18 مارس 2026', 'start': '10:00 ص', 'end': '02:00 م', 'reason': 'مهمة خارجية', 'status': 'مفعّل'},
  ];
  bool _showAddAtt = false;
  final _attDate = TextEditingController();
  final _attStart = TextEditingController();
  final _attEnd = TextEditingController();
  final _attReason = TextEditingController();
  String _attEmpId = '';

  // ═══ مواقع ═══
  bool _showAddLoc = false;
  String? _editingLocId; // null = adding new, non-null = editing existing
  final _locName = TextEditingController();
  final _locLat = TextEditingController();
  final _locLng = TextEditingController();
  final _locRadius = TextEditingController(text: '300');
  LatLng? _pickedLatLng;
  final _locSearchCtrl = TextEditingController();
  GoogleMapController? _mapCtrl;
  bool _searching = false;
  List<Map<String, dynamic>> _searchResults = [];
  // Employee assignment for location
  Set<String> _locSelectedEmps = {};

  // ═══ أمان الأجهزة ═══
  bool _singleDeviceMode = false;
  String _devSearch = '';
  String _devFilter = 'all'; // all / online / offline

  final _mono = GoogleFonts.ibmPlexMono;

  static const _mapsApiKey = 'AIzaSyB-CkusFlHFxJujo_GagT1kSNoQtmCq630';

  void _searchLocation() async {
    if (_locSearchCtrl.text.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final query = Uri.encodeComponent(_locSearchCtrl.text.trim());

      Uri searchUri;
      if (kIsWeb) {
        searchUri = Uri.parse('${ApiService.baseUrl}/places.php?query=$query');
      } else {
        searchUri = Uri.parse('https://maps.googleapis.com/maps/api/place/textsearch/json?query=$query&language=ar&key=$_mapsApiKey');
      }

      final tsResponse = await http.get(searchUri);
      final tsData = jsonDecode(tsResponse.body);
      
      final results = <Map<String, dynamic>>[];
      for (final place in (tsData['results'] as List? ?? []).take(8)) {
        final loc = place['geometry']?['location'];
        if (loc == null) continue;
        results.add({
          'name': place['name'] ?? '',
          'address': place['formatted_address'] ?? '',
          'lat': (loc['lat'] as num).toDouble(),
          'lng': (loc['lng'] as num).toDouble(),
        });
      }
      setState(() => _searchResults = results);
      if (results.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لم يتم العثور على نتائج — جرّب كلمات أخرى', style: GoogleFonts.tajawal()), backgroundColor: W.orange, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))));
      }
    } catch (e) {
      setState(() => _searchResults = []);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في البحث: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e}', style: GoogleFonts.tajawal()), backgroundColor: W.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))));
      }
    }
    if (mounted) setState(() => _searching = false);
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final pos = LatLng(result['lat'], result['lng']);
    setState(() {
      _pickedLatLng = pos;
      _locLat.text = (result['lat'] as double).toStringAsFixed(6);
      _locLng.text = (result['lng'] as double).toStringAsFixed(6);
      _searchResults = [];
      _locSearchCtrl.text = result['name'] ?? '';
      if (_locName.text.isEmpty) {
        _locName.text = result['name'] ?? '';
      }
    });
    _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(pos, 17));
  }

  void _save() async {
    try {
      await ApiService.post('admin.php?action=save_settings', {
        'generalH': _generalH, 'overtimeRate': _overtimeRate,
        'overtimeActive': _overtimeActive, 'lateGraceMinutes': _lateGraceMinutes,
        'shift1Start': _shifts[0]['start'], 'shift1End': _shifts[0]['end'],
        'shift2Start': _shifts.length > 1 ? _shifts[1]['start'] : '',
        'shift2End': _shifts.length > 1 ? _shifts[1]['end'] : '',
        'shift3Start': _shifts.length > 2 ? _shifts[2]['start'] : '',
        'shift3End': _shifts.length > 2 ? _shifts[2]['end'] : '',
        'authFace': _authFace, 'authFinger': _authFinger, 'authLoc': _authLoc,
        'twoFA': _twoFA, 'loginNotify': _loginNotify, 'failedNotify': _failedNotify,
        'ipWhitelist': _ipWhitelist, 'sessionTimeout': _sessionTimeout,
        'maxAttempts': _maxAttempts, 'forcePassChange': _forcePassChange,
        'primaryColor': _primaryColor, 'orgName': _orgName, 'logo': _logo,
        'fontSize': _fontSize, 'darkMode': _darkMode, 'compactMode': _compactMode,
        'singleDeviceMode': _singleDeviceMode,
        'updatedBy': widget.user['name'] ?? 'مدير النظام',
      });
      await ApiService.post('admin.php?action=audit_log', {
        'user': widget.user['name'] ?? 'مدير النظام', 'action': 'تحديث الإعدادات',
        'target': 'إعدادات النظام — $_tab', 'details': 'تم حفظ إعدادات $_tab', 'type': 'settings',
      });
      setState(() => _saved = true);
      Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _saved = false); });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في حفظ الإعدادات: $e', style: GoogleFonts.tajawal()), backgroundColor: W.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))));
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    try {
      final results = await Future.wait([
        ApiService.get('admin.php?action=get_settings'),
        ApiService.get('users.php?action=list'),
        ApiService.get('admin.php?action=get_locations'),
        ApiService.get('admin.php?action=get_sessions'),
      ]);
      final res = results[0];
      final d = res['settings'] as Map<String, dynamic>? ?? {};
      final usersRes = results[1];
      final locsRes = results[2];
      final sessRes = results[3];
      if (mounted) setState(() {
        _generalH = (d['generalH'] as num?)?.toDouble() ?? _generalH;
        _overtimeRate = (d['overtimeRate'] as num?)?.toDouble() ?? _overtimeRate;
        _overtimeActive = d['overtimeActive'] ?? _overtimeActive;
        _authFace = d['authFace'] ?? _authFace;
        _authFinger = d['authFinger'] ?? _authFinger;
        _authLoc = d['authLoc'] ?? _authLoc;
        _twoFA = d['twoFA'] ?? _twoFA;
        _loginNotify = d['loginNotify'] ?? _loginNotify;
        _failedNotify = d['failedNotify'] ?? _failedNotify;
        _ipWhitelist = d['ipWhitelist'] ?? _ipWhitelist;
        _sessionTimeout = (d['sessionTimeout'] as num?)?.toDouble() ?? _sessionTimeout;
        _maxAttempts = (d['maxAttempts'] as num?)?.toDouble() ?? _maxAttempts;
        _forcePassChange = (d['forcePassChange'] as num?)?.toDouble() ?? _forcePassChange;
        _primaryColor = d['primaryColor'] ?? _primaryColor;
        _orgName = d['orgName'] ?? _orgName;
        _logo = d['logo'] ?? _logo;
        _fontSize = d['fontSize'] ?? _fontSize;
        _darkMode = d['darkMode'] ?? _darkMode;
        _compactMode = d['compactMode'] ?? _compactMode;
        _singleDeviceMode = d['singleDeviceMode'] ?? _singleDeviceMode;
        _lateGraceMinutes = (d['lateGraceMinutes'] as int?) ?? _lateGraceMinutes;
        _settingsUsers = (usersRes['users'] as List? ?? []).cast<Map<String, dynamic>>().where((e) => (e['name'] ?? '').toString().isNotEmpty && e['role'] != 'admin' && e['role'] != 'superadmin').toList();
        _settingsUsers.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
        _settingsLocations = (locsRes['locations'] as List? ?? []).cast<Map<String, dynamic>>();
        _settingsSessions = (sessRes['sessions'] as List? ?? []).cast<Map<String, dynamic>>();
      });
    } catch (_) {}
  }

  final _tabs = const [
    {'k': 'shifts', 'l': 'فترات العمل', 'icon': Icons.layers},
    {'k': 'locations', 'l': 'المواقع', 'icon': Icons.location_on},
    {'k': 'overtime', 'l': 'الأوفرتايم', 'icon': Icons.more_time},
    {'k': 'late', 'l': 'التأخير', 'icon': Icons.timer_off},
    {'k': 'auth', 'l': 'المصادقة', 'icon': Icons.shield},
    {'k': 'security', 'l': 'الأمان', 'icon': Icons.lock},
    {'k': 'appearance', 'l': 'المظهر', 'icon': Icons.desktop_windows},
    {'k': 'custom', 'l': 'بصمة مخصصة', 'icon': Icons.lock_open},
    {'k': 'devicesec', 'l': 'أمان الأجهزة', 'icon': Icons.phone_android},
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    final isMobile = MediaQuery.of(context).size.width < 500;
    return SingleChildScrollView(padding: EdgeInsets.all(isWide ? 28 : (isMobile ? 10 : 14)), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      // Save button only (title is in AppBar)
      Align(alignment: Alignment.centerLeft, child: ElevatedButton.icon(onPressed: _save, icon: Icon(_saved ? Icons.check : Icons.save, size: 16), label: Text(_saved ? 'تم الحفظ' : 'حفظ', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)), style: ElevatedButton.styleFrom(backgroundColor: _saved ? W.green : W.pri, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))))),
      const SizedBox(height: 14),

      // Sub-tabs — scrollable horizontally on mobile
      SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          children: _tabs.map((t) {
            final sel = _tab == t['k'];
            return Padding(
              padding: const EdgeInsets.only(left: 6),
              child: InkWell(
                onTap: () => setState(() => _tab = t['k'] as String),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? W.pri : W.white,
                    borderRadius: BorderRadius.circular(8),
                    border: sel ? null : Border.all(color: W.border),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(t['icon'] as IconData, size: 15, color: sel ? Colors.white : W.sub),
                    const SizedBox(width: 6),
                    Text(t['l'] as String, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : W.sub)),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 16),

      // ═══════ فترات العمل ═══════
      if (_tab == 'shifts') _buildShifts(),
      // ═══════ المواقع ═══════
      if (_tab == 'locations') _buildLocations(),
      // ═══════ الأوفرتايم ═══════
      if (_tab == 'overtime') _buildOvertime(),
      // ═══════ التأخير ═══════
      if (_tab == 'late') _buildLateSettings(),
      // ═══════ المصادقة ═══════
      if (_tab == 'auth') _buildAuth(),
      // ═══════ الأمان ═══════
      if (_tab == 'security') _buildSecurity(),
      // ═══════ المظهر ═══════
      if (_tab == 'appearance') _buildAppearance(),
      // ═══════ بصمة مخصصة ═══════
      if (_tab == 'custom') _buildCustomAtt(),
      // ═══════ أمان الأجهزة ═══════
      if (_tab == 'devicesec') _buildDeviceSecurity(),
    ]));
  }

  // ─────────────────── فترات العمل ───────────────────
  Widget _buildShifts() { final isMobile = MediaQuery.of(context).size.width < 500; return Column(children: [
    if (_showAddShift) _card(border: W.pri, child: Column(children: [
      Builder(builder: (ctx) {
        final isWide = MediaQuery.of(ctx).size.width > 500;
        if (isWide) {
          return Row(children: [Expanded(child: _input(_shiftEnd, 'وقت الانتهاء', '04:00 م', isLtr: true)), const SizedBox(width: 10), Expanded(child: _input(_shiftStart, 'وقت البداية', '08:00 ص', isLtr: true)), const SizedBox(width: 10), Expanded(flex: 2, child: _input(_shiftName, 'اسم الفترة', 'الفترة الرابعة'))]);
        }
        return Column(children: [_input(_shiftName, 'اسم الفترة', 'الفترة الرابعة'), const SizedBox(height: 10), Row(children: [Expanded(child: _input(_shiftEnd, 'وقت الانتهاء', '04:00 م', isLtr: true)), const SizedBox(width: 10), Expanded(child: _input(_shiftStart, 'وقت البداية', '08:00 ص', isLtr: true))])]);
      }),
      const SizedBox(height: 12),
      Row(children: [_greenBtn('✓ إضافة', () { if (_shiftName.text.isEmpty) return; setState(() { _shifts.add({'id': DateTime.now().millisecondsSinceEpoch, 'name': _shiftName.text, 'start': _shiftStart.text, 'end': _shiftEnd.text, 'color': [W.pri, Color(0xFF7F56D9), Color(0xFF0BA5EC), W.orange][_shifts.length % 4], 'active': true}); _shiftName.clear(); _shiftStart.clear(); _shiftEnd.clear(); _showAddShift = false; }); }), SizedBox(width: 8), _cancelBtn(() => setState(() => _showAddShift = false))]),
    ])),
    isMobile ? Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Align(alignment: Alignment.centerRight, child: Text('حدد فترات العمل — كل فترة بوقت بداية ونهاية', style: GoogleFonts.tajawal(fontSize: 11, color: W.sub))),
      const SizedBox(height: 8),
      _addBtn('إضافة فترة', () => setState(() => _showAddShift = true)),
    ]) : Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_addBtn('إضافة فترة', () => setState(() => _showAddShift = true)), Flexible(child: Text('حدد فترات العمل — كل فترة بوقت بداية ونهاية', style: GoogleFonts.tajawal(fontSize: 12, color: W.sub)))]),
    const SizedBox(height: 14),
    ...List.generate(_shifts.length, (i) { final sh = _shifts[i]; final color = sh['color'] as Color; return Container(margin: EdgeInsets.only(bottom: 10), padding: EdgeInsets.all(isMobile ? 14 : 22), decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: sh['active'] == true ? color.withOpacity(0.3) : W.border)), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(mainAxisSize: MainAxisSize.min, children: [Switch(value: sh['active'] == true, activeColor: W.green, onChanged: (v) => setState(() => _shifts[i]['active'] = v)), InkWell(onTap: () => setState(() => _shifts.removeAt(i)), child: Icon(Icons.delete_outline, size: 16, color: W.red))]), Flexible(child: Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: Text(sh['name'] as String, style: GoogleFonts.tajawal(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w700, color: W.text), overflow: TextOverflow.ellipsis)), SizedBox(width: 8), Container(width: isMobile ? 36 : 44, height: isMobile ? 36 : 44, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Icon(Icons.access_time, size: isMobile ? 16 : 20, color: color))]))]),
      const SizedBox(height: 14),
      Row(children: [Expanded(child: _timeBox('البداية', sh['start'] as String, color)), Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('→', style: TextStyle(fontSize: 18, color: W.hint))), Expanded(child: _timeBox('النهاية', sh['end'] as String, color))]),
    ])); }),
  ]); }

  // ─────────────────── المواقع ───────────────────
  void _editLocation(String docId, Map<String, dynamic> loc) {
    setState(() {
      _editingLocId = docId;
      _showAddLoc = true;
      _locName.text = loc['name'] ?? '';
      _locRadius.text = (loc['radius'] ?? 300).toString();
      final lat = (loc['lat'] as num?)?.toDouble();
      final lng = (loc['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        _pickedLatLng = LatLng(lat, lng);
        _locLat.text = lat.toStringAsFixed(6);
        _locLng.text = lng.toStringAsFixed(6);
      }
      final assigned = ((loc['assignedEmployees'] ?? loc['assigned_employees']) as List?)?.cast<String>() ?? [];
      _locSelectedEmps = assigned.toSet();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_pickedLatLng != null) {
        _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(_pickedLatLng!, 17));
      }
    });
  }

  void _resetLocForm() {
    _locName.clear(); _locLat.clear(); _locLng.clear(); _locSearchCtrl.clear();
    _locRadius.text = '300';
    setState(() { _showAddLoc = false; _pickedLatLng = null; _locSelectedEmps.clear(); _editingLocId = null; });
  }

  Widget _buildLocations() { final isMobile = MediaQuery.of(context).size.width < 500; return Column(children: [
    isMobile ? Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('مواقع العمل المعتمدة — الموظف يبصم في أي موقع مفعّل', style: GoogleFonts.tajawal(fontSize: 11, color: W.sub)),
      const SizedBox(height: 8),
      _addBtn('إضافة موقع', () => setState(() { _editingLocId = null; _showAddLoc = true; })),
    ]) : Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_addBtn('إضافة موقع', () => setState(() { _editingLocId = null; _showAddLoc = true; })), Flexible(child: Text('مواقع العمل المعتمدة — الموظف يبصم في أي موقع مفعّل', style: GoogleFonts.tajawal(fontSize: 12, color: W.sub)))]),
    const SizedBox(height: 14),
    if (_showAddLoc) _card(border: W.pri, child: Column(children: [
      // Edit/Add header
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text(_editingLocId != null ? 'تعديل الموقع' : 'إضافة موقع جديد', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: W.text)),
        const SizedBox(width: 8),
        Icon(_editingLocId != null ? Icons.edit_location_alt : Icons.add_location_alt, size: 20, color: W.pri),
      ]),
      const SizedBox(height: 12),
      _input(_locName, 'اسم الموقع', 'مدارس المروج النموذجية'),
      const SizedBox(height: 10),
      // ─── Search with Autocomplete Suggestions ───
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('ابحث عن الموقع', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub)),
        const SizedBox(height: 4),
        Row(children: [
          InkWell(onTap: _searching ? null : _searchLocation, child: Container(
            height: 44, padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: W.pri, borderRadius: BorderRadius.circular(4)),
            child: Center(child: _searching ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.search, size: 18, color: Colors.white)),
          )),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller: _locSearchCtrl,
            textAlign: TextAlign.right,
            style: GoogleFonts.tajawal(fontSize: 13),
            onChanged: (v) {},
            onSubmitted: (_) => _searchLocation(),
            decoration: InputDecoration(
              hintText: 'اكتب اسم المكان... مثال: مدارس المروج',
              hintStyle: GoogleFonts.tajawal(fontSize: 12, color: W.hint),
              filled: true, fillColor: W.bg, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.border)),
              suffixIcon: Icon(Icons.location_searching, size: 16, color: W.muted),
            ),
          )),
        ]),
        // ─── Autocomplete Suggestions Dropdown ───
        if (_searchResults.isNotEmpty) Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: Offset(0, 4))]),
          child: Column(children: [
            ..._searchResults.map((r) => InkWell(
              onTap: () => _selectSearchResult(r),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: W.div))),
                child: Row(children: [
                  const Spacer(),
                  Expanded(flex: 5, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(r['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: W.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if ((r['address'] ?? '').isNotEmpty) Text(r['address'], style: GoogleFonts.tajawal(fontSize: 11, color: W.muted), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ])),
                  const SizedBox(width: 10),
                  Container(width: 32, height: 32, decoration: BoxDecoration(color: W.redL, borderRadius: BorderRadius.circular(4)), child: Icon(Icons.location_on, size: 16, color: W.red)),
                ]),
              ),
            )),
          ]),
        ),
      ]),
      const SizedBox(height: 10),
      // ─── Google Map ───
      Container(
        height: isMobile ? 220 : 300, width: double.infinity,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
        clipBehavior: Clip.hardEdge,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: _pickedLatLng ?? const LatLng(24.7741, 46.7386), zoom: 15),
          onMapCreated: (ctrl) => _mapCtrl = ctrl,
          onTap: (pos) => setState(() { _pickedLatLng = pos; _locLat.text = pos.latitude.toStringAsFixed(6); _locLng.text = pos.longitude.toStringAsFixed(6); }),
          markers: _pickedLatLng != null ? {Marker(markerId: const MarkerId('picked'), position: _pickedLatLng!, infoWindow: const InfoWindow(title: 'الموقع المختار'))} : {},
          circles: _pickedLatLng != null ? {Circle(circleId: const CircleId('radius'), center: _pickedLatLng!, radius: double.tryParse(_locRadius.text) ?? 300, fillColor: const Color(0xFF17B26A).withOpacity(0.15), strokeColor: const Color(0xFF17B26A).withOpacity(0.5), strokeWidth: 2)} : {},
          myLocationEnabled: true, myLocationButtonEnabled: true, zoomControlsEnabled: true,
        ),
      ),
      const SizedBox(height: 8),
      if (_pickedLatLng != null) Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: W.greenL, borderRadius: BorderRadius.circular(4)),
        child: Wrap(alignment: WrapAlignment.center, spacing: 4, runSpacing: 2, children: [
          Text('${_pickedLatLng!.latitude.toStringAsFixed(4)}, ${_pickedLatLng!.longitude.toStringAsFixed(4)}', style: _mono(fontSize: 10, color: W.green)),
          Icon(Icons.check_circle, size: 14, color: W.green),
          Text('تم تحديد الموقع', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.green)),
        ]),
      ),
      if (_pickedLatLng == null) Text('ابحث عن الموقع أو اضغط على الخريطة لتحديده', style: GoogleFonts.tajawal(fontSize: 12, color: W.muted)),
      const SizedBox(height: 14),
      // ─── Radius Slider ───
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(6)),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: W.pri.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text('${int.tryParse(_locRadius.text) ?? 300} متر', style: GoogleFonts.ibmPlexMono(fontSize: 16, fontWeight: FontWeight.w800, color: W.pri))),
            Text('نطاق البصمة', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: W.text)),
          ]),
          const SizedBox(height: 8),
          Directionality(textDirection: TextDirection.ltr, child: Slider(
            value: (double.tryParse(_locRadius.text) ?? 300).clamp(50, 2000),
            min: 50, max: 2000, divisions: 39,
            activeColor: W.pri,
            label: '${int.tryParse(_locRadius.text) ?? 300}م',
            onChanged: (v) => setState(() => _locRadius.text = v.round().toString()),
          )),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('2000م', style: GoogleFonts.tajawal(fontSize: 10, color: W.hint)),
            Text('50م', style: GoogleFonts.tajawal(fontSize: 10, color: W.hint)),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        _greenBtn(_editingLocId != null ? '✓ حفظ التعديل' : '✓ إضافة', () async {
          if (_locName.text.isEmpty || _pickedLatLng == null) return;
          final data = {
            'name': _locName.text.trim(),
            'lat': _pickedLatLng!.latitude,
            'lng': _pickedLatLng!.longitude,
            'radius': int.tryParse(_locRadius.text) ?? 300,
            'active': true,
            'assignedEmployees': _locSelectedEmps.toList(),
          };
          if (_editingLocId != null) {
            await ApiService.post('admin.php?action=save_location', {...data, 'id': _editingLocId});
          } else {
            await ApiService.post('admin.php?action=save_location', data);
          }
          _resetLocForm();
          _loadSettings();
        }),
        const SizedBox(width: 8),
        _cancelBtn(() => _resetLocForm()),
      ]),
      // ─── Employee Assignment ───
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(children: [
            Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: W.pri.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text('${_locSelectedEmps.length} موظف', style: GoogleFonts.ibmPlexMono(fontSize: 11, fontWeight: FontWeight.w700, color: W.pri))),
            const Spacer(),
            Text('تحديد الموظفين لهذا الموقع', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: W.text)),
            const SizedBox(width: 8),
            Icon(Icons.people, size: 18, color: W.pri),
          ]),
          const SizedBox(height: 4),
          Text('اختر الموظفين المسموح لهم بالبصمة في هذا الموقع (اتركها فارغة للسماح للجميع)', style: GoogleFonts.tajawal(fontSize: 11, color: W.muted)),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end, children: _settingsUsers.map((emp) {
            final uid = emp['uid'] ?? emp['_id'];
            final sel = _locSelectedEmps.contains(uid);
            return InkWell(
              onTap: () => setState(() { sel ? _locSelectedEmps.remove(uid) : _locSelectedEmps.add(uid); }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: sel ? W.priLight : W.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: sel ? W.pri : W.border)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(sel ? Icons.check_circle : Icons.circle_outlined, size: 16, color: sel ? W.pri : W.muted),
                  const SizedBox(width: 6),
                  Text(emp['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? W.pri : W.text)),
                ]),
              ),
            );
          }).toList()),
        ]),
      ),
    ])),
    Column(children: _settingsLocations.map((loc) {
      final locId = loc['id'] ?? loc['_id'] ?? '';
      final active = loc['active'] ?? true;
      final radius = loc['radius'] ?? 200;
      final assignedEmps = ((loc['assignedEmployees'] ?? loc['assigned_employees']) as List?)?.cast<String>() ?? [];
      return Container(margin: EdgeInsets.only(bottom: 10), padding: EdgeInsets.all(isMobile ? 12 : 18), decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: active ? Color(0xFFABEFC6) : W.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            InkWell(onTap: () async { await ApiService.post('admin.php?action=delete_location', {'id': locId}); _loadSettings(); }, child: Container(width: 28, height: 28, decoration: BoxDecoration(color: Color(0xFFFEF3F2), borderRadius: BorderRadius.circular(4)), child: Icon(Icons.delete_outline, size: 14, color: W.red))),
            const SizedBox(width: 4),
            InkWell(onTap: () => _editLocation(locId, loc), child: Container(width: 28, height: 28, decoration: BoxDecoration(color: W.priLight, borderRadius: BorderRadius.circular(4)), child: Icon(Icons.edit, size: 14, color: W.pri))),
            const SizedBox(width: 4),
            SizedBox(width: 44, child: Switch(value: active, activeColor: W.green, onChanged: (v) async { await ApiService.post('admin.php?action=save_location', {...loc, 'id': locId, 'active': v}); _loadSettings(); })),
          ]),
          const Spacer(),
          Flexible(child: Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(loc['name'] ?? '', style: GoogleFonts.tajawal(fontSize: isMobile ? 13 : 14, fontWeight: FontWeight.w600, color: W.text), overflow: TextOverflow.ellipsis), Text('${(loc['lat'] ?? 0).toStringAsFixed(4)}, ${(loc['lng'] ?? 0).toStringAsFixed(4)}', style: GoogleFonts.ibmPlexMono(fontSize: 10, color: W.muted))])), SizedBox(width: 8), Container(width: isMobile ? 30 : 36, height: isMobile ? 30 : 36, decoration: BoxDecoration(color: active ? Color(0xFFECFDF3) : W.bg, borderRadius: BorderRadius.circular(6)), child: Icon(Icons.location_on, size: 14, color: active ? W.green : W.muted))])),
        ]),
        const SizedBox(height: 8),
        Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: W.priLight, borderRadius: BorderRadius.circular(4)),
          child: Text(assignedEmps.isEmpty ? 'جميع الموظفين' : '${assignedEmps.length} موظف مخصص', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.pri))),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${radius}م', style: GoogleFonts.ibmPlexMono(fontSize: 14, fontWeight: FontWeight.w700, color: W.pri)), Text('نطاق البصمة', style: GoogleFonts.tajawal(fontSize: 12, color: W.sub))]),
        Directionality(textDirection: TextDirection.ltr, child: Slider(value: (radius as num).toDouble(), min: 50, max: 1000, divisions: 19, activeColor: W.pri, label: '${radius}م', onChanged: (v) async { await ApiService.post('admin.php?action=save_location', {...loc, 'id': locId, 'radius': v.round()}); _loadSettings(); })),
      ]));
    }).toList()),
  ]); }

  // ─────────────────── أمان الأجهزة ───────────────────
  Widget _buildDeviceSecurity() {
    // Build session map: uid → session
    final sessionMap = <String, Map<String, dynamic>>{};
    for (final s in _settingsSessions) sessionMap[(s['uid'] ?? '').toString()] = s;

    final employees = _settingsUsers.where((e) => (e['name'] ?? '').toString().isNotEmpty && e['role'] != 'admin' && e['role'] != 'superadmin').toList();
    employees.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));

    // Filter
    var filtered = employees.where((emp) {
      final uid = (emp['uid'] ?? '').toString();
      final hasSession = sessionMap.containsKey(uid);
      if (_devFilter == 'online' && !hasSession) return false;
      if (_devFilter == 'offline' && hasSession) return false;
      if (_devSearch.isNotEmpty) {
        final q = _devSearch.toLowerCase();
        return (emp['name'] ?? '').toString().toLowerCase().contains(q) ||
               (emp['dept'] ?? '').toString().toLowerCase().contains(q) ||
               (sessionMap[uid]?['device_model'] ?? '').toString().toLowerCase().contains(q);
      }
      return true;
    }).toList();

    final onlineCount = employees.where((e) => sessionMap.containsKey((e['uid'] ?? '').toString())).length;
    final offlineCount = employees.length - onlineCount;

    final isMobile = MediaQuery.of(context).size.width < 500;
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [

      // ── Stats ──
      Row(children: [
        _devStatCard('متصل الآن', '$onlineCount', const Color(0xFF059669), const Color(0xFFD1FAE5), Icons.wifi_rounded),
        SizedBox(width: isMobile ? 6 : 10),
        _devStatCard('غير متصل', '$offlineCount', W.red, W.redL, Icons.wifi_off_rounded),
        SizedBox(width: isMobile ? 6 : 10),
        _devStatCard('إجمالي', '${employees.length}', W.muted, W.bg, Icons.people_rounded),
      ]),
      const SizedBox(height: 14),

      // ── Security notice ──
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF6EE7B7)),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('تقييد الجهاز الواحد مفعّل تلقائياً', style: GoogleFonts.tajawal(fontSize: isMobile ? 12 : 13, fontWeight: FontWeight.w700, color: const Color(0xFF065F46))),
            const SizedBox(height: 4),
            Text('لا يمكن لأي موظف فتح حسابه على جهازين في نفس الوقت — يجب تسجيل الخروج أو إنهاء الجلسة من هنا.', style: GoogleFonts.tajawal(fontSize: isMobile ? 10 : 11, color: const Color(0xFF047857), height: 1.6), textAlign: TextAlign.right),
          ])),
          const SizedBox(width: 10),
          Container(width: isMobile ? 34 : 40, height: isMobile ? 34 : 40, decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(6)),
            child: Icon(Icons.shield_rounded, size: isMobile ? 16 : 20, color: const Color(0xFF059669))),
        ]),
      ),

      // ── Search + filter ──
      if (isMobile) ...[
        Container(
          height: 38,
          decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(9), border: Border.all(color: W.border)),
          child: TextField(
            onChanged: (v) => setState(() => _devSearch = v),
            textAlign: TextAlign.right,
            style: GoogleFonts.tajawal(fontSize: 12, color: W.text),
            decoration: InputDecoration(
              hintText: 'بحث بالاسم أو الجهاز...',
              hintStyle: GoogleFonts.tajawal(fontSize: 12, color: W.hint),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              suffixIcon: Icon(Icons.search_rounded, size: 16, color: W.hint),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(9), border: Border.all(color: W.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _devFilterTab('all', 'الكل'),
            _devFilterTab('online', 'متصل'),
            _devFilterTab('offline', 'غير متصل'),
          ]),
        ),
      ] else Row(children: [
        // Filter tabs
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(9), border: Border.all(color: W.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _devFilterTab('all', 'الكل'),
            _devFilterTab('online', 'متصل'),
            _devFilterTab('offline', 'غير متصل'),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(
          height: 38,
          decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(9), border: Border.all(color: W.border)),
          child: TextField(
            onChanged: (v) => setState(() => _devSearch = v),
            textAlign: TextAlign.right,
            style: GoogleFonts.tajawal(fontSize: 12, color: W.text),
            decoration: InputDecoration(
              hintText: 'بحث بالاسم أو الجهاز...',
              hintStyle: GoogleFonts.tajawal(fontSize: 12, color: W.hint),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              suffixIcon: Icon(Icons.search_rounded, size: 16, color: W.hint),
            ),
          ),
        )),
      ]),
      const SizedBox(height: 14),

      // ── Employee list ──
      Container(
        decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
        child: filtered.isEmpty
          ? Padding(padding: const EdgeInsets.all(40), child: Center(child: Column(children: [
              Icon(Icons.devices_rounded, size: 40, color: W.hint),
              const SizedBox(height: 10),
              Text('لا يوجد نتائج', style: GoogleFonts.tajawal(fontSize: 13, color: W.muted)),
            ])))
          : Column(children: filtered.asMap().entries.map((entry) {
              final i = entry.key;
              final emp = entry.value;
              final uid = (emp['uid'] ?? '').toString();
              final session = sessionMap[uid];
              final hasSession = session != null;
              final isFirst = i == 0;
              final isLast = i == filtered.length - 1;

              final name = (emp['name'] ?? '').toString();
              final initials = name.length >= 2 ? name.substring(0, 2) : (name.isNotEmpty ? name[0] : 'م');
              final dept = (emp['dept'] ?? '').toString();
              final empId = (emp['emp_id'] ?? emp['empId'] ?? '').toString();
              final multi = emp['multi_device_allowed'] == 1 || emp['multi_device_allowed'] == true || emp['multiDeviceAllowed'] == true;

              // Device info from session
              final platform = (session?['platform'] ?? emp['last_platform'] ?? '').toString();
              final model = (session?['device_model'] ?? emp['last_device_model'] ?? '').toString();
              final osVer = (session?['os_version'] ?? emp['last_os_version'] ?? '').toString();
              final loginAt = session?['login_at']?.toString() ?? '';

              final pIcon = _getDeviceIcon(platform);
              final pColor = _devPlatformColor(platform);
              final statusColor = hasSession ? const Color(0xFF059669) : const Color(0xFFD0D5DD);

              String loginTime = '—';
              if (loginAt.isNotEmpty) {
                try {
                  final dt = DateTime.parse(loginAt);
                  final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
                  loginTime = '${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'م' : 'ص'}';
                } catch (_) {}
              }

              return Container(
                decoration: BoxDecoration(
                  borderRadius: isFirst
                    ? const BorderRadius.vertical(top: Radius.circular(14))
                    : isLast ? const BorderRadius.vertical(bottom: Radius.circular(14)) : BorderRadius.zero,
                  border: isFirst ? null : Border(top: BorderSide(color: W.div)),
                ),
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16, vertical: isMobile ? 10 : 14),
                child: isMobile
                  // ── Mobile: vertical layout ──
                  ? Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Row(children: [
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: hasSession ? const Color(0xFFD1FAE5) : W.bg, borderRadius: BorderRadius.circular(12)),
                          child: Text(hasSession ? 'متصل' : 'غير متصل', style: GoogleFonts.tajawal(fontSize: 9, fontWeight: FontWeight.w600, color: hasSession ? const Color(0xFF059669) : W.muted)),
                        ),
                        const Spacer(),
                        Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(name, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: W.text), overflow: TextOverflow.ellipsis),
                          Text('$dept · $empId', style: GoogleFonts.tajawal(fontSize: 10, color: W.muted), overflow: TextOverflow.ellipsis),
                        ])),
                        const SizedBox(width: 8),
                        Stack(children: [
                          Container(width: 36, height: 36, decoration: BoxDecoration(color: W.priLight, shape: BoxShape.circle),
                            child: Center(child: Text(initials, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w700, color: W.pri)))),
                          Positioned(bottom: 0, right: 0, child: Container(width: 10, height: 10,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor, border: Border.all(color: W.white, width: 1.5)))),
                        ]),
                      ]),
                      if (hasSession) ...[
                        const SizedBox(height: 6),
                        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                          if (osVer.isNotEmpty) Container(padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(4)),
                            child: Text(osVer, style: GoogleFonts.tajawal(fontSize: 9, color: W.muted))),
                          if (osVer.isNotEmpty) const SizedBox(width: 4),
                          Flexible(child: Text(model.isNotEmpty ? model : platform, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: W.text), overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 4),
                          Container(width: 22, height: 22, decoration: BoxDecoration(color: pColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                            child: Icon(pIcon, size: 12, color: pColor)),
                        ]),
                      ],
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 4, alignment: WrapAlignment.start, children: [
                        if (hasSession) GestureDetector(
                          onTap: () async {
                            await ApiService.post('admin.php?action=delete_session', {'uid': uid});
                            _loadSettings();
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('تم إنهاء جلسة $name', style: GoogleFonts.tajawal(color: Colors.white)),
                              backgroundColor: W.green, behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: W.redL, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.redBd)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.logout_rounded, size: 11, color: W.red),
                              const SizedBox(width: 3),
                              Text('إنهاء الجلسة', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: W.red)),
                            ]),
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            final newVal = !multi;
                            setState(() {
                              final idx = _settingsUsers.indexWhere((e) => (e['uid'] ?? '') == uid);
                              if (idx != -1) _settingsUsers[idx]['multi_device_allowed'] = newVal ? 1 : 0;
                            });
                            await ApiService.post('users.php?action=update', {'uid': uid, 'multi_device_allowed': newVal});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: multi ? Color(0xFFECFDF5) : W.bg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: multi ? Color(0xFF6EE7B7) : W.border),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(multi ? Icons.devices_rounded : Icons.phone_android_rounded, size: 11, color: multi ? W.green : Color(0xFF9CA3AF)),
                              const SizedBox(width: 3),
                              Text(multi ? 'متعدد' : 'جهاز واحد', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: multi ? W.green : Color(0xFF9CA3AF))),
                            ]),
                          ),
                        ),
                      ]),
                    ])
                  // ── Desktop: original horizontal layout ──
                  : Row(children: [

                  // ── Actions ──
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    if (hasSession)
                      GestureDetector(
                        onTap: () async {
                          await ApiService.post('admin.php?action=delete_session', {'uid': uid});
                          _loadSettings();
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('تم إنهاء جلسة $name', style: GoogleFonts.tajawal(color: Colors.white)),
                            backgroundColor: W.green, behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: W.redL, borderRadius: BorderRadius.circular(7), border: Border.all(color: W.redBd)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.logout_rounded, size: 12, color: W.red),
                            const SizedBox(width: 4),
                            Text('إنهاء الجلسة', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: W.red)),
                          ]),
                        ),
                      ),
                    if (hasSession) const SizedBox(height: 6),
                    GestureDetector(
                        onTap: () async {
                          final newVal = !multi;
                          setState(() {
                            final idx = _settingsUsers.indexWhere((e) => (e['uid'] ?? '') == uid);
                            if (idx != -1) _settingsUsers[idx]['multi_device_allowed'] = newVal ? 1 : 0;
                          });
                          await ApiService.post('users.php?action=update', {'uid': uid, 'multi_device_allowed': newVal});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: multi ? Color(0xFFECFDF5) : W.bg,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: multi ? Color(0xFF6EE7B7) : W.border),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(multi ? Icons.devices_rounded : Icons.phone_android_rounded, size: 12, color: multi ? W.green : Color(0xFF9CA3AF)),
                            const SizedBox(width: 4),
                            Text(multi ? 'متعدد' : 'جهاز واحد', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: multi ? W.green : Color(0xFF9CA3AF))),
                          ]),
                        ),
                      ),
                  ]),
                  const SizedBox(width: 10),

                  // ── Device info ──
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    if (hasSession) ...[
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        Flexible(child: Text(model.isNotEmpty ? model : platform, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.text), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 6),
                        Container(width: 28, height: 28, decoration: BoxDecoration(color: pColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                          child: Icon(pIcon, size: 14, color: pColor)),
                      ]),
                      const SizedBox(height: 3),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        if (osVer.isNotEmpty) ...[
                          Container(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(4)),
                            child: Text(osVer, style: GoogleFonts.tajawal(fontSize: 9, color: W.muted))),
                          const SizedBox(width: 4),
                        ],
                        if (loginTime != '—') ...[
                          Icon(Icons.access_time_rounded, size: 10, color: W.muted),
                          const SizedBox(width: 3),
                          Text('دخل $loginTime', style: GoogleFonts.tajawal(fontSize: 10, color: W.muted)),
                        ],
                      ]),
                    ] else ...[
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        if (model.isNotEmpty) Flexible(child: Text(model, style: GoogleFonts.tajawal(fontSize: 11, color: W.sub), overflow: TextOverflow.ellipsis)),
                        if (model.isNotEmpty) const SizedBox(width: 4),
                        Text('غير متصل', style: GoogleFonts.tajawal(fontSize: 11, color: W.muted)),
                      ]),
                    ],
                  ])),
                  const SizedBox(width: 10),

                  // ── Employee ──
                  Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(name, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: W.text), overflow: TextOverflow.ellipsis),
                    Text('$dept · $empId', style: GoogleFonts.tajawal(fontSize: 10, color: W.muted), overflow: TextOverflow.ellipsis),
                  ])),
                  const SizedBox(width: 10),

                  // ── Avatar with status dot ──
                  Stack(children: [
                    Container(width: 40, height: 40, decoration: BoxDecoration(color: W.priLight, shape: BoxShape.circle),
                      child: Center(child: Text(initials, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: W.pri)))),
                    Positioned(bottom: 0, right: 0, child: Container(width: 12, height: 12,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor, border: Border.all(color: W.white, width: 2)))),
                  ]),
                ]),
              );
            }).toList()),
      ),
    ]);
  }

  Widget _devStatCard(String label, String val, Color color, Color bg, IconData icon) {
    final isMobile = MediaQuery.of(context).size.width < 500;
    return Expanded(child: Container(
      padding: EdgeInsets.all(isMobile ? 10 : 14),
      decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(width: isMobile ? 26 : 30, height: isMobile ? 26 : 30, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
          child: Icon(icon, size: isMobile ? 12 : 14, color: color)),
        const SizedBox(height: 6),
        Text(val, style: GoogleFonts.ibmPlexMono(fontSize: isMobile ? 15 : 18, fontWeight: FontWeight.w800, color: W.text)),
        Text(label, style: GoogleFonts.tajawal(fontSize: isMobile ? 9 : 10, color: W.sub)),
      ]),
    ));
  }

  Widget _devFilterTab(String val, String label) {
    final on = _devFilter == val;
    return GestureDetector(
      onTap: () => setState(() => _devFilter = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: on ? W.pri : Colors.transparent, borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: on ? FontWeight.w700 : FontWeight.w400, color: on ? Colors.white : W.sub)),
      ),
    );
  }

  Color _devPlatformColor(String p) {
    final s = p.toLowerCase();
    if (s.contains('ios') || s.contains('iphone')) return const Color(0xFF555555);
    if (s.contains('android')) return const Color(0xFF3DDC84);
    if (s.contains('web')) return const Color(0xFF1D4ED8);
    return W.muted;
  }

  IconData _getDeviceIcon(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('ios') || p.contains('iphone')) return Icons.phone_iphone;
    if (p.contains('android')) return Icons.phone_android;
    if (p.contains('web')) return Icons.computer;
    return Icons.devices;
  }

  // ─────────────────── الأوفرتايم ───────────────────
  Widget _buildOvertime() {
    final isWide = MediaQuery.of(context).size.width > 800;
    final cards = [
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        _cardHeader('ساعات العمل الرسمية', Icons.access_time, W.pri),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          SizedBox(width: 80, child: TextField(
            controller: TextEditingController(text: _generalH.toStringAsFixed(1)),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexMono(fontSize: 18, fontWeight: FontWeight.w800, color: W.pri),
            decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: W.border)), suffixText: 'h'),
            onChanged: (v) { final val = double.tryParse(v); if (val != null && val >= 1 && val <= 24) setState(() => _generalH = val); },
          )),
          Text('ساعات/يوم', style: GoogleFonts.tajawal(fontSize: 12, color: W.sub)),
        ]),
      ])),
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        _cardHeader('معامل الأوفرتايم', Icons.more_time, W.orange),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          SizedBox(width: 80, child: TextField(
            controller: TextEditingController(text: _overtimeRate.toStringAsFixed(2)),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexMono(fontSize: 18, fontWeight: FontWeight.w800, color: W.orange),
            decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: W.border)), prefixText: '×'),
            onChanged: (v) { final val = double.tryParse(v); if (val != null && val >= 1 && val <= 5) setState(() => _overtimeRate = val); },
          )),
          Text('من الراتب', style: GoogleFonts.tajawal(fontSize: 12, color: W.sub)),
        ]),
      ])),
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        _cardHeader('تفعيل الأوفرتايم', Icons.more_time, W.orange),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Switch(value: _overtimeActive, activeColor: W.green, onChanged: (v) => setState(() => _overtimeActive = v)),
          Text(_overtimeActive ? 'مفعّل' : 'معطّل', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600, color: _overtimeActive ? W.green : W.muted)),
        ]),
        const SizedBox(height: 4),
        Text('أي ساعات فوق المحدد = أوفرتايم', style: GoogleFonts.tajawal(fontSize: 11, color: W.muted)),
      ])),
    ];

    if (isWide) {
      return Row(children: [
        Expanded(child: cards[0]), const SizedBox(width: 14),
        Expanded(child: cards[1]), const SizedBox(width: 14),
        Expanded(child: cards[2]),
      ]);
    }
    return Column(children: [
      cards[0], const SizedBox(height: 10),
      cards[1], const SizedBox(height: 10),
      cards[2],
    ]);
  }

  // ─────────────────── التأخير (صفحة منفصلة) ───────────────────
  Widget _buildLateSettings() {
    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      _cardHeader('سماحية التأخير', Icons.timer_off, W.red),
      const SizedBox(height: 8),
      Text('عدد الدقائق المسموحة قبل احتساب الموظف متأخراً', style: GoogleFonts.tajawal(fontSize: 12, color: W.muted), textAlign: TextAlign.right),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        SizedBox(width: 100, child: TextField(
          controller: TextEditingController(text: '$_lateGraceMinutes'),
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: GoogleFonts.ibmPlexMono(fontSize: 20, fontWeight: FontWeight.w800, color: W.red),
          decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: W.border)), suffixText: 'د'),
          onChanged: (v) { final val = int.tryParse(v); if (val != null && val >= 0 && val <= 120) setState(() => _lateGraceMinutes = val); },
        )),
        Text('سماحية التأخير (بالدقائق)', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: W.text)),
      ]),
      const SizedBox(height: 12),
      Container(
        width: double.infinity, padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFFEF3F2), borderRadius: BorderRadius.circular(6)),
        child: Text('مثال: لو السماحية 15 دقيقة والدوام يبدأ 8:00 — الموظف اللي يجي 8:15 أو قبل مش متأخر، بس 8:16 يتحسب متأخر', style: GoogleFonts.tajawal(fontSize: 11, color: W.red, height: 1.6), textAlign: TextAlign.right),
      ),
    ]));
  }

  // ─────────────────── المصادقة ───────────────────
  Widget _buildAuth() => Column(children: [
    _card(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      _cardHeader('إعدادات المصادقة العامة', Icons.shield, W.pri),
      const SizedBox(height: 4),
      Text('هذه الإعدادات تُطبّق على جميع الموظفين — يمكنك تخصيص موظف معين من الأسفل', style: GoogleFonts.tajawal(fontSize: 11, color: W.muted), textAlign: TextAlign.right),
      const SizedBox(height: 10),
    ])),
    _toggleCard('التعرف على الوجه', 'التحقق من هوية الموظف عبر الكاميرا', Icons.face, W.pri, _authFace, (v) => setState(() => _authFace = v)),
    _toggleCard('البصمة الرقمية', 'بصمة الإصبع عبر الجهاز', Icons.fingerprint, W.green, _authFinger, (v) => setState(() => _authFinger = v)),
    _toggleCard('التحقق من الموقع', 'التأكد من التواجد في نطاق العمل', Icons.location_on, W.orange, _authLoc, (v) => setState(() => _authLoc = v)),
    const SizedBox(height: 20),
    // ─── Per-employee override ───
    _card(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      _cardHeader('تخصيص موظف معين', Icons.person_pin, const Color(0xFF7F56D9)),
      Text('السماح أو منع البصمة/الموقع لموظف محدد بشكل مختلف عن الإعداد العام', style: GoogleFonts.tajawal(fontSize: 11, color: W.muted), textAlign: TextAlign.right),
      const SizedBox(height: 12),
      Builder(builder: (_) {
          final users = _settingsUsers.where((e) => (e['name'] ?? '').toString().isNotEmpty && e['role'] != 'admin').toList();
          users.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
          if (users.isEmpty) return Text('لا يوجد موظفين', style: GoogleFonts.tajawal(fontSize: 12, color: W.muted));
          return Column(children: users.map((emp) {
            final uid = emp['uid'] ?? emp['_id'];
            final hasOverride = emp['authOverride'] == true;
            final empBio = emp['authBiometric'] ?? true;
            final empLoc = emp['authLoc'] ?? true;
            final empFace = emp['authFace'] ?? _authFace;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: hasOverride ? Color(0xFFF4F3FF) : W.bg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: hasOverride ? Color(0xFF7F56D9).withOpacity(0.3) : W.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(children: [
                  InkWell(
                    onTap: () async {
                      await ApiService.post('users.php?action=update', {
                        'uid': uid,
                        'authOverride': !hasOverride,
                        if (!hasOverride) 'authBiometric': _authFinger,
                        if (!hasOverride) 'authLoc': _authLoc,
                        if (!hasOverride) 'authFace': _authFace,
                      });
                      _loadSettings();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: hasOverride ? Color(0xFF7F56D9).withOpacity(0.1) : W.div, borderRadius: BorderRadius.circular(6)),
                      child: Text(hasOverride ? 'إلغاء التخصيص' : 'تخصيص', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: hasOverride ? Color(0xFF7F56D9) : W.sub)),
                    ),
                  ),
                  const Spacer(),
                  Text(emp['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: W.text)),
                  const SizedBox(width: 6),
                  Icon(hasOverride ? Icons.tune : Icons.person_outline, size: 16, color: hasOverride ? Color(0xFF7F56D9) : W.muted),
                ]),
                if (hasOverride) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Switch(value: empFace, activeColor: W.green, onChanged: (v) async { await ApiService.post('users.php?action=update', {'uid': uid, 'authFace': v}); _loadSettings(); }),
                    const Spacer(),
                    Row(children: [
                      Text('بصمة الوجه', style: GoogleFonts.tajawal(fontSize: 12, color: W.text)),
                      const SizedBox(width: 4),
                      Icon(Icons.face, size: 14, color: W.pri),
                    ]),
                  ]),
                  Row(children: [
                    Switch(value: empBio, activeColor: W.green, onChanged: (v) async { await ApiService.post('users.php?action=update', {'uid': uid, 'authBiometric': v}); _loadSettings(); }),
                    const Spacer(),
                    Row(children: [
                      Text('البصمة', style: GoogleFonts.tajawal(fontSize: 12, color: W.text)),
                      const SizedBox(width: 4),
                      Icon(Icons.fingerprint, size: 14, color: W.green),
                    ]),
                  ]),
                  Row(children: [
                    Switch(value: empLoc, activeColor: W.green, onChanged: (v) async { await ApiService.post('users.php?action=update', {'uid': uid, 'authLoc': v}); _loadSettings(); }),
                    const Spacer(),
                    Row(children: [
                      Text('الموقع', style: GoogleFonts.tajawal(fontSize: 12, color: W.text)),
                      const SizedBox(width: 4),
                      Icon(Icons.location_on, size: 14, color: W.orange),
                    ]),
                  ]),
                  // Face reset button
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      await ApiService.post('face.php?action=reset', {'uid': uid});
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إعادة تعيين بصمة الوجه لـ ${emp['name']}', style: GoogleFonts.tajawal()), backgroundColor: W.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: W.redL, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.redBd)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('إعادة تعيين بصمة الوجه', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: W.red)),
                        const SizedBox(width: 4),
                        Icon(Icons.refresh, size: 12, color: W.red),
                      ]),
                    ),
                  ),
                ],
              ]),
            );
          }).toList());
        }),
    ])),
  ]);

  // ─────────────────── الأمان ───────────────────
  Widget _buildSecurity() => Column(children: [
    _card(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      _cardHeader('التحقق بخطوتين (2FA)', Icons.lock, W.red),
      _secToggle('تفعيل التحقق بخطوتين', 'إرسال رمز تحقق عبر SMS أو البريد عند تسجيل الدخول', _twoFA, (v) => setState(() => _twoFA = v)),
      _secToggle('إشعار تسجيل الدخول', 'إخطار المدير عند أي تسجيل دخول جديد', _loginNotify, (v) => setState(() => _loginNotify = v)),
      _secToggle('إشعار محاولات الدخول الفاشلة', 'تنبيه فوري عند محاولة دخول فاشلة', _failedNotify, (v) => setState(() => _failedNotify = v)),
    ])),
    const SizedBox(height: 14),
    _card(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      _cardHeader('سياسات الأمان', Icons.shield, const Color(0xFF7F56D9)),
      _sliderSetting('مهلة انتهاء الجلسة (بالدقائق)', _sessionTimeout, 5, 120, 23, W.pri, (v) => setState(() => _sessionTimeout = v)),
      _sliderSetting('عدد محاولات الدخول المسموحة', _maxAttempts, 1, 10, 9, W.red, (v) => setState(() => _maxAttempts = v)),
      _sliderSetting('إجبار تغيير كلمة المرور (كل X يوم)', _forcePassChange, 7, 365, 51, W.orange, (v) => setState(() => _forcePassChange = v)),
      _secToggle('تقييد IP', 'السماح فقط لعناوين محددة', _ipWhitelist, (v) => setState(() => _ipWhitelist = v)),
    ])),
  ]);

  // ─────────────────── المظهر ───────────────────
  Widget _buildAppearance() => Column(children: [
    _card(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      _cardHeader('تخصيص المظهر', Icons.desktop_windows, W.pri),
      const SizedBox(height: 10),
      _input(TextEditingController(text: _orgName), 'اسم المؤسسة', 'مدارس المروج النموذجية الأهلية'),
      const SizedBox(height: 14),
      Align(alignment: Alignment.centerRight, child: Text('حجم الخط', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub))),
      const SizedBox(height: 6),
      Row(children: [{'k': 'small', 'l': 'صغير'}, {'k': 'medium', 'l': 'متوسط'}, {'k': 'large', 'l': 'كبير'}].map((f) => Expanded(child: Padding(padding: EdgeInsets.only(left: 6), child: InkWell(onTap: () => setState(() => _fontSize = f['k']!), child: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: _fontSize == f['k'] ? W.priLight : W.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: _fontSize == f['k'] ? W.pri : W.border, width: _fontSize == f['k'] ? 2 : 1)), child: Center(child: Text(f['l']!, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: _fontSize == f['k'] ? W.pri : W.sub)))))))).toList()),
    ])),
    const SizedBox(height: 14),
    _card(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      _cardHeader('خيارات العرض', Icons.visibility, const Color(0xFF0BA5EC)),
      _secToggle('الوضع المضغوط', 'تقليل المسافات والحجوم لعرض بيانات أكثر', _compactMode, (v) => setState(() => _compactMode = v)),
    ])),
  ]);

  // ─────────────────── بصمة مخصصة ───────────────────
  Widget _buildCustomAtt() { final isMobile = MediaQuery.of(context).size.width < 500; return Column(children: [
    isMobile ? Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('افتح البصمة لموظف محدد في وقت معين', style: GoogleFonts.tajawal(fontSize: 12, color: W.sub)),
      const SizedBox(height: 8),
      ElevatedButton.icon(onPressed: () => setState(() => _showAddAtt = true), icon: const Icon(Icons.add, size: 14), label: Text('فتح بصمة لموظف', style: GoogleFonts.tajawal(fontWeight: FontWeight.w600, fontSize: 13)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE8F8FD), foregroundColor: const Color(0xFF0BA5EC), side: const BorderSide(color: Color(0xFF0BA5EC)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)))),
    ]) : Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      ElevatedButton.icon(onPressed: () => setState(() => _showAddAtt = true), icon: const Icon(Icons.add, size: 14), label: Text('فتح بصمة لموظف', style: GoogleFonts.tajawal(fontWeight: FontWeight.w600, fontSize: 13)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE8F8FD), foregroundColor: const Color(0xFF0BA5EC), side: const BorderSide(color: Color(0xFF0BA5EC)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)))),
      Flexible(child: Text('افتح البصمة لموظف محدد في وقت معين', style: GoogleFonts.tajawal(fontSize: 14, color: W.sub))),
    ]),
    const SizedBox(height: 14),
    if (_showAddAtt) _card(border: const Color(0xFF0BA5EC), child: Column(children: [
      isMobile ? Column(children: [
        _input(_attDate, 'التاريخ', '18 مارس 2026'),
        const SizedBox(height: 8),
        Row(children: [Expanded(child: _input(_attEnd, 'إلى', '02:00 م', isLtr: true)), const SizedBox(width: 10), Expanded(child: _input(_attStart, 'من', '10:00 ص', isLtr: true))]),
        const SizedBox(height: 8),
        _input(_attReason, 'السبب', 'مهمة خارجية'),
      ]) : Row(children: [Expanded(child: _input(_attReason, 'السبب', 'مهمة خارجية')), const SizedBox(width: 10), Expanded(child: _input(_attEnd, 'إلى', '02:00 م', isLtr: true)), const SizedBox(width: 10), Expanded(child: _input(_attStart, 'من', '10:00 ص', isLtr: true)), const SizedBox(width: 10), Expanded(child: _input(_attDate, 'التاريخ', '18 مارس 2026'))]),
      const SizedBox(height: 12),
      Row(children: [ElevatedButton(onPressed: () { setState(() { _customAtt.add({'id': DateTime.now().millisecondsSinceEpoch, 'empName': 'موظف', 'date': _attDate.text, 'start': _attStart.text, 'end': _attEnd.text, 'reason': _attReason.text, 'status': 'مفعّل'}); _attDate.clear(); _attStart.clear(); _attEnd.clear(); _attReason.clear(); _showAddAtt = false; }); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0BA5EC), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))), child: Text('✓ فتح البصمة', style: GoogleFonts.tajawal(fontWeight: FontWeight.w600))), const SizedBox(width: 8), _cancelBtn(() => setState(() => _showAddAtt = false))]),
    ])),
    ..._customAtt.map((a) => Container(margin: EdgeInsets.only(bottom: 10), padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 22, vertical: isMobile ? 12 : 16), decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)), child: Row(children: [
      Row(mainAxisSize: MainAxisSize.min, children: [InkWell(onTap: () => setState(() => _customAtt.removeWhere((x) => x['id'] == a['id'])), child: Icon(Icons.delete_outline, size: 14, color: W.red)), SizedBox(width: 6), Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Color(0xFFECFDF3), borderRadius: BorderRadius.circular(20)), child: Text(a['status'] as String, style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: W.green)))]),
      const Spacer(),
      Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: Text(a['empName'] as String, style: GoogleFonts.tajawal(fontSize: isMobile ? 13 : 14, fontWeight: FontWeight.w600, color: W.text), overflow: TextOverflow.ellipsis)), SizedBox(width: 6), Icon(Icons.lock_open, size: 14, color: Color(0xFF0BA5EC))]), Text('${a['date']} — من ${a['start']} إلى ${a['end']}', style: GoogleFonts.tajawal(fontSize: isMobile ? 10 : 12, color: W.sub), overflow: TextOverflow.ellipsis), Text('السبب: ${a['reason']}', style: GoogleFonts.tajawal(fontSize: isMobile ? 10 : 11, color: W.muted), overflow: TextOverflow.ellipsis)])),
    ]))),
    if (_customAtt.isEmpty) _card(child: Center(child: Padding(padding: EdgeInsets.all(20), child: Text('لا توجد بصمات مخصصة', style: GoogleFonts.tajawal(fontSize: 13, color: W.muted))))),
  ]); }

  // ═══════════ Shared Widgets ═══════════
  Widget _card({Widget? child, Color? border}) { final isMobile = MediaQuery.of(context).size.width < 500; return Container(margin: EdgeInsets.only(bottom: isMobile ? 10 : 14), padding: EdgeInsets.all(isMobile ? 14 : 22), decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: border ?? W.border, width: border != null ? 2 : 1)), child: child); }
  Widget _cardHeader(String title, IconData icon, Color color) { final isMobile = MediaQuery.of(context).size.width < 500; return Padding(padding: EdgeInsets.only(bottom: isMobile ? 10 : 14), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [Flexible(child: Text(title, style: GoogleFonts.tajawal(fontSize: isMobile ? 14 : 15, fontWeight: FontWeight.w700, color: W.text), overflow: TextOverflow.ellipsis)), SizedBox(width: 8), Container(width: isMobile ? 34 : 40, height: isMobile ? 34 : 40, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Icon(icon, size: isMobile ? 16 : 18, color: color))])); }
  Widget _timeBox(String label, String time, Color color) { final isMobile = MediaQuery.of(context).size.width < 500; return Container(padding: EdgeInsets.all(isMobile ? 8 : 12), decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(6)), child: Column(children: [Text(label, style: GoogleFonts.tajawal(fontSize: isMobile ? 10 : 11, color: W.muted)), SizedBox(height: 4), Text(time, style: GoogleFonts.ibmPlexMono(fontSize: isMobile ? 14 : 18, fontWeight: FontWeight.w700, color: color))])); }
  Widget _input(TextEditingController ctrl, String label, String hint, {bool isLtr = false}) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(label, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub)), SizedBox(height: 4), TextField(controller: ctrl, textAlign: isLtr ? TextAlign.center : TextAlign.right, style: GoogleFonts.tajawal(fontSize: 13), decoration: InputDecoration(hintText: hint, hintStyle: GoogleFonts.tajawal(color: W.hint, fontSize: 12), filled: true, fillColor: W.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: W.border)), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)))]);
  Widget _addBtn(String label, VoidCallback onTap) => ElevatedButton.icon(onPressed: onTap, icon: Icon(Icons.add, size: 14), label: Text(label, style: GoogleFonts.tajawal(fontWeight: FontWeight.w600, fontSize: 13)), style: ElevatedButton.styleFrom(backgroundColor: W.priLight, foregroundColor: W.pri, side: BorderSide(color: W.pri, style: BorderStyle.solid), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))));
  Widget _greenBtn(String label, VoidCallback onTap) => ElevatedButton(onPressed: onTap, style: ElevatedButton.styleFrom(backgroundColor: W.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))), child: Text(label, style: GoogleFonts.tajawal(fontWeight: FontWeight.w600)));
  Widget _cancelBtn(VoidCallback onTap) => TextButton(onPressed: onTap, child: Text('إلغاء', style: GoogleFonts.tajawal(color: W.sub)));
  Widget _toggleCard(String title, String desc, IconData icon, Color color, bool value, Function(bool) onChanged) { final isMobile = MediaQuery.of(context).size.width < 500; return Container(margin: EdgeInsets.only(bottom: 10), padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 22, vertical: isMobile ? 12 : 18), decoration: BoxDecoration(color: W.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: W.border)), child: Row(children: [Switch(value: value, activeColor: W.green, onChanged: onChanged), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(title, style: GoogleFonts.tajawal(fontSize: isMobile ? 13 : 15, fontWeight: FontWeight.w600, color: W.text), overflow: TextOverflow.ellipsis), Text(desc, style: GoogleFonts.tajawal(fontSize: isMobile ? 10 : 12, color: W.muted), overflow: TextOverflow.ellipsis, maxLines: 2)])), SizedBox(width: isMobile ? 8 : 12), Container(width: isMobile ? 34 : 42, height: isMobile ? 34 : 42, decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(6)), child: Icon(icon, size: isMobile ? 16 : 20, color: color))])); }
  Widget _secToggle(String title, String desc, bool value, Function(bool) onChanged) => Container(padding: EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: W.div))), child: Row(children: [Switch(value: value, activeColor: W.green, onChanged: onChanged), const SizedBox(width: 4), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(title, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: W.text), overflow: TextOverflow.ellipsis), Text(desc, style: GoogleFonts.tajawal(fontSize: 11, color: W.muted), overflow: TextOverflow.ellipsis, maxLines: 2)]))]));
  Widget _sliderSetting(String label, double value, double min, double max, int divisions, Color color, Function(double) onChanged) => Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(label, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: W.sub), overflow: TextOverflow.ellipsis), Row(children: [Text('${value.round()}', style: GoogleFonts.ibmPlexMono(fontSize: 16, fontWeight: FontWeight.w700, color: color)), const SizedBox(width: 4), Expanded(child: Slider(value: value, min: min, max: max, divisions: divisions, activeColor: color, onChanged: onChanged))])]));
}
