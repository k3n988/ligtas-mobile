import 'package:equatable/equatable.dart';
import 'triage_level.dart';

enum HouseholdStatus { pending, rescued }

enum StructureType { singleStory, lightMaterials, multiStory }

extension StructureTypeX on StructureType {
  String get label {
    switch (this) {
      case StructureType.singleStory:    return 'Single-story';
      case StructureType.lightMaterials: return 'Light materials';
      case StructureType.multiStory:     return 'Multi-story';
    }
  }
}

class Household extends Equatable {
  final String id;
  final double latitude;
  final double longitude;
  final String city;
  final String barangay;
  final String purok;
  final String street;
  final StructureType structure;
  final String head;
  final String contact;
  final int occupants;
  final List<Vulnerability> vulnerabilities;
  final String notes;
  final HouseholdStatus status;
  final TriageLevel triageLevel;
  final String? assignedAssetId;
  final DateTime? dispatchedAt;
  final DateTime registeredAt;

  const Household({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.barangay,
    required this.purok,
    required this.street,
    required this.structure,
    required this.head,
    required this.contact,
    required this.occupants,
    required this.vulnerabilities,
    required this.notes,
    required this.status,
    required this.triageLevel,
    required this.registeredAt,
    this.assignedAssetId,
    this.dispatchedAt,
  });

  // ── Supabase serialisation ──────────────────────────────────────────────────

  factory Household.fromJson(Map<String, dynamic> j) => Household(
        id:         j['id'] as String,
        latitude:   (j['latitude']  as num).toDouble(),
        longitude:  (j['longitude'] as num).toDouble(),
        city:       j['city']      as String,
        barangay:   j['barangay']  as String,
        purok:      j['purok']     as String? ?? '',
        street:     j['street']    as String? ?? '',
        structure:  StructureType.values.firstWhere(
            (e) => e.name == j['structure'], orElse: () => StructureType.singleStory),
        head:       j['head']      as String,
        contact:    j['contact']   as String? ?? '',
        occupants:  j['occupants'] as int,
        vulnerabilities: ((j['vulnerabilities'] as List?) ?? [])
            .map((e) => Vulnerability.values.firstWhere(
                (v) => v.name == e, orElse: () => Vulnerability.pwd))
            .toList(),
        notes:       j['notes']      as String? ?? '',
        status:      HouseholdStatus.values.firstWhere(
            (e) => e.name == j['status'], orElse: () => HouseholdStatus.pending),
        triageLevel: TriageLevel.values.firstWhere(
            (e) => e.name == j['triage_level'], orElse: () => TriageLevel.stable),
        registeredAt:    DateTime.parse(j['registered_at'] as String),
        assignedAssetId: j['assigned_asset_id'] as String?,
        dispatchedAt:    j['dispatched_at'] != null
            ? DateTime.parse(j['dispatched_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id':               id,
        'latitude':         latitude,
        'longitude':        longitude,
        'city':             city,
        'barangay':         barangay,
        'purok':            purok,
        'street':           street,
        'structure':        structure.name,
        'head':             head,
        'contact':          contact,
        'occupants':        occupants,
        'vulnerabilities':  vulnerabilities.map((v) => v.name).toList(),
        'notes':            notes,
        'status':           status.name,
        'triage_level':     triageLevel.name,
        'registered_at':    registeredAt.toIso8601String(),
        'assigned_asset_id': assignedAssetId,
        'dispatched_at':    dispatchedAt?.toIso8601String(),
      };

  bool get isRescued => status == HouseholdStatus.rescued;
  bool get isDispatched => assignedAssetId != null && status == HouseholdStatus.pending;

  Household copyWith({
    String? id,
    double? latitude,
    double? longitude,
    String? city,
    String? barangay,
    String? purok,
    String? street,
    StructureType? structure,
    String? head,
    String? contact,
    int? occupants,
    List<Vulnerability>? vulnerabilities,
    String? notes,
    HouseholdStatus? status,
    TriageLevel? triageLevel,
    DateTime? registeredAt,
    String? assignedAssetId,
    DateTime? dispatchedAt,
    bool clearAssignment = false,
  }) {
    return Household(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      city: city ?? this.city,
      barangay: barangay ?? this.barangay,
      purok: purok ?? this.purok,
      street: street ?? this.street,
      structure: structure ?? this.structure,
      head: head ?? this.head,
      contact: contact ?? this.contact,
      occupants: occupants ?? this.occupants,
      vulnerabilities: vulnerabilities ?? this.vulnerabilities,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      triageLevel: triageLevel ?? this.triageLevel,
      registeredAt: registeredAt ?? this.registeredAt,
      assignedAssetId: clearAssignment ? null : (assignedAssetId ?? this.assignedAssetId),
      dispatchedAt: clearAssignment ? null : (dispatchedAt ?? this.dispatchedAt),
    );
  }

  @override
  List<Object?> get props => [
        id, latitude, longitude, city, barangay, purok, street,
        structure, head, contact, occupants, vulnerabilities, notes,
        status, triageLevel, registeredAt, assignedAssetId, dispatchedAt,
      ];
}
