import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'registration_provider.dart';
import 'triage_preview.dart';

const _barangays = [
  'Brgy. 001', 'Brgy. 090', 'Brgy. 145', 'Brgy. 176',
  'Brgy. 201', 'Brgy. 220', 'Brgy. 255', 'Brgy. 289',
];

const _damageLabels = ['None', 'Minor', 'Major', 'Destroyed'];

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
            // ── Triage preview ──────────────────────────────────────────
            if (state.preview != null) ...[
              TriagePreviewCard(level: state.preview!),
              const SizedBox(height: 20),
            ],

            // ── Section: Household Info ─────────────────────────────────
            _SectionHeader('Household Information'),
            const SizedBox(height: 12),
            _field(
              label: 'Head of Household',
              hint: 'Full name',
              icon: Icons.person_outline,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              onChanged: (v) => notifier.update((s) => s.copyWith(headName: v)),
            ),
            const SizedBox(height: 12),
            _DropdownField(
              label: 'Barangay',
              icon: Icons.location_on_outlined,
              items: _barangays,
              value: state.barangay.isEmpty ? null : state.barangay,
              onChanged: (v) => notifier.update((s) => s.copyWith(barangay: v ?? '')),
            ),
            const SizedBox(height: 20),

            // ── Section: Members ────────────────────────────────────────
            _SectionHeader('Household Members'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _CounterTile(label: 'Total', icon: Icons.group, value: state.memberCount, min: 1, onChanged: (v) => notifier.update((s) => s.copyWith(memberCount: v)))),
              const SizedBox(width: 10),
              Expanded(child: _CounterTile(label: 'Elderly', icon: Icons.elderly, value: state.elderlyCount, onChanged: (v) => notifier.update((s) => s.copyWith(elderlyCount: v)))),
              const SizedBox(width: 10),
              Expanded(child: _CounterTile(label: 'Infants', icon: Icons.child_care, value: state.infantCount, onChanged: (v) => notifier.update((s) => s.copyWith(infantCount: v)))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _CounterTile(label: 'Medical', icon: Icons.medical_services, value: state.medicalCount, onChanged: (v) => notifier.update((s) => s.copyWith(medicalCount: v)))),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _ToggleTile(
                  label: 'Person w/ Disability',
                  icon: Icons.accessible,
                  value: state.hasDisabled,
                  onChanged: (v) => notifier.update((s) => s.copyWith(hasDisabled: v)),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // ── Section: Damage Level ────────────────────────────────────
            _SectionHeader('Structural Damage'),
            const SizedBox(height: 12),
            _DamagePicker(
              value: state.damageLevel,
              onChanged: (v) => notifier.update((s) => s.copyWith(damageLevel: v)),
            ),
            const SizedBox(height: 20),

            // ── Section: Location ────────────────────────────────────────
            _SectionHeader('Location'),
            const SizedBox(height: 12),
            _LocationTile(
              lat: state.latitude,
              lng: state.longitude,
              isLocating: state.isLocating,
              onCapture: notifier.captureLocation,
            ),
            const SizedBox(height: 32),

            // ── Submit ──────────────────────────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: state.isSubmitting
                    ? null
                    : () async {
                        if (state.barangay.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select a barangay')),
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
                    : Text('Submit Registration', style: AppTextStyles.titleLarge.copyWith(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    required void Function(String) onChanged,
  }) {
    return TextFormField(
      style: AppTextStyles.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        labelStyle: AppTextStyles.bodyMedium,
        filled: true,
        fillColor: AppColors.cardBackground,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
      ),
      validator: validator,
      onChanged: onChanged,
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title.toUpperCase(), style: AppTextStyles.labelLarge.copyWith(color: AppColors.accent));
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<String> items;
  final String? value;
  final void Function(String?) onChanged;

  const _DropdownField({
    required this.label,
    required this.icon,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      dropdownColor: AppColors.cardBackground,
      style: AppTextStyles.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        labelStyle: AppTextStyles.bodyMedium,
        filled: true,
        fillColor: AppColors.cardBackground,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
      ),
      items: items.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
      onChanged: onChanged,
    );
  }
}

class _CounterTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final int value;
  final int min;
  final void Function(int) onChanged;

  const _CounterTile({
    required this.label,
    required this.icon,
    required this.value,
    this.min = 0,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 18),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.labelSmall),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _btn(Icons.remove, () { if (value > min) onChanged(value - 1); }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('$value', style: AppTextStyles.headlineMedium),
              ),
              _btn(Icons.add, () => onChanged(value + 1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback fn) => GestureDetector(
        onTap: fn,
        child: Container(
          width: 24, height: 24,
          decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 14, color: AppColors.textPrimary),
        ),
      );
}

class _ToggleTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final void Function(bool) onChanged;

  const _ToggleTile({required this.label, required this.icon, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: value ? AppColors.accent.withValues(alpha: 0.15) : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: value ? AppColors.accent : AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(icon, color: value ? AppColors.accent : AppColors.textSecondary, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: AppTextStyles.bodyMedium.copyWith(color: value ? AppColors.accent : AppColors.textSecondary))),
            Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

class _DamagePicker extends StatelessWidget {
  final int value;
  final void Function(int) onChanged;
  const _DamagePicker({required this.value, required this.onChanged});

  static const _colors = [AppColors.stable, AppColors.elevated, AppColors.high, AppColors.critical];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (i) {
        final selected = value == i;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected ? _colors[i].withValues(alpha: 0.2) : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: selected ? _colors[i] : AppColors.divider, width: selected ? 2 : 1),
              ),
              child: Column(
                children: [
                  Icon(Icons.home, color: _colors[i], size: 22),
                  const SizedBox(height: 4),
                  Text(_damageLabels[i], style: AppTextStyles.labelSmall.copyWith(color: _colors[i])),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _LocationTile extends StatelessWidget {
  final double? lat;
  final double? lng;
  final bool isLocating;
  final Future<void> Function() onCapture;

  const _LocationTile({required this.lat, required this.lng, required this.isLocating, required this.onCapture});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
      child: Row(
        children: [
          Icon(Icons.gps_fixed, color: lat != null ? AppColors.accent : AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: lat != null
                ? Text('${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent))
                : Text('Tap to capture GPS location', style: AppTextStyles.bodyMedium),
          ),
          isLocating
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
              : TextButton(
                  onPressed: onCapture,
                  child: Text(lat != null ? 'Recapture' : 'Capture', style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent)),
                ),
        ],
      ),
    );
  }
}
