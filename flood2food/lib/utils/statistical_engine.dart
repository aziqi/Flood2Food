import 'dart:math';
import '../models/sensor_data.dart';

class CalibrationResult {
  final SensorData finalData;
  final double uniformityScore;
  final String recommendation;

  CalibrationResult({
    required this.finalData,
    required this.uniformityScore,
    required this.recommendation,
  });

  Map<String, dynamic> toJson() {
    return {
      'finalData': finalData.toJson(),
      'uniformityScore': uniformityScore,
      'recommendation': recommendation,
    };
  }

  factory CalibrationResult.fromJson(Map<String, dynamic> json) {
    return CalibrationResult(
      finalData: SensorData.fromJson(json['finalData'] as Map<String, dynamic>),
      uniformityScore: (json['uniformityScore'] as num).toDouble(),
      recommendation: json['recommendation'] as String,
    );
  }
}

class StatisticalEngine {
  /// Membuang pencilan (outlier) menggunakan IQR dan menghitung rata-rata robust.
  /// Jika datanya terlalu sedikit (misal < 3), kita abaikan IQR dan pakai rata-rata biasa.
  static double _calculateRobustMean(List<double> values) {
    if (values.isEmpty) return 0;
    if (values.length < 3) {
      return values.reduce((a, b) => a + b) / values.length;
    }

    final sorted = List<double>.from(values)..sort();
    final q1Index = (sorted.length * 0.25).floor();
    final q3Index = (sorted.length * 0.75).floor();
    
    final q1 = sorted[q1Index];
    final q3 = sorted[q3Index];
    final iqr = q3 - q1;

    final lowerBound = q1 - (1.5 * iqr);
    final upperBound = q3 + (1.5 * iqr);

    final filtered = sorted.where((v) => v >= lowerBound && v <= upperBound).toList();
    if (filtered.isEmpty) {
      // Fallback ke median murni jika pemfilteran terlalu agresif
      return sorted[(sorted.length / 2).floor()];
    }

    return filtered.reduce((a, b) => a + b) / filtered.length;
  }

  /// Menghitung Koefisien Variasi (CV) dalam persentase
  static double _calculateCoefficientOfVariation(List<double> values) {
    if (values.isEmpty || values.length <= 1) return 0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    if (mean == 0) return 0;

    final variance = values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
    final stdDev = sqrt(variance);

    return (stdDev / mean) * 100;
  }

  static CalibrationResult processSpatialData(List<SensorData> points) {
    if (points.isEmpty) {
      throw Exception('Tidak ada titik data untuk dikalibrasi');
    }

    final nValues = points.map((e) => e.nitrogen).toList();
    final pValues = points.map((e) => e.phosphorus).toList();
    final kValues = points.map((e) => e.kalium).toList();
    final phValues = points.map((e) => e.ph).toList();
    final ecValues = points.map((e) => e.ec).toList();
    final humValues = points.map((e) => e.humidity).toList();
    final tempValues = points.map((e) => e.temperature).toList();

    // Hitung Robust Mean (bebas outlier)
    final finalN = _calculateRobustMean(nValues);
    final finalP = _calculateRobustMean(pValues);
    final finalK = _calculateRobustMean(kValues);
    final finalPh = _calculateRobustMean(phValues);
    final finalEc = _calculateRobustMean(ecValues);
    final finalHum = _calculateRobustMean(humValues);
    final finalTemp = _calculateRobustMean(tempValues);

    // Hitung Keseragaman (Homogenitas) dari NPK (unsur hara utama)
    final cvN = _calculateCoefficientOfVariation(nValues);
    final cvP = _calculateCoefficientOfVariation(pValues);
    final cvK = _calculateCoefficientOfVariation(kValues);
    final cvPh = _calculateCoefficientOfVariation(phValues);
    
    // Homogenitas adalah 100% dikurang Rata-rata CV unsur utama (maksimal 100, minimal 0)
    final avgCV = (cvN + cvP + cvK + cvPh) / 4;
    double uniformityScore = 100 - avgCV;
    if (uniformityScore < 0) uniformityScore = 0;
    if (uniformityScore > 100) uniformityScore = 100;

    String recommendation = 'Lahan Anda Seragam. Terapkan pemupukan berimbang di seluruh area.';
    if (uniformityScore < 85) {
      // Cari unsur yang paling tidak seragam
      final maxCV = [cvN, cvP, cvK].reduce(max);
      String worstElement = 'Nitrogen';
      if (maxCV == cvP) worstElement = 'Fosfor';
      if (maxCV == cvK) worstElement = 'Kalium';
      
      recommendation = 'Lahan kurang seragam (Heterogen). Unsur $worstElement bervariasi cukup ekstrem. Periksa area mana yang sangat rendah $worstElement dan berikan pupuk tambahan khusus di area tersebut.';
    }

    final finalData = SensorData(
      nitrogen: finalN,
      phosphorus: finalP,
      kalium: finalK,
      ph: finalPh,
      ec: finalEc,
      humidity: finalHum,
      temperature: finalTemp,
      status: 'calibration_result',
      timestamp: DateTime.now(),
    );

    return CalibrationResult(
      finalData: finalData,
      uniformityScore: uniformityScore,
      recommendation: recommendation,
    );
  }
}
