import 'package:equatable/equatable.dart';
import 'triage_level.dart';

class Household extends Equatable {
  final String id;
  final String headName;
  final String barangay;
  final int memberCount;
  final int elderlyCount;
  final int infantCount;
  final int medicalCount;
  final bool hasDisabled;

  /// 0 = None · 1 = Minor · 2 = Major · 3 = Destroyed
  final int damageLevel;

  final double latitude;
  final double longitude;
  final TriageLevel triageLevel;
  final DateTime registeredAt;
  final bool isRescued;

  const Household({
    required this.id,
    required this.headName,
    required this.barangay,
    required this.memberCount,
    required this.elderlyCount,
    required this.infantCount,
    required this.medicalCount,
    required this.hasDisabled,
    required this.damageLevel,
    required this.latitude,
    required this.longitude,
    required this.triageLevel,
    required this.registeredAt,
    this.isRescued = false,
  });

  Household copyWith({
    String? id,
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
    TriageLevel? triageLevel,
    DateTime? registeredAt,
    bool? isRescued,
  }) {
    return Household(
      id: id ?? this.id,
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
      triageLevel: triageLevel ?? this.triageLevel,
      registeredAt: registeredAt ?? this.registeredAt,
      isRescued: isRescued ?? this.isRescued,
    );
  }

  @override
  List<Object?> get props => [
        id,
        headName,
        barangay,
        memberCount,
        elderlyCount,
        infantCount,
        medicalCount,
        hasDisabled,
        damageLevel,
        latitude,
        longitude,
        triageLevel,
        registeredAt,
        isRescued,
      ];
}
