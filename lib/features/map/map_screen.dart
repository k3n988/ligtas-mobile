import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/models/asset.dart';
import '../../core/models/household.dart';
import '../../core/models/triage_level.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/triage_badge.dart';
import '../../providers/app_state.dart';
import '../../providers/active_hazards_provider.dart';
import '../../providers/hazard_provider.dart';
import '../auth/auth_provider.dart';
import 'map_controller.dart';
import 'marker_icons.dart';
import 'marker_layer.dart';
import 'legend_widget.dart';
import 'hazard_control_panel.dart';

const _initialCamera = CameraPosition(
  target: LatLng(10.6765, 122.9509),
  zoom: 13.5,
);

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  Set<Marker> _markers = {};
  List<Household> _lastHouseholds = [];
  List<Asset> _lastAssets = [];
  bool _iconsPreloaded = false;
  bool _hasInitialZoomed = false;

  @override
  void initState() {
    super.initState();
    _preload();
    // Provider values set BEFORE this screen mounted are missed by ref.listen
    // (which only fires on *changes*). Read them once on the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePendingActions());
  }

  /// Called once after mount and also by ref.listen for subsequent changes.
  void _handleLocate(String id) {
    ref.read(locateHouseholdProvider.notifier).state = null;
    final households = ref.read(householdProvider);
    final ctrl       = ref.read(mapControllerProvider.notifier);
    try {
      final h = households.firstWhere((hh) => hh.id == id);
      // panToHousehold: satellite, zoom 19, sets selected → panel shows, NO route
      ctrl.panToHousehold(h);
    } catch (_) {}
  }

  void _handleDispatch(String id) {
    ref.read(dispatchHouseholdProvider.notifier).state = null;
    final households = ref.read(householdProvider);
    final ctrl       = ref.read(mapControllerProvider.notifier);
    try {
      final h = households.firstWhere((hh) => hh.id == id);
      // selectHouseholdAndRouteFromGps: zoom 15.5, sets selected → panel shows + GPS route
      ctrl.selectHouseholdAndRouteFromGps(h);
    } catch (_) {}
  }

  void _handlePendingActions() {
    if (!mounted) return;
    final locateId   = ref.read(locateHouseholdProvider);
    final dispatchId = ref.read(dispatchHouseholdProvider);
    // Small delay so GoogleMap.onMapCreated finishes before we animate
    if (locateId != null || dispatchId != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        if (locateId   != null) _handleLocate(locateId);
        if (dispatchId != null) _handleDispatch(dispatchId);
      });
    }
  }

  Future<void> _preload() async {
    await preloadMarkerIcons();
    if (mounted) setState(() => _iconsPreloaded = true);
  }

  Future<void> _rebuildMarkers(
    List<Household> households,
    List<Asset> assets,
    MapControllerNotifier ctrl,
  ) async {
    final householdMarkers = await buildHouseholdMarkersAsync(
      households: households,
      onTap: (h) => ctrl.selectHousehold(h, assets: assets),
    );
    final assetMarkers = await buildAssetMarkers(assets);
    if (mounted) {
      setState(() => _markers = {...householdMarkers, ...assetMarkers});
    }
  }

  // ── Build hazard circles from active hazards ─────────────────────────────
  Set<Circle> _buildHazardCircles(List<ActiveHazard> hazards) {
    final circles = <Circle>{};
    for (final h in hazards) {
      if (h.type == 'Flood') continue;
      final center = LatLng(h.centerLat, h.centerLng);
      circles.addAll([
        Circle(circleId: CircleId('${h.id}_stable'),   center: center, radius: h.radiusStable   * 1000, strokeColor: const Color(0xFF58A6FF), strokeWidth: 2, fillColor: const Color(0x1558A6FF)),
        Circle(circleId: CircleId('${h.id}_elevated'), center: center, radius: h.radiusElevated * 1000, strokeColor: const Color(0xFFF1C40F), strokeWidth: 2, fillColor: Colors.transparent),
        Circle(circleId: CircleId('${h.id}_high'),     center: center, radius: h.radiusHigh     * 1000, strokeColor: const Color(0xFFF39C12), strokeWidth: 2, fillColor: Colors.transparent),
        Circle(circleId: CircleId('${h.id}_critical'), center: center, radius: h.radiusCritical * 1000, strokeColor: const Color(0xFFFF4D4D), strokeWidth: 2, fillColor: const Color(0x14FF4D4D)),
      ]);
    }
    return circles;
  }

  Set<Marker> _buildHazardMarkers(List<ActiveHazard> hazards) => {
    for (final h in hazards)
      if (h.type != 'Flood')
        Marker(
          markerId: MarkerId('hz_${h.id}'),
          position: LatLng(h.centerLat, h.centerLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'ACTIVE: ${h.type}'),
          zIndexInt: 500,
        ),
  };

  @override
  Widget build(BuildContext context) {
    final households    = ref.watch(householdProvider);
    final assets        = ref.watch(assetProvider);
    final ctrl          = ref.watch(mapControllerProvider.notifier);
    final mapState      = ref.watch(mapControllerProvider);
    final isRescuer     = ref.watch(authProvider).role == UserRole.rescuer;
    final activeHazards = ref.watch(activeHazardsProvider);
    final isPicking     = ref.watch(pickingLocationProvider);
    final pendingCoords = ref.watch(pendingCoordsProvider);

    // Auto-pan to hazard center when a new hazard is activated
    ref.listen<List<ActiveHazard>>(activeHazardsProvider, (prev, next) {
      if (next.isEmpty) return;
      final prevIds = prev?.map((h) => h.id).toSet() ?? {};
      final newHazard = next.firstWhere(
        (h) => !prevIds.contains(h.id) && h.type != 'Flood',
        orElse: () => next.first,
      );
      if (!prevIds.contains(newHazard.id) && newHazard.type != 'Flood') {
        ctrl.animateTo(LatLng(newHazard.centerLat, newHazard.centerLng), zoom: 12);
      }
    });

    final hazardCircles  = _buildHazardCircles(activeHazards);
    final hazardMarkers  = _buildHazardMarkers(activeHazards);

    // Pending coords marker (dashed circle while admin is picking location)
    final pendingMarker = pendingCoords != null
        ? <Marker>{
            Marker(
              markerId: const MarkerId('pending_pin'),
              position: pendingCoords,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              infoWindow: const InfoWindow(title: 'Pinned location'),
              zIndexInt: 999,
            ),
          }
        : <Marker>{};

    // Rebuild markers when data changes or icons first load
    if (_iconsPreloaded &&
        (households != _lastHouseholds || assets != _lastAssets)) {
      _lastHouseholds = households;
      _lastAssets     = assets;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _rebuildMarkers(households, assets, ctrl);
        if (!_hasInitialZoomed && households.isNotEmpty) {
          _hasInitialZoomed = true;
          Future.delayed(const Duration(milliseconds: 300), () {
            ctrl.fitAllHouseholds(households);
          });
        }
      });
    }

    // Listen for locate/dispatch triggered while screen is already mounted
    ref.listen<String?>(locateHouseholdProvider,   (_, id) { if (id != null) _handleLocate(id);   });
    ref.listen<String?>(dispatchHouseholdProvider, (_, id) { if (id != null) _handleDispatch(id); });

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── Google Map ────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: _initialCamera,
            onMapCreated: ctrl.onMapCreated,
            onCameraMove: ctrl.onCameraMove,
            markers: {..._markers, ...hazardMarkers, ...pendingMarker},
            polylines: mapState.polylines,
            circles: hazardCircles,
            mapType: mapState.mapType,
            style: _cleanMapStyle,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
            onTap: (pos) {
              if (isPicking) {
                ref.read(pendingCoordsProvider.notifier).state = pos;
                ref.read(pickingLocationProvider.notifier).state = false;
                return;
              }
              ctrl.selectHousehold(null);
            },
          ),

          // ── Search bar ────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: _SearchBar(ctrl: ctrl, isSearching: mapState.isSearching),
            ),
          ),

          // ── Pick-location banner (admin pinning household on map) ─────
          if (isPicking)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF58A6FF),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
                  ),
                  child: const Text(
                    '📍 Tap map to pin household location',
                    style: TextStyle(color: Color(0xFF0D1117), fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          if (isPicking)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 12,
              child: GestureDetector(
                onTap: () => ref.read(pickingLocationProvider.notifier).state = false,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    border: Border.all(color: const Color(0xFF30363D)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('✕ Cancel',
                      style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ),

          // ── Hazard Control Panel ──────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            left: 0,
            right: 0,
            child: const HazardControlPanel(),
          ),

          // ── Right-side controls ───────────────────────────────────────
          Positioned(
            right: 12,
            top: MediaQuery.of(context).padding.top + 76,
            child: _MapControls(ctrl: ctrl, is3D: mapState.is3D),
          ),

          // ── Stats overlay (admin only) ────────────────────────────────
          if (mapState.selected == null && !isRescuer)
            Positioned(
              bottom: 70,
              left: 12,
              child: _StatsOverlay(households: households),
            ),

          // ── Legend ────────────────────────────────────────────────────
          if (mapState.selected == null)
            Positioned(
              bottom: 16,
              left: isRescuer ? 10 : null,
              right: isRescuer ? null : 0,
              child: isRescuer
                  ? const LegendWidget()
                  : const Center(child: LegendWidget()),
            ),

          // ── Household overlay panel (shown on pin tap) ────────────────
          if (mapState.selected != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 16,
              child: _HouseholdPanel(
                household: mapState.selected!,
                nearestAsset: mapState.nearestAsset,
                routeMeters: mapState.routeDistanceMeters,
                isRouting: mapState.isRouting,
                onClose: () => ctrl.selectHousehold(null),
                onRescue: () {
                  ref
                      .read(householdProvider.notifier)
                      .markRescued(mapState.selected!.id);
                  ctrl.selectHousehold(null);
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Household overlay panel ───────────────────────────────────────────────────

class _HouseholdPanel extends StatelessWidget {
  final Household household;
  final Asset? nearestAsset;
  final double? routeMeters;
  final bool isRouting;
  final VoidCallback onClose;
  final VoidCallback onRescue;

  const _HouseholdPanel({
    required this.household,
    required this.nearestAsset,
    required this.routeMeters,
    required this.isRouting,
    required this.onClose,
    required this.onRescue,
  });

  @override
  Widget build(BuildContext context) {
    final h = household;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
            decoration: BoxDecoration(
              color: (h.isRescued
                      ? const Color(0xFF238636)
                      : h.triageLevel.color)
                  .withValues(alpha: 0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                TriageBadge(level: h.triageLevel),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    h.head,
                    style: AppTextStyles.titleLarge.copyWith(
                      color: h.isRescued
                          ? const Color(0xFF238636)
                          : h.triageLevel.color,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(Icons.close,
                      color: AppColors.textSecondary, size: 20),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('ID:', h.id),
                _row(
                  'Loc:',
                  [
                    if (h.street.isNotEmpty) h.street,
                    if (h.barangay.isNotEmpty) 'brgy. ${h.barangay.toLowerCase()}',
                    h.city.toLowerCase(),
                  ].join(', '),
                ),
                _row(
                  'Occupants: ${h.occupants}',
                  '  |  Structure: ${h.structure.label}',
                  plain: true,
                ),
                if (h.contact.isNotEmpty) _row('Contact:', h.contact),
                // Source (blue)
                if (h.source != null && h.source!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Text('Source:  ',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textSecondary)),
                        Expanded(
                          child: Text(
                            h.source!,
                            style: AppTextStyles.bodyMedium.copyWith(
                                color: const Color(0xFF58A6FF)),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Notes — always shown ("None" when empty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Notes:  ',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary)),
                      Expanded(
                        child: Text(
                          h.notes.isEmpty ? 'None' : h.notes,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                if (!h.isRescued) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: h.isDispatched
                          ? const Color(0xFFF0A500).withValues(alpha: 0.10)
                          : const Color(0xFF8B949E).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: h.isDispatched
                            ? const Color(0xFFF0A500).withValues(alpha: 0.5)
                            : AppColors.divider,
                      ),
                    ),
                    child: Text(
                      h.isDispatched
                          ? '🚨  Status: Waiting for Responder'
                          : '⏳  Status: Pending Dispatch',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: h.isDispatched
                            ? const Color(0xFFF0A500)
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            child: isRouting
                ? const Row(
                    children: [
                      SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF1A73E8)),
                      ),
                      SizedBox(width: 8),
                      Text('Finding nearest rescuer…',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    ],
                  )
                : nearestAsset != null
                    // Asset-based route
                    ? Row(
                        children: [
                          Text(nearestAsset!.icon,
                              style: const TextStyle(fontSize: 15)),
                          const SizedBox(width: 6),
                          Text('Routing from: ',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary)),
                          Expanded(
                            child: Text(
                              nearestAsset!.name,
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: const Color(0xFF1A73E8),
                                  fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (routeMeters != null)
                            _distancePill(routeMeters!, const Color(0xFF1A73E8)),
                        ],
                      )
                    // GPS route (rescuer dispatched from queue)
                    : routeMeters != null
                        ? Row(
                            children: [
                              const Icon(Icons.my_location,
                                  size: 15, color: Color(0xFF4CAF50)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Routing from your location',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                      color: const Color(0xFF4CAF50),
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              _distancePill(routeMeters!, const Color(0xFF4CAF50)),
                            ],
                          )
                        : const SizedBox.shrink(),
          ),
          if (h.vulnerabilities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: h.vulnerabilities.map((v) => _vulnChip(v)).toList(),
              ),
            )
          else
            const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: h.isRescued
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF238636).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '✓  Rescued',
                      style: AppTextStyles.titleMedium
                          .copyWith(color: const Color(0xFF238636)),
                    ),
                  )
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onRescue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.stable,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        'MARK AS RESCUED',
                        style: AppTextStyles.titleMedium.copyWith(
                            color: Colors.white,
                            letterSpacing: 0.5),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _distancePill(double meters, Color color) {
    final text = meters >= 1000
        ? '${(meters / 1000).toStringAsFixed(1)} km'
        : '${meters.round()} m';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _row(String label, String value, {bool plain = false}) {
    if (plain) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          '$label$value',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label  ',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          Expanded(
            child: Text(value,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _vulnChip(Vulnerability v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: v.triggersLevel.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: v.triggersLevel.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(v.icon, size: 11, color: v.triggersLevel.color),
          const SizedBox(width: 4),
          Text(v.label,
              style: TextStyle(
                  fontSize: 11,
                  color: v.triggersLevel.color,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatefulWidget {
  final MapControllerNotifier ctrl;
  final bool isSearching;
  const _SearchBar({required this.ctrl, required this.isSearching});

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _focus.unfocus();
    final error = await widget.ctrl.searchAndGo(_controller.text);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.high),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.location_on, color: Color(0xFF1A73E8), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              style: const TextStyle(color: Colors.black87, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Search location...',
                hintStyle: TextStyle(color: Colors.black38, fontSize: 15),
                border: InputBorder.none,
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
            ),
          ),
          if (widget.isSearching)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF1A73E8)),
              ),
            )
          else
            GestureDetector(
              onTap: _submit,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFF1A73E8),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: const Icon(Icons.search, color: Colors.white, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Right-side map controls ───────────────────────────────────────────────────

class _MapControls extends StatelessWidget {
  final MapControllerNotifier ctrl;
  final bool is3D;
  const _MapControls({required this.ctrl, required this.is3D});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // GROUP 1: Zoom In, Zoom Out, Compass
        Container(
          width: 44,
          decoration: _boxDecoration(),
          child: Column(
            children: [
              _ControlButton(icon: Icons.add, onTap: ctrl.zoomIn),
              _divider(),
              _ControlButton(icon: Icons.remove, onTap: ctrl.zoomOut),
              _divider(),
              _ControlButton(icon: Icons.navigation, onTap: ctrl.resetBearing),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // GROUP 2: My Location
        Container(
          width: 44,
          decoration: _boxDecoration(),
          child: _ControlButton(
            icon: Icons.my_location,
            onTap: ctrl.goToMyLocation,
          ),
        ),
        const SizedBox(height: 10),

        // GROUP 3: Map Type Toggle
        Container(
          width: 44,
          decoration: _boxDecoration(),
          child: _ControlButton(
            icon: Icons.map_outlined,
            onTap: ctrl.toggle3D,
            active: is3D,
          ),
        ),
      ],
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      width: 32,
      color: Colors.grey.withValues(alpha: 0.3),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 44,
          child: Center(
            child: Icon(
              icon,
              size: 22,
              color: active ? const Color(0xFF1A73E8) : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Stats overlay ─────────────────────────────────────────────────────────────

class _StatsOverlay extends StatelessWidget {
  final List<Household> households;
  const _StatsOverlay({required this.households});

  @override
  Widget build(BuildContext context) {
    final critical = households
        .where((h) => !h.isRescued && h.triageLevel == TriageLevel.critical)
        .length;
    final high = households
        .where((h) => !h.isRescued && h.triageLevel == TriageLevel.high)
        .length;
    final elevated = households
        .where((h) => !h.isRescued && h.triageLevel == TriageLevel.elevated)
        .length;
    final rescued = households.where((h) => h.isRescued).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.2), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _statDot(AppColors.critical, critical, 'Critical'),
          const SizedBox(width: 12),
          _statDot(AppColors.high, high, 'High'),
          const SizedBox(width: 12),
          _statDot(AppColors.elevated, elevated, 'Elevated'),
          const SizedBox(width: 12),
          _statDot(AppColors.stable, rescued, 'Rescued'),
        ],
      ),
    );
  }

  Widget _statDot(Color color, int count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$count',
            style: AppTextStyles.headlineMedium
                .copyWith(color: color, fontSize: 18)),
        Text(label, style: AppTextStyles.labelSmall),
      ],
    );
  }
}

// ── Map style: hides all POI pins ─────────────────────────────────────────────

const String _cleanMapStyle = '''
[
  { "featureType": "poi",            "stylers": [{ "visibility": "off" }] },
  { "featureType": "poi.business",   "stylers": [{ "visibility": "off" }] },
  { "featureType": "poi.attraction", "stylers": [{ "visibility": "off" }] },
  { "featureType": "poi.government", "stylers": [{ "visibility": "off" }] },
  { "featureType": "poi.medical",    "stylers": [{ "visibility": "off" }] },
  { "featureType": "poi.park",       "stylers": [{ "visibility": "off" }] },
  { "featureType": "poi.place_of_worship", "stylers": [{ "visibility": "off" }] },
  { "featureType": "poi.school",     "stylers": [{ "visibility": "off" }] },
  { "featureType": "poi.sports_complex", "stylers": [{ "visibility": "off" }] },
  { "featureType": "transit",        "stylers": [{ "visibility": "off" }] }
]
''';