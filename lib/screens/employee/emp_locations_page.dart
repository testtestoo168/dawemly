import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

class EmpLocationsPage extends StatefulWidget {
  final Map<String, dynamic> user;
  const EmpLocationsPage({super.key, required this.user});
  @override
  State<EmpLocationsPage> createState() => _EmpLocationsPageState();
}

class _EmpLocationsPageState extends State<EmpLocationsPage> {
  TextStyle _tj(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);

  List<Map<String, dynamic>> _locations = [];
  bool _loading = true;
  GoogleMapController? _mapController;
  Position? _myPosition;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _loadData() async {
    // Load locations and current position in parallel
    final locFuture = _fetchLocations();
    final posFuture = _fetchPosition();
    final locs = await locFuture;
    final pos = await posFuture;
    if (mounted) {
      setState(() {
        _locations = locs;
        _myPosition = pos;
        _loading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchLocations() async {
    final result = await ApiService.get('admin.php?action=get_locations');
    if (result['success'] == true) {
      final allLocs = (result['locations'] as List? ?? []).cast<Map<String, dynamic>>();
      return allLocs.where((loc) {
        final active = loc['active'];
        if (active == false || active == 0) return false;
        final assigned = (loc['assignedEmployees'] as List?)?.cast<String>() ??
            (loc['assigned_employees'] as List?)?.cast<String>() ?? [];
        return assigned.isEmpty || assigned.contains(widget.user['uid']);
      }).toList();
    }
    return [];
  }

  Future<Position?> _fetchPosition() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
    } catch (_) {
      return null;
    }
  }

  void _animateToLocation(int index) {
    if (index >= _locations.length) return;
    final loc = _locations[index];
    final lat = (loc['lat'] as num?)?.toDouble();
    final lng = (loc['lng'] as num?)?.toDouble();
    if (lat != null && lng != null && _mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16));
      setState(() => _selectedIndex = index);
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
        title: Text('مواقع العمل', style: _tj(17, weight: FontWeight.w700, color: C.text)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: C.text),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: C.border, height: 1)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: C.pri))
          : _locations.isEmpty
              ? Center(
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
                )
              : Column(
                  children: [
                    // Map
                    Expanded(
                      flex: 3,
                      child: _buildMap(),
                    ),
                    // Location cards
                    Expanded(
                      flex: 2,
                      child: _buildLocationsList(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildMap() {
    final markers = <Marker>{};
    final circles = <Circle>{};

    for (int i = 0; i < _locations.length; i++) {
      final loc = _locations[i];
      final lat = (loc['lat'] as num?)?.toDouble();
      final lng = (loc['lng'] as num?)?.toDouble();
      final radius = (loc['radius'] as num?)?.toDouble() ?? 300;
      final name = loc['name'] ?? 'موقع ${i + 1}';
      final isSelected = i == _selectedIndex;

      if (lat != null && lng != null) {
        markers.add(Marker(
          markerId: MarkerId('loc_$i'),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(title: name, snippet: 'النطاق: ${radius.toInt()}م'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isSelected ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange,
          ),
        ));

        circles.add(Circle(
          circleId: CircleId('zone_$i'),
          center: LatLng(lat, lng),
          radius: radius,
          fillColor: isSelected
              ? const Color(0xFF17B26A).withValues(alpha: 0.18)
              : const Color(0xFFFF9500).withValues(alpha: 0.10),
          strokeColor: isSelected ? const Color(0xFF17B26A) : const Color(0xFFFF9500),
          strokeWidth: 2,
        ));
      }
    }

    // Add employee position marker
    if (_myPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('my_position'),
        position: LatLng(_myPosition!.latitude, _myPosition!.longitude),
        infoWindow: const InfoWindow(title: 'موقعي الحالي'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }

    // Initial camera on first location
    final firstLoc = _locations.isNotEmpty ? _locations[_selectedIndex] : null;
    final initLat = (firstLoc?['lat'] as num?)?.toDouble() ?? _myPosition?.latitude ?? 24.7136;
    final initLng = (firstLoc?['lng'] as num?)?.toDouble() ?? _myPosition?.longitude ?? 46.6753;

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: LatLng(initLat, initLng), zoom: 15),
      markers: markers,
      circles: circles,
      onMapCreated: (c) => _mapController = c,
      myLocationEnabled: false,
      zoomControlsEnabled: true,
      mapToolbarEnabled: false,
    );
  }

  Widget _buildLocationsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _locations.length,
      itemBuilder: (ctx, i) {
        final loc = _locations[i];
        final radius = (loc['radius'] ?? 300) as num;
        final lat = (loc['lat'] as num?)?.toDouble();
        final lng = (loc['lng'] as num?)?.toDouble();
        final isSelected = i == _selectedIndex;

        // Calculate distance from employee
        String? distanceText;
        bool? isInside;
        if (_myPosition != null && lat != null && lng != null) {
          final dist = Geolocator.distanceBetween(_myPosition!.latitude, _myPosition!.longitude, lat, lng);
          isInside = dist <= radius;
          distanceText = dist < 1000
              ? '${dist.round()} م'
              : '${(dist / 1000).toStringAsFixed(1)} كم';
        }

        return GestureDetector(
          onTap: () => _animateToLocation(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: C.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isSelected ? C.green : C.border, width: isSelected ? 2 : 1),
              boxShadow: isSelected
                  ? [BoxShadow(color: C.green.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 2))]
                  : [],
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Distance & status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (distanceText != null)
                      Text(distanceText, style: GoogleFonts.ibmPlexMono(fontSize: 11, fontWeight: FontWeight.w600, color: C.sub)),
                    if (isInside != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isInside ? C.greenL : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isInside ? 'داخل النطاق' : 'خارج النطاق',
                          style: _tj(10, weight: FontWeight.w600, color: isInside ? C.green : C.red),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 8),
                // Radius badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: C.greenL,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('${radius.toInt()}م', style: _tj(11, weight: FontWeight.w600, color: C.green)),
                ),
                const Spacer(),
                // Info
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        loc['name'] ?? 'موقع',
                        style: _tj(14, weight: FontWeight.w700, color: C.text),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${(loc['lat'] ?? 0).toStringAsFixed(4)}, ${(loc['lng'] ?? 0).toStringAsFixed(4)}',
                        style: GoogleFonts.ibmPlexMono(fontSize: 10, color: C.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Icon
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? C.greenL : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.location_on_rounded, size: 20, color: isSelected ? C.green : C.sub),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
