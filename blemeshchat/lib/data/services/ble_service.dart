// lib/data/services/ble_service.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/device_node.dart';

class BLEService {
  static const String SERVICE_UUID = '0000MESH-0000-1000-8000-00805F9B34FB';
  static const String CHAR_MESSAGE_TX_UUID = '0000MEA1-0000-1000-8000-00805F9B34FB';
  static const String CHAR_MESSAGE_RX_UUID = '0000MEA2-0000-1000-8000-00805F9B34FB';
  static const String CHAR_DEVICE_INFO_UUID = '0000MEA3-0000-1000-8000-00805F9B34FB';

  // Maximum simultaneous connections
  static const int MAX_CONNECTIONS_IOS = 7;
  static const int MAX_CONNECTIONS_ANDROID = 15;

  // Connected devices map: deviceId -> BluetoothDevice
  final Map<String, BluetoothDevice> _connectedDevices = {};
  
  // Characteristics cache: deviceId -> characteristics
  final Map<String, BluetoothCharacteristic> _txCharacteristics = {};
  final Map<String, BluetoothCharacteristic> _rxCharacteristics = {};
  
  // Stream controllers
  final _scanResultsController = StreamController<List<DeviceNode>>.broadcast();
  final _connectionStateController = StreamController<ConnectionStateUpdate>.broadcast();
  final _dataReceivedController = StreamController<ReceivedData>.broadcast();
  
  // Discovered devices cache
  final Map<String, DeviceNode> _discoveredDevices = {};
  
  // My device info
  String? _myDeviceId;
  String? _myDeviceName;
  
  bool _isScanning = false;
  bool _isAdvertising = false;
  bool _isInitialized = false;

  // Getters
  Stream<List<DeviceNode>> get scanResults => _scanResultsController.stream;
  Stream<ConnectionStateUpdate> get connectionStates => _connectionStateController.stream;
  Stream<ReceivedData> get dataReceived => _dataReceivedController.stream;
  bool get isScanning => _isScanning;
  bool get isAdvertising => _isAdvertising;
  List<DeviceNode> get connectedDevices {
    return _connectedDevices.keys.map((id) => _discoveredDevices[id]).whereType<DeviceNode>().toList();
  }

  //Initialize ble service
  

  /// Start scanning for nearby devices
  Future<void> startScanning() async {
    if (_isScanning) return;
    if (!_isInitialized) throw Exception('BLE Service not initialized');

    print('Starting BLE scan...');
    _isScanning = true;

    try {
      // Start scanning with service UUID filter
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 30),
        withServices: [Guid(SERVICE_UUID)],
      );

      // Listen to scan results
      FlutterBluePlus.scanResults.listen((results) {
        _processScanResults(results);
      });

