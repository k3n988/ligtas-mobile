import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/models/asset.dart';
import '../../core/models/household.dart';
import '../../core/models/triage_level.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/map_utils.dart';
import '../../core/widgets/triage_badge.dart';
import '../../providers/app_state.dart';
import '../auth/auth_provider.dart';
import 'map_controller.dart';
import 'marker_icons.dart';
import 'marker_layer.dart';
import 'legend_widget.dart';

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

  @override
  Widget build(BuildContext context) {
    final households  = ref.watch(householdProvider);
    final assets      = ref.watch(assetProvider);
    final ctrl        = ref.watch(mapControllerProvider.notifier);
    final state       = ref.watch(mapControllerProvider);
    final isRescuer   = ref.watch(authProvider).role == UserRole.rescuer;

    // Rebuild markers when households or assets change, or icons first load
    if (_iconsPreloaded &&
        (households != _lastHouseholds || assets != _lastAssets)) {
      _lastHouseholds = households;
      _lastAssets = assets;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _rebuildMarkers(households, assets, ctrl);

        // Auto-zoom to fit all pins ONLY on the first successful load
        if (!_hasInitialZoomed && households.isNotEmpty) {
          _hasInitialZoomed = true;
          // Small delay so the map layout finishes rendering first
          Future.delayed(const Duration(milliseconds: 300), () {
            ctrl.fitAllHouseholds(households);
          });
        }
      });
    }

    // Pan to household when "Locate" tapped from Queue / Assets
    ref.listen(locateHouseholdProvider, (_, id) {
      if (id == null) return;
      try {
        final h = households.firstWhere((h) => h.id == id);
        ctrl.selectHousehold(h, assets: assets);
      } catch (_) {}
      ref.read(locateHouseholdProvider.notifier).state = null;
    });

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
            markers: _markers,
            polylines: state.polylines,
            mapType: state.mapType,
            style: _cleanMapStyle,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
            onTap: (_) => ctrl.selectHousehold(null),
          ),

          // ── Search bar ────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: _SearchBar(ctrl: ctrl, isSearching: state.isSearching),
            ),
          ),

          // ── Right-side controls ───────────────────────────────────────
          Positioned(
            right: 12,
            top: MediaQuery.of(context).padding.top + 76,
            child: _MapControls(ctrl: ctrl, is3D: state.is3D),
          ),

          // ── Stats overlay (admin only) ────────────────────────────────
          if (state.selected == null && !isRescuer)
            Positioned(
              bottom: 70,
              left: 12,
              child: _StatsOverlay(households: households),
            ),

          // ── Legend ────────────────────────────────────────────────────
          if (state.selected == null)
            Positioned(
              bottom: 16,
              left: isRescuer ? 10 : null,
              right: isRescuer ? null : 0,
              child: isRescuer
                  ? const LegendWidget()
                  : const Center(child: LegendWidget()),
            ),

          // ── Household overlay panel (shown on pin tap) ────────────────
          if (state.selected != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 16,
              child: _HouseholdPanel(
                household: state.selected!,
                nearestAsset: state.nearestAsset,
                routeMeters: state.routeDistanceMeters,
                isRouting: state.isRouting,
                onClose: () => ctrl.selectHousehold(null),
                onRescue: () {
                  ref
                      .read(householdProvider.notifier)
                      .markRescued(state.selected!.id);
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
                  '${h.barangay}, ${h.city}'
                  '${h.purok.isNotEmpty ? ' · Purok ${h.purok}' : ''}'
                  '${h.street.isNotEmpty ? '\n${h.street}' : ''}',
                ),
                _row(
                  'Occupants: ${h.occupants}',
                  '  |  Structure: ${h.structure.name}',
                  plain: true,
                ),
                if (h.contact.isNotEmpty) _row('Contact:', h.contact),
                if (h.notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Notes:  ',
                            style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary)),
                        Expanded(
                          child: Text(
                            h.notes,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A73E8)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                formatDistance(routeMeters!),
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A73E8)),
                              ),
                            ),
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