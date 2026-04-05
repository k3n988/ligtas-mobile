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

class Asset {
  final String id;
  final String name;
  final String type;     // "Boat" | "Truck" | "Ambulance"
  final String unit;     // "BFP Marine" | "Army 303rd" | "Red Cross"
  final AssetStatus status;
  final double latitude;
  final double longitude;
  final String icon;     // emoji
  final int capacity;
  final String? contact; // rescuer login contact number

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
    this.contact,
  });

  factory Asset.fromJson(Map<String, dynamic> j) => Asset(
        id:        j['id']       as String,
        name:      j['name']     as String,
        type:      j['type']     as String,
        unit:      j['unit']     as String,
        status:    AssetStatus.values.firstWhere(
            (e) => e.name == j['status'], orElse: () => AssetStatus.standby),
        latitude:  (j['lat'] as num).toDouble(),
        longitude: (j['lng'] as num).toDouble(),
        icon:      j['icon']     as String,
        capacity:  (j['capacity'] as int?) ?? 0,
        contact:   j['contact']  as String?,
      );

  Map<String, dynamic> toJson() => {
        'id':     id,
        'name':   name,
        'type':   type,
        'unit':   unit,
        'status': status.name,
        'lat':    latitude,
        'lng':    longitude,
        'icon':   icon,
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
    String? contact,
  }) {
    return Asset(
      id:        id        ?? this.id,
      name:      name      ?? this.name,
      type:      type      ?? this.type,
      unit:      unit      ?? this.unit,
      status:    status    ?? this.status,
      latitude:  latitude  ?? this.latitude,
      longitude: longitude ?? this.longitude,
      icon:      icon      ?? this.icon,
      capacity:  capacity  ?? this.capacity,
      contact:   contact   ?? this.contact,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Asset &&
        other.id        == id        &&
        other.name      == name      &&
        other.type      == type      &&
        other.unit      == unit      &&
        other.status    == status    &&
        other.latitude  == latitude  &&
        other.longitude == longitude &&
        other.icon      == icon      &&
        other.capacity  == capacity  &&
        other.contact   == contact;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, type, unit, status, latitude, longitude, icon, capacity, contact);
}
