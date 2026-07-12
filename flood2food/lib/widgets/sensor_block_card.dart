import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/sensor_data.dart';
import '../bloc/sensor/sensor_bloc.dart';
import '../bloc/sensor/sensor_state.dart';
import 'sensor_gauge.dart';
import 'dashboard_chart.dart';

class SensorBlockCard extends StatelessWidget {
  final String label;
  final String parameter;
  final String unit;
  final double minValue;
  final double maxValue;
  final Color color;
  final IconData icon;

  const SensorBlockCard({
    super.key,
    required this.label,
    required this.parameter,
    required this.unit,
    required this.minValue,
    required this.maxValue,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    // Ultra-Optimization: Leaf-Node Rendering dengan BlocSelector
    return BlocSelector<SensorBloc, SensorState, _BlockData>(
      selector: (state) {
        return _BlockData(
          latestValue: _getValue(state.latestData),
          historyLength: state.history.length,
          history: state.history, 
        );
      },
      builder: (context, data) {
        final colorScheme = Theme.of(context).colorScheme;
        final isDark = colorScheme.brightness == Brightness.dark;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: colorScheme.onSurface.withValues(alpha: 0.05),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header (Judul & Ikon) ---
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.bolt_rounded, size: 14, color: color),
                        const SizedBox(width: 4),
                        Text(
                          '${data.latestValue.toStringAsFixed(parameter == 'EC' ? 2 : 1)} $unit',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // --- Konten (Gauge & Chart) ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Kiri: Gauge (sekarang bebas bingkai)
                  SensorGauge(
                    value: data.latestValue,
                    unit: unit,
                    minValue: minValue,
                    maxValue: maxValue,
                    color: color,
                  ),
                  const SizedBox(width: 24),
                  // Kanan: Chart Telemetri
                  Expanded(
                    child: SizedBox(
                      height: 90,
                      child: DashboardChart(
                        history: data.history,
                        parameter: parameter,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  double _getValue(SensorData data) {
    switch (parameter) {
      case 'pH': return data.ph;
      case 'N': return data.nitrogen;
      case 'P': return data.phosphorus;
      case 'K': return data.kalium;
      case 'EC': return data.ec;
      case 'Temperature': return data.temperature;
      case 'Humidity': return data.humidity;
      default: return 0;
    }
  }
}

// Bionic Data Class: Mencegah Deep Equals yang memakan memori CPU
class _BlockData {
  final double latestValue;
  final int historyLength;
  final List<SensorData> history;
  
  _BlockData({
    required this.latestValue, 
    required this.historyLength,
    required this.history,
  });
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _BlockData &&
          runtimeType == other.runtimeType &&
          latestValue == other.latestValue &&
          historyLength == other.historyLength; // Pengecekan instan, 0 ms lag!
          
  @override
  int get hashCode => latestValue.hashCode ^ historyLength.hashCode;
}
