import '../../services/bluetooth_service.dart';

abstract class BluetoothState {
  const BluetoothState();
}

class BluetoothInitial extends BluetoothState {
  const BluetoothInitial();
}

class BluetoothScanning extends BluetoothState {
  final List<BleScanResult> devices;
  const BluetoothScanning(this.devices);
}

class BluetoothScanComplete extends BluetoothState {
  final List<BleScanResult> devices;
  const BluetoothScanComplete(this.devices);
}

class BluetoothConnecting extends BluetoothState {
  final String deviceName;
  const BluetoothConnecting(this.deviceName);
}

class BluetoothConnected extends BluetoothState {
  final String deviceName;
  const BluetoothConnected(this.deviceName);
}

class BluetoothDisconnected extends BluetoothState {
  final String? lastDeviceName;
  const BluetoothDisconnected({this.lastDeviceName});
}

class BluetoothError extends BluetoothState {
  final String message;
  const BluetoothError(this.message);
}
