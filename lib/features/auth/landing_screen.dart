import 'dart:async';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/api_keys.dart';
import '../../core/data/lgu_data.dart';
import '../../core/models/asset.dart';
import '../../core/models/household.dart';
import '../map/legend_widget.dart';
import '../map/marker_layer.dart';
import 'login_modal.dart';
import '../map/hazard_control_panel.dart';
import '../../core/models/triage_level.dart';
import '../../providers/active_hazards_provider.dart';

// ── Web Design System Colors (Light Mode Extracted from Screenshots) ──
const _bgBase = Color(0xFFF0F4F8);       // Light grayish-blue background for the sheet
const _bgSurface = Colors.white;         // White cards and inputs
const _border = Color(0xFFE2E8F0);       // Light borders
const _criticalRed = Color(0xFFDC2626);  // Header bottom border & alerts
const _accentBlue = Color(0xFF0A67D0);   // Primary buttons (Login, Search)
const _textPrimary = Color(0xFF1E293B);  // Dark text for headings
const _textMuted = Color(0xFF64748B);    // Gray text for subtitles
const _volcanoGradientStart = Color(0xFFFFF0E5); 
const _volcanoGradientEnd = Color(0xFFFFFBEB);

const _initialCamera = CameraPosition(
  target: LatLng(10.6765, 122.9509),
  zoom: 10.5,
);

const Map<String, LatLng> _cityCoords = {
  'Bacolod City':    LatLng(10.6765, 122.9509),
  'Bago City':       LatLng(10.5369, 122.8362),
  'Cadiz City':      LatLng(10.9532, 123.3026),
  'Escalante City':  LatLng(10.8424, 123.4965),
  'Himamaylan City': LatLng(10.0988, 122.8712),
  'Kabankalan City': LatLng(9.9870,  122.8150),
  'La Carlota City': LatLng(10.4211, 122.9220),
  'Sagay City':      LatLng(10.8978, 123.4239),
  'San Carlos City': LatLng(10.4925, 123.4142),
  'Silay City':      LatLng(10.7964, 122.9715),
  'Talisay City':    LatLng(10.7346, 122.9694),
  'Victorias City':  LatLng(10.9025, 123.0770),
};

const Map<String, List<Map<String, String>>> _hotlines = {
  'Bacolod City': [
    {'label': 'CDRRMO',             'number': '(034) 434-0116'},
    {'label': 'BFP Bacolod',        'number': '(034) 432-5401'},
    {'label': 'PNP Bacolod',        'number': '(034) 433-3060'},
    {'label': 'National Emergency', 'number': '911'},
  ],
  'Talisay City': [
    {'label': 'MDRRMO Talisay',     'number': '(034) 495-0114'},
    {'label': 'BFP Talisay',        'number': '(034) 495-0888'},
    {'label': 'National Emergency', 'number': '911'},
  ],
  'Silay City': [
    {'label': 'MDRRMO Silay',       'number': '(034) 495-5270'},
    {'label': 'BFP Silay',          'number': '(034) 495-5116'},
    {'label': 'National Emergency', 'number': '911'},
  ],
  'Bago City': [
    {'label': 'CDRRMO Bago',        'number': '(034) 461-0333'},
    {'label': 'National Emergency', 'number': '911'},
  ],
  'Cadiz City': [
    {'label': 'MDRRMO Cadiz',       'number': '(034) 493-0365'},
    {'label': 'National Emergency', 'number': '911'},
  ],
  'Escalante City': [
    {'label': 'MDRRMO Escalante',   'number': '(034) 454-0011'},
    {'label': 'National Emergency', 'number': '911'},
  ],
  'Himamaylan City': [
    {'label': 'MDRRMO Himamaylan',  'number': '(034) 388-2154'},
    {'label': 'National Emergency', 'number': '911'},
  ],
  'Kabankalan City': [
    {'label': 'CDRRMO Kabankalan',  'number': '(034) 471-2063'},
    {'label': 'National Emergency', 'number': '911'},
  ],
  'La Carlota City': [
    {'label': 'MDRRMO La Carlota',  'number': '(034) 460-0335'},
    {'label': 'National Emergency', 'number': '911'},
  ],
  'Sagay City': [
    {'label': 'CDRRMO Sagay',       'number': '(034) 488-0333'},
    {'label': 'National Emergency', 'number': '911'},
  ],
  'San Carlos City': [
    {'label': 'CDRRMO San Carlos',  'number': '(034) 312-5240'},
    {'label': 'National Emergency', 'number': '911'},
  ],
  'Victorias City': [
    {'label': 'MDRRMO Victorias',   'number': '(034) 399-2100'},
    {'label': 'National Emergency', 'number': '911'},
  ],
};

