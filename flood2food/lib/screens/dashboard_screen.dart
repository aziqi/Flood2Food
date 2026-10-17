import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../bloc/sensor/sensor_bloc.dart';
import '../bloc/sensor/sensor_event.dart';
import '../bloc/sensor/sensor_state.dart';
import '../bloc/gamification/gamification_bloc.dart';
import '../bloc/gamification/gamification_event.dart';
import '../bloc/gamification/gamification_state.dart';
import '../widgets/sensor_block_card.dart';
import '../widgets/plant_health_card.dart';
import '../models/sensor_data.dart';
import '../widgets/app_drawer.dart';
import 'tasks_screen.dart';
import 'bluetooth_scan_screen.dart';
import 'sensor_log_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Kita tetap mengakses connection state & gamification dari sini, 
    // tetapi pembaruan data sensor (angka & grafik) diurus otomatis oleh SensorBlockCard (Leaf-node)
    final sensorState = context.watch<SensorBloc>().state;
    final gamificationState = context.watch<GamificationBloc>().state;
    final data = sensorState.latestData;

    return BlocListener<SensorBloc, SensorState>(
      listenWhen: (previous, current) => current.errorMessage != null && previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${state.errorMessage}'),
              backgroundColor: Colors.red.shade800,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'TUTUP',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
          context.read<SensorBloc>().add(ClearErrorEvent());
        }
      },
      child: Scaffold(
        drawer: const AppDrawer(),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              context.read<GamificationBloc>().add(GenerateDailyTasks(data));
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  centerTitle: true,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95), // Mencegah teks bertabrakan
                  surfaceTintColor: Colors.transparent,
                  title: const Text('Flood2Food', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.history_rounded),
                      tooltip: 'Riwayat Sensor',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SensorLogScreen()),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events_rounded, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              '${gamificationState.profile.level}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), // Padding bawah ekstra untuk Floating Nav Bar
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _connectionBanner(context, sensorState.isConnected, sensorState.source),
                      if (sensorState.isConnected) ...[
                        const SizedBox(height: 16),
                        _remoteModeToggle(context, data.modeHemat),
                      ],
                      const SizedBox(height: 16),
                      PlantHealthCard(data: data),
                      const SizedBox(height: 24),
                      _sectionHeader('Telemetry Real-Time', Icons.speed_rounded),
                      const SizedBox(height: 16),
                      
                      // Bionic Sensor Blocks (Otonom & Terisolasi)
                      const SensorBlockCard(label: 'Temperature', parameter: 'Temperature', unit: '°C', minValue: 0, maxValue: 100, color: Color(0xFFE91E63), icon: Icons.thermostat_rounded),
                      const SensorBlockCard(label: 'Humidity', parameter: 'Humidity', unit: '%', minValue: 0, maxValue: 100, color: Color(0xFF00BCD4), icon: Icons.water_drop_rounded),
                      const SensorBlockCard(label: 'Nitrogen', parameter: 'N', unit: 'mg/kg', minValue: 0, maxValue: 100, color: Color(0xFFE3EF26), icon: Icons.science_rounded),
                      const SensorBlockCard(label: 'Phosphorus', parameter: 'P', unit: 'mg/kg', minValue: 0, maxValue: 80, color: Color(0xFFFF9800), icon: Icons.bolt_rounded),
                      const SensorBlockCard(label: 'Kalium', parameter: 'K', unit: 'mg/kg', minValue: 0, maxValue: 80, color: Color(0xFF9C27B0), icon: Icons.water_rounded),
                      const SensorBlockCard(label: 'pH', parameter: 'pH', unit: '', minValue: 0, maxValue: 14, color: Color(0xFF4CAF50), icon: Icons.invert_colors_rounded),
                      const SensorBlockCard(label: 'EC', parameter: 'EC', unit: 'µS/cm', minValue: 0, maxValue: 3000, color: Color(0xFF2196F3), icon: Icons.flash_on_rounded),
                      
                      const SizedBox(height: 32),
                      _sectionHeader('Daily Tasks', Icons.task_alt_rounded),
                      const SizedBox(height: 16),
                      _taskPreview(context, gamificationState, data),
                    ].animate(interval: 15.ms).fadeIn(duration: 300.ms, curve: Curves.easeOut).slideY(begin: 0.1, curve: Curves.easeOutQuint)),
                  ),
                ),
              ],
            ),
          ),
          
          // Overlay Sinkronisasi SD Card
          if (sensorState.isLoadingHistory)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2), blurRadius: 40, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sd_storage_rounded, size: 56, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 24),
                      Text(
                        'Menyinkronkan SD Card...',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Menarik ribuan riwayat data dari kebun Anda.',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Builder(
                        builder: (context) {
                          final int progress = sensorState.syncProgress;
                          final int total = sensorState.syncTotal;
                          final double targetValue = total > 0 ? (progress / total).clamp(0.0, 1.0) : 0.0;
                          
                          return TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: targetValue), 
                            duration: const Duration(milliseconds: 400), 
                            builder: (context, val, _) {
                              return Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: LinearProgressIndicator(
                                      value: val,
                                      minHeight: 8,
                                      backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text('Blok Data: $progress dari $total  (${(val * 100).toStringAsFixed(0)}%)',
                                      style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary, fontSize: 16)),
                                      
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    child: TextButton.icon(
                                      onPressed: () {
                                        context.read<SensorBloc>().add(CancelHistorySync());
                                      },
                                      icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent),
                                      label: const Text('Batal', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ));
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Builder(
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _connectionBanner(BuildContext context, bool isConnected, String? source) {
    if (!isConnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.sensors_off_rounded, size: 24, color: Colors.redAccent),
                const SizedBox(width: 12),
                const Text('Sensor Terputus', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.redAccent)),
              ]
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BluetoothScanScreen(useMock: false))),
                    icon: const Icon(Icons.bluetooth_rounded, size: 18),
                    label: const Text('Bluetooth', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                      side: const BorderSide(color: Colors.teal),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => context.read<SensorBloc>().add(ConnectSensor()),
                    icon: const Icon(Icons.monitor_heart_rounded, size: 18),
                    label: const Text('Simulasi', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          ]
        )
      );
    }

    final isBluetooth = source == 'bluetooth';
    final color = isBluetooth ? Colors.blueAccent : Colors.teal;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Icon(
                  isBluetooth ? Icons.bluetooth_connected_rounded : Icons.monitor_heart_rounded,
                  size: 16,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isBluetooth ? 'Sistem Bluetooth Aktif' : 'Simulasi Quantum Aktif',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.read<SensorBloc>().add(DisconnectSensor()),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Text('Putuskan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.redAccent)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _taskPreview(
    BuildContext context,
    GamificationState gamification,
    SensorData data,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    if (gamification.isGenerating) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 0.90), 
              duration: const Duration(seconds: 8), 
              builder: (context, value, _) {
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('AI sedang meracik misi...', 
                            style: TextStyle(fontSize: 13, color: colorScheme.primary, fontWeight: FontWeight.w800)),
                        Text('${(value * 100).toStringAsFixed(0)}%', 
                            style: TextStyle(fontSize: 13, color: colorScheme.primary, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
                        backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    }

    final tasks = gamification.dailyTasks.take(3).toList();
    return Column(
      children: [
        if (gamification.error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: Colors.orange[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(gamification.error!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange[800])),
                ),
              ],
            ),
          ),
        
        if (tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(child: Text('Tidak ada misi aktif.', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)))),
          )
        else
          ...tasks.map(
            (task) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: task.isCompleted ? Colors.green.withValues(alpha: 0.1) : colorScheme.onSurface.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    task.isCompleted ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
                    color: task.isCompleted ? Colors.green : colorScheme.onSurface.withValues(alpha: 0.3),
                    size: 24,
                  ),
                ),
                title: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                    color: task.isCompleted ? colorScheme.onSurface.withValues(alpha: 0.5) : colorScheme.onSurface,
                  ),
                ),
                subtitle: Text('+${task.xpReward} XP', style: TextStyle(fontSize: 13, color: Colors.amber.shade700, fontWeight: FontWeight.w800)),
                trailing: Icon(Icons.chevron_right_rounded, color: colorScheme.onSurface.withValues(alpha: 0.2)),
              ),
            ),
          ),

        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.05),
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksScreen())),
                child: Text('Lihat Semua', style: TextStyle(fontWeight: FontWeight.w800, color: colorScheme.primary, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  backgroundColor: Colors.orange.withValues(alpha: 0.1),
                ),
                onPressed: () {
                  if (data.timestamp.millisecondsSinceEpoch != 0) {
                    context.read<GamificationBloc>().add(GenerateDailyTasks(data, forceRefresh: true));
                  } else {
                    _showTopNotification(context, 'Tunggu data sensor masuk terlebih dahulu.');
                  }
                },
                icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.orange),
                label: const Text('Segarkan', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.orange, fontSize: 13)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showTopNotification(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final shadowColor = isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.1);
    
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: shadowColor, blurRadius: 12, offset: const Offset(0, 6))
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.orangeAccent.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.sensors_off_rounded, color: Colors.orangeAccent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(fontWeight: FontWeight.w700, color: textColor, fontSize: 14),
                  ),
                ),
              ],
            ),
          ).animate()
           .slideY(begin: -2.0, end: 0, curve: Curves.easeOutBack, duration: const Duration(milliseconds: 500))
           .fadeIn(duration: const Duration(milliseconds: 400)),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }

  Widget _remoteModeToggle(BuildContext context, bool isHemat) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isHemat 
                ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                : const Color(0xFF2196F3).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isHemat ? Icons.eco_rounded : Icons.bolt_rounded,
              color: isHemat ? const Color(0xFF4CAF50) : const Color(0xFF2196F3),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode Operasi Node',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  isHemat ? 'Mode Hemat Daya' : 'Mode Normal',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isHemat,
            activeThumbColor: const Color(0xFF4CAF50),
            activeTrackColor: const Color(0xFF4CAF50).withValues(alpha: 0.3),
            inactiveThumbColor: const Color(0xFF2196F3),
            inactiveTrackColor: const Color(0xFF2196F3).withValues(alpha: 0.3),
            onChanged: (val) {
              // Tembakkan event ganti mode ke BLOC!
              context.read<SensorBloc>().add(ToggleModeEvent());
              
              // Berikan umpan balik haptic mekanikal
              HapticFeedback.mediumImpact();
              
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Mengirim perintah ganti mode ke Node...'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0);
  }
}
