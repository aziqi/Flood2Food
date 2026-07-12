import '../../models/sensor_data.dart';
import '../../services/ble_service_base.dart';

abstract class SensorEvent {}

class ConnectSensor extends SensorEvent {}

class ConnectBluetoothSensor extends SensorEvent {
  final BleServiceBase bleService;
  ConnectBluetoothSensor(this.bleService);
}

class DisconnectSensor extends SensorEvent {}

class LoadSensorLog extends SensorEvent {}

class SensorDataReceived extends SensorEvent {
  final SensorData data;
  SensorDataReceived(this.data);
}

class BleDisconnected extends SensorEvent {}

class HistoryCompleteEvent extends SensorEvent {}

class ClearSensorLog extends SensorEvent {}

class CancelHistorySync extends SensorEvent {}

class FetchNodeDataEvent extends SensorEvent {}

class FetchAllNodeDataEvent extends SensorEvent {}

class ToggleModeEvent extends SensorEvent {}

class StartCalibrationEvent extends SensorEvent {}

class TriggerCalibrationReadEvent extends SensorEvent {}

class AddCalibrationPointEvent extends SensorEvent {
  final SensorData data;
  AddCalibrationPointEvent(this.data);
}

class FinishCalibrationEvent extends SensorEvent {}

class CancelCalibrationEvent extends SensorEvent {}

class DeleteSdCardEvent extends SensorEvent {
  final String target; // 'node' atau 'gateway'
  DeleteSdCardEvent({required this.target});
}

class ClearErrorEvent extends SensorEvent {}

class ClearSuccessEvent extends SensorEvent {}

class SetIntervalEvent extends SensorEvent {
  final int normalSec;
  final int hematSec;
  SetIntervalEvent({required this.normalSec, required this.hematSec});
}
