import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'sensor_event.dart';
import 'sensor_state.dart';
import '../../models/sensor_data.dart';
import '../../services/sensor_service.dart';
import '../../services/ble_service_base.dart';
import '../../services/sensor_log_service.dart';
import '../../services/firebase_sync_service.dart';
import '../../services/calibration_log_service.dart';
import '../../utils/statistical_engine.dart';

class SensorBloc extends Bloc<SensorEvent, SensorState> {
  final SensorService _sensorService = SensorService();
  final SensorLogService _logService = SensorLogService();
  BleServiceBase? _bleService;
  StreamSubscription<dynamic>? _subscription;
  StreamSubscription<dynamic>? _bleSub;
  StreamSubscription<bool>? _bleConnSub;

  Timer? _logBatchTimer;
  final List<SensorData> _logBuffer = [];

  SensorBloc() : super(SensorInitial()) {
    on<ConnectSensor>(_onConnect);
    on<ConnectBluetoothSensor>(_onConnectBluetooth);
    on<DisconnectSensor>(_onDisconnect);
    on<SensorDataReceived>(_onDataReceived);
    on<LoadSensorLog>(_onLoadLog);
    on<BleDisconnected>(_onBleDisconnected);
    on<HistoryCompleteEvent>(_onHistoryComplete);
    on<ClearSensorLog>(_onClearLog);
    on<CancelHistorySync>(_onCancelHistorySync);
    on<FetchNodeDataEvent>(_onFetchNodeData);
    on<FetchAllNodeDataEvent>(_onFetchAllNodeData);
    on<ToggleModeEvent>(_onToggleMode);
    on<StartCalibrationEvent>(_onStartCalibration);
    on<TriggerCalibrationReadEvent>(_onTriggerCalibrationRead);
    on<AddCalibrationPointEvent>(_onAddCalibrationPoint);
    on<FinishCalibrationEvent>(_onFinishCalibration);
    on<CancelCalibrationEvent>(_onCancelCalibration);
    on<DeleteSdCardEvent>(_onDeleteSdCard);
    on<ClearErrorEvent>(_onClearError);
    on<ClearSuccessEvent>(_onClearSuccess);
    on<SetIntervalEvent>(_onSetInterval);
    add(LoadSensorLog());
  }

  Future<void> _onLoadLog(
    LoadSensorLog event,
    Emitter<SensorState> emit,
  ) async {
    // 1. Coba tarik dari Cloud Firebase
    final cloudLogs = await FirebaseSyncService.fetchSensorHistory();
    
    // 2. Tarik dari log lokal (sebagai cadangan)
    final localLogs = await _logService.loadLog();
    
    // 3. Gunakan Cloud jika ada, jika kosong gunakan Lokal
    final logs = cloudLogs.isNotEmpty ? cloudLogs : localLogs;
    
    if (logs.isNotEmpty) {
      emit(SensorDisconnected(latestData: logs.last, history: logs));
    }
  }

  Future<void> _onConnect(
    ConnectSensor event,
    Emitter<SensorState> emit,
  ) async {
    await _disconnectAll();
    emit(
      SensorConnected(
        latestData: state.latestData,
        history: state.history,
        source: 'simulasi',
        isLoadingHistory: false, // Langsung simulasi tanpa loading SD Card
      ),
    );
    
    _subscription = _sensorService.sensorStream.listen((data) {
      if (data.status == 'history_complete') {
        add(HistoryCompleteEvent());
      } else {
        add(SensorDataReceived(data));
      }
    });

    // Safety timeout
    Timer(const Duration(seconds: 15), () {
      if (!isClosed) {
        add(HistoryCompleteEvent());
      }
    });

    await _sensorService.startSimulation();
  }

  Future<void> _onConnectBluetooth(
    ConnectBluetoothSensor event,
    Emitter<SensorState> emit,
  ) async {
    await _disconnectAll();
    emit(
      SensorConnected(
        latestData: state.latestData,
        history: state.history,
        source: 'bluetooth',
        isLoadingHistory: true, // Otomatis loading karena Node akan langsung memuntahkan data saat terhubung
      ),
    );
    _bleService = event.bleService;

    // Safety timeout: hanya jika 5 menit (300 detik) tidak ada history_complete, auto-hide loading
    Timer(const Duration(seconds: 300), () {
      if (!isClosed) {
        add(HistoryCompleteEvent());
      }
    });

    FlutterForegroundTask.startService(
      notificationTitle: 'Flood2Food',
      notificationText: 'Memantau sensor di latar belakang',
    );
    _startLogBatchTimer();

    try {
      _bleSub = _bleService!.dataStream.listen((data) {
        if (data.status == 'history_complete') {
          add(HistoryCompleteEvent());
        } else {
          add(SensorDataReceived(SensorData.fromBluetoothSensorData(data)));
        }
      });
      _bleConnSub = _bleService!.connectionState.listen((isConnected) {
        if (!isConnected) {
          add(BleDisconnected());
        }
      });
    } catch (e) {
      emit(
        SensorDisconnected(
          latestData: state.latestData,
          history: state.history,
          source: 'bluetooth',
        ),
      );
    }
  }

