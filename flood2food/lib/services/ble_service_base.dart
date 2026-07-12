import 'dart:async';
import '../models/bluetooth_sensor_data.dart';

class BleScanResult {
  final String deviceId;
  final String name;
  final int rssi;

  BleScanResult({
    required this.deviceId,
    required this.name,
    required this.rssi,
  });
}

abstract class BleServiceBase {
  Stream<BluetoothSensorData> get dataStream;
  Stream<bool> get connectionState;
  Stream<List<BleScanResult>> get scanResultsStream;
  bool get isConnected;

  Future<void> startScan({Duration timeout = const Duration(seconds: 15)});
  Future<void> stopScan();
  Future<void> connect(String deviceId);
  Future<void> disconnect();
  Future<void> sendCommand(String command);
  Future<void> cancelSync() async {}
  void dispose();
}
