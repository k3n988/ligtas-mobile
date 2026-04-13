import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/household.dart';
import '../../core/models/triage_level.dart';
import '../../core/services/location_service.dart';
import '../../core/utils/triage_logic.dart';
import '../../providers/app_state.dart';

class RegistrationFormState {
  final String head;
  final String contact;
  final String city;
  final String barangay;
  final String purok;
  final String street;
  final StructureType structure;
  final int occupants;
  final Set<Vulnerability> vulnerabilities;
  final String notes;
  final double? latitude;
  final double? longitude;
  final bool isLocating;
  final bool isSubmitting;

  const RegistrationFormState({
    this.head = '',
    this.contact = '',
    this.city = '',
    this.barangay = '',
    this.purok = '',
    this.street = '',
    this.structure = StructureType.singleStory,
    this.occupants = 1,
    this.vulnerabilities = const {},
    this.notes = '',
    this.latitude,
    this.longitude,
    this.isLocating = false,
    this.isSubmitting = false,
  });

  TriageLevel get previewTriage => assessTriage(vulnerabilities.toList());

  RegistrationFormState copyWith({
    String? head,
    String? contact,
    String? city,
    String? barangay,
    String? purok,
    String? street,
    StructureType? structure,
    int? occupants,
    Set<Vulnerability>? vulnerabilities,
    String? notes,
    double? latitude,
    double? longitude,
    bool? isLocating,
    bool? isSubmitting,
  }) {
    return RegistrationFormState(
      head: head ?? this.head,
      contact: contact ?? this.contact,
      city: city ?? this.city,
      barangay: barangay ?? this.barangay,
      purok: purok ?? this.purok,
      street: street ?? this.street,
      structure: structure ?? this.structure,
      occupants: occupants ?? this.occupants,
      vulnerabilities: vulnerabilities ?? this.vulnerabilities,
      notes: notes ?? this.notes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isLocating: isLocating ?? this.isLocating,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class RegistrationNotifier extends StateNotifier<RegistrationFormState> {
  final Ref _ref;
  final _uuid = const Uuid();
  final _location = LocationService();

  RegistrationNotifier(this._ref) : super(const RegistrationFormState());

  void setField(RegistrationFormState Function(RegistrationFormState) fn) {
    state = fn(state);
  }

  void toggleVulnerability(Vulnerability v) {
    final set = Set<Vulnerability>.from(state.vulnerabilities);
    if (set.contains(v)) {
      set.remove(v);
    } else {
      set.add(v);
    }
    state = state.copyWith(vulnerabilities: set);
  }

  void setCity(String city) {
    state = state.copyWith(city: city, barangay: '');
  }

  Future<void> captureLocation() async {
    state = state.copyWith(isLocating: true);
    final (lat, lng) = await _location.getCurrentLocation();
    state = state.copyWith(latitude: lat, longitude: lng, isLocating: false);
  }

  Future<bool> submit() async {
    if (state.latitude == null) await captureLocation();
    state = state.copyWith(isSubmitting: true);

    final h = Household(
      id: 'HH-${_uuid.v4().substring(0, 6).toUpperCase()}',
      latitude: state.latitude!,
      longitude: state.longitude!,
      city: state.city,
      barangay: state.barangay,
      purok: state.purok,
      street: state.street,
      structure: state.structure,
      head: state.head,
      contact: state.contact,
      occupants: state.occupants,
      vulnerabilities: state.vulnerabilities.toList(),
      notes: state.notes,
      status: HouseholdStatus.pending,
      triageLevel: state.previewTriage,
      registeredAt: DateTime.now(),
    );

    _ref.read(householdProvider.notifier).add(h);
    state = const RegistrationFormState();
    return true;
  }
}

final registrationProvider = StateNotifierProvider.autoDispose<
    RegistrationNotifier, RegistrationFormState>(
  (ref) => RegistrationNotifier(ref),
);
