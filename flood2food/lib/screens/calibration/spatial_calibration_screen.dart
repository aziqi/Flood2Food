import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/sensor/sensor_bloc.dart';
import '../../bloc/sensor/sensor_event.dart';
import '../../bloc/sensor/sensor_state.dart';
import '../../models/sensor_data.dart';
import '../../utils/statistical_engine.dart';

class SpatialCalibrationScreen extends StatefulWidget {
  const SpatialCalibrationScreen({super.key});

  @override
  State<SpatialCalibrationScreen> createState() => _SpatialCalibrationScreenState();
}

class _SpatialCalibrationScreenState extends State<SpatialCalibrationScreen> {
  // Batasan maxPoints dihapus sesuai permintaan

  @override
  void initState() {
    super.initState();
    context.read<SensorBloc>().add(StartCalibrationEvent());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.read<SensorBloc>().add(CancelCalibrationEvent());
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kalibrasi Sawah'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: BlocConsumer<SensorBloc, SensorState>(
          listenWhen: (previous, current) {
            return previous is SensorConnected && 
                   previous.isCalibrating && 
                   current is SensorConnected && 
                   !current.isCalibrating;
          },
          listener: (context, state) {
            // Jika kalibrasi selesai atau dibatalkan dari luar, tutup layar
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          builder: (context, state) {
            if (state is! SensorConnected) {
              return _buildDisconnectedState();
            }

            final points = state.calibrationPoints;
            
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(points.length),
                  const SizedBox(height: 32),
                  Expanded(
                    child: _buildPointsList(points),
                  ),
                  const SizedBox(height: 24),
                  if (state.isWaitingCalibrationData)
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('Menunggu data dari Node...', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  else
                    _buildControls(context, state, points.length),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDisconnectedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.bluetooth_disabled_rounded, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Sensor Terputus.\nHarap sambungkan sensor terlebih dahulu.', textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildHeader(int currentPoints) {
    return Column(
      children: [
        Text(
          'Total Titik Data: $currentPoints',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tancapkan alat di zona sawah, lalu tekan Kunci Titik Data.\nMinimal ambil 2 titik yang tersebar di area lahan untuk hasil yang akurat.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildPointsList(List<SensorData> points) {
    if (points.isEmpty) {
      return Center(
        child: Text(
          'Belum ada titik yang direkam.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        ),
      );
    }
    return ListView.builder(
      itemCount: points.length,
      itemBuilder: (context, index) {
        final data = points[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).elevatedButtonTheme.style?.backgroundColor?.resolve({}) ?? Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10), // Kotak dengan ujung halus
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}', 
                style: TextStyle(
                  color: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}) ?? Colors.black, 
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            title: Text('Titik ${index + 1}'),
            subtitle: Text(
              'N: ${data.nitrogen.toInt()} | P: ${data.phosphorus.toInt()} | K: ${data.kalium.toInt()}\n'
              'pH: ${data.ph.toStringAsFixed(1)} | EC: ${data.ec.toStringAsFixed(2)} | Mois: ${data.humidity.toInt()}%'
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls(BuildContext context, SensorConnected state, int currentPoints) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () {
            // Perintahkan Node untuk mengambil data baru
            context.read<SensorBloc>().add(TriggerCalibrationReadEvent());
          },
          icon: const Icon(Icons.add_location_alt_rounded),
          label: const Text('Kunci Titik Data Saat Ini'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: currentPoints < 2 ? null : () => _showResultDialog(context, state.calibrationPoints),
          icon: const Icon(Icons.analytics_rounded),
          label: const Text('Selesai & Analisis'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
    );
  }

  void _showResultDialog(BuildContext context, List<SensorData> points) {
    final result = StatisticalEngine.processSpatialData(points);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Hasil Homogenitas', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${result.uniformityScore.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 48, 
                  fontWeight: FontWeight.bold,
                  color: result.uniformityScore > 85 ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                result.recommendation,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.read<SensorBloc>().add(CancelCalibrationEvent()); // Batal simpan
                Navigator.of(context).pop();
              },
              child: const Text('Buang', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.read<SensorBloc>().add(FinishCalibrationEvent()); // Simpan dan terapkan
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profil tanah berhasil diperbarui!')),
                );
              },
              child: const Text('Terapkan Profil'),
            ),
          ],
        );
      }
    );
  }
}
