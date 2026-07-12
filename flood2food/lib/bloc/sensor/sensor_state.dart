import '../../models/sensor_data.dart';

abstract class SensorState {
  final SensorData latestData;
  final List<SensorData> history;
  final bool isConnected;
  final String? source;
  final bool isLoadingHistory;
  final int syncProgress;
  final int syncTotal;
  final bool isCalibrating;
  final bool isWaitingCalibrationData;
  final List<SensorData> calibrationPoints;
  final String? errorMessage;
  final String? successMessage;

  const SensorState({
    required this.latestData,
    required this.history,
    required this.isConnected,
    this.source,
    this.isLoadingHistory = false,
    this.syncProgress = 0,
    this.syncTotal = 0,
    this.isCalibrating = false,
    this.isWaitingCalibrationData = false,
    this.calibrationPoints = const [],
    this.errorMessage,
    this.successMessage,
  });
}

class SensorInitial extends SensorState {
  SensorInitial()
    : super(
        isConnected: false,
        latestData: SensorData(
          nitrogen: 0,
          phosphorus: 0,
          kalium: 0,
          temperature: 0,
          ec: 0,
          humidity: 0,
          ph: 0.0,
          timestamp: DateTime.fromMillisecondsSinceEpoch(0),
        ),
        history: const [],
        isLoadingHistory: false,
        syncProgress: 0,
        syncTotal: 1,
        isCalibrating: false,
        isWaitingCalibrationData: false,
        calibrationPoints: const [],
      );
}

class SensorConnected extends SensorState {
  const SensorConnected({
    required super.latestData,
    required super.history,
    super.source,
    super.isLoadingHistory = false,
    super.syncProgress = 0,
    super.syncTotal = 1,
    super.isCalibrating = false,
    super.isWaitingCalibrationData = false,
    super.calibrationPoints = const [],
    super.errorMessage,
    super.successMessage,
  }) : super(isConnected: true);

  SensorConnected copyWith({
    SensorData? latestData,
    List<SensorData>? history,
    String? source,
    bool? isLoadingHistory,
    int? syncProgress,
    int? syncTotal,
    bool? isCalibrating,
    bool? isWaitingCalibrationData,
    List<SensorData>? calibrationPoints,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return SensorConnected(
      latestData: latestData ?? this.latestData,
      history: history ?? this.history,
      source: source ?? this.source,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      syncProgress: syncProgress ?? this.syncProgress,
      syncTotal: syncTotal ?? this.syncTotal,
      isCalibrating: isCalibrating ?? this.isCalibrating,
      isWaitingCalibrationData: isWaitingCalibrationData ?? this.isWaitingCalibrationData,
      calibrationPoints: calibrationPoints ?? this.calibrationPoints,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class SensorDisconnected extends SensorState {
  const SensorDisconnected({
    required super.latestData,
    required super.history,
    super.source,
  }) : super(isConnected: false, isLoadingHistory: false, syncProgress: 0, syncTotal: 1, isCalibrating: false, isWaitingCalibrationData: false, calibrationPoints: const []);
}