class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  String? _city;
  String? _barangay;
  Household? _selectedHousehold;

  // Area status
  Map<String, dynamic>? _areaStatus;
  bool _fetchingStatus = false;
  bool _noStatusData   = false;
  LatLng? _selectedCoords;

  final _dio = Dio();

  GoogleMapController? _mapController;
  Set<Marker> _markers    = {};
  MapType     _mapType    = MapType.normal;


  static const double _snapMin = 0.11; 
  static const double _snapMax = 0.85;

  final DraggableScrollableController _sheetCtrl = DraggableScrollableController();

  // ── Haversine distance ────────────────────────────────────────────────────
  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.pow(math.sin(dLng / 2), 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  String _hazardZoneLabel(double distKm, Map<String, dynamic> radii) {
    final critical = (radii['radius_critical'] as num?)?.toDouble() ?? 0;
    final high     = (radii['radius_high']     as num?)?.toDouble() ?? 0;
    final elevated = (radii['radius_elevated'] as num?)?.toDouble() ?? 0;
    final stable   = (radii['radius_stable']   as num?)?.toDouble() ?? 0;
    if (distKm <= critical) return 'Critical Zone';
    if (distKm <= high)     return 'High-Risk Zone';
    if (distKm <= elevated) return 'Elevated Zone';
    if (distKm <= stable)   return 'Stable Zone';
    return 'Outside Hazard Area';
  }

  Color _hazardZoneColor(double distKm, Map<String, dynamic> radii) {
    final critical = (radii['radius_critical'] as num?)?.toDouble() ?? 0;
    final high     = (radii['radius_high']     as num?)?.toDouble() ?? 0;
    final elevated = (radii['radius_elevated'] as num?)?.toDouble() ?? 0;
    final stable   = (radii['radius_stable']   as num?)?.toDouble() ?? 0;
    if (distKm <= critical) return const Color(0xFFDC2626);
    if (distKm <= high)     return const Color(0xFFF97316);
    if (distKm <= elevated) return const Color(0xFFEAB308);
    if (distKm <= stable)   return const Color(0xFF3B82F6);
    return const Color(0xFF22C55E);
  }

  String _hazardAdvisory(String type) {
    switch (type.toLowerCase()) {
      case 'volcano':
        return 'Ashfall warning. Stay indoors, seal windows, wear an N95 mask when going outside, and prepare an emergency go-bag with essential documents, medicine, and 3-day supplies.';
      case 'flood':
        return 'Monitor water levels closely. If you live near riverbanks or low-lying areas, evacuate immediately to the nearest evacuation center. Do not cross flooded roads.';
      case 'earthquake':
        return 'Aftershocks may occur. Stay away from damaged structures. Inspect your home for gas leaks and structural damage before re-entering.';
      case 'typhoon':
        return 'Secure loose objects outdoors. Stay indoors away from windows. Follow the local DRRMO for evacuation orders.';
      case 'landslide':
        return 'Avoid slopes and hillsides. Evacuate if you hear rumbling or notice tilting trees. Do not return until authorities declare it safe.';
      default:
        return 'A hazard has been detected near your area. Stay alert and follow the instructions of your local DRRMO.';
    }
  }

  Future<void> _geocodeBarangay(String barangay, String city) async {
    try {
      final res = await _dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'address': '$barangay, $city, Negros Occidental, Philippines',
          'key': ApiKeys.googleMaps,
        },
      );
      final results = res.data['results'] as List?;
      if (results != null && results.isNotEmpty) {
        final loc = results[0]['geometry']['location'];
        final coords = LatLng(loc['lat'] as double, loc['lng'] as double);
        if (mounted) setState(() => _selectedCoords = coords);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(coords, 16));
      }
    } catch (_) {}
  }

  Future<void> _loadAreaStatus(String city, String barangay) async {
    setState(() { _fetchingStatus = true; _noStatusData = false; _areaStatus = null; });
    try {
      final rows = await Supabase.instance.client
          .from('area_status')
          .select('alert_level, advisory, updated_at')
          .eq('city', city)
          .eq('barangay', barangay)
          .limit(1);
      if (!mounted) return;
      if (rows.isEmpty) {
        setState(() { _fetchingStatus = false; _noStatusData = true; });
      } else {
        setState(() { _fetchingStatus = false; _areaStatus = Map<String, dynamic>.from(rows.first); });
      }
    } catch (_) {
      if (mounted) setState(() { _fetchingStatus = false; _noStatusData = true; });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadHouseholds();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, 
    ));
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _sheetCtrl.dispose();
    _dio.close();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController c) => _mapController = c;

  void _panToCity(String city) {
    final coords = _cityCoords[city];
    if (coords == null || _mapController == null) return;
    _mapController!.animateCamera(CameraUpdate.newLatLngZoom(coords, 13));
  }

  void _zoomIn()  => _mapController?.animateCamera(CameraUpdate.zoomIn());
  void _zoomOut() => _mapController?.animateCamera(CameraUpdate.zoomOut());
  void _resetBearing() => _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          const CameraPosition(target: LatLng(10.6765, 122.9509), zoom: 13.5),
        ),
      );
  void _toggleMapType() => setState(() => _mapType =
      _mapType == MapType.normal ? MapType.satellite : MapType.normal);

  Future<void> _goToMyLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition();
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 15),
      );
    } catch (_) {}
  }

  Future<void> _loadHouseholds() async {
    try {
      // 1. Live Fetch from Supabase
      final householdRes = await Supabase.instance.client.from('households').select();
      final assetsRes = await Supabase.instance.client.from('assets').select();
      
      // 2. Parse JSON to Models
      final List<Household> fetchedHouseholds = (householdRes as List)
          .map((data) => Household.fromJson(data))
          .toList();
          
      final List<Asset> fetchedAssets = (assetsRes as List)
          .map((data) => Asset.fromJson(data))
          .toList();

      // 3. Build Map Markers
      final hhMarkers = await buildHouseholdMarkersAsync(
        households: fetchedHouseholds,
        onTap: (h) {
          if (mounted) {
            setState(() {
              _selectedHousehold = h;
            });
          }
        },
      );
      
      final assetMarkers = await buildAssetMarkers(fetchedAssets);

      // 4. Update state — hazard markers are built dynamically in build()
      if (mounted) {
        setState(() {
          _markers = {
            ...hhMarkers,
            ...assetMarkers,
          };
        });
      }
    } catch (e) {
      debugPrint('Error fetching data from Supabase: $e');
    }
  }

  void _openLogin({bool signUp = false}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => LoginModal(
        initialTab: signUp ? AuthTab.signUp : AuthTab.login,
      ),
    );
  }

  // Build dynamic hazard circles from live provider data
  Set<Circle> _buildHazardCircles(List<ActiveHazard> hazards) {
    final circles = <Circle>{};
    for (final h in hazards) {
      if (h.type == 'Flood') continue; // flood uses polygons, not rings
      final center = LatLng(h.centerLat, h.centerLng);
      circles.addAll([
        Circle(circleId: CircleId('${h.id}_critical'), center: center, radius: h.radiusCritical * 1000, strokeColor: const Color(0xFFFF4D4D), strokeWidth: 2, fillColor: const Color(0x19FF4D4D)),
        Circle(circleId: CircleId('${h.id}_high'),     center: center, radius: h.radiusHigh     * 1000, strokeColor: const Color(0xFFF39C12), strokeWidth: 2, fillColor: Colors.transparent),
        Circle(circleId: CircleId('${h.id}_elevated'), center: center, radius: h.radiusElevated * 1000, strokeColor: const Color(0xFFF1C40F), strokeWidth: 2, fillColor: Colors.transparent),
        Circle(circleId: CircleId('${h.id}_stable'),   center: center, radius: h.radiusStable   * 1000, strokeColor: const Color(0xFF58A6FF), strokeWidth: 2, fillColor: Colors.transparent),
      ]);
    }
    return circles;
  }

  Set<Marker> _buildHazardMarkers(List<ActiveHazard> hazards) {
    return {
      for (final h in hazards)
        if (h.type != 'Flood')
          Marker(
            markerId: MarkerId('hazard_${h.id}'),
            position: LatLng(h.centerLat, h.centerLng),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: 'ACTIVE: ${h.type}'),
          ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final activeHazards = ref.watch(activeHazardsProvider);
    final hazardCircles = _buildHazardCircles(activeHazards);
    final hazardMarkers = _buildHazardMarkers(activeHazards);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. ── Full-screen map ──────────────────────────────────────────────
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: _initialCamera,
              mapType: _mapType,
              markers: {..._markers, ...hazardMarkers},
              circles: hazardCircles,
              onMapCreated: _onMapCreated,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              // Tapping the empty map closes the popup
              onTap: (_) {
                if (_selectedHousehold != null) {
                  setState(() => _selectedHousehold = null);
                }
              },
            ),
          ),

          // 2. ── Hazard Control Panel ──────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 16, 
            left: 0,
            right: 0,
            child: const HazardControlPanel(),
          ),

          // 3. ── Map Controls ──────────────────────────────────────────────
          Positioned(
            right: 12,
            top: MediaQuery.of(context).padding.top + 70,
            child: _LandingMapControls(
              onZoomIn: _zoomIn, onZoomOut: _zoomOut, onReset: _resetBearing,
              onMyLocation: _goToMyLocation, onToggleMap: _toggleMapType,
              isSatellite: _mapType == MapType.satellite,
            ),
          ),

          // 4. ── Legend ────────────────────────────────────────────────────
          const Positioned(
            bottom: 120, 
            left: 12,
            child: LegendWidget(), 
          ),

          // 5. ── Draggable Bottom Sheet ────────────────────────────────────
          DraggableScrollableSheet(
            controller: _sheetCtrl,
            initialChildSize: _snapMax,
            minChildSize: _snapMin,
            maxChildSize: _snapMax,
            snap: true,
            builder: (context, scrollCtrl) {
              return Container(
                decoration: const BoxDecoration(
                  color: _bgBase,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4)),
                  ],
                ),
                child: CustomScrollView(
                  controller: scrollCtrl,
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _DragHandle()),
                    SliverToBoxAdapter(child: _Header(onLoginTap: _openLogin)),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _LandingSearchBar(mapController: _mapController),
                          const SizedBox(height: 16),
                          const _VolcanoAlertCard(),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'CHECK YOUR AREA',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                const Text(
                                  'Select your city and barangay to see the current status and advisories for your area.',
                                  style: TextStyle(color: _textMuted, fontSize: 13, height: 1.4),
                                ),
                                const SizedBox(height: 16),
                                _Dropdown(
                                  hint: '- Select City -',
                                  value: _city,
                                  items: negrosOccidentalCities,
                                  onChanged: (v) {
                                    setState(() {
                                      _city = v;
                                      _barangay = null;
                                      _areaStatus = null;
                                      _noStatusData = false;
                                      _selectedCoords = null;
                                    });
                                    if (v != null) _panToCity(v);
                                  },
                                ),
                                const SizedBox(height: 12),
                                _Dropdown(
                                  hint: '- Select Barangay -',
                                  value: _barangay,
                                  items: _city != null ? (cityBarangays[_city] ?? []) : [],
                                  enabled: _city != null,
                                  onChanged: (v) {
                                    setState(() {
                                      _barangay = v;
                                      _areaStatus = null;
                                      _noStatusData = false;
                                    });
                                    if (v != null && _city != null) {
                                      _geocodeBarangay(v, _city!);
                                      _loadAreaStatus(_city!, v);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          // ── Area status / advisory ──────────────────────
                          if (_city != null && _barangay != null) ...[
                            const SizedBox(height: 16),
                            if (_fetchingStatus)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            else if (_noStatusData)
                              _SectionCard(
                                title: 'AREA STATUS',
                                child: Text(
                                  'No status posted yet for $_barangay, $_city.',
                                  style: const TextStyle(color: _textMuted, fontSize: 13),
                                ),
                              )
                            else if (_areaStatus != null) ...[
                              _AreaAlertCard(status: _areaStatus!, city: _city!, barangay: _barangay!),
                              if (_areaStatus!['advisory'] != null && (_areaStatus!['advisory'] as String).isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _SectionCard(
                                  title: 'LGU ADVISORY',
                                  child: Text(
                                    _areaStatus!['advisory'] as String,
                                    style: const TextStyle(color: _textPrimary, fontSize: 13, height: 1.6),
                                  ),
                                ),
                              ],
                            ],
                            // ── Hazard zone advisory ───────────────────────
                            if (_selectedCoords != null)
                              ...activeHazards.map((hazard) {
                                final distKm = _haversineKm(
                                  _selectedCoords!.latitude, _selectedCoords!.longitude,
                                  hazard.centerLat,
                                  hazard.centerLng,
                                );
                                final zone  = _hazardZoneLabel(distKm, {
                                  'radius_critical': hazard.radiusCritical,
                                  'radius_high':     hazard.radiusHigh,
                                  'radius_elevated': hazard.radiusElevated,
                                  'radius_stable':   hazard.radiusStable,
                                });
                                final color = _hazardZoneColor(distKm, {
                                  'radius_critical': hazard.radiusCritical,
                                  'radius_high':     hazard.radiusHigh,
                                  'radius_elevated': hazard.radiusElevated,
                                  'radius_stable':   hazard.radiusStable,
                                });
                                final advisory = _hazardAdvisory(hazard.type);
                                return Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: color.withValues(alpha: 0.5)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'HAZARD-AWARE ADVISORY',
                                          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${hazard.type} — $zone',
                                          style: const TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Approx. ${distKm.toStringAsFixed(1)} km from hazard center.',
                                          style: const TextStyle(color: _textMuted, fontSize: 12),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(advisory, style: const TextStyle(color: _textPrimary, fontSize: 13, height: 1.6)),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                          ],
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'EMERGENCY HOTLINES',
                            child: Column(
                              children: [
                                if (_city != null && _hotlines.containsKey(_city))
                                  ..._hotlines[_city]!.map((h) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: _HotlineRow(
                                          label: h['label']!,
                                          number: h['number']!,
                                          highlight: h['number'] == '911',
                                        ),
                                      ))
                                else ...[
                                  const _HotlineRow(
                                    label: 'National Emergency',
                                    number: '911',
                                    highlight: true,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Select your city above to see local DRRMO numbers.',
                                    style: TextStyle(color: _textMuted, fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // 6. ── Priority Household Popup (TOPMOST) ─────────────────────────
          if (_selectedHousehold != null)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.35, // Centers above the sheet
              left: 0,
              right: 0,
              child: Center(
                child: _PriorityHouseholdPopup(
                  household: _selectedHousehold!,
                  onClose: () => setState(() => _selectedHousehold = null),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Volcano Alert Card ───────────────────────────────────────────────────────
class _VolcanoAlertCard extends StatelessWidget {
  const _VolcanoAlertCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_volcanoGradientStart, _volcanoGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        boxShadow: const [
           BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _criticalRed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'LIVE VOLCANO ALERT',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'VOLCANO',
                    style: TextStyle(color: Color(0xFF7C2D12), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                  ),
                ],
              ),
              const Icon(Icons.landscape, color: Color(0xFF7C2D12), size: 36),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'A volcano hazard zone is currently being monitored on the map. Review the actions below before continuing.',
            style: TextStyle(color: _textPrimary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          _actionPill('Wear mask outdoors'),
          const SizedBox(height: 8),
          _actionPill('Stay indoors if ashfall increases'),
          const SizedBox(height: 8),
          _actionPill('Prepare for evacuation updates'),
        ],
      ),
    );
  }

  Widget _actionPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF9A3412), fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ── Drag handle ───────────────────────────────────────────────────────────────
class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1), 
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Integrated Header ────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final VoidCallback onLoginTap;
  const _Header({required this.onLoginTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(color: _criticalRed, width: 2),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Image.asset(
            'asset/logo2.png',
            width: 36,
            height: 36,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'L.I.G.T.A.S.',
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: 1.6,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Location Intelligence & Geospatial\nTriage for Accelerated Support',
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 8,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.wb_sunny_outlined, size: 14, color: _textPrimary),
                SizedBox(width: 4),
                Text('Light Mode', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textPrimary)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          FilledButton(
            onPressed: onLoginTap,
            style: FilledButton.styleFrom(
              backgroundColor: _accentBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text(
              'LOG IN',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search Bar (Google Places API Overlay) ───────────────────────────────────
class _PlaceSuggestion {
  final String placeId; 
  final String title;
  final String subtitle;
  
  _PlaceSuggestion({required this.placeId, required this.title, required this.subtitle});
}

class _LandingSearchBar extends StatefulWidget {
  final GoogleMapController? mapController;
  const _LandingSearchBar({required this.mapController});

  @override
  State<_LandingSearchBar> createState() => _LandingSearchBarState();
}

class _LandingSearchBarState extends State<_LandingSearchBar> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  List<_PlaceSuggestion> _suggestions = [];
  Timer? _debounce;
  bool _isLoading = false;

  static final String _apiKey = ApiKeys.googleMaps; 

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus && _ctrl.text.isNotEmpty && _suggestions.isNotEmpty) {
        _showOverlay();
      } else if (!_focus.hasFocus) {
        _hideOverlay();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    _hideOverlay();
    super.dispose();
  }

  void _panToLocation(LatLng coords, {double zoom = 14.0}) {
    if (widget.mapController == null) return;
    widget.mapController!.animateCamera(CameraUpdate.newLatLngZoom(coords, zoom));
  }

  Future<void> _handleCurrentLocationTap() async {
    _ctrl.text = 'Your Current Location';
    _hideOverlay();
    _focus.unfocus();
    
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) return;
      
      final pos = await Geolocator.getCurrentPosition();
      _panToLocation(LatLng(pos.latitude, pos.longitude), zoom: 15.0);
    } catch (_) {}
  }

  void _onTextChanged(String value) {
    setState(() {}); 
    
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (value.isEmpty) {
      setState(() => _suggestions = []);
      _hideOverlay();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isLoading = true);
      
      try {
        final url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json'
            '?input=$value&key=$_apiKey&components=country:ph'; 
            
        final response = await Dio().get(url);
        
        if (response.data['status'] == 'OK') {
          final predictions = response.data['predictions'] as List;
          
          setState(() {
            _suggestions = predictions.map((p) {
              final mainText = p['structured_formatting']['main_text'] ?? '';
              final secondaryText = p['structured_formatting']['secondary_text'] ?? '';
              return _PlaceSuggestion(
                placeId: p['place_id'],
                title: mainText,
                subtitle: secondaryText,
              );
            }).toList();
          });
          
          if (_suggestions.isNotEmpty && _focus.hasFocus) {
            _showOverlay();
            _overlayEntry?.markNeedsBuild();
          }
        }
      } catch (e) {
        debugPrint('Error fetching places: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _getPlaceDetailsAndPan(String placeId) async {
    try {
      final url = 'https://maps.googleapis.com/maps/api/geocode/json'
          '?place_id=$placeId&key=$_apiKey';
          
      final response = await Dio().get(url);
      
      if (response.data['status'] == 'OK') {
        final location = response.data['results'][0]['geometry']['location'];
        final lat = location['lat'];
        final lng = location['lng'];
        
        _panToLocation(LatLng(lat, lng));
      }
    } catch (e) {
      debugPrint('Error fetching geocode: $e');
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    
    RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    var size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, size.height + 4),
          child: _buildDropdown(),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildDropdown() {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: _handleCurrentLocationTap,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.my_location, color: Color(0xFF0A67D0), size: 18),
                    SizedBox(width: 12),
                    Text(
                      'Your Current Location',
                      style: TextStyle(color: Color(0xFF0A67D0), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            
            if (_suggestions.isNotEmpty)
              const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
            
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                  itemBuilder: (context, index) {
                    final item = _suggestions[index];
                    return InkWell(
                      onTap: () {
                        _ctrl.text = item.title;
                        _hideOverlay();
                        _focus.unfocus();
                        _getPlaceDetailsAndPan(item.placeId); 
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.push_pin, color: Color(0xFFDC2626), size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  if (item.subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      item.subtitle,
                                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                    ),
                                  ]
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
          ]
        ),
        padding: const EdgeInsets.only(left: 12, right: 8),
        child: Row(
          children: [
            const Icon(Icons.push_pin, color: Color(0xFFDC2626), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                onChanged: _onTextChanged,
                style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search a place or barangay...',
                  hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: 16, height: 16, 
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A67D0))
                ),
              )
            else if (_ctrl.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _ctrl.clear();
                  _onTextChanged(''); 
                  _focus.requestFocus(); 
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.close, color: Color(0xFF64748B), size: 18),
                ),
              ),
              
            GestureDetector(
              onTap: () {
                _hideOverlay();
                _focus.unfocus();
                if (_suggestions.isNotEmpty) {
                  _ctrl.text = _suggestions.first.title;
                  _getPlaceDetailsAndPan(_suggestions.first.placeId);
                }
              },
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A67D0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.search, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sections & Cards ─────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?>? onChanged;
  final bool enabled;

  const _Dropdown({
    required this.hint, required this.value, required this.items, required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: _bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            hint: Text(hint, style: const TextStyle(color: _textMuted, fontSize: 14)),
            isExpanded: true,
            dropdownColor: _bgSurface,
            icon: const Icon(Icons.keyboard_arrow_down, color: _textPrimary),
            style: const TextStyle(color: _textPrimary, fontSize: 14),
            onChanged: enabled ? onChanged : null,
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          ),
        ),
      ),
    );
  }
}

// ── Area Alert Card ───────────────────────────────────────────────────────────

class _AreaAlertCard extends StatelessWidget {
  final Map<String, dynamic> status;
  final String city;
  final String barangay;

  const _AreaAlertCard({required this.status, required this.city, required this.barangay});

  @override
  Widget build(BuildContext context) {
    final level = status['alert_level'] as String? ?? 'Normal';
    final updatedAt = status['updated_at'] as String?;

    Color levelColor;
    Color levelBg;
    Color levelBorder;
    switch (level) {
      case 'Pre-emptive Evacuation':
        levelColor  = const Color(0xFFF85149);
        levelBg     = const Color(0xFF2D1217);
        levelBorder = const Color(0xFFDA3633);
        break;
      case 'Monitoring':
        levelColor  = const Color(0xFFD29922);
        levelBg     = const Color(0xFF1F1A0E);
        levelBorder = const Color(0xFF9E6A03);
        break;
      default:
        levelColor  = const Color(0xFF3FB950);
        levelBg     = const Color(0xFF0D2016);
        levelBorder = const Color(0xFF238636);
    }

    String? timeLabel;
    if (updatedAt != null) {
      try {
        final dt = DateTime.parse(updatedAt).toLocal();
        timeLabel = '${dt.month}/${dt.day}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: levelBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: levelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BARANGAY ALERT LEVEL',
            style: TextStyle(color: levelColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5),
          ),
          const SizedBox(height: 6),
          Text(
            level,
            style: TextStyle(color: levelColor, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '$barangay, $city${timeLabel != null ? ' · Updated $timeLabel' : ''}',
            style: const TextStyle(color: _textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _HotlineRow extends StatelessWidget {
  final String label;
  final String number;
  final bool highlight;
  
  const _HotlineRow({required this.label, required this.number, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _bgBase, 
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          Text(
            number,
            style: TextStyle(
              color: highlight ? const Color(0xFF059669) : _textPrimary, 
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingMapControls extends StatelessWidget {
  final VoidCallback onZoomIn, onZoomOut, onReset, onMyLocation, onToggleMap;
  final bool isSatellite;

  const _LandingMapControls({
    required this.onZoomIn, required this.onZoomOut, required this.onReset,
    required this.onMyLocation, required this.onToggleMap, required this.isSatellite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.add, onZoomIn),
          _divider(),
          _btn(Icons.remove, onZoomOut),
          _divider(),
          _btn(Icons.explore_outlined, onReset),
          _divider(),
          _btn(Icons.my_location, onMyLocation),
          _divider(),
          _btn(isSatellite ? Icons.map_outlined : Icons.satellite_outlined, onToggleMap),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: _textPrimary),
        ),
      );

  Widget _divider() => const Divider(height: 1, thickness: 1, color: _border);
}

// ── Custom Marker Popup ──────────────────────────────────────────────────────
class _PriorityHouseholdPopup extends StatelessWidget {
  final Household household;
  final VoidCallback onClose;

  const _PriorityHouseholdPopup({
    required this.household,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main Card
        Container(
          width: 280,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D24), // Dark theme background
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Priority Household', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  GestureDetector(
                    onTap: onClose,
                    child: const Icon(Icons.close, color: Color(0xFF64748B), size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Barangay
              Text('Brgy: ${household.barangay}', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13)),
              const SizedBox(height: 4),
              
              // Triage Level
              Row(
                children: [
                  const Text('Triage Level: ', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13)),
                  Text(
                    household.triageLevel.name.toUpperCase(),
                    style: TextStyle(
                      color: household.triageLevel.color, // Uses the exact color from your Triage enum
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // PII Notice
              const Text(
                'Personally Identifiable Information (PII) is\nhidden.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontStyle: FontStyle.italic, height: 1.4),
              ),
              const SizedBox(height: 16),

              // Vulnerability Tags (e.g. Senior, PWD)
              if (household.vulnerabilities.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: household.vulnerabilities.map((v) => 
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF292E36),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF3F4652)),
                      ),
                      child: Text(v.label, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
                    )
                  ).toList(),
                ),
            ],
          ),
        ),
        
        // The little triangle pointing down
        ClipPath(
          clipper: _TriangleClipper(),
          child: Container(
            width: 20,
            height: 10,
            color: const Color(0xFF1A1D24),
          ),
        ),
      ],
    );
  }
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(size.width, 0); // Top right
    path.lineTo(size.width / 2, size.height); // Bottom center
    path.close(); // Back to top left
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}