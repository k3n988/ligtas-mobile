import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'storage_service.dart';

const _kServiceId = 'ph.gov.ligtas.mesh';
const _kRetryInterval = Duration(seconds: 20);
const _kMaxHops = 10;

/// Prefer Nearby Connections first.
/// flutter_blue_plus is not used here because it is BLE central-role only.

final meshServiceProvider = Provider<MeshService>((ref) {
  final storage = ref.read(storageServiceProvider);
  final service = MeshService(storage: storage);
  ref.onDispose(service.dispose);
  return service;
});

class MeshService {
  MeshService({required StorageService storage}) : _storage = storage;

  final StorageService _storage;
  final _db = Supabase.instance.client;
  final Nearby _nearby = Nearby();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _retryTimer;

  final Set<String> _connectedEndpoints = <String>{};
  final Set<String> _requestedEndpoints = <String>{};
  final Set<String> _seenPacketIds = <String>{};

  bool _initialized = false;
  bool _hasInternet = false;
  bool _isAdvertising = false;
  bool _isDiscovering = false;

  final _statusController = StreamController<MeshStatus>.broadcast();
  Stream<MeshStatus> get statusStream => _statusController.stream;

  bool get isOnline => _hasInternet;
  bool get isMeshRunning => _isAdvertising || _isDiscovering;
  int get connectedPeerCount => _connectedEndpoints.length;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _storage.init();
    await _refreshConnectivity();
    _watchConnectivity();
    _startRetryLoop();

    final granted = await _requestMeshPermissions();
    if (!granted) {
      debugPrint('[Mesh] Permissions not fully granted. Mesh transport disabled.');
      return;
    }

