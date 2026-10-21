import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import '../models/sensor_data.dart';

class SensorService {
  final _controller = StreamController<SensorData>.broadcast();
  Timer? _timer;
  bool _isRunning = false;
  List<SensorData>? _csvData;
  int _currentIndex = 0;

  Stream<SensorData> get sensorStream => _controller.stream;
  List<SensorData>? get csvData => _csvData;

  Future<void> loadCsvData() async {
    if (_csvData != null) return;

    final raw = await rootBundle.loadString('assets/data_npk.csv');
    final lines = raw.split('\n');

    _csvData = lines.skip(1).where((line) => line.trim().isNotEmpty).map((
      line,
    ) {
      final parts = line.split(',');
      return SensorData(
        nitrogen: double.tryParse(parts[6].trim()) ?? 0,
        phosphorus: double.tryParse(parts[7].trim()) ?? 0,
        kalium: double.tryParse(parts[8].trim()) ?? 0,
        temperature: double.tryParse(parts[2].trim()) ?? 0,
        ec: (double.tryParse(parts[4].trim()) ?? 0) / 100,
        humidity: double.tryParse(parts[3].trim()) ?? 0,
        ph: double.tryParse(parts[5].trim()) ?? 7.0,
        timestamp: _parseTimestamp(parts[1].trim(), parts[0].trim()),
      );
    }).toList();
  }

  DateTime _parseTimestamp(String dateStr, String timeStr) {
    try {
      final dateParts = dateStr.split('/');
      final timeParts = timeStr.split(':');
      return DateTime(
        int.parse(dateParts[2]),
        int.parse(dateParts[1]),
        int.parse(dateParts[0]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
        int.parse(timeParts[2]),
      );
    } catch (_) {
      return DateTime.now();
    }
  }

  Future<void> startSimulation({
    Duration interval = const Duration(seconds: 5),
  }) async {
    if (_isRunning) return;
    await loadCsvData();
    _isRunning = true;
    _currentIndex = 0;

    // --- SUNTIKAN RIWAYAT SIMULASI INSTAN ---
    if (_csvData != null && _csvData!.isNotEmpty) {
      final now = DateTime.now();
      int historyCount = 50;
      if (historyCount > _csvData!.length) historyCount = _csvData!.length;
      
      for (int i = 0; i < historyCount; i++) {
        // Ambil data acak ke belakang untuk membuat efek riwayat yang rapi
        final originalIndex = (_csvData!.length - historyCount + i) % _csvData!.length;
        final original = _csvData![originalIndex];
        
        final historyData = SensorData(
          nitrogen: original.nitrogen,
          phosphorus: original.phosphorus,
          kalium: original.kalium,
          temperature: original.temperature,
          ec: original.ec,
          humidity: original.humidity,
          ph: original.ph,
          timestamp: now.subtract(Duration(minutes: historyCount - i)),
          status: 'history',
        );
        _controller.add(historyData);
      }
      
      // Kirim sinyal bahwa riwayat selesai dikirim (mematikan loading bar)
      Future.delayed(const Duration(seconds: 2), () {
        final completeData = SensorData(
          nitrogen: 0, phosphorus: 0, kalium: 0, temperature: 0,
          ec: 0, humidity: 0, ph: 0, timestamp: DateTime.now(),
          status: 'history_complete',
        );
        _controller.add(completeData);
      });
    }

    _timer = Timer.periodic(interval, (_) {
      if (_csvData == null || _csvData!.isEmpty) return;
      final original = _csvData![_currentIndex];
      final realtimeData = SensorData(
        nitrogen: original.nitrogen,
        phosphorus: original.phosphorus,
        kalium: original.kalium,
        temperature: original.temperature,
        ec: original.ec,
        humidity: original.humidity,
        ph: original.ph,
        timestamp: DateTime.now(),
      );
      _controller.add(realtimeData);
      _currentIndex = (_currentIndex + 1) % _csvData!.length;
    });
  }

  void stop() {
    _timer?.cancel();
    _isRunning = false;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
