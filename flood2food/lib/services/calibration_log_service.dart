import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/statistical_engine.dart';

class CalibrationLogService {
  static const String _key = 'spatial_calibration_history';

  Future<void> saveResult(CalibrationResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final List<CalibrationResult> history = await getHistory();
    history.add(result);
    
    // Simpan dalam urutan terbaru ke terlama atau biarkan saja, 
    // kita biarkan history.add berarti paling akhir adalah paling baru.
    
    final List<String> jsonList = history.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_key, jsonList);
  }

  Future<List<CalibrationResult>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jsonList = prefs.getStringList(_key);
    
    if (jsonList == null || jsonList.isEmpty) {
      return [];
    }

    return jsonList.map((str) {
      final map = jsonDecode(str) as Map<String, dynamic>;
      return CalibrationResult.fromJson(map);
    }).toList();
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
