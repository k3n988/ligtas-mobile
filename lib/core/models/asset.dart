import 'package:equatable/equatable.dart';

enum AssetType { boat, truck, helicopter, medicalTeam }

extension AssetTypeX on AssetType {
  String get label {
    switch (this) {
      case AssetType.boat:
        return 'Rescue Boat';
      case AssetType.truck:
        return 'Relief Truck';
      case AssetType.helicopter:
        return 'Helicopter';
      case AssetType.medicalTeam:
        return 'Medical Team';
    }
  }

  String get icon {
    switch (this) {
      case AssetType.boat:
        return '⛵';
      case AssetType.truck:
        return '🚛';
      case AssetType.helicopter:
        return '🚁';
      case AssetType.medicalTeam:
        return '🏥';
    }
  }
}

enum AssetStatus { available, deployed, maintenance }

extension AssetStatusX on AssetStatus {
  String get label {
    switch (this) {
      case AssetStatus.available:
        return 'Available';
      case AssetStatus.deployed:
        return 'Deployed';
      case AssetStatus.maintenance:
        return 'Maintenance';
    }
  }
}

class Asset extends Equatable {
  final String id;
  final String name;
  final AssetType type;
  final String location;
  final int capacity;
  final AssetStatus status;
  final double? latitude;
  final double? longitude;

  const Asset({
    required this.id,
    required this.name,
    required this.type,
    required this.location,
    required this.capacity,
    required this.status,
    this.latitude,
    this.longitude,
  });

  Asset copyWith({
    String? id,
    String? name,
    AssetType? type,
    String? location,
    int? capacity,
    AssetStatus? status,
    double? latitude,
    double? longitude,
  }) {
    return Asset(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      location: location ?? this.location,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, type, location, capacity, status, latitude, longitude];
}
