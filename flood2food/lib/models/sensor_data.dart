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

  double get plantHealthScore {
    double score = 0;
    
    // Nitrogen (Available N): Ideal 70-120 mg/kg, Kritis <25, Toksik >200
    if (nitrogen >= 70 && nitrogen <= 120) {
      score += 20;
    } else if (nitrogen >= 25 && nitrogen <= 200) {
      score += 10;
    }
    
    // Phosphorus (Olsen P): Ideal 15-25 mg/kg, Kritis <10, Berlebih >35
    if (phosphorus >= 15 && phosphorus <= 25) {
      score += 15;
    } else if (phosphorus >= 10 && phosphorus <= 35) {
      score += 7.5;
    }
    
    // Kalium (Exchangeable K): Ideal 100-200 mg/kg, Kritis <60
    if (kalium >= 100 && kalium <= 200) {
      score += 15;
    } else if (kalium >= 60 && kalium <= 300) {
      score += 7.5;
    }
    
    // Kelembapan (VWC): Ideal 40-60%, Kritis <20%
    if (humidity >= 40 && humidity <= 60) {
      score += 15;
    } else if (humidity >= 20 && humidity <= 80) {
      score += 7.5;
    }
    
    // pH Tanah: Ideal 5.5-7.0, Kritis <5.0 atau >7.5
    if (ph >= 5.5 && ph <= 7.0) {
      score += 20;
    } else if (ph >= 5.0 && ph <= 7.5) {
      score += 10;
    }
    
    // EC (Salinitas): Ideal <2.0 mS/cm, Kritis >3.0 mS/cm
    if (ec <= 2.0) {
      score += 15;
    } else if (ec <= 3.0) {
      score += 7.5;
    }
    
    return score;
  }

  String get healthStatus {
    final s = plantHealthScore;
    if (s >= 85) return 'Excellent';
    if (s >= 65) return 'Good';
    if (s >= 45) return 'Fair';
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
        ec: bsd.kond,  // Gateway already sends EC in mS/cm (divided by 1000)
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
