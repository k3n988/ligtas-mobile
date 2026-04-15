import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import '../../providers/active_hazards_provider.dart';

const List<String> _hazardTypes = [
  'Flood', 'Volcano', 'Earthquake', 'Typhoon', 'Landslide', 'Storm Surge',
];

const Map<String, Color> _ringColors = {
  'critical': Color(0xFFFF4D4D),
  'high':     Color(0xFFF39C12),
  'elevated': Color(0xFFF1C40F),
  'stable':   Color(0xFF58A6FF),
};

class HazardControlPanel extends ConsumerStatefulWidget {
  const HazardControlPanel({super.key});

  @override
  ConsumerState<HazardControlPanel> createState() => _HazardControlPanelState();
}

class _HazardControlPanelState extends ConsumerState<HazardControlPanel> {
  bool   _isOpen      = false;
  String _focusedType = '';
  String _hazardType  = 'Volcano';

  // Radii inputs
  final _criticalCtrl = TextEditingController(text: '1.0');
  final _highCtrl     = TextEditingController(text: '3.0');
  final _elevatedCtrl = TextEditingController(text: '5.0');
  final _stableCtrl   = TextEditingController(text: '10.0');
  bool _saving = false;

  @override
  void dispose() {
    _criticalCtrl.dispose();
    _highCtrl.dispose();
    _elevatedCtrl.dispose();
    _stableCtrl.dispose();
    super.dispose();
  }

  void _prefillFromHazard(ActiveHazard h) {
    setState(() => _hazardType = h.type);
    _criticalCtrl.text = h.radiusCritical.toString();
    _highCtrl.text     = h.radiusHigh.toString();
    _elevatedCtrl.text = h.radiusElevated.toString();
    _stableCtrl.text   = h.radiusStable.toString();
    // Also pre-fill the draft center so it shows immediately
    ref.read(draftHazardCenterProvider.notifier).state =
        (lat: h.centerLat, lng: h.centerLng);
  }

  Future<void> _activate() async {
    final center = ref.read(draftHazardCenterProvider);
    if (center == null) return;
    setState(() => _saving = true);
    await ref.read(activeHazardsProvider.notifier).activate(
          type:      _hazardType,
          centerLat: center.lat,
          centerLng: center.lng,
          critical:  double.tryParse(_criticalCtrl.text) ?? 1,
          high:      double.tryParse(_highCtrl.text)     ?? 3,
          elevated:  double.tryParse(_elevatedCtrl.text) ?? 5,
          stable:    double.tryParse(_stableCtrl.text)   ?? 10,
        );
    ref.read(draftHazardCenterProvider.notifier).state = null;
    setState(() { _saving = false; _isOpen = false; });
  }

  Future<void> _clear(String type) async {
    setState(() => _saving = true);
    await ref.read(activeHazardsProvider.notifier).clear(type);
    ref.read(draftHazardCenterProvider.notifier).state = null;
    setState(() { _saving = false; _isOpen = false; });
  }

