import 'dart:async';
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

  GoogleMapController? _mapController;
  Set<Marker> _markers    = {};
  MapType     _mapType    = MapType.normal;

  // ── Volcano Coordinates & Hazard Rings ──
  final LatLng _volcanoCoords = const LatLng(10.4102, 123.1300);

  Set<Circle> get _hazardRings {
    return {
      Circle(
        circleId: const CircleId('critical_1km'),
        center: _volcanoCoords,
        radius: 1000, // 1km
        strokeColor: Colors.red,
        strokeWidth: 2,
        fillColor: Colors.red.withValues(alpha: 0.1),
      ),
      Circle(
        circleId: const CircleId('high_3km'),
        center: _volcanoCoords,
        radius: 3000, 
        strokeColor: Colors.orange,
        strokeWidth: 2,
        fillColor: Colors.transparent,
      ),
      Circle(
        circleId: const CircleId('elevated_5km'),
        center: _volcanoCoords,
        radius: 5000,
        strokeColor: Colors.amber,
        strokeWidth: 2,
        fillColor: Colors.transparent,
      ),
      Circle(
        circleId: const CircleId('stable_10km'),
        center: _volcanoCoords,
        radius: 10000,
        strokeColor: Colors.blue,
        strokeWidth: 2,
        fillColor: Colors.transparent,
      ),
    };
  }

  static const double _snapMin = 0.11; 
  static const double _snapMax = 0.85;

  final DraggableScrollableController _sheetCtrl = DraggableScrollableController();

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
          debugPrint('Tapped household: ${h.id}');
        },
      );
      
      final assetMarkers = await buildAssetMarkers(fetchedAssets);

      // 4. Create the Volcano Origin Marker
      final volcanoMarker = Marker(
        markerId: const MarkerId('volcano_center'),
        position: _volcanoCoords,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'ACTIVE: Volcano'),
      );

      // 5. Update state
      if (mounted) {
        setState(() {
          _markers = {
            ...hhMarkers,
            ...assetMarkers,
            volcanoMarker,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── Full-screen map ──────────────────────────────────────────────
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: _initialCamera,
              mapType: _mapType,
              markers: _markers,          
              circles: _hazardRings,      
              onMapCreated: _onMapCreated,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
            ),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _criticalRed.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                    ]
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('ACTIVE: Volcano', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            right: 12,
            top: MediaQuery.of(context).padding.top + 70,
            child: _LandingMapControls(
              onZoomIn: _zoomIn, onZoomOut: _zoomOut, onReset: _resetBearing,
              onMyLocation: _goToMyLocation, onToggleMap: _toggleMapType,
              isSatellite: _mapType == MapType.satellite,
            ),
          ),

          const Positioned(
            bottom: 120, 
            left: 12,
            child: LegendWidget(), 
          ),

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
                                    setState(() => _city = v);
                                    if (v != null) _panToCity(v);
                                  },
                                ),
                                const SizedBox(height: 12),
                                _Dropdown(
                                  hint: '- Select Barangay -',
                                  value: null,
                                  items: const [], 
                                  onChanged: (v) {},
                                ),
                              ],
                            ),
                          ),
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

  // FIX: Using final instead of const for the API key getter to prevent compilation errors
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

  const _Dropdown({
    required this.hint, required this.value, required this.items, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          onChanged: onChanged,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        ),
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
    return Column(
      children: [
        Container(
          width: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Column(
            children: [
              _btn(icon: Icons.fullscreen, onTap: onReset),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _btn({required IconData icon, required VoidCallback onTap}) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 44,
            child: Center(child: Icon(icon, size: 24, color: _textPrimary)),
          ),
        ),
      );
}