  void _onBleDisconnected(BleDisconnected event, Emitter<SensorState> emit) {
    emit(
      SensorDisconnected(
        latestData: state.latestData,
        history: state.history,
        source: 'bluetooth',
      ),
    );
  }

  Future<void> _onHistoryComplete(
    HistoryCompleteEvent event,
    Emitter<SensorState> emit,
  ) async {
    await _flushLogBuffer();
    if (state is SensorConnected) {
      emit(
        (state as SensorConnected).copyWith(isLoadingHistory: false),
      );
    }
  }

  void _onDisconnect(DisconnectSensor event, Emitter<SensorState> emit) {
    _disconnectAll();
    emit(
      SensorDisconnected(latestData: state.latestData, history: state.history),
    );
  }

  Future<void> _onClearLog(
    ClearSensorLog event,
    Emitter<SensorState> emit,
  ) async {
    // 1. Langsung bersihkan memori lokal dan persiapkan data kosong
    _logBuffer.clear();
    final emptyData = SensorData(
      nitrogen: 0,
      phosphorus: 0,
      kalium: 0,
      temperature: 0,
      ec: 0,
      humidity: 0,
      ph: 0.0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    );

    // 2. Langsung pancarkan status kosong ke UI (agar grafik & angka instan menjadi nol)
    if (state is SensorConnected) {
      emit(
        SensorConnected(
          latestData: emptyData,
          history: const [],
          source: state.source,
        ),
      );
    } else {
      emit(SensorDisconnected(latestData: emptyData, history: const []));
    }

    // 3. Eksekusi pembersihan fisik di latar belakang (tanpa memblokir UI)
    await _logService.clearLog();
    FirebaseSyncService.deleteSensorHistory(); // Berjalan asinkron (tanpa await)
  }

  Future<void> _onCancelHistorySync(
    CancelHistorySync event,
    Emitter<SensorState> emit,
  ) async {
    if (_bleService != null) {
      await _bleService!.cancelSync();
    }
    
    // Langsung hentikan tampilan loading bar
    if (state is SensorConnected) {
      emit(
        SensorConnected(
          latestData: state.latestData,
          history: state.history,
          source: state.source,
          isLoadingHistory: false,
        ),
      );
    }
  }

  void _onFetchNodeData(FetchNodeDataEvent event, Emitter<SensorState> emit) {
    if (state is SensorConnected && _bleService != null) {
      final connected = state as SensorConnected;
      
      // 🛡️ ANTI-SPAM: Abaikan klik jika sinkronisasi sedang berlangsung
      if (connected.isLoadingHistory) {
        debugPrint('Spam dihentikan: Sedang sinkronisasi...');
        return; 
      }
      
      if (connected.source == 'bluetooth') {
        emit(connected.copyWith(isLoadingHistory: true));
        _bleService!.sendCommand('get_data');
      }
    }
  }

  void _onFetchAllNodeData(FetchAllNodeDataEvent event, Emitter<SensorState> emit) {
    if (state is SensorConnected && _bleService != null) {
      final connected = state as SensorConnected;
      
      // 🛡️ ANTI-SPAM
      if (connected.isLoadingHistory) {
        return; 
      }
      
      if (connected.source == 'bluetooth') {
        emit(connected.copyWith(isLoadingHistory: true));
        _bleService!.sendCommand('H_ALL');
      }
    }
  }

  Future<void> _onToggleMode(
    ToggleModeEvent event,
    Emitter<SensorState> emit,
  ) async {
    if (_bleService != null && state is SensorConnected) {
      final currentState = state as SensorConnected;
      final currentData = currentState.latestData;
      
      final updatedData = SensorData(
        nitrogen: currentData.nitrogen,
        temperature: currentData.temperature,
        kalium: currentData.kalium,
        phosphorus: currentData.phosphorus,
        ec: currentData.ec,
        humidity: currentData.humidity,
        ph: currentData.ph,
        timestamp: currentData.timestamp,
        modeHemat: !currentData.modeHemat,
        status: currentData.status,
      );

      emit(currentState.copyWith(latestData: updatedData));
      await _bleService!.sendCommand("TOGGLE_MODE");
    }
  }