      // Listen for scan stopped
      FlutterBluePlus.isScanning.listen((scanning) {
        if (!scanning) {
          _isScanning = false;
          print('BLE scan stopped');
        }
      });
    } catch (e) {
      _isScanning = false;
      print('Error starting scan: $e');
      rethrow;
    }
  }

  /// Stop scanning
  Future<void> stopScanning() async {
    if (!_isScanning) return;

    try {
      await FlutterBluePlus.stopScan();
      _isScanning = false;
      print('BLE scan stopped manually');
    } catch (e) {
      print('Error stopping scan: $e');
    }
  }

  /// Start advertising (peripheral mode)
  Future<void> startAdvertising() async {
    if (_isAdvertising) return;
    if (!_isInitialized) throw Exception('BLE Service not initialized');

    print('Starting BLE advertising...');
    
    // Note: flutter_blue_plus doesn't support peripheral mode natively
    // You would need to use platform channels or a different package like flutter_ble_peripheral
    // For now, we'll mark it as advertising and implement actual advertising via platform channels
    
    _isAdvertising = true;
    
    // TODO: Implement platform-specific advertising
    // - iOS: Use CoreBluetooth CBPeripheralManager
    // - Android: Use BluetoothLeAdvertiser
    
    print('BLE advertising started (requires platform implementation)');
  }

  /// Stop advertising
  Future<void> stopAdvertising() async {
    if (!_isAdvertising) return;

    _isAdvertising = false;
    
    // TODO: Implement platform-specific stop advertising
    
    print('BLE advertising stopped');
  }

  /// Connect to a device
  Future<void> connectToDevice(String deviceId) async {
    if (_connectedDevices.containsKey(deviceId)) {
      print('Already connected to device: $deviceId');
      return;
    }

    final deviceNode = _discoveredDevices[deviceId];
    if (deviceNode == null) {
      throw Exception('Device not found: $deviceId');
    }

    // Check connection limit
    final maxConnections = _getMaxConnections();
    if (_connectedDevices.length >= maxConnections) {
      throw Exception('Maximum connections reached ($maxConnections)');
    }

    print('Connecting to device: ${deviceNode.name}...');

    try {
      // Find the Bluetooth device from scan results
      final scanResults = await FlutterBluePlus.scanResults.first;
      final scanResult = scanResults.firstWhere(
        (result) => result.device.id.toString() == deviceNode.address,
        orElse: () => throw Exception('Device not found in scan results'),
      );

      final device = scanResult.device;

      // Connect to device
      //await device.connect();

      // Discover services
      final services = await device.discoverServices();

      // Find our custom service
      final service = services.firstWhere(
        (s) => s.uuid.toString().toUpperCase() == SERVICE_UUID.toUpperCase(),
        orElse: () => throw Exception('Mesh service not found'),
      );

      // Find characteristics
      final txChar = service.characteristics.firstWhere(
        (c) => c.uuid.toString().toUpperCase() == CHAR_MESSAGE_TX_UUID.toUpperCase(),
        orElse: () => throw Exception('TX characteristic not found'),
      );

      final rxChar = service.characteristics.firstWhere(
        (c) => c.uuid.toString().toUpperCase() == CHAR_MESSAGE_RX_UUID.toUpperCase(),
        orElse: () => throw Exception('RX characteristic not found'),
      );

      // Subscribe to RX notifications
      await rxChar.setNotifyValue(true);
      rxChar.value.listen((value) {
        if (value.isNotEmpty) {
          _dataReceivedController.add(ReceivedData(
            deviceId: deviceId,
            data: Uint8List.fromList(value),
          ));
        }
      });

      // Store device and characteristics
      _connectedDevices[deviceId] = device;
      _txCharacteristics[deviceId] = txChar;
      _rxCharacteristics[deviceId] = rxChar;

      // Update device node
      _discoveredDevices[deviceId] = deviceNode.copyWith(isConnected: true);

      // Emit connection state
      _connectionStateController.add(ConnectionStateUpdate(
        deviceId: deviceId,
        state: ConnectionState.connected,
      ));

      print('Connected to device: ${deviceNode.name}');

      // Listen for disconnection
      device.state.listen((state) {
        if (state == BluetoothDeviceState.disconnected) {
          _handleDisconnection(deviceId);
        }
      });
    } catch (e) {
      print('Error connecting to device: $e');
      _handleDisconnection(deviceId);
      rethrow;
    }
  }

  /// Disconnect from a device
  Future<void> disconnectDevice(String deviceId) async {
    final device = _connectedDevices[deviceId];
    if (device == null) return;

    try {
      await device.disconnect();
      _handleDisconnection(deviceId);
      print('Disconnected from device: $deviceId');
    } catch (e) {
      print('Error disconnecting: $e');
    }
  }

  /// Send data to a connected device
  Future<void> sendData(String deviceId, Uint8List data) async {
    final txChar = _txCharacteristics[deviceId];
    if (txChar == null) {
      throw Exception('Device not connected: $deviceId');
    }

    try {
      // Split data into chunks if necessary (BLE MTU limit)
      const maxChunkSize = 512;
      
      if (data.length <= maxChunkSize) {
        await txChar.write(data, withoutResponse: true);
      } else {
        // Send data in chunks
        for (int i = 0; i < data.length; i += maxChunkSize) {
          final end = (i + maxChunkSize < data.length) ? i + maxChunkSize : data.length;
          final chunk = data.sublist(i, end);
          await txChar.write(chunk, withoutResponse: true);
          await Future.delayed(const Duration(milliseconds: 50)); // Small delay between chunks
        }
      }

      print('Sent ${data.length} bytes to device: $deviceId');
    } catch (e) {
      print('Error sending data: $e');
      rethrow;
    }
  }

  /// Disconnect all devices
  Future<void> disconnectAll() async {
    final deviceIds = _connectedDevices.keys.toList();
    for (final deviceId in deviceIds) {
      await disconnectDevice(deviceId);
    }
  }

  /// Dispose resources
  void dispose() {
    stopScanning();
    stopAdvertising();
    disconnectAll();
    _scanResultsController.close();
    _connectionStateController.close();
    _dataReceivedController.close();
  }

  // Private helper methods

  void _processScanResults(List<ScanResult> results) {
    final updatedDevices = <DeviceNode>[];

    for (final result in results) {
      final deviceId = _extractDeviceId(result);
      if (deviceId == null || deviceId == _myDeviceId) continue;

      final deviceName = result.device.name.isNotEmpty 
          ? result.device.name 
          : 'Unknown Device';

      final existingDevice = _discoveredDevices[deviceId];
      final deviceNode = DeviceNode(
        id: deviceId,
        name: deviceName,
        address: result.device.id.toString(),
        rssi: result.rssi,
        lastSeen: DateTime.now(),
        isConnected: existingDevice?.isConnected ?? false,
        hopCount: 0, // Direct connection
      );

      _discoveredDevices[deviceId] = deviceNode;
      updatedDevices.add(deviceNode);
    }

    _scanResultsController.add(updatedDevices);
  }

  String? _extractDeviceId(ScanResult result) {
    // Try to get device ID from advertisement data
    final manufacturerData = result.advertisementData.manufacturerData;
    if (manufacturerData.isNotEmpty) {
      // Assume device ID is in manufacturer data (first 16 bytes)
      final data = manufacturerData.values.first;
      if (data.length >= 16) {
        return _bytesToUuid(Uint8List.fromList(data.sublist(0, 16)));
      }
    }

    // Fallback: use device MAC address as ID
    return result.device.id.toString();
  }

  String _bytesToUuid(Uint8List bytes) {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  void _handleDisconnection(String deviceId) {
    _connectedDevices.remove(deviceId);
    _txCharacteristics.remove(deviceId);
    _rxCharacteristics.remove(deviceId);

    final device = _discoveredDevices[deviceId];
    if (device != null) {
      _discoveredDevices[deviceId] = device.copyWith(isConnected: false);
    }

    _connectionStateController.add(ConnectionStateUpdate(
      deviceId: deviceId,
      state: ConnectionState.disconnected,
    ));
  }

  int _getMaxConnections() {
    // TODO: Detect platform (iOS vs Android)
    // For now, use conservative limit
    return MAX_CONNECTIONS_IOS;
  }
}

// Helper classes

class ConnectionStateUpdate {
  final String deviceId;
  final ConnectionState state;

  ConnectionStateUpdate({
    required this.deviceId,
    required this.state,
  });
}

enum ConnectionState {
  connecting,
  connected,
  disconnecting,
  disconnected,
}

class ReceivedData {
  final String deviceId;
  final Uint8List data;

  ReceivedData({
    required this.deviceId,
    required this.data,
  });
}