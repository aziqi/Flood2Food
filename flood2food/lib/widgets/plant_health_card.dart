import 'package:flutter/material.dart';
import '../models/sensor_data.dart';

class PlantHealthCard extends StatelessWidget {
  final SensorData data;

  const PlantHealthCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final score = data.plantHealthScore;
    final status = data.healthStatus;
    final color = score >= 85
        ? Colors.green
        : score >= 65
            ? Colors.lightGreen
            : score >= 45
                ? Colors.orange
                : Colors.red;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    score.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text('%', style: TextStyle(fontSize: 12, color: color)),
                ],
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plant Health',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _getRecommendation(status),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRecommendation(String status) {
    switch (status) {
      case 'Excellent':
        return 'Pertahankan perawatan saat ini';
      case 'Good':
        return 'Sedikit perbaikan untuk hasil optimal';
      case 'Fair':
        return 'Perlu tindakan perbaikan segera';
      case 'Poor':
        return 'Butuh intervensi serius';
      default:
        return '';
    }
  }
}