  Future<void> _onDataReceived(
    SensorDataReceived event,
    Emitter<SensorState> emit,
  ) async {
    final newData = event.data;
    
    if (newData.status == 'sync_progress') {
      if (state is SensorConnected) {
        emit(
          SensorConnected(
            latestData: state.latestData,
            history: state.history,
            source: state.source,
            isLoadingHistory: state.isLoadingHistory,
            syncProgress: newData.temperature.toInt(),
            syncTotal: newData.humidity.toInt(),
          ),
        );
      }
      return;
    }
    
    if (newData.status == 'error' || newData.status.startsWith('error_')) {
      if (state is SensorConnected) {
        final current = state as SensorConnected;
        String errorMsg = newData.status.startsWith('error_') 
            ? newData.status.substring('error_'.length) 
            : 'Terjadi kesalahan sistem';
        if (errorMsg.isEmpty) errorMsg = 'Terjadi kesalahan sistem';
            
        emit(current.copyWith(
          errorMessage: errorMsg,
          isWaitingCalibrationData: current.isWaitingCalibrationData ? false : current.isWaitingCalibrationData,
        ));
      }
      return; 
    }

    if (newData.status == 'success' || newData.status.startsWith('success_')) {
      if (state is SensorConnected) {
        final current = state as SensorConnected;
        String successMsg = newData.status.startsWith('success_') 
            ? newData.status.substring('success_'.length) 
            : 'Berhasil!';
        if (successMsg.isEmpty) successMsg = 'Berhasil memproses data!';
            
        emit(current.copyWith(
          successMessage: successMsg,
        ));
      }
      return; 
    }

    final isHistory = newData.status == 'history';
    final currentHistory = List<SensorData>.from(state.history);

    // Lempar data ke Firebase secara asinkron (hanya untuk data Live, data History diunggah via Batch)
    if (!isHistory) {
      FirebaseSyncService.pushSensorData(newData);
    }

    _logBuffer.add(newData);

    bool currentLoadingHistory = (state is SensorConnected)
        ? (state as SensorConnected).isLoadingHistory
        : false;

    // If we receive live data, force loading history to false because live data only flows after history completes
    if (!isHistory && currentLoadingHistory) {
      currentLoadingHistory = false;
    }

    if (isHistory || currentLoadingHistory) {
      // 🛡️ ANTI-DUPLIKASI (UPSERT): Jika waktu persis sama, timpa datanya, jangan ditumpuk!
      final existingIndex = currentHistory.indexWhere((d) => d.timestamp == newData.timestamp);
      if (existingIndex != -1) {
        currentHistory[existingIndex] = newData;
      } else {
        currentHistory.add(newData);
      }
      
      currentHistory.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      emit(
        SensorConnected(
          latestData:
              state.latestData, // Keep the live data as latest if it exists
          history: currentHistory,
          source: state.source,
          isLoadingHistory: currentLoadingHistory,
        ),
      );
      return;
    }

    // 🛡️ ANTI-AMNESIA: Batas memori UI dinaikkan menjadi 10.000 (sekitar 1 bulan data per 5 detik)
    // agar hasil sinkronisasi History yang melelahkan tidak langsung sirna saat 1 data Live masuk!
    final trimmed = currentHistory.length > 10000
        ? currentHistory.sublist(currentHistory.length - 10000)
        : currentHistory;

    // 🛡️ ANTI-DUPLIKASI (LIVE): Sama halnya untuk data live yang baru masuk
    final existingIndexLive = trimmed.indexWhere((d) => d.timestamp == newData.timestamp);
    if (existingIndexLive != -1) {
      trimmed[existingIndexLive] = newData;
    } else {
      trimmed.add(newData);
    }

    if (state is SensorConnected) {
      final current = state as SensorConnected;
      
      List<SensorData> updatedCalibPoints = current.calibrationPoints;
      bool stillWaiting = current.isWaitingCalibrationData;
      
      if (current.isCalibrating && current.isWaitingCalibrationData) {
        updatedCalibPoints = List<SensorData>.from(current.calibrationPoints)..add(newData);
        stillWaiting = false;
      }
      
      emit(
        current.copyWith(
          latestData: newData,
          history: trimmed,
          source: current.source,
          isLoadingHistory: false,
          calibrationPoints: updatedCalibPoints,
          isWaitingCalibrationData: stillWaiting,
        ),
      );
    }
  }

