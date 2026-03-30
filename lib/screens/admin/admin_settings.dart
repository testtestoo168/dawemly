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

  final _mono = GoogleFonts.ibmPlexMono;

  static const _mapsApiKey = 'AIzaSyB-CkusFlHFxJujo_GagT1kSNoQtmCq630';

  // Search using Google Places Autocomplete API directly
  // Helper to add CORS proxy for web
  String _proxyUrl(String url) {
    if (kIsWeb) return 'https://corsproxy.io/?${Uri.encodeComponent(url)}';
    return url;
  }

  void _searchLocation() async {
    if (_locSearchCtrl.text.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final query = Uri.encodeComponent(_locSearchCtrl.text.trim());
      
      // Use Text Search directly (simpler, one API call)
      final tsUrl = 'https://maps.googleapis.com/maps/api/place/textsearch/json?query=$query&language=ar&key=$_mapsApiKey';
      final tsResponse = await http.get(Uri.parse(_proxyUrl(tsUrl)));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لم يتم العثور على نتائج — جرّب كلمات أخرى', style: GoogleFonts.tajawal()), backgroundColor: C.orange, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
      }
    } catch (e) {
      setState(() => _searchResults = []);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في البحث: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e}', style: GoogleFonts.tajawal()), backgroundColor: C.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في حفظ الإعدادات: $e', style: GoogleFonts.tajawal()), backgroundColor: C.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    try {
      final res = await ApiService.get('admin.php?action=get_settings');
      final d = res['settings'] as Map<String, dynamic>? ?? {};
      final usersRes = await ApiService.get('users.php?action=list');
      final locsRes = await ApiService.get('admin.php?action=get_locations');
      final sessRes = await ApiService.get('admin.php?action=get_sessions');
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
        _settingsUsers = (usersRes['users'] as List? ?? []).cast<Map<String, dynamic>>().where((e) => (e['name'] ?? '').toString().isNotEmpty && e['role'] != 'admin').toList();
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
    {'k': 'auth', 'l': 'المصادقة', 'icon': Icons.shield},
    {'k': 'security', 'l': 'الأمان', 'icon': Icons.lock},
    {'k': 'appearance', 'l': 'المظهر', 'icon': Icons.desktop_windows},
    {'k': 'custom', 'l': 'بصمة مخصصة', 'icon': Icons.lock_open},
    {'k': 'devicesec', 'l': 'أمان الأجهزة', 'icon': Icons.phone_android},
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    return SingleChildScrollView(padding: EdgeInsets.all(isWide ? 28 : 14), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      // Header
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        ElevatedButton.icon(onPressed: _save, icon: Icon(_saved ? Icons.check : Icons.save, size: 16), label: Text(_saved ? 'تم الحفظ' : 'حفظ الإعدادات', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)), style: ElevatedButton.styleFrom(backgroundColor: _saved ? C.green : C.pri, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
        Flexible(child: Text('الإعدادات', style: GoogleFonts.tajawal(fontSize: isWide ? 24 : 18, fontWeight: FontWeight.w800, color: C.text))),
      ]),
      const SizedBox(height: 20),

      // Sub-tabs
      Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end, children: _tabs.map((t) => InkWell(
        onTap: () => setState(() => _tab = t['k'] as String),
        borderRadius: BorderRadius.circular(10),
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9), decoration: BoxDecoration(color: _tab == t['k'] ? C.pri : C.white, borderRadius: BorderRadius.circular(10), border: _tab == t['k'] ? null : Border.all(color: C.border)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(t['icon'] as IconData, size: 15, color: _tab == t['k'] ? Colors.white : C.sub), const SizedBox(width: 6), Text(t['l'] as String, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: _tab == t['k'] ? Colors.white : C.sub))])),
      )).toList()),
      const SizedBox(height: 24),

      // ═══════ فترات العمل ═══════
      if (_tab == 'shifts') _buildShifts(),
      // ═══════ المواقع ═══════
      if (_tab == 'locations') _buildLocations(),
      // ═══════ الأوفرتايم ═══════
      if (_tab == 'overtime') _buildOvertime(),
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
  Widget _buildShifts() => Column(children: [
    if (_showAddShift) _card(border: C.pri, child: Column(children: [
      Row(children: [Expanded(child: _input(_shiftEnd, 'وقت الانتهاء', '04:00 م', isLtr: true)), const SizedBox(width: 10), Expanded(child: _input(_shiftStart, 'وقت البداية', '08:00 ص', isLtr: true)), const SizedBox(width: 10), Expanded(flex: 2, child: _input(_shiftName, 'اسم الفترة', 'الفترة الرابعة'))]),
      const SizedBox(height: 12),
      Row(children: [_greenBtn('✓ إضافة', () { if (_shiftName.text.isEmpty) return; setState(() { _shifts.add({'id': DateTime.now().millisecondsSinceEpoch, 'name': _shiftName.text, 'start': _shiftStart.text, 'end': _shiftEnd.text, 'color': [C.pri, const Color(0xFF7F56D9), const Color(0xFF0BA5EC), C.orange][_shifts.length % 4], 'active': true}); _shiftName.clear(); _shiftStart.clear(); _shiftEnd.clear(); _showAddShift = false; }); }), const SizedBox(width: 8), _cancelBtn(() => setState(() => _showAddShift = false))]),
    ])),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_addBtn('إضافة فترة', () => setState(() => _showAddShift = true)), Flexible(child: Text('حدد فترات العمل — كل فترة بوقت بداية ونهاية', style: GoogleFonts.tajawal(fontSize: 12, color: C.sub)))]),
    const SizedBox(height: 14),
    ...List.generate(_shifts.length, (i) { final sh = _shifts[i]; final color = sh['color'] as Color; return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: sh['active'] == true ? color.withOpacity(0.3) : C.border)), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Switch(value: sh['active'] == true, activeColor: C.green, onChanged: (v) => setState(() => _shifts[i]['active'] = v)), InkWell(onTap: () => setState(() => _shifts.removeAt(i)), child: const Icon(Icons.delete_outline, size: 16, color: C.red))]), Row(children: [Text(sh['name'] as String, style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)), const SizedBox(width: 10), Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.access_time, size: 20, color: color))])]),
      const SizedBox(height: 14),
      Row(children: [Expanded(child: _timeBox('البداية', sh['start'] as String, color)), const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('→', style: TextStyle(fontSize: 20, color: C.hint))), Expanded(child: _timeBox('النهاية', sh['end'] as String, color))]),
    ])); }),
  ]);

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
      final assigned = (loc['assignedEmployees'] as List?)?.cast<String>() ?? [];
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

  Widget _buildLocations() => Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_addBtn('إضافة موقع', () => setState(() { _editingLocId = null; _showAddLoc = true; })), Flexible(child: Text('مواقع العمل المعتمدة — الموظف يبصم في أي موقع مفعّل', style: GoogleFonts.tajawal(fontSize: 12, color: C.sub)))]),
    const SizedBox(height: 14),
    if (_showAddLoc) _card(border: C.pri, child: Column(children: [
      // Edit/Add header
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text(_editingLocId != null ? 'تعديل الموقع' : 'إضافة موقع جديد', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: C.text)),
        const SizedBox(width: 8),
        Icon(_editingLocId != null ? Icons.edit_location_alt : Icons.add_location_alt, size: 20, color: C.pri),
      ]),
      const SizedBox(height: 12),
      _input(_locName, 'اسم الموقع', 'مدارس المروج النموذجية'),
      const SizedBox(height: 10),
      // ─── Search with Autocomplete Suggestions ───
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('ابحث عن الموقع', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.sub)),
        const SizedBox(height: 4),
        Row(children: [
          InkWell(onTap: _searching ? null : _searchLocation, child: Container(
            height: 44, padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: C.pri, borderRadius: BorderRadius.circular(8)),
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
              hintStyle: GoogleFonts.tajawal(fontSize: 12, color: C.hint),
              filled: true, fillColor: C.bg, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.border)),
              suffixIcon: const Icon(Icons.location_searching, size: 16, color: C.muted),
            ),
          )),
        ]),
        // ─── Autocomplete Suggestions Dropdown ───
        if (_searchResults.isNotEmpty) Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))]),
          child: Column(children: [
            ..._searchResults.map((r) => InkWell(
              onTap: () => _selectSearchResult(r),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.div))),
                child: Row(children: [
                  const Spacer(),
                  Expanded(flex: 5, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(r['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: C.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if ((r['address'] ?? '').isNotEmpty) Text(r['address'], style: GoogleFonts.tajawal(fontSize: 11, color: C.muted), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ])),
                  const SizedBox(width: 10),
                  Container(width: 32, height: 32, decoration: BoxDecoration(color: C.redL, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.location_on, size: 16, color: C.red)),
                ]),
              ),
            )),
          ]),
        ),
      ]),
      const SizedBox(height: 10),
      // ─── Google Map ───
      Container(
        height: 300, width: double.infinity,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: C.greenL, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${_pickedLatLng!.latitude.toStringAsFixed(4)}, ${_pickedLatLng!.longitude.toStringAsFixed(4)}', style: _mono(fontSize: 11, color: C.green)),
          const SizedBox(width: 6),
          const Icon(Icons.check_circle, size: 14, color: C.green),
          const SizedBox(width: 4),
          Text('تم تحديد الموقع', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.green)),
        ]),
      ),
      if (_pickedLatLng == null) Text('ابحث عن الموقع أو اضغط على الخريطة لتحديده', style: GoogleFonts.tajawal(fontSize: 12, color: C.muted)),
      const SizedBox(height: 14),
      // ─── Radius Slider ───
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: C.pri.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('${int.tryParse(_locRadius.text) ?? 300} متر', style: GoogleFonts.ibmPlexMono(fontSize: 16, fontWeight: FontWeight.w800, color: C.pri))),
            Text('نطاق البصمة', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: C.text)),
          ]),
          const SizedBox(height: 8),
          Directionality(textDirection: TextDirection.ltr, child: Slider(
            value: (double.tryParse(_locRadius.text) ?? 300).clamp(50, 2000),
            min: 50, max: 2000, divisions: 39,
            activeColor: C.pri,
            label: '${int.tryParse(_locRadius.text) ?? 300}م',
            onChanged: (v) => setState(() => _locRadius.text = v.round().toString()),
          )),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('2000م', style: GoogleFonts.tajawal(fontSize: 10, color: C.hint)),
            Text('50م', style: GoogleFonts.tajawal(fontSize: 10, color: C.hint)),
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
        decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: C.pri.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('${_locSelectedEmps.length} موظف', style: GoogleFonts.ibmPlexMono(fontSize: 11, fontWeight: FontWeight.w700, color: C.pri))),
            const Spacer(),
            Text('تحديد الموظفين لهذا الموقع', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: C.text)),
            const SizedBox(width: 8),
            const Icon(Icons.people, size: 18, color: C.pri),
          ]),
          const SizedBox(height: 4),
          Text('اختر الموظفين المسموح لهم بالبصمة في هذا الموقع (اتركها فارغة للسماح للجميع)', style: GoogleFonts.tajawal(fontSize: 11, color: C.muted)),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end, children: _settingsUsers.map((emp) {
            final uid = emp['uid'] ?? emp['_id'];
            final sel = _locSelectedEmps.contains(uid);
            return InkWell(
              onTap: () => setState(() { sel ? _locSelectedEmps.remove(uid) : _locSelectedEmps.add(uid); }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: sel ? C.priLight : C.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: sel ? C.pri : C.border)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(sel ? Icons.check_circle : Icons.circle_outlined, size: 16, color: sel ? C.pri : C.muted),
                  const SizedBox(width: 6),
                  Text(emp['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? C.pri : C.text)),
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
      final assignedEmps = (loc['assignedEmployees'] as List?)?.cast<String>() ?? [];
      return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: active ? const Color(0xFFABEFC6) : C.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [
          InkWell(onTap: () async { await ApiService.post('admin.php?action=delete_location', {'id': locId}); _loadSettings(); }, child: Container(width: 30, height: 30, decoration: BoxDecoration(color: const Color(0xFFFEF3F2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.delete_outline, size: 16, color: C.red))),
          const SizedBox(width: 6),
          InkWell(onTap: () => _editLocation(locId, loc), child: Container(width: 30, height: 30, decoration: BoxDecoration(color: C.priLight, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.edit, size: 16, color: C.pri))),
          const SizedBox(width: 6),
          Switch(value: active, activeColor: C.green, onChanged: (v) async { await ApiService.post('admin.php?action=save_location', {...loc, 'id': locId, 'active': v}); _loadSettings(); }),
        ]), Row(children: [Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(loc['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600, color: C.text)), Text('${(loc['lat'] ?? 0).toStringAsFixed(4)}, ${(loc['lng'] ?? 0).toStringAsFixed(4)}', style: GoogleFonts.ibmPlexMono(fontSize: 11, color: C.muted))]), const SizedBox(width: 10), Container(width: 36, height: 36, decoration: BoxDecoration(color: active ? const Color(0xFFECFDF3) : C.bg, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.location_on, size: 16, color: active ? C.green : C.muted))])]),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: C.priLight, borderRadius: BorderRadius.circular(8)),
          child: Text(assignedEmps.isEmpty ? 'جميع الموظفين' : '${assignedEmps.length} موظف مخصص', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: C.pri))),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${radius}م', style: GoogleFonts.ibmPlexMono(fontSize: 14, fontWeight: FontWeight.w700, color: C.pri)), Text('نطاق البصمة', style: GoogleFonts.tajawal(fontSize: 12, color: C.sub))]),
        Directionality(textDirection: TextDirection.ltr, child: Slider(value: (radius as num).toDouble(), min: 50, max: 1000, divisions: 19, activeColor: C.pri, label: '${radius}م', onChanged: (v) async { await ApiService.post('admin.php?action=save_location', {...loc, 'id': locId, 'radius': v.round()}); _loadSettings(); })),
      ]));
    }).toList()),
  ]);

  // ─────────────────── أمان الأجهزة ───────────────────
  Widget _buildDeviceSecurity() => Column(children: [
    _card(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      _cardHeader('التحكم في الأجهزة', Icons.phone_android, C.pri),
      _secToggle(
        'تقييد جهاز واحد',
        'منع الموظف من تسجيل الدخول على أكثر من جهاز في نفس الوقت — يجب تسجيل الخروج من الجهاز الأول',
        _singleDeviceMode,
        (v) => setState(() => _singleDeviceMode = v),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(children: [
            const Spacer(),
            Text('كيف يعمل هذا الخيار؟', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: C.text)),
            const SizedBox(width: 8),
            Container(width: 32, height: 32, decoration: BoxDecoration(color: C.priLight, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.info_outline, size: 16, color: C.pri)),
          ]),
          const SizedBox(height: 8),
          Text('عند تفعيل هذا الخيار، إذا حاول الموظف فتح حسابه من جهاز آخر، سيظهر له رسالة تطلب منه تسجيل الخروج من الجهاز الأول أولاً.', style: GoogleFonts.tajawal(fontSize: 12, color: C.sub, height: 1.6), textAlign: TextAlign.right),
        ]),
      ),
    ])),
    const SizedBox(height: 14),
    // ─── Per-employee multi-device permission ───
    if (_singleDeviceMode) _card(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      _cardHeader('استثناء موظفين من التقييد', Icons.people_outline, const Color(0xFF7F56D9)),
      Text('السماح لموظفين معينين باستخدام أكثر من جهاز حتى مع تفعيل التقييد', style: GoogleFonts.tajawal(fontSize: 11, color: C.muted), textAlign: TextAlign.right),
      const SizedBox(height: 12),
      _settingsUsers.isEmpty
        ? Padding(padding: const EdgeInsets.all(12), child: Text('لا يوجد موظفين', style: GoogleFonts.tajawal(fontSize: 12, color: C.muted)))
        : Column(mainAxisSize: MainAxisSize.min, children: _settingsUsers.map((emp) {
            final uid = emp['uid'] ?? emp['_id'];
            final allowed = emp['multiDeviceAllowed'] == true;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: allowed ? const Color(0xFFFFFAEB) : C.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: allowed ? C.orangeBd : C.border)),
              child: Row(children: [
                Switch(value: allowed, activeColor: C.orange, onChanged: (v) async { await ApiService.post('users.php?action=update', {'uid': uid, 'multiDeviceAllowed': v}); _loadSettings(); }),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(emp['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: C.text)),
                  Text(allowed ? 'مسموح بأكثر من جهاز' : 'جهاز واحد فقط', style: GoogleFonts.tajawal(fontSize: 10, color: allowed ? C.orange : C.muted)),
                ]),
                const SizedBox(width: 8),
                Icon(allowed ? Icons.devices : Icons.phone_android, size: 18, color: allowed ? C.orange : C.muted),
              ]),
            );
          }).toList()),
    ])),
    if (_singleDeviceMode) const SizedBox(height: 14),
    // ─── Active sessions ───
    _card(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      _cardHeader('الأجهزة النشطة الآن', Icons.devices, const Color(0xFF0BA5EC)),
      _settingsSessions.isEmpty
        ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('لا توجد أجهزة نشطة حالياً', style: GoogleFonts.tajawal(fontSize: 13, color: C.muted))))
        : Column(mainAxisSize: MainAxisSize.min, children: _settingsSessions.map((s) {
            final sessionId = s['id'] ?? s['_id'] ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
              child: Row(children: [
                InkWell(
                  onTap: () async {
                    await ApiService.post('admin.php?action=delete_session', {'id': sessionId});
                    _loadSettings();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إنهاء الجلسة', style: GoogleFonts.tajawal()), backgroundColor: C.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                  },
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: C.redL, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.redBd)),
                    child: Text('إنهاء', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: C.red))),
                ),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(s['userName'] ?? '—', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: C.text)),
                  Text(s['deviceModel'] ?? 'جهاز غير معروف', style: GoogleFonts.tajawal(fontSize: 11, color: C.sub)),
                  if ((s['osVersion'] ?? '').toString().isNotEmpty) Text(s['osVersion'], style: GoogleFonts.tajawal(fontSize: 10, color: C.muted)),
                ]),
                const SizedBox(width: 10),
                Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFE8F8FD), borderRadius: BorderRadius.circular(10)),
                  child: Icon(_getDeviceIcon(s['platform'] ?? ''), size: 18, color: const Color(0xFF0BA5EC))),
              ]),
            );
          }).toList()),
    ])),
  ]);

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
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [_cardHeader('ساعات العمل الرسمية', Icons.access_time, C.pri), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${_generalH.toStringAsFixed(1)}h', style: GoogleFonts.ibmPlexMono(fontSize: 22, fontWeight: FontWeight.w800, color: C.pri)), Text('ساعات/يوم', style: GoogleFonts.tajawal(fontSize: 12, color: C.sub))]), const SizedBox(height: 8), Slider(value: _generalH, min: 4, max: 12, divisions: 16, activeColor: C.pri, onChanged: (v) => setState(() => _generalH = v))])),
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [_cardHeader('معامل الأوفرتايم', Icons.more_time, C.orange), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('×${_overtimeRate.toStringAsFixed(2)}', style: GoogleFonts.ibmPlexMono(fontSize: 22, fontWeight: FontWeight.w800, color: C.orange)), Text('من الراتب', style: GoogleFonts.tajawal(fontSize: 12, color: C.sub))]), const SizedBox(height: 8), Slider(value: _overtimeRate, min: 1, max: 3, divisions: 8, activeColor: C.orange, onChanged: (v) => setState(() => _overtimeRate = v))])),
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [_cardHeader('تفعيل الأوفرتايم', Icons.more_time, C.orange), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Switch(value: _overtimeActive, activeColor: C.green, onChanged: (v) => setState(() => _overtimeActive = v)), Text(_overtimeActive ? 'مفعّل' : 'معطّل', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600, color: _overtimeActive ? C.green : C.muted))]), const SizedBox(height: 6), Text('أي ساعات فوق المحدد = أوفرتايم', style: GoogleFonts.tajawal(fontSize: 11, color: C.muted))])),
    ];
    
    final lateCard = _card(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      _cardHeader('سماحية التأخير', Icons.timer_off, C.red),
      const SizedBox(height: 4),
      Text('عدد الدقائق المسموحة قبل احتساب الموظف متأخر', style: GoogleFonts.tajawal(fontSize: 11, color: C.muted), textAlign: TextAlign.right),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('$_lateGraceMinutes دقيقة', style: GoogleFonts.ibmPlexMono(fontSize: 22, fontWeight: FontWeight.w800, color: C.red)),
        Text('سماحية', style: GoogleFonts.tajawal(fontSize: 12, color: C.sub)),
      ]),
      const SizedBox(height: 8),
      Slider(value: _lateGraceMinutes.toDouble(), min: 0, max: 60, divisions: 12, activeColor: C.red, onChanged: (v) => setState(() => _lateGraceMinutes = v.round())),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('60 دقيقة', style: GoogleFonts.tajawal(fontSize: 10, color: C.muted)),
        Text('0 دقيقة', style: GoogleFonts.tajawal(fontSize: 10, color: C.muted)),
      ]),
    ]));
    
    if (isWide) {
      return Column(children: [
        Row(children: [
          Expanded(child: cards[0]), const SizedBox(width: 14),
          Expanded(child: cards[1]), const SizedBox(width: 14),
          Expanded(child: cards[2]),
        ]),
        const SizedBox(height: 14),
        lateCard,
      ]);
    }
    return Column(children: [
      cards[0], const SizedBox(height: 10),
      cards[1], const SizedBox(height: 10),
      cards[2], const SizedBox(height: 10),
      lateCard,
    ]);
  }

  // ─────────────────── المصادقة ───────────────────
  Widget _buildAuth() => Column(children: [
    _card(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      _cardHeader('إعدادات المصادقة العامة', Icons.shield, C.pri),
      const SizedBox(height: 4),
      Text('هذه الإعدادات تُطبّق على جميع الموظفين — يمكنك تخصيص موظف معين من الأسفل', style: GoogleFonts.tajawal(fontSize: 11, color: C.muted), textAlign: TextAlign.right),
      const SizedBox(height: 10),
    ])),
    _toggleCard('التعرف على الوجه', 'التحقق من هوية الموظف عبر الكاميرا', Icons.face, C.pri, _authFace, (v) => setState(() => _authFace = v)),
    _toggleCard('البصمة الرقمية', 'بصمة الإصبع عبر الجهاز', Icons.fingerprint, C.green, _authFinger, (v) => setState(() => _authFinger = v)),
    _toggleCard('التحقق من الموقع', 'التأكد من التواجد في نطاق العمل', Icons.location_on, C.orange, _authLoc, (v) => setState(() => _authLoc = v)),
    const SizedBox(height: 20),
    // ─── Per-employee override ───
    _card(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      _cardHeader('تخصيص موظف معين', Icons.person_pin, const Color(0xFF7F56D9)),
      Text('السماح أو منع البصمة/الموقع لموظف محدد بشكل مختلف عن الإعداد العام', style: GoogleFonts.tajawal(fontSize: 11, color: C.muted), textAlign: TextAlign.right),
      const SizedBox(height: 12),
      Builder(builder: (_) {
          final users = _settingsUsers.where((e) => (e['name'] ?? '').toString().isNotEmpty && e['role'] != 'admin').toList();
          users.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
          if (users.isEmpty) return Text('لا يوجد موظفين', style: GoogleFonts.tajawal(fontSize: 12, color: C.muted));
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
                color: hasOverride ? const Color(0xFFF4F3FF) : C.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: hasOverride ? const Color(0xFF7F56D9).withOpacity(0.3) : C.border),
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
                      decoration: BoxDecoration(color: hasOverride ? const Color(0xFF7F56D9).withOpacity(0.1) : C.div, borderRadius: BorderRadius.circular(6)),
                      child: Text(hasOverride ? 'إلغاء التخصيص' : 'تخصيص', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: hasOverride ? const Color(0xFF7F56D9) : C.sub)),
                    ),
                  ),
                  const Spacer(),
                  Text(emp['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: C.text)),
                  const SizedBox(width: 6),
                  Icon(hasOverride ? Icons.tune : Icons.person_outline, size: 16, color: hasOverride ? const Color(0xFF7F56D9) : C.muted),
                ]),
                if (hasOverride) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Switch(value: empFace, activeColor: C.green, onChanged: (v) async { await ApiService.post('users.php?action=update', {'uid': uid, 'authFace': v}); _loadSettings(); }),
                    const Spacer(),
                    Row(children: [
                      Text('بصمة الوجه', style: GoogleFonts.tajawal(fontSize: 12, color: C.text)),
                      const SizedBox(width: 4),
                      const Icon(Icons.face, size: 14, color: C.pri),
                    ]),
                  ]),
                  Row(children: [
                    Switch(value: empBio, activeColor: C.green, onChanged: (v) async { await ApiService.post('users.php?action=update', {'uid': uid, 'authBiometric': v}); _loadSettings(); }),
                    const Spacer(),
                    Row(children: [
                      Text('البصمة', style: GoogleFonts.tajawal(fontSize: 12, color: C.text)),
                      const SizedBox(width: 4),
                      const Icon(Icons.fingerprint, size: 14, color: C.green),
                    ]),
                  ]),
                  Row(children: [
                    Switch(value: empLoc, activeColor: C.green, onChanged: (v) async { await ApiService.post('users.php?action=update', {'uid': uid, 'authLoc': v}); _loadSettings(); }),
                    const Spacer(),
                    Row(children: [
                      Text('الموقع', style: GoogleFonts.tajawal(fontSize: 12, color: C.text)),
                      const SizedBox(width: 4),
                      const Icon(Icons.location_on, size: 14, color: C.orange),
                    ]),
                  ]),
                  // Face reset button
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      await ApiService.post('face.php?action=reset', {'uid': uid});
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إعادة تعيين بصمة الوجه لـ ${emp['name']}', style: GoogleFonts.tajawal()), backgroundColor: C.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: C.redL, borderRadius: BorderRadius.circular(6), border: Border.all(color: C.redBd)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('إعادة تعيين بصمة الوجه', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: C.red)),
                        const SizedBox(width: 4),
                        const Icon(Icons.refresh, size: 12, color: C.red),
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
      _cardHeader('التحقق بخطوتين (2FA)', Icons.lock, C.red),
      _secToggle('تفعيل التحقق بخطوتين', 'إرسال رمز تحقق عبر SMS أو البريد عند تسجيل الدخول', _twoFA, (v) => setState(() => _twoFA = v)),
      _secToggle('إشعار تسجيل الدخول', 'إخطار المدير عند أي تسجيل دخول جديد', _loginNotify, (v) => setState(() => _loginNotify = v)),
      _secToggle('إشعار محاولات الدخول الفاشلة', 'تنبيه فوري عند محاولة دخول فاشلة', _failedNotify, (v) => setState(() => _failedNotify = v)),
    ])),
    const SizedBox(height: 14),
    _card(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      _cardHeader('سياسات الأمان', Icons.shield, const Color(0xFF7F56D9)),
      _sliderSetting('مهلة انتهاء الجلسة (بالدقائق)', _sessionTimeout, 5, 120, 23, C.pri, (v) => setState(() => _sessionTimeout = v)),
      _sliderSetting('عدد محاولات الدخول المسموحة', _maxAttempts, 1, 10, 9, C.red, (v) => setState(() => _maxAttempts = v)),
      _sliderSetting('إجبار تغيير كلمة المرور (كل X يوم)', _forcePassChange, 7, 365, 51, C.orange, (v) => setState(() => _forcePassChange = v)),
      _secToggle('تقييد IP', 'السماح فقط لعناوين محددة', _ipWhitelist, (v) => setState(() => _ipWhitelist = v)),
    ])),
  ]);

  // ─────────────────── المظهر ───────────────────
  Widget _buildAppearance() => Column(children: [
    _card(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      _cardHeader('تخصيص المظهر', Icons.desktop_windows, C.pri),
      const SizedBox(height: 10),
      _input(TextEditingController(text: _orgName), 'اسم المؤسسة', 'مدارس المروج النموذجية الأهلية'),
      const SizedBox(height: 14),
      Align(alignment: Alignment.centerRight, child: Text('حجم الخط', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.sub))),
      const SizedBox(height: 6),
      Row(children: [{'k': 'small', 'l': 'صغير'}, {'k': 'medium', 'l': 'متوسط'}, {'k': 'large', 'l': 'كبير'}].map((f) => Expanded(child: Padding(padding: const EdgeInsets.only(left: 6), child: InkWell(onTap: () => setState(() => _fontSize = f['k']!), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _fontSize == f['k'] ? C.priLight : C.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _fontSize == f['k'] ? C.pri : C.border, width: _fontSize == f['k'] ? 2 : 1)), child: Center(child: Text(f['l']!, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: _fontSize == f['k'] ? C.pri : C.sub)))))))).toList()),
    ])),
    const SizedBox(height: 14),
    _card(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      _cardHeader('خيارات العرض', Icons.visibility, const Color(0xFF0BA5EC)),
      _secToggle('الوضع المضغوط', 'تقليل المسافات والحجوم لعرض بيانات أكثر', _compactMode, (v) => setState(() => _compactMode = v)),
    ])),
  ]);

  // ─────────────────── بصمة مخصصة ───────────────────
  Widget _buildCustomAtt() => Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      ElevatedButton.icon(onPressed: () => setState(() => _showAddAtt = true), icon: const Icon(Icons.add, size: 14), label: Text('فتح بصمة لموظف', style: GoogleFonts.tajawal(fontWeight: FontWeight.w600, fontSize: 13)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE8F8FD), foregroundColor: const Color(0xFF0BA5EC), side: const BorderSide(color: Color(0xFF0BA5EC)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
      Text('افتح البصمة لموظف محدد في وقت معين', style: GoogleFonts.tajawal(fontSize: 14, color: C.sub)),
    ]),
    const SizedBox(height: 14),
    if (_showAddAtt) _card(border: const Color(0xFF0BA5EC), child: Column(children: [
      Row(children: [Expanded(child: _input(_attReason, 'السبب', 'مهمة خارجية')), const SizedBox(width: 10), Expanded(child: _input(_attEnd, 'إلى', '02:00 م', isLtr: true)), const SizedBox(width: 10), Expanded(child: _input(_attStart, 'من', '10:00 ص', isLtr: true)), const SizedBox(width: 10), Expanded(child: _input(_attDate, 'التاريخ', '18 مارس 2026'))]),
      const SizedBox(height: 12),
      Row(children: [ElevatedButton(onPressed: () { setState(() { _customAtt.add({'id': DateTime.now().millisecondsSinceEpoch, 'empName': 'موظف', 'date': _attDate.text, 'start': _attStart.text, 'end': _attEnd.text, 'reason': _attReason.text, 'status': 'مفعّل'}); _attDate.clear(); _attStart.clear(); _attEnd.clear(); _attReason.clear(); _showAddAtt = false; }); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0BA5EC), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: Text('✓ فتح البصمة', style: GoogleFonts.tajawal(fontWeight: FontWeight.w600))), const SizedBox(width: 8), _cancelBtn(() => setState(() => _showAddAtt = false))]),
    ])),
    ..._customAtt.map((a) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16), decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)), child: Row(children: [
      Row(children: [InkWell(onTap: () => setState(() => _customAtt.removeWhere((x) => x['id'] == a['id'])), child: const Icon(Icons.delete_outline, size: 14, color: C.red)), const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFECFDF3), borderRadius: BorderRadius.circular(20)), child: Text(a['status'] as String, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: C.green)))]),
      const Spacer(),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Row(children: [Text(a['empName'] as String, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600, color: C.text)), const SizedBox(width: 6), const Icon(Icons.lock_open, size: 16, color: Color(0xFF0BA5EC))]), Text('${a['date']} — من ${a['start']} إلى ${a['end']}', style: GoogleFonts.tajawal(fontSize: 12, color: C.sub)), Text('السبب: ${a['reason']}', style: GoogleFonts.tajawal(fontSize: 11, color: C.muted))]),
    ]))),
    if (_customAtt.isEmpty) _card(child: Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('لا توجد بصمات مخصصة', style: GoogleFonts.tajawal(fontSize: 13, color: C.muted))))),
  ]);

  // ═══════════ Shared Widgets ═══════════
  Widget _card({Widget? child, Color? border}) => Container(margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: border ?? C.border, width: border != null ? 2 : 1)), child: child);
  Widget _cardHeader(String title, IconData icon, Color color) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text(title, style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: C.text)), const SizedBox(width: 8), Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: color))]));
  Widget _timeBox(String label, String time, Color color) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(10)), child: Column(children: [Text(label, style: GoogleFonts.tajawal(fontSize: 11, color: C.muted)), const SizedBox(height: 4), Text(time, style: GoogleFonts.ibmPlexMono(fontSize: 18, fontWeight: FontWeight.w700, color: color))]));
  Widget _input(TextEditingController ctrl, String label, String hint, {bool isLtr = false}) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(label, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.sub)), const SizedBox(height: 4), TextField(controller: ctrl, textAlign: isLtr ? TextAlign.center : TextAlign.right, style: GoogleFonts.tajawal(fontSize: 13), decoration: InputDecoration(hintText: hint, hintStyle: GoogleFonts.tajawal(color: C.hint), filled: true, fillColor: C.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.border)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)))]);
  Widget _addBtn(String label, VoidCallback onTap) => ElevatedButton.icon(onPressed: onTap, icon: const Icon(Icons.add, size: 14), label: Text(label, style: GoogleFonts.tajawal(fontWeight: FontWeight.w600, fontSize: 13)), style: ElevatedButton.styleFrom(backgroundColor: C.priLight, foregroundColor: C.pri, side: BorderSide(color: C.pri, style: BorderStyle.solid), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  Widget _greenBtn(String label, VoidCallback onTap) => ElevatedButton(onPressed: onTap, style: ElevatedButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: Text(label, style: GoogleFonts.tajawal(fontWeight: FontWeight.w600)));
  Widget _cancelBtn(VoidCallback onTap) => TextButton(onPressed: onTap, child: Text('إلغاء', style: GoogleFonts.tajawal(color: C.sub)));
  Widget _toggleCard(String title, String desc, IconData icon, Color color, bool value, Function(bool) onChanged) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18), decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Switch(value: value, activeColor: C.green, onChanged: onChanged), Row(children: [Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(title, style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w600, color: C.text)), Text(desc, style: GoogleFonts.tajawal(fontSize: 12, color: C.muted))]), const SizedBox(width: 12), Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 20, color: color))])]));
  Widget _secToggle(String title, String desc, bool value, Function(bool) onChanged) => Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.div))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Switch(value: value, activeColor: C.green, onChanged: onChanged), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(title, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600, color: C.text)), Text(desc, style: GoogleFonts.tajawal(fontSize: 12, color: C.muted))]))]));
  Widget _sliderSetting(String label, double value, double min, double max, int divisions, Color color, Function(double) onChanged) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(label, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.sub)), Row(children: [Text('${value.round()}', style: GoogleFonts.ibmPlexMono(fontSize: 18, fontWeight: FontWeight.w700, color: color)), const Spacer(), Expanded(flex: 3, child: Slider(value: value, min: min, max: max, divisions: divisions, activeColor: color, onChanged: onChanged))])]));
}
