import 'bluetooth_sensor_data.dart';

class SensorData {
  final double nitrogen;
  final double temperature;
  final double kalium;
  final double phosphorus;
  final double ec;
  final double humidity;
  final double ph;
  final DateTime timestamp;
  final bool modeHemat;
  final String status;

  SensorData({
    required this.nitrogen,
    required this.temperature,
    required this.kalium,
    required this.phosphorus,
    required this.ec,
    required this.humidity,
    required this.ph,
    this.modeHemat = false,
    this.status = '',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  double get npkAverage => (nitrogen + phosphorus + kalium) / 3;

  // Plant Health Score (0-100) berbasis ambang agronomi sawah padi
  // (FAO / IRRI Dobermann & Fairhurst 2000 / UC Davis / Maas & Hoffman EC).
  // Bobot: N 25%, P 20%, K 20%, pH 15%, EC 10%, VWC 10%.
  double get plantHealthScore {
    double score = 0;

    // Nitrogen (Available/Mineral N): defisiensi <20, optimum 20-50, berlebih >80-100
    if (nitrogen >= 20 && nitrogen <= 50) {
      score += 25;
    } else if ((nitrogen >= 10 && nitrogen < 20) || (nitrogen > 50 && nitrogen <= 100)) {
      score += 12.5;
    }

    // Phosphorus (Olsen P): defisiensi <6, optimum 10-25, berlebih >40-50
    if (phosphorus >= 10 && phosphorus <= 25) {
      score += 20;
    } else if ((phosphorus >= 6 && phosphorus < 10) || (phosphorus > 25 && phosphorus <= 50)) {
      score += 10;
    }

    // Kalium (Exchangeable K): defisiensi <60, optimum 100-200, berlebih >300-400
    if (kalium >= 100 && kalium <= 200) {
      score += 20;
    } else if ((kalium >= 60 && kalium < 100) || (kalium > 200 && kalium <= 300)) {
      score += 10;
    }

    // Kelembapan/VWC: kering <20%, optimum 30-45%, becek >55%
    if (humidity >= 30 && humidity <= 45) {
      score += 10;
    } else if ((humidity >= 20 && humidity < 30) || (humidity > 45 && humidity <= 55)) {
      score += 5;
    }

    // pH Tanah: asam kuat <5.0, optimum 5.5-7.0, alkalin >7.5
    if (ph >= 5.5 && ph <= 7.0) {
      score += 15;
    } else if (ph >= 5.0 && ph <= 7.5) {
      score += 7.5;
    }

    // EC (Salinitas, µS/cm): aman <200, stres 400-1000, parah >1000
    if (ec <= 200) {
      score += 10;
    } else if (ec <= 400) {
      score += 5;
    }

    return score;
  }

  String get healthStatus {
    final s = plantHealthScore;
    if (s >= 80) return 'Excellent';
    if (s >= 60) return 'Good';
    if (s >= 40) return 'Fair';
    return 'Poor';
  }

  Map<String, dynamic> toJson() => {
    'nitrogen': nitrogen,
    'temperature': temperature,
    'kalium': kalium,
    'phosphorus': phosphorus,
    'ec': ec,
    'humidity': humidity,
    'ph': ph,
    'mode_hemat': modeHemat,
    'timestamp': timestamp.toIso8601String(),
  };

  factory SensorData.fromBluetoothSensorData(
    BluetoothSensorData bsd,
  ) =>
      SensorData(
        nitrogen: bsd.n,
        phosphorus: bsd.p,
        kalium: bsd.k,
        temperature: bsd.suhu,
        humidity: bsd.humi,
        ph: bsd.ph,
        ec: bsd.kond,  // EC sudah dalam satuan final µS/cm (node & gateway konsisten)
        modeHemat: bsd.modeHemat,
        status: bsd.status,
        timestamp: _parseTimestamp(bsd.tanggal, bsd.waktu),
      );

  static DateTime _parseTimestamp(String tanggal, String waktu) {
    try {
      if (tanggal.isEmpty && waktu.isEmpty) return DateTime(1970, 1, 1);
      
      // FIX TANGGAL 0001: Jika RTC Node mati/belum disinkronkan, ia mengirimkan format kosong/0
      if (tanggal.contains('--') || tanggal.contains('00/00/0000') || tanggal.contains('0000-00-00')) {
        return DateTime(1970, 1, 1);
      }
      
      // Format from gateway history: YYYY-MM-DD (ISO)
      if (tanggal.contains('-')) {
        final isoStr = waktu.isNotEmpty ? '${tanggal}T$waktu' : tanggal;
        return DateTime.parse(isoStr);
      }
      
      // Format from live data: DD/MM/YYYY
      final parts = tanggal.split('/');
      if (parts.length == 3) {
        final isoStr = '${parts[2]}-${parts[1]}-${parts[0]}T$waktu';
        return DateTime.parse(isoStr);
      }
    } catch (_) {}
    return DateTime(1970, 1, 1);
  }

  factory SensorData.fromJson(Map<String, dynamic> json) => SensorData(
    nitrogen: (json['nitrogen'] as num).toDouble(),
    phosphorus: (json['phosphorus'] as num).toDouble(),
    kalium: (json['kalium'] as num).toDouble(),
    temperature: (json['temperature'] as num).toDouble(),
    ec: (json['ec'] as num).toDouble(),
    humidity: (json['humidity'] as num).toDouble(),
    ph: (json['ph'] as num).toDouble(),
    modeHemat: json['mode_hemat'] as bool? ?? false,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}
