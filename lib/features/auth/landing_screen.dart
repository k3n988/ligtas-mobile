import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/data/lgu_data.dart';
import '../../core/theme/app_colors.dart';
import 'login_modal.dart';

const _initialCamera = CameraPosition(
  target: LatLng(10.6765, 122.9509),
  zoom: 10.5,
);

const Map<String, String> _drrmoHotlines = {
  'Bacolod City':    '(034) 433-0080',
  'Bago City':       '(034) 461-0111',
  'Cadiz City':      '(034) 493-0040',
  'Escalante City':  '(034) 454-0108',
  'Himamaylan City': '(034) 388-2038',
  'Kabankalan City': '(034) 471-2019',
  'La Carlota City': '(034) 460-0117',
  'Sagay City':      '(034) 488-0037',
  'San Carlos City': '(034) 312-5411',
  'Silay City':      '(034) 495-0030',
  'Talisay City':    '(034) 495-7002',
  'Victorias City':  '(034) 399-1021',
};

class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  String? _city;
  String? _barangay;

  // Snap positions: collapsed peek | default open | full open
  static const double _snapMin  = 0.09;
  static const double _snapMid  = 0.60;
  static const double _snapFull = 0.84;

  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();

  @override
  void dispose() {
    _sheetCtrl.dispose();
    super.dispose();
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
    final barangays =
        _city != null ? (cityBarangays[_city] ?? <String>[]) : <String>[];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Full-screen map ──────────────────────────────────────────────
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: _initialCamera,
              mapType: MapType.normal,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
            ),
          ),

          // ── Header overlay (sits on top of map) ──────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: _Header(onLoginTap: _openLogin),
          ),

          // ── Draggable info panel ─────────────────────────────────────────
          DraggableScrollableSheet(
            controller: _sheetCtrl,
            initialChildSize: _snapMid,
            minChildSize: _snapMin,
            maxChildSize: _snapFull,
            snap: true,
            snapSizes: const [_snapMin, _snapMid, _snapFull],
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
                  slivers: [
                    // Sticky drag handle
                    SliverToBoxAdapter(child: _DragHandle()),

                    // Scrollable content
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 40),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _SearchHint(),
                          const SizedBox(height: 14),
                          _SectionCard(
                            title: 'CHECK YOUR AREA',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 6),
                                Text(
                                  'Select your city and barangay to see the current status and advisories for your area.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _Dropdown(
                                  hint: '— Select City —',
                                  value: _city,
                                  items: negrosOccidentalCities,
                                  onChanged: (v) => setState(() {
                                    _city = v;
                                    _barangay = null;
                                  }),
                                ),
                                const SizedBox(height: 8),
                                _Dropdown(
                                  hint: '— Select Barangay —',
                                  value: _barangay,
                                  items: barangays,
                                  onChanged: barangays.isEmpty
                                      ? null
                                      : (v) =>
                                          setState(() => _barangay = v),
                                ),
                                if (_city != null && _barangay != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: _AreaStatus(
                                      city: _city!,
                                      barangay: _barangay!,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SectionCard(
                            title: 'ARE YOU A VULNERABLE HOUSEHOLD?',
                            titleColor: AppColors.accent,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 6),
                                Text(
                                  'Make sure rescuers know you are there. Register seniors, PWDs, bedridden, and infants before a disaster strikes — so they are first on the priority list.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: () =>
                                        _openLogin(signUp: true),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.accent,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                    child: const Text(
                                      'REGISTER NOW  →',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SectionCard(
                            title: 'EMERGENCY HOTLINES',
                            child: Column(
                              children: [
                                const SizedBox(height: 8),
                                _HotlineRow(
                                  label: 'National Emergency',
                                  number: '911',
                                  highlight: true,
                                ),
                                if (_city != null &&
                                    _drrmoHotlines.containsKey(_city)) ...[
                                  const SizedBox(height: 8),
                                  _HotlineRow(
                                    label: '$_city DRRMO',
                                    number: _drrmoHotlines[_city]!,
                                  ),
                                ] else ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Select your city above to see local DRRMO numbers.',
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
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          // Slight dark gradient so header reads on top of the map
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.surface.withValues(alpha: 0.97),
              AppColors.surface.withValues(alpha: 0.85),
            ],
          ),
          border: Border(
              bottom: BorderSide(color: AppColors.divider.withValues(alpha: 0.6))),
        ),
        child: Row(
          children: [
            Image.asset(
              'asset/logo2.png',
              width: 42,
              height: 42,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'L.I.G.T.A.S.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'Location Intelligence & Geospatial Triage',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const Spacer(),
            FilledButton(
              onPressed: onLoginTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                minimumSize: Size.zero,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text(
                'LOG IN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _SearchHint extends StatelessWidget {
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
          const Expanded(
            child: Text(
              'Search a place or barangay...',
              style: TextStyle(color: Colors.black38, fontSize: 14),
            ),
          ),
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(23),
                bottomRight: Radius.circular(23),
              ),
            ),
            child: const Icon(Icons.search, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Color? titleColor;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
    this.titleColor,
  });

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
            style: TextStyle(
              color: titleColor ?? AppColors.accent,
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

class _AreaStatus extends StatelessWidget {
  final String city;
  final String barangay;
  const _AreaStatus({required this.city, required this.barangay});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.accent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$barangay, $city — No active advisories at this time.',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
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
  const _HotlineRow({
    required this.label,
    required this.number,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 13)),
        ),
        Text(
          number,
          style: TextStyle(
            color: highlight ? AppColors.accent : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: highlight ? 16 : 13,
          ),
        ),
      ],
    );
  }
}
