import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/sensor_data.dart';

class DashboardChart extends StatelessWidget {
  final List<SensorData> history;
  final String parameter;
  final Color color;

  const DashboardChart({
    super.key,
    required this.history,
    required this.parameter,
    required this.color,
  });

  List<SensorData> get _chartData {
    if (history.length <= 30) return history;
    return history.sublist(history.length - 30);
  }

  double _getValue(SensorData data) {
    switch (parameter) {
      case 'pH':
        return data.ph;
      case 'N':
        return data.nitrogen;
      case 'P':
        return data.phosphorus;
      case 'K':
        return data.kalium;
      case 'EC':
        return data.ec;
      case 'Temperature':
        return data.temperature;
      case 'Humidity':
        return data.humidity;
      default:
        return 0;
    }
  }

  String _getUnit() {
    switch (parameter) {
      case 'pH':
        return '';
      case 'EC':
        return ' µS/cm';
      case 'Temperature':
        return ' °C';
      case 'Humidity':
        return ' %';
      default:
        return ' mg/kg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final chartData = _chartData;

    if (chartData.isEmpty) {
      return const Center(child: Text('Belum ada data', style: TextStyle(fontSize: 12)));
    }

    final values = chartData.map(_getValue).toList();
    double minY = values.reduce((a, b) => a < b ? a : b);
    double maxY = values.reduce((a, b) => a > b ? a : b);
    
    if (minY == maxY) {
      minY -= 1.0;
      maxY += 1.0;
    }
    final padding = (maxY - minY) * 0.2;

    return RepaintBoundary(
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 3,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withValues(alpha: 0.1),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  int decimals = 0;
                  if (parameter == 'pH') decimals = 1;
                  if (parameter == 'EC') decimals = 2;
                  if ((maxY - minY) < 4 && parameter != 'EC' && parameter != 'pH') decimals = 1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      value.toStringAsFixed(decimals),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color.withValues(alpha: 0.8)),
                      textAlign: TextAlign.right,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: chartData.asMap().entries.map((e) {
                return FlSpot(e.key.toDouble(), _getValue(e.value));
              }).toList(),
              isCurved: true,
              color: color,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.15),
              ),
            ),
          ],
          minY: minY - padding,
          maxY: maxY + padding,
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final data = chartData[spot.x.toInt()];
                  final timeStr = '${data.timestamp.hour.toString().padLeft(2, '0')}:${data.timestamp.minute.toString().padLeft(2, '0')}';
                  final valStr = '${spot.y.toStringAsFixed(parameter == 'EC' ? 2 : 1)}${_getUnit()}';
                  
                  return LineTooltipItem(
                    '$timeStr\n',
                    TextStyle(
                      color: Theme.of(context).colorScheme.surface,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      TextSpan(
                        text: valStr,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.surface,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}
