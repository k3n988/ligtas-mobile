import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/data/lgu_data.dart';
import '../../core/models/household.dart';
import '../../core/models/triage_level.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_state.dart';
import '../auth/auth_provider.dart';
import '../map/legend_widget.dart';
import '../map/marker_icons.dart';
import '../map/marker_layer.dart';

final _db = Supabase.instance.client;

// ── Citizen screen ─────────────────────────────────────────────────────────────

class CitizenScreen extends ConsumerStatefulWidget {
  const CitizenScreen({super.key});

  @override
  ConsumerState<CitizenScreen> createState() => _CitizenScreenState();
}

class _CitizenScreenState extends ConsumerState<CitizenScreen> {
  Household?       _myHousehold;
  bool             _loading  = true;
  bool             _showForm = false;
  int              _tabIndex = 0;

  // Realtime
  RealtimeChannel? _channel;
  String?          _prevApprovalStatus;
  String?          _prevRescueStatus;
  String?          _prevAssignedAssetId;

  @override
  void initState() {
    super.initState();
    _fetchMyHousehold();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _fetchMyHousehold() async {
    final username = ref.read(authProvider).username ?? '';
    try {
      final rows = await _db
          .from('households')
          .select()
          .eq('contact', username)
          .limit(1);
      if (!mounted) return;
      if (rows.isNotEmpty) {
        final hh = Household.fromJson(rows.first);
        setState(() {
          _myHousehold = hh;
          _loading     = false;
        });
        _subscribeRealtime(hh.id);
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Realtime subscription ──────────────────────────────────────────────────

  void _subscribeRealtime(String householdId) {
    if (_channel != null) return; // already subscribed
    _prevApprovalStatus  = _myHousehold?.approvalStatus;
    _prevRescueStatus    = _myHousehold?.status.name;
    _prevAssignedAssetId = _myHousehold?.assignedAssetId;

    _channel = _db
        .channel('citizen_hh_$householdId')
        .onPostgresChanges(
          event:    PostgresChangeEvent.update,
          schema:   'public',
          table:    'households',
          filter:   PostgresChangeFilter(
            type:   PostgresChangeFilterType.eq,
            column: 'id',
            value:  householdId,
          ),
          callback: (payload) => _handleRealtimeUpdate(payload.newRecord),
        )
        .subscribe();
  }

  void _handleRealtimeUpdate(Map<String, dynamic> record) {
    if (!mounted) return;

    final newApproval = record['approval_status'] as String?;
    final newRescue   = (record['status'] as String? ?? '').toLowerCase();
    final newAsset    = record['assigned_asset_id'] as String?;

    // "Your request is queued."
    if (_prevApprovalStatus != 'approved' && newApproval == 'approved') {
      _showStatusNotification(
        icon:  Icons.check_circle,
        color: const Color(0xFF2E7D32),
        title: 'Registration Approved',
        body:  'Your request is now queued for rescue operations.',
      );
    }

    // "Responders are on the way."
    if (_prevAssignedAssetId == null && newAsset != null) {
      _showStatusNotification(
        icon:  Icons.directions_run,
        color: AppColors.accent,
        title: 'Responders on the way',
        body:  'A rescue team has been dispatched to your location.',
      );
    }

    // "Marked as Rescued."
    if (_prevRescueStatus != 'rescued' && newRescue == 'rescued') {
      _showStatusNotification(
        icon:  Icons.favorite,
        color: const Color(0xFF1565C0),
        title: 'Marked as Rescued',
        body:  'You have been marked as rescued. Stay safe!',
      );
    }

    // Also notify when registration is rejected
    if (_prevApprovalStatus != 'rejected' && newApproval == 'rejected') {
      _showStatusNotification(
        icon:  Icons.cancel,
        color: const Color(0xFFD32F2F),
        title: 'Registration Rejected',
        body:  'Please re-submit with valid documentation.',
      );
    }

    _prevApprovalStatus  = newApproval;
    _prevRescueStatus    = newRescue;
    _prevAssignedAssetId = newAsset;

    // Refresh local state
    setState(() => _loading = true);
    _fetchMyHousehold();
  }

  void _showStatusNotification({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior:        SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
        duration:        const Duration(seconds: 5),
        margin:          const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withValues(alpha: 0.4)),
        ),
        content: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(body,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _confirmMarkSafe() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('I Am Safe',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          'This will mark you as rescued and remove your household from the active rescue queue.\n\n'
          'Only confirm if you have already evacuated independently.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            child: const Text('Yes, I Am Safe'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _markAsSafe();
  }

  Future<void> _markAsSafe() async {
    if (_myHousehold == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _db.from('households').update({
        'status':            'Rescued',
        'assigned_asset_id': null,
        'dispatched_at':     null,
      }).eq('id', _myHousehold!.id);
      if (mounted) {
        setState(() => _loading = true);
        await _fetchMyHousehold();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Marked as safe. Removed from rescue queue.'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _confirmCancelRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Cancel Rescue Request',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          'This will cancel the current rescue dispatch and return your record to the pending queue. '
          'You can request again later.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Request',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF85149)),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _cancelRequest();
  }

  Future<void> _cancelRequest() async {
    if (_myHousehold == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _db.from('households').update({
        'assigned_asset_id': null,
        'dispatched_at':     null,
      }).eq('id', _myHousehold!.id);
      if (mounted) {
        setState(() => _loading = true);
        await _fetchMyHousehold();
        messenger.showSnackBar(
          const SnackBar(content: Text('Rescue request cancelled.')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final username = ref.watch(authProvider).username ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(username),
            Expanded(
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  _buildHomeTab(username),
                  const _CitizenMapTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon:         Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon:         Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Risk Map',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(String username) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_showForm || _myHousehold == null) {
      return _CitizenRegistrationForm(
        contact: username,
        onSubmitted: () {
          setState(() {
            _showForm = false;
            _loading  = true;
          });
          _fetchMyHousehold();
        },
      );
    }
    return _HouseholdStatusView(
      household:       _myHousehold!,
      onResubmit:      () => setState(() => _showForm = true),
      onMarkSafe:      _confirmMarkSafe,
      onCancelRequest: _confirmCancelRequest,
    );
  }

  Widget _buildHeader(String username) {
    final display = username.contains('@')
        ? username.split('@').first
        : username;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Image.asset('asset/logo2.png', width: 36, height: 36),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('L.I.G.T.A.S.',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: 2)),
              Text('Citizen Portal',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 10,
                      letterSpacing: 1)),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(display,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              GestureDetector(
                onTap: () => ref.read(authProvider.notifier).logout(),
                child: Text('Log out',
                    style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Citizen map tab (read-only risk map) ────────────────────────────────────────

class _CitizenMapTab extends ConsumerStatefulWidget {
  const _CitizenMapTab();

  @override
  ConsumerState<_CitizenMapTab> createState() => _CitizenMapTabState();
}

class _CitizenMapTabState extends ConsumerState<_CitizenMapTab> {
  Set<Marker>  _markers        = {};
  bool         _iconsPreloaded = false;
  List<Household> _lastHouseholds = [];
  GoogleMapController? _mapController;
  MapType _mapType = MapType.normal;

  static const _initial = CameraPosition(
    target: LatLng(10.6765, 122.9509),
    zoom: 13.5,
  );

  @override
  void initState() {
    super.initState();
    preloadMarkerIcons().then((_) {
      if (mounted) setState(() => _iconsPreloaded = true);
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _zoomIn()  => _mapController?.animateCamera(CameraUpdate.zoomIn());
  void _zoomOut() => _mapController?.animateCamera(CameraUpdate.zoomOut());
  void _resetBearing() => _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(
          target: _initial.target,
          zoom: _initial.zoom,
          tilt: 0,
          bearing: 0,
        )));
  void _toggleMapType() => setState(() => _mapType =
      _mapType == MapType.normal ? MapType.satellite : MapType.normal);

  Future<void> _goToMyLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      _mapController?.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 17),
      ));
    } catch (_) {}
  }

  Future<void> _rebuildMarkers(List<Household> households) async {
    final householdMarkers = await buildHouseholdMarkersAsync(
      households: households,
      onTap: (_) {}, // read-only in citizen view
    );
    if (mounted) {
      setState(() => _markers = householdMarkers);
    }
  }

  @override
  Widget build(BuildContext context) {
    final households = ref.watch(householdProvider);
    if (_iconsPreloaded && households != _lastHouseholds) {
      _lastHouseholds = households;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _rebuildMarkers(households);
      });
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: _initial,
          markers:               _markers,
          mapType:               _mapType,
          myLocationButtonEnabled: false,
          zoomControlsEnabled:     false,
          onMapCreated: (c) => _mapController = c,
        ),
        // Legend (bottom-left)
        Positioned(
          left:   0,
          bottom: 0,
          child:  const LegendWidget(),
        ),
        // Map controls (right side)
        Positioned(
          right:  12,
          bottom: 80,
          child:  _CitizenMapControls(
            onZoomIn:      _zoomIn,
            onZoomOut:     _zoomOut,
            onReset:       _resetBearing,
            onMyLocation:  _goToMyLocation,
            onToggleMap:   _toggleMapType,
            isSatellite:   _mapType == MapType.satellite,
          ),
        ),
        // Asset indicator (top)
        Positioned(
          top:  12,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_car,
                      color: AppColors.accent, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Risk Map',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Status view ─────────────────────────────────────────────────────────────────

class _HouseholdStatusView extends StatelessWidget {
  final Household    household;
  final VoidCallback onResubmit;
  final VoidCallback onMarkSafe;
  final VoidCallback onCancelRequest;

  const _HouseholdStatusView({
    required this.household,
    required this.onResubmit,
    required this.onMarkSafe,
    required this.onCancelRequest,
  });

  @override
  Widget build(BuildContext context) {
    final h      = household;
    final status = h.approvalStatus ?? 'pending';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Approval status banner ───────────────────────────────────────
          _StatusBanner(status: status),
          const SizedBox(height: 16),

          // ── Quick actions ────────────────────────────────────────────────
          if (status == 'approved' && !h.isRescued) ...[
            Row(
              children: [
                // I AM SAFE
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onMarkSafe,
                    icon:  const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('I AM SAFE',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                // CANCEL REQUEST — only show when dispatched
                if (h.isDispatched) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCancelRequest,
                      icon:  const Icon(Icons.cancel_outlined,
                          size: 18, color: Color(0xFFF85149)),
                      label: const Text('CANCEL',
                          style: TextStyle(
                              color: Color(0xFFF85149),
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFF85149)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              h.isDispatched
                  ? 'Tap "I AM SAFE" if you evacuated independently, or "CANCEL" if your situation changed.'
                  : 'Tap if you have already evacuated independently. This removes you from the rescue queue.',
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.4),
            ),
            const SizedBox(height: 16),
          ],

          // ── Household info ───────────────────────────────────────────────
          _InfoCard(
            title: 'YOUR HOUSEHOLD',
            rows: [
              _InfoRow('Head',    h.head),
              _InfoRow('Contact', h.contact),
              _InfoRow('Location',
                  '${h.barangay}, ${h.city}'
                  '${h.purok.isNotEmpty ? ' · Purok ${h.purok}' : ''}'),
              _InfoRow('Occupants', '${h.occupants}'),
              _InfoRow('Structure', h.structure.label),
            ],
          ),
          const SizedBox(height: 12),

          // ── Vulnerabilities ──────────────────────────────────────────────
          if (h.vulnerabilities.isNotEmpty) ...[
            _InfoCard(
              title: 'VULNERABILITIES',
              rows: h.vulnerabilities
                  .map((v) => _InfoRow('', v.label))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],

          // ── Triage level (only visible if approved) ──────────────────────
          if (status == 'approved') ...[
            _InfoCard(
              title: 'TRIAGE LEVEL',
              rows: [
                _InfoRow('Priority',
                    '${h.triageLevel.label} — ${_triageDesc(h.triageLevel)}'),
              ],
              accentColor: h.triageLevel.color,
            ),
            const SizedBox(height: 12),
          ],

          // ── Rescue status ────────────────────────────────────────────────
          if (status == 'approved')
            _InfoCard(
              title: 'RESCUE STATUS',
              rows: [
                _InfoRow(
                  'Status',
                  h.isRescued
                      ? '✅ Rescued / Safe'
                      : h.assignedAssetId != null
                          ? '🚨 Rescuers dispatched — on the way'
                          : '⏳ Awaiting rescue dispatch',
                ),
              ],
            ),

          // ── Document ────────────────────────────────────────────────────
          if (h.documentUrl != null) ...[
            const SizedBox(height: 12),
            _InfoCard(
              title: 'SUBMITTED DOCUMENT',
              rows: [_InfoRow('File', 'Document uploaded ✓')],
            ),
          ],

          if (status == 'rejected') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onResubmit,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('RE-SUBMIT REGISTRATION',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _triageDesc(TriageLevel l) {
    switch (l) {
      case TriageLevel.critical: return 'Immediate rescue needed';
      case TriageLevel.high:     return 'High priority';
      case TriageLevel.elevated: return 'Elevated risk';
      case TriageLevel.stable:   return 'Stable';
    }
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = switch (status) {
      'approved' => (
          icon: Icons.check_circle,
          color: const Color(0xFF2E7D32),
          bg:    const Color(0xFF1A3A2A),
          title: 'Registration Approved',
          sub:   'Your household is on the official vulnerability map.',
        ),
      'rejected' => (
          icon: Icons.cancel,
          color: const Color(0xFFD32F2F),
          bg:    const Color(0xFF3A1A1A),
          title: 'Registration Rejected',
          sub:   'Please re-submit with valid documentation.',
        ),
      _ => (
          icon: Icons.hourglass_top,
          color: AppColors.accent,
          bg:    AppColors.surface,
          title: 'Pending Approval',
          sub:   'Your submission is being reviewed by LGU staff.',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: config.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: config.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(config.icon, color: config.color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(config.title,
                    style: TextStyle(
                        color: config.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(config.sub,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String      title;
  final List<_InfoRow> rows;
  final Color?      accentColor;
  const _InfoCard({required this.title, required this.rows, this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: accentColor ?? AppColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 10),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (r.label.isNotEmpty) ...[
                      SizedBox(
                        width: 80,
                        child: Text(r.label,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12)),
                      ),
                    ],
                    Expanded(
                      child: Text(r.value,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 13)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
}

// ── Registration form ──────────────────────────────────────────────────────────

class _CitizenRegistrationForm extends ConsumerStatefulWidget {
  final String        contact;
  final VoidCallback  onSubmitted;
  const _CitizenRegistrationForm({
    required this.contact,
    required this.onSubmitted,
  });

  @override
  ConsumerState<_CitizenRegistrationForm> createState() =>
      _CitizenRegistrationFormState();
}

class _CitizenRegistrationFormState
    extends ConsumerState<_CitizenRegistrationForm> {
  final _headCtrl   = TextEditingController();
  final _purokCtrl  = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();
  int   _occupants  = 1;
  String?           _city;
  String?           _barangay;
  final Set<Vulnerability> _vulns = {};
  XFile?  _document;
  bool    _submitting = false;
  String? _error;

  @override
  void dispose() {
    _headCtrl.dispose();
    _purokCtrl.dispose();
    _streetCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    final picker = ImagePicker();
    final file   = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _document = file);
  }

  Future<void> _submit() async {
    if (_headCtrl.text.isEmpty || _city == null || _barangay == null) {
      setState(() => _error = 'Please fill in all required fields.');
      return;
    }
    setState(() { _submitting = true; _error = null; });

    try {
      String? docUrl;
      if (_document != null) {
        final bytes = await _document!.readAsBytes();
        final ext   = _document!.name.split('.').last;
        final path  = 'citizen-docs/${const Uuid().v4()}.$ext';
        await _db.storage.from('documents').uploadBinary(path, bytes);
        docUrl = _db.storage.from('documents').getPublicUrl(path);
      }

      final id = 'CIT-${const Uuid().v4().substring(0, 8).toUpperCase()}';
      await _db.from('households').insert({
        'id':              id,
        'head':            _headCtrl.text.trim(),
        'contact':         widget.contact,
        'city':            _city,
        'barangay':        _barangay,
        'purok':           _purokCtrl.text.trim(),
        'street':          _streetCtrl.text.trim(),
        'notes':           _notesCtrl.text.trim(),
        'occupants':       _occupants,
        'vuln_arr':        _vulns.map((v) => v.name).toList(),
        'structure':       'singleStory',
        'status':          'Pending',
        'triage_level':    'stable',
        'approval_status': 'pending',
        'source':          'citizen',
        'document_url':    docUrl,
        'lat':             0.0,
        'lng':             0.0,
      });

      if (mounted) widget.onSubmitted();
    } catch (e) {
      setState(() {
        _submitting = false;
        _error      = 'Submission failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final barangays = _city != null
        ? (cityBarangays[_city] ?? <String>[])
        : <String>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── One-per-household notice ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF2D1C0A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD4862A).withValues(alpha: 0.5)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFD4862A), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'STRICTLY ONE REGISTRATION PER HOUSEHOLD.\n'
                    'Duplicate submissions will be rejected. If your household is already registered by LGU staff, do not re-register.',
                    style: TextStyle(
                        color: Color(0xFFD4862A),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Info banner ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.accent, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Self-Registration — Citizen Portal\n'
                    'Your submission will be reviewed by LGU staff before being added to the official vulnerability map.',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _sectionLabel('PERSONAL & ADDRESS DETAILS'),
          _field('Household Head / Full Name *', _headCtrl),
          const SizedBox(height: 10),

          _label('City / Municipality *'),
          _dropdown(
            hint: 'Select City',
            value: _city,
            items: negrosOccidentalCities,
            onChanged: (v) => setState(() { _city = v; _barangay = null; }),
          ),
          const SizedBox(height: 10),

          _label('Barangay *'),
          _dropdown(
            hint: 'Select Barangay',
            value: _barangay,
            items: barangays,
            onChanged: barangays.isEmpty
                ? null
                : (v) => setState(() => _barangay = v),
          ),
          const SizedBox(height: 10),

          Row(children: [
            Expanded(child: _field('Purok / Sitio', _purokCtrl)),
            const SizedBox(width: 10),
            SizedBox(
              width: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Occupants'),
                  Container(
                    decoration: _boxDecor(),
                    child: Row(
                      children: [
                        _iconBtn(Icons.remove,
                            () => setState(() {
                              if (_occupants > 1) _occupants--;
                            })),
                        Expanded(
                          child: Text('$_occupants',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600)),
                        ),
                        _iconBtn(Icons.add,
                            () => setState(() => _occupants++)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 10),
          _field('Street / Landmark', _streetCtrl),
          const SizedBox(height: 20),

          _sectionLabel('VULNERABILITIES'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: Vulnerability.values.map((v) {
              final selected = _vulns.contains(v);
              return FilterChip(
                label: Text(v.label),
                selected: selected,
                onSelected: (val) => setState(() {
                  val ? _vulns.add(v) : _vulns.remove(v);
                }),
                backgroundColor: AppColors.cardBackground,
                selectedColor:   AppColors.accent.withValues(alpha: 0.2),
                checkmarkColor:  AppColors.accent,
                labelStyle: TextStyle(
                  color: selected ? AppColors.accent : AppColors.textSecondary,
                  fontSize: 12,
                ),
                side: BorderSide(
                  color: selected ? AppColors.accent : AppColors.divider,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          _sectionLabel('SUPPORTING DOCUMENT'),
          Text(
            'Upload a valid Senior/PWD ID or medical certificate.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickDocument,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _document != null ? AppColors.accent : AppColors.divider,
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _document != null
                        ? Icons.check_circle_outline
                        : Icons.upload_file,
                    color: _document != null
                        ? AppColors.accent
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _document != null
                        ? _document!.name
                        : 'Tap to upload document',
                    style: TextStyle(
                      color: _document != null
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          _sectionLabel('ADDITIONAL NOTES'),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText:  'Any special circumstances...',
              hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
              filled:    true,
              fillColor: AppColors.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:   BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:   BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:   const BorderSide(color: AppColors.accent),
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2D1217),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xAAF85149)),
              ),
              child: Text(_error!,
                  style: const TextStyle(
                      color: Color(0xFFF85149), fontSize: 12)),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding:         const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width:  20,
                      height: 20,
                      child:  CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text(
                      'SUBMIT REGISTRATION',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          fontSize: 14),
                    ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2)),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11)),
      );

  Widget _field(String hint, TextEditingController ctrl) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(hint),
          TextField(
            controller: ctrl,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText:  hint.replaceAll(' *', ''),
              hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
              filled:    true,
              fillColor: AppColors.cardBackground,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 11),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:   BorderSide(color: AppColors.divider)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:   BorderSide(color: AppColors.divider)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:   const BorderSide(color: AppColors.accent)),
            ),
          ),
        ],
      );

  Widget _dropdown({
    required String             hint,
    required String?            value,
    required List<String>       items,
    required ValueChanged<String?>? onChanged,
  }) =>
      Container(
        decoration: _boxDecor(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButton<String>(
          value:        value,
          hint:         Text(hint,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          isExpanded:   true,
          underline:    const SizedBox.shrink(),
          dropdownColor: AppColors.cardBackground,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          onChanged: onChanged,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
        ),
      );

  BoxDecoration _boxDecor() => BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      );

  Widget _iconBtn(IconData icon, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Icon(icon, color: AppColors.textSecondary, size: 18),
        ),
      );
}

// ── Map controls for citizen map tab ─────────────────────────────────────────

class _CitizenMapControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;
  final VoidCallback onMyLocation;
  final VoidCallback onToggleMap;
  final bool isSatellite;

  const _CitizenMapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
    required this.onMyLocation,
    required this.onToggleMap,
    required this.isSatellite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
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
          child: Icon(icon, size: 20, color: const Color(0xFF1E293B)),
        ),
      );

  Widget _divider() => const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0));
}