    await _startNearby();
  }

  void dispose() {
    _connectivitySub?.cancel();
    _retryTimer?.cancel();
    _statusController.close();

    _safeStopDiscovery();
    _safeStopAdvertising();
    _safeStopAllEndpoints();
  }

  Future<void> enqueueIAmSafe({
    required String householdId,
    required String originatorContact,
    double? lat,
    double? lng,
  }) {
    return _enqueue(
      householdId: householdId,
      originatorContact: originatorContact,
      type: MeshPacketType.iAmSafe,
      lat: lat,
      lng: lng,
    );
  }

  Future<void> enqueueResubmit({
    required String householdId,
    required String originatorContact,
    double? lat,
    double? lng,
  }) {
    return _enqueue(
      householdId: householdId,
      originatorContact: originatorContact,
      type: MeshPacketType.resubmitRequest,
      lat: lat,
      lng: lng,
    );
  }

  Future<void> _enqueue({
    required String householdId,
    required String originatorContact,
    required MeshPacketType type,
    double? lat,
    double? lng,
  }) async {
    final packet = MeshPacket(
      packetId: const Uuid().v4(),
      householdId: householdId,
      originatorContact: originatorContact,
      type: type,
      createdAt: DateTime.now().toUtc(),
      lat: lat,
      lng: lng,
    );

    await _storage.savePendingPacket(packet);
    debugPrint('[Mesh] Enqueued ${packet.type.name} for household=${packet.householdId}');

    if (_hasInternet) {
      await _deliverToSupabase(packet);
      await _storage.purgeDelivered();
      return;
    }

    await _broadcastPacket(packet);
    _emitStatus(MeshStatus.broadcasting);
  }

  Future<void> _refreshConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _hasInternet = results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      _hasInternet = false;
    }
  }

  void _watchConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) async {
      final wasOffline = !_hasInternet;
      _hasInternet = results.any((r) => r != ConnectivityResult.none);

      if (wasOffline && _hasInternet) {
        debugPrint('[Mesh] Connectivity available. Flushing queue.');
        _emitStatus(MeshStatus.flushing);
        await _flushQueue();
      }
    });
  }

  void _startRetryLoop() {
    _retryTimer = Timer.periodic(_kRetryInterval, (_) async {
      final pending = await _storage.getPendingPackets();
      if (pending.isEmpty) return;

      if (_hasInternet) {
        await _flushQueue();
      } else {
        for (final packet in pending) {
          await _broadcastPacket(packet);
        }
        _emitStatus(MeshStatus.broadcasting);
      }
    });
  }

  Future<void> _flushQueue() async {
    final pending = await _storage.getPendingPackets();
    for (final packet in pending) {
      await _deliverToSupabase(packet);
    }
    await _storage.purgeDelivered();
  }

  Future<void> _deliverToSupabase(MeshPacket packet) async {
    try {
      switch (packet.type) {
        case MeshPacketType.iAmSafe:
          await _db.from('households').update({
            'status': 'Rescued',
            'assigned_asset_id': null,
            'dispatched_at': null,
          }).eq('id', packet.householdId);
          break;

        case MeshPacketType.resubmitRequest:
          await _db.from('households').update({
            'approval_status': 'pending',
          }).eq('id', packet.householdId);
          break;
      }

      await _db.from('mesh_delivery_log').insert({
        'packet_id': packet.packetId,
        'household_id': packet.householdId,
        'originator_contact': packet.originatorContact,
        'type': packet.type.name,
        'created_at': packet.createdAt.toIso8601String(),
        'hop_count': packet.hopCount,
        'delivered_at': DateTime.now().toUtc().toIso8601String(),
        if (packet.lat != null) 'lat': packet.lat,
        if (packet.lng != null) 'lng': packet.lng,
      });

      await _storage.markDelivered(packet.packetId);
      _emitStatus(MeshStatus.delivered);
      debugPrint('[Mesh] Delivered packet=${packet.packetId}');
    } catch (e, st) {
      debugPrint('[Mesh] Delivery failed packet=${packet.packetId} error=$e\n$st');
      _emitStatus(MeshStatus.error);
    }
  }

  Future<void> _startNearby() async {
    await _startAdvertising();
    await _startDiscovery();
  }

  Future<void> _startAdvertising() async {
    if (_isAdvertising) return;

    try {
      final ok = await _nearby.startAdvertising(
        _deviceName(),
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: (String endpointId, ConnectionInfo info) async {
          debugPrint('[Mesh] Advertising: connection initiated from $endpointId');
          await _acceptConnection(endpointId);
        },
        onConnectionResult: (String endpointId, Status status) {
          debugPrint('[Mesh] Advertising: connection result $endpointId -> ${status.name}');
          if (status == Status.CONNECTED) {
            _connectedEndpoints.add(endpointId);
          }
        },
        onDisconnected: (String endpointId) {
          debugPrint('[Mesh] Advertising: disconnected $endpointId');
          _connectedEndpoints.remove(endpointId);
        },
        serviceId: _kServiceId,
      );

      _isAdvertising = ok;
      debugPrint('[Mesh] Advertising started=$_isAdvertising');
    } on PlatformException catch (e) {
      debugPrint('[Mesh] startAdvertising PlatformException: ${e.message}');
    } catch (e) {
      debugPrint('[Mesh] startAdvertising failed: $e');
    }
  }

  Future<void> _startDiscovery() async {
    if (_isDiscovering) return;

    try {
      final ok = await _nearby.startDiscovery(
        _deviceName(),
        Strategy.P2P_CLUSTER,
        onEndpointFound: (String endpointId, String endpointName, String serviceId) async {
          debugPrint('[Mesh] Found endpoint=$endpointId name=$endpointName service=$serviceId');

          if (serviceId != _kServiceId) return;
          if (_connectedEndpoints.contains(endpointId)) return;
          if (_requestedEndpoints.contains(endpointId)) return;

          _requestedEndpoints.add(endpointId);
          await _requestConnection(endpointId);
        },
        onEndpointLost: (String? endpointId) {
          debugPrint('[Mesh] Lost endpoint=$endpointId');
          if (endpointId == null) return;
          _requestedEndpoints.remove(endpointId);
          _connectedEndpoints.remove(endpointId);
        },
        serviceId: _kServiceId,
      );

      _isDiscovering = ok;
      debugPrint('[Mesh] Discovery started=$_isDiscovering');
    } on PlatformException catch (e) {
      debugPrint('[Mesh] startDiscovery PlatformException: ${e.message}');
    } catch (e) {
      debugPrint('[Mesh] startDiscovery failed: $e');
    }
  }

  Future<void> _requestConnection(String endpointId) async {
    try {
      await _nearby.requestConnection(
        _deviceName(),
        endpointId,
        onConnectionInitiated: (String id, ConnectionInfo info) async {
          debugPrint('[Mesh] RequestConnection initiated id=$id');
          await _acceptConnection(id);
        },
        onConnectionResult: (String id, Status status) async {
          debugPrint('[Mesh] RequestConnection result id=$id status=${status.name}');
          if (status == Status.CONNECTED) {
            _connectedEndpoints.add(id);
            await _pushPendingQueueToEndpoint(id);
          } else {
            _requestedEndpoints.remove(id);
          }
        },
        onDisconnected: (String id) {
          debugPrint('[Mesh] RequestConnection disconnected id=$id');
          _connectedEndpoints.remove(id);
          _requestedEndpoints.remove(id);
        },
      );
    } on PlatformException catch (e) {
      debugPrint('[Mesh] requestConnection PlatformException: ${e.message}');
      _requestedEndpoints.remove(endpointId);
    } catch (e) {
      debugPrint('[Mesh] requestConnection failed: $e');
      _requestedEndpoints.remove(endpointId);
    }
  }

  Future<void> _acceptConnection(String endpointId) async {
    try {
      await _nearby.acceptConnection(
        endpointId,
        onPayLoadRecieved: (String id, Payload payload) async {
          if (payload.type == PayloadType.BYTES && payload.bytes != null) {
            await handleIncomingBytes(payload.bytes!, sourceEndpointId: id);
          }
        },
      );

      _connectedEndpoints.add(endpointId);
      await _pushPendingQueueToEndpoint(endpointId);
    } on PlatformException catch (e) {
      debugPrint('[Mesh] acceptConnection PlatformException: ${e.message}');
    } catch (e) {
      debugPrint('[Mesh] acceptConnection failed: $e');
    }
  }

  Future<void> _pushPendingQueueToEndpoint(String endpointId) async {
    final pending = await _storage.getPendingPackets();
    for (final packet in pending) {
      await _sendPacketToEndpoint(endpointId, packet);
    }
  }

  Future<void> _broadcastPacket(MeshPacket packet) async {
    if (packet.hopCount >= _kMaxHops) {
      debugPrint('[Mesh] Drop packet=${packet.packetId} max hops reached');
      return;
    }

    if (_connectedEndpoints.isEmpty) {
      debugPrint('[Mesh] No connected peers yet for packet=${packet.packetId}');
      return;
    }

    for (final endpointId in _connectedEndpoints.toList()) {
      await _sendPacketToEndpoint(endpointId, packet);
    }
  }

  Future<void> _sendPacketToEndpoint(String endpointId, MeshPacket packet) async {
    try {
      await _nearby.sendBytesPayload(endpointId, Uint8List.fromList(packet.toBytes()));
      debugPrint('[Mesh] Sent packet=${packet.packetId} to endpoint=$endpointId');
    } catch (e) {
      debugPrint('[Mesh] sendPayload failed endpoint=$endpointId packet=${packet.packetId} error=$e');
    }
  }

  Future<void> _sendAck(String endpointId, String packetId) async {
    try {
      final ackBytes = Uint8List.fromList(
        utf8.encode(jsonEncode({
          'kind': 'ack',
          'packet_id': packetId,
        })),
      );
      await _nearby.sendBytesPayload(endpointId, ackBytes);
      debugPrint('[Mesh] ACK sent packet=$packetId to endpoint=$endpointId');
    } catch (e) {
      debugPrint('[Mesh] ACK send failed packet=$packetId endpoint=$endpointId error=$e');
    }
  }

  Future<void> handleIncomingBytes(
    List<int> bytes, {
    String? sourceEndpointId,
  }) async {
    try {
      final decoded = utf8.decode(bytes);
      final dynamic json = jsonDecode(decoded);

      if (json is Map<String, dynamic> && json['kind'] == 'ack') {
        final packetId = json['packet_id'] as String?;
        if (packetId != null) {
          await _storage.markDelivered(packetId);
          await _storage.purgeDelivered();
          _emitStatus(MeshStatus.delivered);
          debugPrint('[Mesh] ACK received packet=$packetId');
        }
        return;
      }

      final packet = MeshPacket.fromJson(json as Map<String, dynamic>);
      await _handleIncomingPacket(packet, sourceEndpointId: sourceEndpointId);
    } catch (e) {
      debugPrint('[Mesh] Failed to parse incoming payload: $e');
    }
  }

  Future<void> _handleIncomingPacket(
    MeshPacket packet, {
    String? sourceEndpointId,
  }) async {
    if (_seenPacketIds.contains(packet.packetId)) {
      debugPrint('[Mesh] Duplicate packet ignored ${packet.packetId}');
      return;
    }
    _seenPacketIds.add(packet.packetId);

    debugPrint('[Mesh] Incoming packet=${packet.packetId} type=${packet.type.name} hop=${packet.hopCount}');

    if (_hasInternet) {
      await _deliverToSupabase(packet);
      if (sourceEndpointId != null) {
        await _sendAck(sourceEndpointId, packet.packetId);
      }
      return;
    }

    final relay = packet.withNextHop();
    if (relay.hopCount > _kMaxHops) {
      debugPrint('[Mesh] Relay drop packet=${packet.packetId} hop overflow');
      return;
    }

    await _storage.savePendingPacket(relay);
    await _broadcastPacket(relay);
    _emitStatus(MeshStatus.broadcasting);
  }

  Future<bool> _requestMeshPermissions() async {
    try {
      if (defaultTargetPlatform != TargetPlatform.android) {
        debugPrint('[Mesh] Nearby relay is currently intended for Android.');
      }

      final statuses = await <Permission>[
        Permission.locationWhenInUse,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.nearbyWifiDevices,
      ].request();

      final allGranted = statuses.values.every((s) {
        return s.isGranted || s.isLimited;
      });

      return allGranted;
    } catch (e) {
      debugPrint('[Mesh] Permission request failed: $e');
      return false;
    }
  }

  String _deviceName() {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    return 'LIGTAS-${ts.substring(ts.length - 6)}';
  }

  void _safeStopAdvertising() {
    try {
      _nearby.stopAdvertising();
    } catch (_) {}
    _isAdvertising = false;
  }

  void _safeStopDiscovery() {
    try {
      _nearby.stopDiscovery();
    } catch (_) {}
    _isDiscovering = false;
  }

  void _safeStopAllEndpoints() {
    try {
      _nearby.stopAllEndpoints();
    } catch (_) {}
    _connectedEndpoints.clear();
    _requestedEndpoints.clear();
  }

  void _emitStatus(MeshStatus status) {
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }
}

enum MeshStatus {
  broadcasting,
  flushing,
  delivered,
  error,
}