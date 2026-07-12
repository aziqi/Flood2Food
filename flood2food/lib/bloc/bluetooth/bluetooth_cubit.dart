import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bluetooth_state.dart';
import '../../services/bluetooth_service.dart';

class BluetoothCubit extends Cubit<BluetoothState> {
  final BleServiceBase _service;
  bool keepServiceAlive = false;

  StreamSubscription? _scanSub;

  BluetoothCubit({BleServiceBase? service})
      : _service = service ?? RealBleService(),
        super(const BluetoothInitial()) {
    startScan();
  }

  BleServiceBase get service => _service;

  void startScan() async {
    emit(const BluetoothScanning([]));
    
    _scanSub?.cancel();
    _scanSub = _service.scanResultsStream.listen((devices) {
      emit(BluetoothScanning(devices));
    });

    try {
      await _service.startScan();
    } catch (e) {
      emit(BluetoothError(e.toString()));
    }
  }

  void stopScan() {
    _service.stopScan();
  }

  Future<void> connect(String deviceId, String deviceName) async {
    emit(BluetoothConnecting(deviceName));
    try {
      await _service.connect(deviceId);
      emit(BluetoothConnected(deviceName));
    } catch (e) {
      emit(BluetoothError(e.toString()));
    }
  }

  Future<void> disconnect() async {
    await _service.disconnect();
    emit(const BluetoothDisconnected());
  }

  void clearError() {
    if (state is BluetoothError) {
      emit(const BluetoothDisconnected());
    }
  }

  @override
  Future<void> close() {
    _scanSub?.cancel();
    if (!keepServiceAlive) {
      _service.dispose();
    }
    return super.close();
  }
}
