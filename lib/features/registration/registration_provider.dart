import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/household.dart';
import '../../core/models/triage_level.dart';
import '../../core/services/location_service.dart';
import '../../core/utils/triage_logic.dart';
import '../../providers/app_state.dart';

class RegistrationFormState {
  final String headName;
  final String barangay;
  final int memberCount;
  final int elderlyCount;
  final int infantCount;
  final int medicalCount;
  final bool hasDisabled;
  final int damageLevel;
  final double? latitude;
  final double? longitude;
  final bool isLocating;
  final bool isSubmitting;
  final TriageLevel? preview;

  const RegistrationFormState({
    this.headName = '',
    this.barangay = '',
    this.memberCount = 1,
    this.elderlyCount = 0,
    this.infantCount = 0,
    this.medicalCount = 0,
    this.hasDisabled = false,
    this.damageLevel = 0,
    this.latitude,
    this.longitude,
    this.isLocating = false,
    this.isSubmitting = false,
    this.preview,
  });

  RegistrationFormState copyWith({
    String? headName,
    String? barangay,
    int? memberCount,
    int? elderlyCount,
    int? infantCount,
    int? medicalCount,
    bool? hasDisabled,
    int? damageLevel,
    double? latitude,
    double? longitude,
    bool? isLocating,
    bool? isSubmitting,
    TriageLevel? preview,
  }) {
    return RegistrationFormState(
      headName: headName ?? this.headName,
      barangay: barangay ?? this.barangay,
      memberCount: memberCount ?? this.memberCount,
      elderlyCount: elderlyCount ?? this.elderlyCount,
      infantCount: infantCount ?? this.infantCount,
      medicalCount: medicalCount ?? this.medicalCount,
      hasDisabled: hasDisabled ?? this.hasDisabled,
      damageLevel: damageLevel ?? this.damageLevel,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isLocating: isLocating ?? this.isLocating,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      preview: preview ?? this.preview,
    );
  }

  TriageLevel computePreview() => assessTriage(
        medicalCount: medicalCount,
        elderlyCount: elderlyCount,
        infantCount: infantCount,
        hasDisabled: hasDisabled,
        damageLevel: damageLevel,
        memberCount: memberCount,
      );
}

class RegistrationNotifier extends StateNotifier<RegistrationFormState> {
  final Ref _ref;
  final _uuid = const Uuid();
  final _location = LocationService();

  RegistrationNotifier(this._ref) : super(const RegistrationFormState());

  void update(RegistrationFormState Function(RegistrationFormState) fn) {
    state = fn(state);
    state = state.copyWith(preview: state.computePreview());
  }

  Future<void> captureLocation() async {
    state = state.copyWith(isLocating: true);
    final (lat, lng) = await _location.getCurrentLocation();
    state = state.copyWith(latitude: lat, longitude: lng, isLocating: false);
  }

  Future<bool> submit() async {
    if (state.latitude == null) await captureLocation();
    state = state.copyWith(isSubmitting: true);

    final level = state.computePreview();
    final h = Household(
      id: _uuid.v4(),
      headName: state.headName,
      barangay: state.barangay,
      memberCount: state.memberCount,
      elderlyCount: state.elderlyCount,
      infantCount: state.infantCount,
      medicalCount: state.medicalCount,
      hasDisabled: state.hasDisabled,
      damageLevel: state.damageLevel,
      latitude: state.latitude!,
      longitude: state.longitude!,
      triageLevel: level,
      registeredAt: DateTime.now(),
    );

    _ref.read(householdProvider.notifier).add(h);
    state = const RegistrationFormState(); // reset
    return true;
  }
}

final registrationProvider =
    StateNotifierProvider.autoDispose<RegistrationNotifier, RegistrationFormState>(
  (ref) => RegistrationNotifier(ref),
);
