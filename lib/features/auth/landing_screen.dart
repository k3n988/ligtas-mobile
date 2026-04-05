import 'dart:ui' show ImageFilter;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/api_keys.dart'; // used by _LandingSearchBar
import '../../core/data/lgu_data.dart';
import '../../core/models/asset.dart';
import '../../core/models/household.dart';
import '../../core/models/triage_level.dart';
import '../../core/theme/app_colors.dart';
import '../map/legend_widget.dart';
import '../map/marker_icons.dart';
import '../map/marker_layer.dart';
import 'login_modal.dart';

const _initialCamera = CameraPosition(
  target: LatLng(10.6765, 122.9509),
  zoom: 10.5,
);

// City centre coordinates for map panning
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

// Detailed hotlines per city — mirrors web GuestPanel.tsx
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
  String? _city; // used for hotline city filter

  // Map
  GoogleMapController? _mapController;
  Set<Marker> _markers    = {};
  bool        _loadingMap = true;

  // ── BINAGO: Snap positions para saktong taas lang at pwedeng ibaba ──
  static const double _snapMin = 0.12; // Naka-swipe pababa (search bar lang kita)
  static const double _snapMax = 0.25; // Naka-swipe pataas (sagad hanggang hotlines)

  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _loadHouseholds();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:      Colors.transparent,
      statusBarIconBrightness: Brightness.light,
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
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(coords, 13),
    );
  }

  Future<void> _loadHouseholds() async {
    try {
      final db = Supabase.instance.client;

      // Fetch households and assets in parallel
      final results = await Future.wait([
        db.from('households').select().gt('lat', 0),
        db.from('assets').select(),
      ]);

      final households = <Household>[];
      for (final r in results[0] as List) {
        try { households.add(Household.fromJson(r)); } catch (_) {}
      }

      final assets = <Asset>[];
      for (final r in results[1] as List) {
        try { assets.add(Asset.fromJson(r)); } catch (_) {}
      }

      final householdMarkers = await _buildHouseholdMarkers(households);
      final assetMarkers     = await buildAssetMarkers(assets);

      if (mounted) {
        setState(() {
          _markers    = {...householdMarkers, ...assetMarkers};
          _loadingMap = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingMap = false);
    }
  }

  Future<Set<Marker>> _buildHouseholdMarkers(List<Household> households) async {
    final result = <Marker>{};
    for (final h in households) {
      final color = markerColorFor(h.triageLevel, rescued: h.isRescued);
      final icon  = await circularMarker(color, size: 44);
      result.add(Marker(
        markerId: MarkerId(h.id),
        position: LatLng(h.latitude, h.longitude),
        icon:     icon,
        onTap:    () => _showPinPopup(h),
      ));
    }
    return result;
  }

  void _showPinPopup(Household h) {
    // Collapse the sheet so the popup is visible over the map
    _sheetCtrl.animateTo(
      _snapMin,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => _PinPopup(household: h, onLoginTap: _openLogin),
    );
  }

  void _openLogin({bool signUp = false}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => LoginModal(
        initialTab: signUp ? AuthTab.signUp : AuthTab.login,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Full-screen map ──────────────────────────────────────────────
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: _initialCamera,
              mapType: MapType.normal,
              markers: _markers,
              onMapCreated: _onMapCreated,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: false,
            ),
          ),

          if (_loadingMap)
            const Positioned(
              bottom: 120, left: 0, right: 0,
              child: Center(
                child: SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: AppColors.accent),
                ),
              ),
            ),

          // ── Header ───────────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: _Header(onLoginTap: _openLogin),
          ),

          // ── Legend (bottom-left, above sheet) ────────────────────────────
          const Positioned(
            bottom: 90,
            left: 0,
            child: LegendWidget(),
          ),

          // ── Draggable info panel ─────────────────────────────────────────
          DraggableScrollableSheet(
            controller: _sheetCtrl,
            initialChildSize: _snapMax, // Ganyan na agad kataas by default
            minChildSize: _snapMin,     // Hanggang dito lang bababa (Search bar)
            maxChildSize: _snapMax,     // Hanggang diyan lang ang sagad na taas
            snap: true,
            snapSizes: const [_snapMin, _snapMax], // Dalawang pwesto nalang
            builder: (context, scrollCtrl) {
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: CustomScrollView(
                  controller: scrollCtrl,
                  // Disable natin yung scrolling sa mismong loob kung sakto na yung content
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _DragHandle()),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 40),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // ── Functional search bar ────────────────────────
                          _LandingSearchBar(mapController: _mapController),
                          const SizedBox(height: 14),

                          // ── Emergency Hotlines ───────────────────────────
                          _SectionCard(
                            title: _city != null
                                ? 'EMERGENCY HOTLINES · $_city'
                                : 'EMERGENCY HOTLINES',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                // City picker inside hotlines card
                                _Dropdown(
                                  hint: '— Select City —',
                                  value: _city,
                                  items: negrosOccidentalCities,
                                  onChanged: (v) {
                                    setState(() => _city = v);
                                    if (v != null) _panToCity(v);
                                  },
                                ),
                                const SizedBox(height: 10),
                                if (_city != null &&
                                    _hotlines.containsKey(_city))
                                  ..._hotlines[_city]!.map((h) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: _HotlineRow(
                                          label: h['label']!,
                                          number: h['number']!,
                                          highlight: h['number'] == '911',
                                        ),
                                      ))
                                else ...[
                                  _HotlineRow(
                                    label: 'National Emergency',
                                    number: '911',
                                    highlight: true,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Select your city to see local DRRMO numbers.',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                    ),
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

// ── Pin popup (privacy-safe, shown before login) ──────────────────────────────

class _PinPopup extends StatelessWidget {
  final Household household;
  final void Function({bool signUp}) onLoginTap;

  const _PinPopup({required this.household, required this.onLoginTap});

  @override
  Widget build(BuildContext context) {
    final h     = household;
    final color = markerColorFor(h.triageLevel, rescued: h.isRescued);
    final vulns = h.vulnerabilities.map((v) => v.label).toList().cast<String>();

    return Padding(
      padding: EdgeInsets.fromLTRB(
          12, 0, 12, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Coloured header bar ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Priority Household',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close,
                        color: AppColors.textSecondary, size: 20),
                  ),
                ],
              ),
            ),

            // ── Privacy-safe details ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('Brgy', h.barangay),
                  if (h.city.isNotEmpty) _row('City', h.city),
                  _row('Triage Level',
                      h.triageLevel.label, valueColor: color),
                  const SizedBox(height: 4),
                  Text(
                    'Personal details hidden for privacy.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            // ── Vulnerability chips ──────────────────────────────────────
            if (vulns.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: vulns.map((v) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: color.withValues(alpha: 0.35)),
                    ),
                    child: Text(v,
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  )).toList(),
                ),
              ),

            // ── Login CTA ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onLoginTap();
                  },
                  icon: const Icon(Icons.lock_open, size: 16),
                  label: const Text(
                    'LOG IN TO VIEW FULL DETAILS',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.5),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text('$label:',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ),
            Text(value,
                style: TextStyle(
                    color: valueColor ?? AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

// ── Drag handle ───────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onLoginTap;
  const _Header({required this.onLoginTap});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117).withValues(alpha: 0.80),
            border: Border(
              bottom: BorderSide(
                color: AppColors.accent.withValues(alpha: 0.18),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Row(
                children: [
                  // ── Logo ──────────────────────────────────
                  Container(
                    width: 40,
                    height: 40,
                    child: Image.asset(
                      'asset/logo2.png',
                      fit: BoxFit.contain, // Makikita na ang buong logo
                    ),
                  ),
                  const SizedBox(width: 11),

                  // ── Title + subtitle ───────────────────────────────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'L.I.G.T.A.S.',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: 2.5,
                            ),
                          ),
                          const SizedBox(width: 7),
                          // Live indicator dot
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3fb950),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF3fb950)
                                      .withValues(alpha: 0.55),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'Location Intelligence & Geospatial Triage',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          letterSpacing: 0.2,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // ── LOG IN button ──────────────────────────────────────────
                  GestureDetector(
                    onTap: onLoginTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Text(
                        'LOG IN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

/// Functional search bar — geocodes the query and pans the map.
class _LandingSearchBar extends StatefulWidget {
  final GoogleMapController? mapController;
  const _LandingSearchBar({required this.mapController});

  @override
  State<_LandingSearchBar> createState() => _LandingSearchBarState();
}

class _LandingSearchBarState extends State<_LandingSearchBar> {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  final _dio   = Dio();
  bool _searching = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _dio.close();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _ctrl.text.trim();
    if (query.isEmpty) return;
    _focus.unfocus();
    setState(() => _searching = true);
    try {
      final res = await _dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {'address': query, 'key': ApiKeys.googleMaps},
      );
      final results = res.data['results'] as List?;
      if (results != null && results.isNotEmpty && widget.mapController != null) {
        final loc = results[0]['geometry']['location'];
        widget.mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(loc['lat'] as double, loc['lng'] as double),
              zoom: 14,
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No results found.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Search failed. Check your connection.')),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.location_on, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              style: const TextStyle(color: Colors.black87, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search a place or barangay...',
                hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
            ),
          ),
          GestureDetector(
            onTap: _search,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(23),
                  bottomRight: Radius.circular(23),
                ),
              ),
              child: _searching
                  ? const Center(
                      child: SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                    )
                  : const Icon(Icons.search, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
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
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<String>(
        value: value,
        hint: Text(hint,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: AppColors.cardBackground,
        iconEnabledColor: AppColors.textSecondary,
        iconDisabledColor: AppColors.textMuted,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        onChanged: onChanged,
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
      ),
    );
  }
}

class _HotlineRow extends StatelessWidget {
  final String label;
  final String number;
  final bool highlight;
  const _HotlineRow({
    required this.label,
    required this.number,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ),
          GestureDetector(
            onTap: () => launchUrl(Uri.parse('tel:$digits')),
            child: Text(
              number,
              style: TextStyle(
                color: highlight ? AppColors.accent : const Color(0xFF3fb950),
                fontWeight: FontWeight.w700,
                fontSize: highlight ? 16 : 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}