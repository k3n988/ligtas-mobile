import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/data/lgu_data.dart';
import '../../core/models/household.dart';
import '../../core/models/triage_level.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../auth/auth_provider.dart';

final _db = Supabase.instance.client;

// ── Citizen screen ────────────────────────────────────────────────────────────

class CitizenScreen extends ConsumerStatefulWidget {
  const CitizenScreen({super.key});

  @override
  ConsumerState<CitizenScreen> createState() => _CitizenScreenState();
}

class _CitizenScreenState extends ConsumerState<CitizenScreen> {
  Household? _myHousehold;
  bool _loading = true;
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    _fetchMyHousehold();
  }

  Future<void> _fetchMyHousehold() async {
    final username = ref.read(authProvider).username ?? '';
    try {
      final rows = await _db
          .from('households')
          .select()
          .eq('contact', username)
          .eq('source', 'citizen')
          .limit(1);
      if (rows.isNotEmpty && mounted) {
        setState(() {
          _myHousehold = Household.fromJson(rows.first);
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

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
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accent))
                  : _showForm || _myHousehold == null
                      ? _CitizenRegistrationForm(
                          contact: username,
                          onSubmitted: () {
                            setState(() {
                              _showForm = false;
                              _loading = true;
                            });
                            _fetchMyHousehold();
                          },
                        )
                      : _HouseholdStatusView(
                          household: _myHousehold!,
                          onResubmit: () => setState(() => _showForm = true),
                        ),
            ),
          ],
        ),
      ),
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

// ── Status view (household already submitted) ─────────────────────────────────

class _HouseholdStatusView extends StatelessWidget {
  final Household household;
  final VoidCallback onResubmit;
  const _HouseholdStatusView({
    required this.household,
    required this.onResubmit,
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

          // ── Household info ───────────────────────────────────────────────
          _InfoCard(
            title: 'YOUR HOUSEHOLD',
            rows: [
              _InfoRow('Head', h.head),
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
                      ? '✅ Rescued'
                      : h.assignedAssetId != null
                          ? '🚨 Rescuer dispatched'
                          : '⏳ Awaiting rescue',
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
  final String title;
  final List<_InfoRow> rows;
  final Color? accentColor;
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

// ── Registration form ─────────────────────────────────────────────────────────

class _CitizenRegistrationForm extends ConsumerStatefulWidget {
  final String contact;
  final VoidCallback onSubmitted;
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
  final _headCtrl    = TextEditingController();
  final _purokCtrl   = TextEditingController();
  final _streetCtrl  = TextEditingController();
  final _notesCtrl   = TextEditingController();
  int _occupants     = 1;
  String? _city;
  String? _barangay;
  final Set<Vulnerability> _vulns = {};
  XFile? _document;
  bool _submitting = false;
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
    final file = await picker.pickImage(source: ImageSource.gallery);
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

      // Upload document to Supabase Storage if selected
      if (_document != null) {
        final bytes    = await _document!.readAsBytes();
        final ext      = _document!.name.split('.').last;
        final path     = 'citizen-docs/${const Uuid().v4()}.$ext';
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
        'status':          'pending',
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
        _error = 'Submission failed. Please try again.';
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
          // ── Banner ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppColors.accent, size: 20),
                const SizedBox(width: 10),
                const Expanded(
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
                selectedColor:
                    AppColors.accent.withValues(alpha: 0.2),
                checkmarkColor: AppColors.accent,
                labelStyle: TextStyle(
                  color: selected
                      ? AppColors.accent
                      : AppColors.textSecondary,
                  fontSize: 12,
                ),
                side: BorderSide(
                  color: selected
                      ? AppColors.accent
                      : AppColors.divider,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          _sectionLabel('SUPPORTING DOCUMENT'),
          Text(
            'Upload a valid Senior/PWD ID or medical certificate.',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 12),
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
                  color: _document != null
                      ? AppColors.accent
                      : AppColors.divider,
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
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Any special circumstances...',
              hintStyle: TextStyle(
                  color: AppColors.textMuted, fontSize: 13),
              filled: true,
              fillColor: AppColors.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppColors.accent),
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
                border: Border.all(
                    color: const Color(0xAAF85149)),
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
                padding:
                    const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white))
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
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint.replaceAll(' *', ''),
              hintStyle: TextStyle(
                  color: AppColors.textMuted, fontSize: 13),
              filled: true,
              fillColor: AppColors.cardBackground,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 11),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: AppColors.divider)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: AppColors.divider)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: AppColors.accent)),
            ),
          ),
        ],
      );

  Widget _dropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
  }) =>
      Container(
        decoration: _boxDecor(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint,
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 13)),
          isExpanded: true,
          underline: const SizedBox.shrink(),
          dropdownColor: AppColors.cardBackground,
          style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 13),
          onChanged: onChanged,
          items: items
              .map((e) =>
                  DropdownMenuItem(value: e, child: Text(e)))
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
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 8),
          child: Icon(icon,
              color: AppColors.textSecondary, size: 18),
        ),
      );
}
