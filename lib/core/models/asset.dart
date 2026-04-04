import 'package:equatable/equatable.dart';

enum AssetStatus { active, dispatching, standby }

extension AssetStatusX on AssetStatus {
  String get label {
    switch (this) {
      case AssetStatus.active:      return 'Active';
      case AssetStatus.dispatching: return 'Dispatching';
      case AssetStatus.standby:     return 'Standby';
    }
  }
}

class Asset extends Equatable {
  final String id;
  final String name;
  final String type;   // "Boat" | "Truck" | "Ambulance"
  final String unit;   // "BFP Marine" | "Army 303rd" | "Red Cross"
  final AssetStatus status;
  final double latitude;
  final double longitude;
  final String icon;   // emoji
  final int capacity;

  const Asset({
    required this.id,
    required this.name,
    required this.type,
    required this.unit,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.icon,
    required this.capacity,
  });

  factory Asset.fromJson(Map<String, dynamic> j) => Asset(
        id:       j['id']       as String,
        name:     j['name']     as String,
        type:     j['type']     as String,
        unit:     j['unit']     as String,
        status:   AssetStatus.values.firstWhere(
            (e) => e.name == j['status'], orElse: () => AssetStatus.standby),
        latitude: (j['latitude']  as num).toDouble(),
        longitude:(j['longitude'] as num).toDouble(),
        icon:     j['icon']     as String,
        capacity: j['capacity'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id':       id,
        'name':     name,
        'type':     type,
        'unit':     unit,
        'status':   status.name,
        'latitude': latitude,
        'longitude':longitude,
        'icon':     icon,
        'capacity': capacity,
      };

  bool get isAvailable =>
      status == AssetStatus.active || status == AssetStatus.standby;

  Asset copyWith({
    String? id,
    String? name,
    String? type,
    String? unit,
    AssetStatus? status,
    double? latitude,
    double? longitude,
    String? icon,
    int? capacity,
  }) {
    return Asset(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      unit: unit ?? this.unit,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      icon: icon ?? this.icon,
      capacity: capacity ?? this.capacity,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, type, unit, status, latitude, longitude, icon, capacity];
}