  @override
  Widget build(BuildContext context) {
    final hazards      = ref.watch(activeHazardsProvider);
    final isAdmin      = ref.watch(authProvider).isAdmin;
    final draftCenter  = ref.watch(draftHazardCenterProvider);
    final isSelecting  = ref.watch(isSelectingHazardCenterProvider);

    // Auto-prefill when focused hazard changes and it's already active
    final focused = hazards.isEmpty ? null
        : hazards.firstWhere((h) => h.type == _focusedType, orElse: () => hazards.first);

    if (hazards.isEmpty && !isAdmin) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Top bar ─────────────────────────────────────────────────────
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            _TopBtn(
              label: hazards.isEmpty
                  ? 'HAZARD LAYER · ${_hazardType.toUpperCase()}'
                  : 'HAZARD LAYER',
              active: hazards.isNotEmpty,
              onTap: () => setState(() => _isOpen = !_isOpen),
            ),
            ...hazards.map((h) => _ActiveBadge(
                  label:   'ACTIVE: ${h.type.toUpperCase()}',
                  focused: _focusedType == h.type || hazards.length == 1,
                  onTap:   () {
                    setState(() {
                      _focusedType = h.type;
                      _isOpen      = true;
                    });
                    _prefillFromHazard(h);
                  },
                )),
          ],
        ),

        if (_isOpen) ...[
          const SizedBox(height: 10),

          // ── Panel ──────────────────────────────────────────────────────
          Container(
            width: 310,
            constraints: const BoxConstraints(maxHeight: 500),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              border: Border.all(color: const Color(0xFF30363D)),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(color: Colors.black87, blurRadius: 20, offset: Offset(0, 8)),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(width: 3, height: 18, color: const Color(0xFFFF4D4D), margin: const EdgeInsets.only(right: 8)),
                      const Text('⚠ HAZARD LAYER',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      const Spacer(),
                      if (!isAdmin)
                        const Text('Read-only', style: TextStyle(color: Color(0xFF8B949E), fontSize: 10)),
                      GestureDetector(
                        onTap: () => setState(() => _isOpen = false),
                        child: const Icon(Icons.close, color: Color(0xFF8B949E), size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (isAdmin)
                    _buildAdminView(hazards, focused, draftCenter, isSelecting)
                  else
                    _buildReadOnlyView(hazards, focused),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Admin panel ──────────────────────────────────────────────────────────

  Widget _buildAdminView(
    List<ActiveHazard> hazards,
    ActiveHazard? focused,
    ({double lat, double lng})? draftCenter,
    bool isSelecting,
  ) {
    final isFlood    = _hazardType == 'Flood';
    final canActivate = isFlood ? false : draftCenter != null;
    final hasMatchingActive = hazards.any((h) => h.type == _hazardType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Active banner
        if (hasMatchingActive && focused != null)
          _ActiveStatusBanner(hazard: focused),
        if (hasMatchingActive) const SizedBox(height: 12),

        // Type selector
        _label('Disaster Type'),
        _dropdown(
          value: _hazardType,
          items: _hazardTypes,
          onChanged: (v) {
            if (v == null) return;
            setState(() => _hazardType = v);
            final existing = ref.read(activeHazardsProvider)
                .where((h) => h.type == v).firstOrNull;
            if (existing != null) _prefillFromHazard(existing);
          },
        ),
        const SizedBox(height: 12),

        if (!isFlood) ...[
          // ── Hazard Radii ──────────────────────────────────────────────
          _label('Hazard Radii (km)'),
          Row(children: [
            Expanded(child: _radiiInput('Critical', _criticalCtrl, _ringColors['critical']!)),
            const SizedBox(width: 8),
            Expanded(child: _radiiInput('High',     _highCtrl,     _ringColors['high']!)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _radiiInput('Elevated', _elevatedCtrl, _ringColors['elevated']!)),
            const SizedBox(width: 8),
            Expanded(child: _radiiInput('Stable',   _stableCtrl,   _ringColors['stable']!)),
          ]),
          const SizedBox(height: 12),

          // ── Hazard Center ─────────────────────────────────────────────
          _label('Hazard Center'),
          if (draftCenter != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2016),
                border: Border.all(color: const Color(0xFF238636)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '📍 ${draftCenter.lat.toStringAsFixed(5)}, ${draftCenter.lng.toStringAsFixed(5)}',
                style: const TextStyle(color: Color(0xFF3FB950), fontSize: 11, fontWeight: FontWeight.w600),
              ),
            )
          else
            Text(
              isSelecting ? 'Tap on the map to set the epicenter...' : 'No center picked yet',
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
            ),
          const SizedBox(height: 8),

          // Pick Center button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelecting ? const Color(0xFF21262D) : const Color(0xFF1F6FEB),
                foregroundColor: isSelecting ? const Color(0xFF8B949E) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: isSelecting ? null : () {
                ref.read(isSelectingHazardCenterProvider.notifier).state = true;
                setState(() => _isOpen = false); // hide panel while picking
              },
              icon: Icon(isSelecting ? Icons.hourglass_top : Icons.location_searching, size: 16),
              label: Text(
                isSelecting ? 'Tap map to pick...' : '📍 Pick Center on Map',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ] else ...[
          // Flood type — inform admin
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              border: Border.all(color: const Color(0xFF30363D)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Flood zones are drawn on the web admin panel. Activate to show current flood zones on the map.',
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 12, height: 1.5),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // ── Action buttons ────────────────────────────────────────────
        if (!isFlood) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: canActivate ? const Color(0xFF238636) : const Color(0xFF21262D),
                foregroundColor: canActivate ? Colors.white : const Color(0xFF8B949E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: (_saving || !canActivate) ? null : _activate,
              child: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('✅ Activate Hazard Layer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
          if (hasMatchingActive) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF85149),
                  side: const BorderSide(color: Color(0xFFDA3633)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: _saving ? null : () => _clear(_hazardType),
                child: const Text('🗑 Clear Hazard Layer', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
          ],
        ],
      ],
    );
  }

  // ── Read-only panel (rescuer / citizen) ────────────────────────────────────

  Widget _buildReadOnlyView(List<ActiveHazard> hazards, ActiveHazard? focused) {
    if (hazards.isEmpty) {
      return const Text('No active hazards.', style: TextStyle(color: Color(0xFF8B949E), fontSize: 13));
    }

    final h = focused ?? hazards.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Multi-hazard selector chips
        if (hazards.length > 1) ...[
          Wrap(
            spacing: 6,
            children: hazards.map((hz) => GestureDetector(
              onTap: () {
                setState(() => _focusedType = hz.type);
                _prefillFromHazard(hz);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _focusedType == hz.type
                      ? const Color(0xFF3D1A1A)
                      : const Color(0xFF21262D),
                  border: Border.all(color: const Color(0xFFDA3633).withValues(alpha: 0.6)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(hz.type,
                    style: const TextStyle(color: Color(0xFFFF4D4D), fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 12),
        ],

        RichText(
          text: TextSpan(
            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12, height: 1.5),
            children: [
              const TextSpan(text: 'An active '),
              TextSpan(text: h.type, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              const TextSpan(text: ' hazard zone is being monitored. Triage levels for households within these radii are dynamically adjusted.'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _readOnlyRadius('Critical', h.radiusCritical, _ringColors['critical']!),
        const SizedBox(height: 6),
        _readOnlyRadius('High',     h.radiusHigh,     _ringColors['high']!),
        const SizedBox(height: 6),
        _readOnlyRadius('Elevated', h.radiusElevated, _ringColors['elevated']!),
        const SizedBox(height: 6),
        _readOnlyRadius('Stable',   h.radiusStable,   _ringColors['stable']!),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _readOnlyRadius(String label, double value, Color color) => Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text('• $label: ${value}km', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFF8B949E), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      );

  Widget _dropdown({required String value, required List<String> items, required void Function(String?) onChanged}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            border: Border.all(color: const Color(0xFF30363D)),
            borderRadius: BorderRadius.circular(4)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            dropdownColor: const Color(0xFF161B22),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: onChanged,
          ),
        ),
      );

  Widget _radiiInput(String label, TextEditingController ctrl, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          Container(
            height: 36,
            decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                border: Border.all(color: const Color(0xFF30363D)),
                borderRadius: BorderRadius.circular(4)),
            child: TextFormField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  border: InputBorder.none, contentPadding: EdgeInsets.only(left: 8, bottom: 8)),
            ),
          ),
        ],
      );
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _TopBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TopBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1F3044) : const Color(0xFF102338),
            border: Border.all(
                color: active ? const Color(0xFF5DB0FF) : const Color(0xFF3C78AD), width: 1.5),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
          ),
          child: Text(label,
              style: const TextStyle(
                  color: Color(0xFFD7EBFF), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ),
      );
}

class _ActiveBadge extends StatelessWidget {
  final String label;
  final bool focused;
  final VoidCallback onTap;
  const _ActiveBadge({required this.label, required this.focused, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF641A1A), Color(0xFF421010)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            border: Border.all(color: const Color(0xFFD24B4B), width: focused ? 2 : 1.5),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Color(0x55571010), blurRadius: 12)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF6B6B), size: 14),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFFFFE3E3), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
            ],
          ),
        ),
      );
}

class _ActiveStatusBanner extends StatelessWidget {
  final ActiveHazard hazard;
  const _ActiveStatusBanner({required this.hazard});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF3D1A1A),
          border: Border.all(color: const Color(0xFFDA3633)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'HAZARD: ${hazard.type} — ${hazard.centerLat.toStringAsFixed(4)}, ${hazard.centerLng.toStringAsFixed(4)}',
          style: const TextStyle(color: Color(0xFFFF4D4D), fontSize: 11, fontWeight: FontWeight.w600),
        ),
      );
}
