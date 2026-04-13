import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/data/lgu_data.dart';
import '../../core/models/household.dart';
import '../../core/models/triage_level.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'registration_provider.dart';
import 'triage_preview.dart';
import 'map_picker_sheet.dart';

class RegistrationScreen extends ConsumerWidget {
  const RegistrationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final state = ref.watch(registrationProvider);
    final notifier = ref.read(registrationProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.go('/'),
        ),
        title: Text('Register Household', style: AppTextStyles.headlineMedium),
        centerTitle: false,
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Live triage preview ─────────────────────────────────────
            TriagePreviewCard(level: state.previewTriage),
            const SizedBox(height: 20),

            // ── Household Head ──────────────────────────────────────────
            _sectionHeader('Household Information'),
            const SizedBox(height: 12),
            _textField(
              label: 'Head of Household *',
              icon: Icons.person_outline,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              onChanged: (v) => notifier.setField((s) => s.copyWith(head: v)),
            ),
            const SizedBox(height: 12),
            _textField(
              label: 'Contact Number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              onChanged: (v) => notifier.setField((s) => s.copyWith(contact: v)),
            ),
            const SizedBox(height: 20),

            // ── Location ────────────────────────────────────────────────
            _sectionHeader('Location'),
            const SizedBox(height: 12),
            _CityBarangayPicker(state: state, notifier: notifier),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _textField(
                  label: 'Purok',
                  icon: Icons.place_outlined,
                  onChanged: (v) => notifier.setField((s) => s.copyWith(purok: v)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _textField(
                  label: 'Street',
                  icon: Icons.add_road,
                  onChanged: (v) => notifier.setField((s) => s.copyWith(street: v)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            _StructurePicker(
              value: state.structure,
              onChanged: (v) => notifier.setField((s) => s.copyWith(structure: v)),
            ),
            const SizedBox(height: 12),
            _LocationTile(
              lat: state.latitude,
              lng: state.longitude,
              isLocating: state.isLocating,
              onCapture: notifier.captureLocation,
              onPinned: (lat, lng) => notifier.setField(
                  (s) => s.copyWith(latitude: lat, longitude: lng)),
            ),
            const SizedBox(height: 20),

            // ── Occupants ───────────────────────────────────────────────
            _sectionHeader('Occupants'),
            const SizedBox(height: 12),
            _OccupantCounter(
              value: state.occupants,
              onChanged: (v) => notifier.setField((s) => s.copyWith(occupants: v)),
            ),
            const SizedBox(height: 20),

            // ── Vulnerabilities ─────────────────────────────────────────
            _sectionHeader('Vulnerabilities'),
            const SizedBox(height: 4),
            Text('Check all that apply — triage level updates automatically',
                style: AppTextStyles.bodyMedium),
            const SizedBox(height: 12),
            _VulnerabilityGrid(
              selected: state.vulnerabilities,
              onToggle: notifier.toggleVulnerability,
            ),
            const SizedBox(height: 20),

            // ── Notes ───────────────────────────────────────────────────
            _sectionHeader('Notes'),
            const SizedBox(height: 12),
            _textField(
              label: 'Additional notes (optional)',
              icon: Icons.notes_outlined,
              maxLines: 3,
              onChanged: (v) => notifier.setField((s) => s.copyWith(notes: v)),
            ),
            const SizedBox(height: 32),

            // ── Submit ──────────────────────────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: state.isSubmitting
                    ? null
                    : () async {
                        if (state.city.isEmpty || state.barangay.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Please select city and barangay')),
                          );
                          return;
                        }
                        if (formKey.currentState!.validate()) {
                          await notifier.submit();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Household registered successfully'),
                                backgroundColor: AppColors.stable,
                              ),
                            );
                            context.go('/triage');
                          }
                        }
                      },
                child: state.isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Submit Registration',
                        style: AppTextStyles.titleLarge
                            .copyWith(color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _sectionHeader(String title) => Text(
      title.toUpperCase(),
      style: AppTextStyles.labelLarge.copyWith(color: AppColors.accent),
    );

Widget _textField({
  required String label,
  required IconData icon,
  String? Function(String?)? validator,
  void Function(String)? onChanged,
  TextInputType? keyboardType,
  int maxLines = 1,
}) {
  return TextFormField(
    style: AppTextStyles.bodyLarge,
    maxLines: maxLines,
    keyboardType: keyboardType,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
      labelStyle: AppTextStyles.bodyMedium,
      filled: true,
      fillColor: AppColors.cardBackground,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
    ),
    validator: validator,
    onChanged: onChanged,
  );
}

// ── City / Barangay picker ────────────────────────────────────────────────────

class _CityBarangayPicker extends StatelessWidget {
  final RegistrationFormState state;
  final RegistrationNotifier notifier;

