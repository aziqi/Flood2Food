import 'dart:async';
import 'dart:math';
import 'ble_service_base.dart';
import '../models/bluetooth_sensor_data.dart';

class MockBleService extends BleServiceBase {
  final _dataController = StreamController<BluetoothSensorData>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  Timer? _simTimer;
  bool _connected = false;
  final _rng = Random();

  @override
  Stream<BluetoothSensorData> get dataStream => _dataController.stream;
  @override
  Stream<bool> get connectionState => _connectionController.stream;
  @override
  bool get isConnected => _connected;

  @override
  Future<List<BleScanResult>> scan({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await Future.delayed(const Duration(seconds: 2));
    return [
      BleScanResult(
        deviceId: '00:11:22:33:44:55',
        name: 'Mock Sensor Node #1',
        rssi: -55,
      ),
    ];
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> sendCommand(String command) async {}

  @override
  Future<void> connect(String deviceId) async {
    await Future.delayed(const Duration(seconds: 1));
    _connected = true;
    _connectionController.add(true);
    _startSimulation();
  }

  void _startSimulation() {
    _simTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final now = DateTime.now();
      _dataController.add(
        BluetoothSensorData(
          nodeId: 'MOCK-001',
          waktu: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
          tanggal: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
          suhu: 28 + _rng.nextDouble() * 6,
          humi: 55 + _rng.nextDouble() * 30,
          kond: _rng.nextDouble() * 2000,
          ph: 5.5 + _rng.nextDouble() * 2.5,
          n: 20 + _rng.nextDouble() * 60,
          p: 10 + _rng.nextDouble() * 50,
          k: 15 + _rng.nextDouble() * 45,
          sd: 1,
          lora: 1,
          modeHemat: false,
          status: 'connected',
        ),
      );
    });
  }

  @override
  Future<void> disconnect() async {
    _simTimer?.cancel();
    _simTimer = null;
    _connected = false;
    _connectionController.add(false);
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    _dataController.close();
    _connectionController.close();
  }
}
