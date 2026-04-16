import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final storageServiceProvider = Provider<StorageService>(
  (_) => SharedPrefsStorageService(),
);

abstract class StorageService {
  Future<void> init();
  Future<void> clear();

  Future<void> savePendingPacket(MeshPacket packet);
  Future<List<MeshPacket>> getPendingPackets();
  Future<void> markDelivered(String packetId);
  Future<void> purgeDelivered();
}

class InMemoryStorageService implements StorageService {
  final Map<String, MeshPacket> _packets = <String, MeshPacket>{};

  @override
  Future<void> init() async {}

  @override
  Future<void> clear() async {
    _packets.clear();
  }

  @override
  Future<void> savePendingPacket(MeshPacket packet) async {
    final existing = _packets[packet.packetId];
    if (existing != null && existing.delivered) {
      return;
    }
    _packets[packet.packetId] = packet;
  }

  @override
  Future<List<MeshPacket>> getPendingPackets() async {
    return _packets.values.where((p) => !p.delivered).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<void> markDelivered(String packetId) async {
    final packet = _packets[packetId];
    if (packet == null) return;
    _packets[packetId] = packet.copyWith(delivered: true);
  }

  @override
  Future<void> purgeDelivered() async {
    _packets.removeWhere((_, packet) => packet.delivered);
  }
}

class SharedPrefsStorageService implements StorageService {
  static const _kKey = 'mesh_pending_packets';
  SharedPreferences? _prefs;

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  Future<void> clear() async {
    await _prefs?.remove(_kKey);
  }

  @override
  Future<void> savePendingPacket(MeshPacket packet) async {
    final all = await _loadAll();
    final idx = all.indexWhere((p) => p.packetId == packet.packetId);
    if (idx >= 0) {
      if (all[idx].delivered) return;
      all[idx] = packet;
    } else {
      all.add(packet);
    }
    await _persist(all);
  }

  @override
  Future<List<MeshPacket>> getPendingPackets() async {
    final all = await _loadAll();
    return all.where((p) => !p.delivered).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<void> markDelivered(String packetId) async {
    final all = await _loadAll();
    final updated = all
        .map((p) => p.packetId == packetId ? p.copyWith(delivered: true) : p)
        .toList();
    await _persist(updated);
  }

  @override
  Future<void> purgeDelivered() async {
    final all = await _loadAll();
    await _persist(all.where((p) => !p.delivered).toList());
  }

  Future<List<MeshPacket>> _loadAll() async {
    final raw = _prefs?.getString(_kKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => MeshPacket.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist(List<MeshPacket> packets) async {
    final encoded = jsonEncode(packets.map((p) => p.toJson()).toList());
    await _prefs?.setString(_kKey, encoded);
  }
}

enum MeshPacketType {
  iAmSafe,
  resubmitRequest,
}

class MeshPacket {
  final String packetId;
  final String householdId;
  final String originatorContact;
  final MeshPacketType type;
  final DateTime createdAt;
  final int hopCount;
  final bool delivered;
  final double? lat;
  final double? lng;

  const MeshPacket({
    required this.packetId,
    required this.householdId,
    required this.originatorContact,
    required this.type,
    required this.createdAt,
    this.hopCount = 0,
    this.delivered = false,
    this.lat,
    this.lng,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'packet_id': packetId,
      'household_id': householdId,
      'originator_contact': originatorContact,
      'type': type.name,
      'created_at': createdAt.toIso8601String(),
      'hop_count': hopCount,
      'delivered': delivered,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    };
  }

  factory MeshPacket.fromJson(Map<String, dynamic> json) {
    return MeshPacket(
      packetId: json['packet_id'] as String,
      householdId: json['household_id'] as String,
      originatorContact: json['originator_contact'] as String,
      type: MeshPacketType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MeshPacketType.iAmSafe,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      hopCount: (json['hop_count'] as num?)?.toInt() ?? 0,
      delivered: (json['delivered'] as bool?) ?? false,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }

  List<int> toBytes() {
    return utf8.encode(jsonEncode(toJson()));
  }

  factory MeshPacket.fromBytes(List<int> bytes) {
    final decoded = utf8.decode(bytes);
    return MeshPacket.fromJson(jsonDecode(decoded) as Map<String, dynamic>);
  }

  MeshPacket copyWith({
    String? packetId,
    String? householdId,
    String? originatorContact,
    MeshPacketType? type,
    DateTime? createdAt,
    int? hopCount,
    bool? delivered,
    double? lat,
    double? lng,
  }) {
    return MeshPacket(
      packetId: packetId ?? this.packetId,
      householdId: householdId ?? this.householdId,
      originatorContact: originatorContact ?? this.originatorContact,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      hopCount: hopCount ?? this.hopCount,
      delivered: delivered ?? this.delivered,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }

  MeshPacket withNextHop() {
    return copyWith(hopCount: hopCount + 1);
  }

  @override
  String toString() {
    return 'MeshPacket(packetId: $packetId, householdId: $householdId, '
        'type: ${type.name}, hopCount: $hopCount, delivered: $delivered)';
  }
}