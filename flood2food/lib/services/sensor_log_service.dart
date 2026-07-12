import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sensor_data.dart';

class SensorLogService {
  static const String _key = 'sensor_log';
  static const int _maxLogs = 5000;

  Future<List<SensorData>> loadLog() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map((e) => SensorData.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> appendLog(SensorData data) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    List<dynamic> logs = [];
    if (json != null) {
      try {
        logs = jsonDecode(json) as List<dynamic>;
      } catch (_) {}
    }
    logs.add(data.toJson());
    if (logs.length > _maxLogs) {
      logs = logs.sublist(logs.length - _maxLogs);
    }
    await prefs.setString(_key, jsonEncode(logs));
  }

  Future<void> appendBatchLog(List<SensorData> batch) async {
    if (batch.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    List<dynamic> logs = [];
    if (json != null) {
      try {
        logs = jsonDecode(json) as List<dynamic>;
      } catch (_) {}
    }
    for (final d in batch) {
      logs.add(d.toJson());
    }
    if (logs.length > _maxLogs) {
      logs = logs.sublist(logs.length - _maxLogs);
    }
    await prefs.setString(_key, jsonEncode(logs));
  }

  Future<void> clearLog() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<void> exportToCsv() async {
    final logs = await loadLog();
    if (logs.isEmpty) return;

    String csv = "Timestamp,Temperature,Humidity,pH,EC(mS/cm),Nitrogen,Phosphorus,Kalium\n";

    for (var log in logs) {
      csv += "${log.timestamp.toIso8601String()},"
             "${log.temperature.toStringAsFixed(1)},"
             "${log.humidity.toStringAsFixed(1)},"
             "${log.ph.toStringAsFixed(1)},"
             "${log.ec.toStringAsFixed(2)},"
             "${log.nitrogen.toStringAsFixed(0)},"
             "${log.phosphorus.toStringAsFixed(0)},"
             "${log.kalium.toStringAsFixed(0)}\n";
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/flood2food_log_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    await file.writeAsString(csv);

    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(path)], text: 'Data Sensor Flood2Food');
  }
}
