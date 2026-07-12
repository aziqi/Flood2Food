import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bluetooth/bluetooth_cubit.dart';
import '../bloc/bluetooth/bluetooth_state.dart';
import '../bloc/sensor/sensor_bloc.dart';
import '../bloc/sensor/sensor_event.dart';
import '../services/bluetooth_service.dart';

class BluetoothScanScreen extends StatelessWidget {
  final bool useMock;
  const BluetoothScanScreen({super.key, this.useMock = false});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BluetoothCubit(
        service: useMock ? MockBleService() : null,
      ),
      child: const _BluetoothScanView(),
    );
  }
}

class _BluetoothScanView extends StatelessWidget {
  const _BluetoothScanView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BluetoothCubit>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Radar Sensor Bionic', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        centerTitle: true,
      ),
      body: BlocConsumer<BluetoothCubit, BluetoothState>(
        listenWhen: (prev, curr) => curr is BluetoothConnected || curr is BluetoothError,
        listener: (context, state) {
          if (state is BluetoothConnected) {
            cubit.keepServiceAlive = true;
            context.read<SensorBloc>().add(ConnectBluetoothSensor(cubit.service));
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else if (state is BluetoothError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message, style: const TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            );
            cubit.clearError();
          }
        },
        builder: (context, state) {
          if (state is BluetoothInitial) return _buildInitial(context, cubit, colorScheme);
          if (state is BluetoothScanning) return _buildScanning(context, colorScheme);
          if (state is BluetoothScanComplete) return _buildDeviceList(context, state.devices, cubit, colorScheme);
          if (state is BluetoothConnecting) return _buildConnecting(state.deviceName, colorScheme);
          if (state is BluetoothConnected) return _buildConnected(state.deviceName, colorScheme);
          if (state is BluetoothDisconnected) return _buildInitial(context, cubit, colorScheme);
          if (state is BluetoothError) return _buildError(context, cubit, state.message, colorScheme);
          return _buildInitial(context, cubit, colorScheme);
        },
      ),
    );
  }

  Widget _buildInitial(BuildContext context, BluetoothCubit cubit, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.bluetooth_searching_rounded, size: 80, color: colorScheme.primary),
          ),
          const SizedBox(height: 32),
          Text('Siap Memindai Gateway', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text('Pastikan perangkat keras Sensor IoT Anda menyala.', style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: () => cubit.startScan(),
            icon: const Icon(Icons.radar_rounded),
            label: const Text('Aktifkan Radar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildScanning(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(width: 100, height: 100, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary.withValues(alpha: 0.5))),
              Icon(Icons.bluetooth_rounded, size: 40, color: colorScheme.primary),
            ],
          ),
          const SizedBox(height: 32),
          Text('Memindai gelombang radio...', style: TextStyle(fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
        ],
      ),
    );
  }

  Widget _buildDeviceList(BuildContext context, List<BleScanResult> devices, BluetoothCubit cubit, ColorScheme colorScheme) {
    if (devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.bluetooth_disabled_rounded, size: 64, color: Colors.redAccent)),
            const SizedBox(height: 24),
            Text('Tidak Ada Sinyal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: colorScheme.onSurface)),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => cubit.startScan(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Pindai Ulang', style: TextStyle(fontWeight: FontWeight.w800)),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), side: BorderSide(color: colorScheme.primary)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${devices.length} Gateway Ditemukan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: colorScheme.primary)),
              IconButton(onPressed: () => cubit.startScan(), icon: Icon(Icons.refresh_rounded, color: colorScheme.primary)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                    child: Icon(Icons.developer_board_rounded, color: colorScheme.primary),
                  ),
                  title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  subtitle: Text('${device.deviceId}  •  ${device.rssi} dBm', style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w600)),
                  trailing: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _signalColor(device.rssi).withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(Icons.signal_cellular_alt_rounded, color: _signalColor(device.rssi), size: 20),
                  ),
                  onTap: () => cubit.connect(device.deviceId, device.name),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConnecting(String deviceName, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: colorScheme.primary),
          const SizedBox(height: 24),
          Text('Membangun jembatan kuantum ke', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5))),
          Text(deviceName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
        ],
      ),
    );
  }

  Widget _buildConnected(String deviceName, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.check_circle_rounded, size: 80, color: Colors.green)),
          const SizedBox(height: 24),
          Text('Terhubung ke $deviceName', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, BluetoothCubit cubit, String msg, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.warning_rounded, size: 80, color: Colors.redAccent)),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => cubit.startScan(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
          ),
        ],
      ),
    );
  }

  Color _signalColor(int rssi) {
    if (rssi >= -50) return Colors.green;
    if (rssi >= -70) return Colors.orange;
    return Colors.redAccent;
  }
}
