import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/models/household.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/triage_badge.dart';
import '../../providers/app_state.dart';
import 'map_controller.dart';
import 'marker_layer.dart';
import 'legend_widget.dart';

const _initialCamera = CameraPosition(
  target: LatLng(14.5995, 120.9842),
  zoom: 13.5,
);

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final households = ref.watch(householdProvider);
    final ctrl = ref.watch(mapControllerProvider.notifier);
    final state = ref.watch(mapControllerProvider);

    final markers = buildHouseholdMarkers(
      households: households,
      onTap: (h) => ctrl.selectHousehold(h),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── Google Map ────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: _initialCamera,
            onMapCreated: ctrl.onMapCreated,
            markers: markers,
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
            child: _MapControls(
              ctrl: ctrl,
              is3D: state.is3D,
            ),
          ),

          // ── Legend ────────────────────────────────────────────────────
          const Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(child: LegendWidget()),
          ),

          // ── Selected household panel ──────────────────────────────────
          if (state.selected != null)
            Positioned(
              bottom: 70,
              left: 16,
              right: 16,
              child: _HouseholdPanel(
                household: state.selected!,
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
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A73E8)),
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
        // Zoom in
        _ControlButton(
          icon: Icons.add,
          onTap: ctrl.zoomIn,
          topRadius: true,
        ),
        const SizedBox(height: 1),
        // Zoom out
        _ControlButton(
          icon: Icons.remove,
          onTap: ctrl.zoomOut,
          bottomRadius: true,
        ),
        const SizedBox(height: 10),
        // Reset bearing / compass
        _ControlButton(
          icon: Icons.explore_outlined,
          onTap: ctrl.resetBearing,
          topRadius: true,
          bottomRadius: true,
        ),
        const SizedBox(height: 10),
        // 3D toggle
        _ControlButton(
          icon: Icons.view_in_ar_outlined,
          label: is3D ? '2D' : '3D',
          onTap: ctrl.toggle3D,
          active: is3D,
          topRadius: true,
          bottomRadius: true,
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  final bool active;
  final bool topRadius;
  final bool bottomRadius;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.label,
    this.active = false,
    this.topRadius = false,
    this.bottomRadius = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1A73E8) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: topRadius ? const Radius.circular(8) : Radius.zero,
            topRight: topRadius ? const Radius.circular(8) : Radius.zero,
            bottomLeft: bottomRadius ? const Radius.circular(8) : Radius.zero,
            bottomRight: bottomRadius ? const Radius.circular(8) : Radius.zero,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: label != null
            ? Center(
                child: Text(
                  label!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : Colors.black87,
                  ),
                ),
              )
            : Icon(icon, size: 20, color: active ? Colors.white : Colors.black87),
      ),
    );
  }
}

// ── Household detail panel ────────────────────────────────────────────────────

class _HouseholdPanel extends StatelessWidget {
  final Household household;
  final VoidCallback onClose;
  final VoidCallback onRescue;

  const _HouseholdPanel({
    required this.household,
    required this.onClose,
    required this.onRescue,
  });

  @override
  Widget build(BuildContext context) {
    final h = household;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              TriageBadge(level: h.triageLevel),
              const SizedBox(width: 10),
              Expanded(child: Text(h.headName, style: AppTextStyles.titleLarge)),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close,
                    color: AppColors.textSecondary, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(h.barangay, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              _chip(Icons.group, '${h.memberCount} members'),
              if (h.elderlyCount > 0)
                _chip(Icons.elderly, '${h.elderlyCount} elderly'),
              if (h.infantCount > 0)
                _chip(Icons.child_care, '${h.infantCount} infant'),
              if (h.medicalCount > 0)
                _chip(Icons.medical_services, '${h.medicalCount} medical'),
            ],
          ),
          const SizedBox(height: 12),
          if (!h.isRescued)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRescue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.stable,
                ),
                icon: const Icon(Icons.check_circle, color: Colors.white),
                label: Text(
                  'Mark Rescued',
                  style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              child: Text(
                '✓ Rescued',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.stable),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.bodyMedium),
      ],
    );
  }
}
