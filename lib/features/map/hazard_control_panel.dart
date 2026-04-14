import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// IMPORTANT: Adjust this import path to point to your actual auth_provider.dart file
import '../auth/auth_provider.dart'; 

const List<String> _hazardTypes = ['Flood', 'Volcano', 'Earthquake', 'Typhoon', 'Landslide', 'Storm Surge'];

const Map<String, Color> _severityColors = {
  'critical': Color(0xFFFF4D4D),
  'high': Color(0xFFF39C12),
  'elevated': Color(0xFFF1C40F),
  'stable': Color(0xFF58A6FF),
};

class HazardControlPanel extends ConsumerStatefulWidget {
  const HazardControlPanel({super.key});

  @override
  ConsumerState<HazardControlPanel> createState() => _HazardControlPanelState();
}

class _HazardControlPanelState extends ConsumerState<HazardControlPanel> {
  // ── Local UI State ────────────────────────────────────────────────────────
  bool _isOpen = false; 
  String _hazardType = 'Volcano'; 
  
  final _criticalCtrl = TextEditingController(text: '1.0');
  final _highCtrl = TextEditingController(text: '3.0');
  final _elevatedCtrl = TextEditingController(text: '5.0');
  final _stableCtrl = TextEditingController(text: '10.0');

  @override
  void dispose() {
    _criticalCtrl.dispose();
    _highCtrl.dispose();
    _elevatedCtrl.dispose();
    _stableCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Watch the auth state from Riverpod
    final authState = ref.watch(authProvider);
    
    // 2. Determine if user is admin (Uses the getter you added to AuthState)
    final isAdmin = authState.isAdmin; 
    
    return Align(
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── The Toggle Button ───────────────────────────────────────────
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDA3633),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () {
              setState(() {
                _isOpen = !_isOpen;
              });
            },
            icon: const Icon(Icons.warning_amber_rounded, size: 20),
            label: Text(
              'ACTIVE: $_hazardType',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
          
          if (_isOpen) const SizedBox(height: 12),

          // ── The Dropdown Panel ──────────────────────────────────────────
          if (_isOpen)
            Material(
              color: Colors.transparent,
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22), 
                  border: Border.all(color: const Color(0xFF30363D)),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 20, offset: Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.only(left: 8),
                      decoration: const BoxDecoration(border: Border(left: BorderSide(color: Color(0xFFFF4D4D), width: 3))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('HAZARD LAYER', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
                          if (!isAdmin) const Text('Read-only', style: TextStyle(color: Color(0xFF8B949E), fontSize: 10)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Active Badge
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3D1A1A),
                        border: Border.all(color: const Color(0xFFDA3633)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'HAZARD: $_hazardType — 10.4102, 123.1300',
                        style: const TextStyle(color: Color(0xFFFF4D4D), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Dynamic Controls (Admin vs Others) ──────────────────
                    if (isAdmin) ...[
                      // Admin View: Interactive Inputs
                      _buildLabel('Disaster Type'),
                      _buildDropdown(
                        value: _hazardType,
                        items: _hazardTypes,
                        onChanged: (v) => setState(() => _hazardType = v!),
                      ),
                      const SizedBox(height: 14),

                      _buildLabel('Hazard Radii (km)'),
                      Row(
                        children: [
                          Expanded(child: _buildRadiiInput('Critical', _criticalCtrl, _severityColors['critical']!)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildRadiiInput('High', _highCtrl, _severityColors['high']!)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _buildRadiiInput('Elevated', _elevatedCtrl, _severityColors['elevated']!)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildRadiiInput('Stable', _stableCtrl, _severityColors['stable']!)),
                        ],
                      ),
                    ] else ...[
                      // Non-Admin View: Clean Text Display
                      _buildReadOnlyView(),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── UI Helpers ────────────────────────────────────────────────────────────
  
  Widget _buildReadOnlyView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12, height: 1.4),
            children: [
              const TextSpan(text: 'An active '),
              TextSpan(
                text: _hazardType, 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)
              ),
              const TextSpan(text: ' hazard zone is being monitored. Triage levels for households within these radii are dynamically adjusted.'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildReadOnlyRadiusItem('Critical', _criticalCtrl.text, _severityColors['critical']!),
        const SizedBox(height: 8),
        _buildReadOnlyRadiusItem('High', _highCtrl.text, _severityColors['high']!),
        const SizedBox(height: 8),
        _buildReadOnlyRadiusItem('Elevated', _elevatedCtrl.text, _severityColors['elevated']!),
        const SizedBox(height: 8),
        _buildReadOnlyRadiusItem('Stable', _stableCtrl.text, _severityColors['stable']!),
      ],
    );
  }

  Widget _buildReadOnlyRadiusItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 6, 
          height: 6, 
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ${value}km',
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
    );
  }

  Widget _buildDropdown({required String value, required List<String> items, required void Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: const Color(0xFF0D1117), border: Border.all(color: const Color(0xFF30363D)), borderRadius: BorderRadius.circular(4)),
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
  }

  Widget _buildRadiiInput(String label, TextEditingController controller, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 38,
          decoration: BoxDecoration(color: const Color(0xFF0D1117), border: Border.all(color: const Color(0xFF30363D)), borderRadius: BorderRadius.circular(4)),
          child: TextFormField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.only(left: 10, bottom: 10)),
          ),
        ),
      ],
    );
  }
}