  void _startLogBatchTimer() {
    _logBatchTimer?.cancel();
    _logBatchTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _flushLogBuffer();
    });
  }

  Future<void> _flushLogBuffer() async {
    if (_logBuffer.isEmpty) return;

    final batch = List<SensorData>.from(_logBuffer);
    _logBuffer.clear();

    // Write all at once - much faster than one-by-one
    await _logService.appendBatchLog(batch);
    
    // 🔥 BATCH FIREBASE UPLOAD: Filter data history untuk diunggah secara batch ke Firebase
    final historyBatch = batch.where((d) => d.status == 'history').toList();
    if (historyBatch.isNotEmpty) {
      FirebaseSyncService.pushSensorDataBatch(historyBatch);
    }
  }

  Future<void> _disconnectAll() async {
    _logBatchTimer?.cancel();
    _logBatchTimer = null;

    await _flushLogBuffer();

    _subscription?.cancel();
    _subscription = null;
    _sensorService.stop();
    _bleSub?.cancel();
    _bleSub = null;
    _bleConnSub?.cancel();
    _bleConnSub = null;
    if (_bleService != null) {
      await _bleService!.disconnect();
    }
    _bleService = null;

    FlutterForegroundTask.stopService();
  }

  void _onStartCalibration(
    StartCalibrationEvent event,
    Emitter<SensorState> emit,
  ) {
    if (state is SensorConnected) {
      final current = state as SensorConnected;
      _bleService?.sendCommand('CALIB_START');
      emit(current.copyWith(
        isCalibrating: true, 
        isWaitingCalibrationData: false, 
        calibrationPoints: []
      ));
    }
  }

  void _onTriggerCalibrationRead(
    TriggerCalibrationReadEvent event,
    Emitter<SensorState> emit,
  ) {
    if (state is SensorConnected) {
      final current = state as SensorConnected;
      _bleService?.sendCommand('CALIB_READ');
      emit(current.copyWith(isWaitingCalibrationData: true));
    }
  }

  void _onAddCalibrationPoint(
    AddCalibrationPointEvent event,
    Emitter<SensorState> emit,
  ) {
    if (state is SensorConnected) {
      final current = state as SensorConnected;
      if (current.isCalibrating) {
        final newPoints = List<SensorData>.from(current.calibrationPoints)..add(event.data);
        emit(current.copyWith(calibrationPoints: newPoints));
      }
    }
  }

  Future<void> _onFinishCalibration(
    FinishCalibrationEvent event,
    Emitter<SensorState> emit,
  ) async {
    if (state is SensorConnected) {
      final current = state as SensorConnected;
      if (current.isCalibrating && current.calibrationPoints.isNotEmpty) {
        try {
          final result = StatisticalEngine.processSpatialData(current.calibrationPoints);
          final CalibrationLogService calibLog = CalibrationLogService();
          await calibLog.saveResult(result);
          
          // Kirim data valid ke history utama dan update latestData jika valid
          final newHistory = List<SensorData>.from(current.history)..add(result.finalData);
          _logBuffer.add(result.finalData); // Masukkan ke buffer untuk di-push ke Firebase
          
          _bleService?.sendCommand('CALIB_STOP');
          emit(current.copyWith(
            isCalibrating: false,
            isWaitingCalibrationData: false,
            calibrationPoints: [],
            latestData: result.finalData,
            history: newHistory,
          ));
        } catch (e) {
          debugPrint('Error finishing calibration: $e');
          _bleService?.sendCommand('CALIB_STOP');
          emit(current.copyWith(isCalibrating: false, isWaitingCalibrationData: false, calibrationPoints: []));
        }
      } else {
        _bleService?.sendCommand('CALIB_STOP');
        emit(current.copyWith(isCalibrating: false, isWaitingCalibrationData: false, calibrationPoints: []));
      }
    }
  }

  void _onCancelCalibration(
    CancelCalibrationEvent event,
    Emitter<SensorState> emit,
  ) {
    if (state is SensorConnected) {
      final current = state as SensorConnected;
      _bleService?.sendCommand('CALIB_STOP');
      emit(current.copyWith(isCalibrating: false, isWaitingCalibrationData: false, calibrationPoints: []));
    }
  }

  void _onClearError(ClearErrorEvent event, Emitter<SensorState> emit) {
    if (state is SensorConnected) {
      final current = state as SensorConnected;
      emit(current.copyWith(clearError: true));
    }
  }

  void _onClearSuccess(ClearSuccessEvent event, Emitter<SensorState> emit) {
    if (state is SensorConnected) {
      final current = state as SensorConnected;
      emit(current.copyWith(clearSuccess: true));
    }
  }

  void _onDeleteSdCard(
    DeleteSdCardEvent event,
    Emitter<SensorState> emit,
  ) {
    if (state is SensorConnected) {
      if (event.target == 'gateway') {
        _bleService?.sendCommand('DELETE_SD_GATEWAY');
      } else if (event.target == 'node') {
        _bleService?.sendCommand('DELETE_SD_NODE');
      }
    }
  }

  void _onSetInterval(SetIntervalEvent event, Emitter<SensorState> emit) {
    if (_bleService != null && state is SensorConnected) {
      _bleService!.sendCommand('SET_INTERVAL:${event.normalSec}:${event.hematSec}');
    }
  }

  @override
  Future<void> close() {
    _disconnectAll();
    _sensorService.dispose();
    return super.close();
  }
}