  const _CityBarangayPicker({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final barangays = cityBarangays[state.city] ?? [];

    return Column(
      children: [
        _StyledDropdown<String>(
          label: 'City / Municipality *',
          icon: Icons.location_city_outlined,
          value: state.city.isEmpty ? null : state.city,
          items: negrosOccidentalCities,
          itemLabel: (c) => c,
          onChanged: (v) { if (v != null) notifier.setCity(v); },
        ),
        const SizedBox(height: 12),
        _StyledDropdown<String>(
          label: 'Barangay *',
          icon: Icons.holiday_village_outlined,
          value: state.barangay.isEmpty ? null : state.barangay,
          items: barangays,
          itemLabel: (b) => b,
          enabled: state.city.isNotEmpty,
          onChanged: (v) {
            if (v != null) notifier.setField((s) => s.copyWith(barangay: v));
          },
        ),
      ],
    );
  }
}

// ── Generic styled dropdown ───────────────────────────────────────────────────

class _StyledDropdown<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;
  final bool enabled;

  const _StyledDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      dropdownColor: AppColors.cardBackground,
      style: AppTextStyles.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        labelStyle: AppTextStyles.bodyMedium,
        filled: true,
        fillColor: enabled ? AppColors.cardBackground : AppColors.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
      ),
      items: enabled
          ? items
              .map((i) => DropdownMenuItem(value: i, child: Text(itemLabel(i))))
              .toList()
          : [],
      onChanged: enabled ? onChanged : null,
    );
  }
}

// ── Structure picker ──────────────────────────────────────────────────────────

class _StructurePicker extends StatelessWidget {
  final StructureType value;
  final void Function(StructureType) onChanged;

  const _StructurePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: StructureType.values.map((s) {
        final selected = value == s;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(
                  right: s != StructureType.multiStory ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.accent.withValues(alpha: 0.15)
                    : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? AppColors.accent : AppColors.divider,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.home,
                      color: selected
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      size: 20),
                  const SizedBox(height: 4),
                  Text(
                    s.label,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: selected
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Occupant counter ──────────────────────────────────────────────────────────

class _OccupantCounter extends StatelessWidget {
  final int value;
  final void Function(int) onChanged;

  const _OccupantCounter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.group_outlined,
              color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Text('Total Occupants', style: AppTextStyles.bodyLarge),
          const Spacer(),
          _btn(Icons.remove, () { if (value > 1) onChanged(value - 1); }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('$value', style: AppTextStyles.headlineMedium),
          ),
          _btn(Icons.add, () => onChanged(value + 1)),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback fn) => GestureDetector(
        onTap: fn,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.divider,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: AppColors.textPrimary),
        ),
      );
}

// ── Vulnerability grid ────────────────────────────────────────────────────────

class _VulnerabilityGrid extends StatelessWidget {
  final Set<Vulnerability> selected;
  final void Function(Vulnerability) onToggle;

  const _VulnerabilityGrid(
      {required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: Vulnerability.values.map((v) {
        final isSelected = selected.contains(v);
        final level = v.triggersLevel;
        final color = level.color;
        return GestureDetector(
          onTap: () => onToggle(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.15)
                  : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? color : AppColors.divider,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(v.icon,
                    size: 16,
                    color: isSelected ? color : AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  v.label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isSelected ? color : AppColors.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Location tile ─────────────────────────────────────────────────────────────

class _LocationTile extends StatelessWidget {
  final double? lat;
  final double? lng;
  final bool isLocating;
  final Future<void> Function() onCapture;
  final void Function(double lat, double lng) onPinned;

  const _LocationTile({
    required this.lat,
    required this.lng,
    required this.isLocating,
    required this.onCapture,
    required this.onPinned,
  });

  Future<void> _openMapPicker(BuildContext context) async {
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MapPickerSheet(
          initial: lat != null ? LatLng(lat!, lng!) : null,
        ),
      ),
    );
    if (result != null) {
      onPinned(result.latitude, result.longitude);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCoords = lat != null;

    return Column(
      children: [
        // ── Coords display + GPS button ──────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Icon(
                hasCoords ? Icons.location_on : Icons.gps_off,
                color: hasCoords ? AppColors.accent : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: hasCoords
                    ? Text(
                        '${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.accent),
                      )
                    : Text('No location set yet',
                        style: AppTextStyles.bodyMedium),
              ),
              isLocating
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accent),
                    )
                  : TextButton(
                      onPressed: onCapture,
                      child: Text(
                        hasCoords ? 'GPS' : 'GPS',
                        style: AppTextStyles.titleMedium
                            .copyWith(color: AppColors.accent),
                      ),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── Pin on Map button ────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.map_outlined, size: 18),
            label: Text(
              hasCoords ? 'Repin on Map' : 'Pin Location on Map',
              style: AppTextStyles.titleMedium
                  .copyWith(color: AppColors.accent),
            ),
            onPressed: () => _openMapPicker(context),
          ),
        ),
      ],
    );
  }
}
