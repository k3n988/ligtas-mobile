import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/models/hazard_area.dart';
import '../../core/utils/map_utils.dart';
import '../../providers/hazard_provider.dart';

// ── Color helpers ──────────────────────────────────────────────────────────────

Color _fillColor(HazardSeverity severity, bool allRescued) {
  if (allRescued) return const Color(0x4D238636); // semi-transparent green
  return switch (severity) {
    HazardSeverity.critical => const Color(0x99D32F2F),
    HazardSeverity.high     => const Color(0x99E65100),
    HazardSeverity.elevated => const Color(0x99F9A825),
  };
}

Color _strokeColor(HazardSeverity severity, bool allRescued) {
  if (allRescued) return const Color(0xFF238636);
  return switch (severity) {
    HazardSeverity.critical => const Color(0xFFD32F2F),
    HazardSeverity.high     => const Color(0xFFE65100),
    HazardSeverity.elevated => const Color(0xFFF9A825),
  };
}

// ── Builder ───────────────────────────────────────────────────────────────────

/// Builds the [Set<Polygon>] and [Set<Marker>] for all active hazard areas.
/// Must be called inside a [ConsumerWidget] build method.
({Set<Polygon> polygons, Set<Marker> markers}) buildHazardOverlays(
  WidgetRef ref,
  List<HazardArea> hazards,
) {
  final polygons = <Polygon>{};
  final markers  = <Marker>{};

  for (final hazard in hazards) {
    final allRescued = ref.watch(hazardAllRescuedProvider(hazard.id));
    final fill   = _fillColor(hazard.severity, allRescued);
    final stroke = _strokeColor(hazard.severity, allRescued);
    final center = polygonCentroid(hazard.polygonPoints);

    polygons.add(Polygon(
      polygonId: PolygonId(hazard.id),
      points: hazard.polygonPoints,
      fillColor: fill,
      strokeColor: stroke,
      strokeWidth: 2,
      consumeTapEvents: true,
    ));

    markers.add(Marker(
      markerId: MarkerId('hazard_${hazard.id}'),
      position: center,
      infoWindow: InfoWindow(
        title: '${hazard.disasterType.emoji} ${hazard.label}',
        snippet: allRescued
            ? '✓ All residents rescued'
            : '⚠ ${hazard.severity.label}',
      ),
    ));
  }

  return (polygons: polygons, markers: markers);
}

// ── "Add Hazard" floating action button ──────────────────────────────────────

/// A compact FAB the admin can tap to draw a new hazard polygon.
/// [onDraw] is called with the vertices the user taps on the map.
class AddHazardFab extends ConsumerWidget {
  final VoidCallback onTap;
  const AddHazardFab({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.small(
      heroTag: 'hazard_fab',
      backgroundColor: const Color(0xFFD32F2F),
      onPressed: onTap,
      tooltip: 'Mark Hazard Zone',
      child: const Text('⚠', style: TextStyle(fontSize: 18)),
    );
  }
}

// ── Hazard zone form sheet ────────────────────────────────────────────────────

/// Bottom sheet to configure a new hazard area before adding it to the map.
class HazardFormSheet extends StatefulWidget {
  final List<LatLng> points;
  final void Function(HazardArea) onConfirm;

  const HazardFormSheet({
    super.key,
    required this.points,
    required this.onConfirm,
  });

  @override
  State<HazardFormSheet> createState() => _HazardFormSheetState();
}

class _HazardFormSheetState extends State<HazardFormSheet> {
  final _labelController = TextEditingController();
  DisasterType _type = DisasterType.flood;
  HazardSeverity _severity = HazardSeverity.critical;
  int _idCounter = 0;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg   = Color(0xFF112240);
    const card = Color(0xFF1C2B3A);
    const div  = Color(0xFF263850);
    const text = Color(0xFFE8F0FE);
    const muted = Color(0xFF90A4AE);

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: div, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          const Text('Mark Hazard Zone',
              style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 4),
          Text('${widget.points.length} boundary points captured',
              style: const TextStyle(color: muted, fontSize: 13)),
          const SizedBox(height: 16),

          // Label
          TextField(
            controller: _labelController,
            style: const TextStyle(color: text),
            decoration: InputDecoration(
              labelText: 'Zone label (e.g. Flood Zone Alpha)',
              labelStyle: const TextStyle(color: muted, fontSize: 13),
              filled: true, fillColor: card,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: div)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: div)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: Color(0xFF0288D1), width: 1.5)),
            ),
          ),
          const SizedBox(height: 14),

          // Disaster type
          const Text('Disaster Type',
              style: TextStyle(color: muted, fontSize: 11,
                  letterSpacing: 1, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: DisasterType.values.map((t) {
                final sel = _type == t;
                return GestureDetector(
                  onTap: () => setState(() => _type = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFF0288D1).withValues(alpha: 0.2) : card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel ? const Color(0xFF0288D1) : div),
                    ),
                    child: Text('${t.emoji} ${t.label}',
                        style: TextStyle(
                          color: sel ? const Color(0xFF0288D1) : muted,
                          fontSize: 12, fontWeight: FontWeight.w600,
                        )),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Severity
          const Text('Severity',
              style: TextStyle(color: muted, fontSize: 11,
                  letterSpacing: 1, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: HazardSeverity.values.map((s) {
              final sel = _severity == s;
              final color = switch (s) {
                HazardSeverity.critical => const Color(0xFFD32F2F),
                HazardSeverity.high     => const Color(0xFFE65100),
                HazardSeverity.elevated => const Color(0xFFF9A825),
              };
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _severity = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: EdgeInsets.only(
                        right: s != HazardSeverity.elevated ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? color.withValues(alpha: 0.2) : card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: sel ? color : div, width: sel ? 1.5 : 1),
                    ),
                    child: Center(
                      child: Text(s.label,
                          style: TextStyle(
                            color: sel ? color : muted,
                            fontSize: 11, fontWeight: FontWeight.w700,
                          )),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Confirm
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: widget.points.length < 3
                  ? null
                  : () {
                      final label = _labelController.text.trim().isEmpty
                          ? '${_type.label} Zone ${++_idCounter}'
                          : _labelController.text.trim();
                      widget.onConfirm(HazardArea(
                        id: 'HZ-${DateTime.now().millisecondsSinceEpoch}',
                        label: label,
                        disasterType: _type,
                        severity: _severity,
                        polygonPoints: List.from(widget.points),
                      ));
                      Navigator.pop(context);
                    },
              child: const Text('Add Hazard Zone',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
