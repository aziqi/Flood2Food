import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../bloc/gamification/gamification_bloc.dart';
import '../bloc/gamification/gamification_event.dart';
import '../bloc/sensor/sensor_bloc.dart';
import '../bloc/sensor/sensor_event.dart';
import '../bloc/sensor/sensor_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDeletingSdCard = false;
  
  // Interval settings (dalam detik)
  int _normalIntervalSec = 20;
  int _hematIntervalSec = 1200;

  @override
  void initState() {
    super.initState();
    _loadIntervalSettings();
  }

  Future<void> _loadIntervalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _normalIntervalSec = prefs.getInt('normalIntervalSec') ?? 20;
      _hematIntervalSec = prefs.getInt('hematIntervalSec') ?? 1200;
    });
  }

  Future<void> _saveIntervalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('normalIntervalSec', _normalIntervalSec);
    await prefs.setInt('hematIntervalSec', _hematIntervalSec);
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds detik';
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    if (sec == 0) return '$min menit';
    return '$min mnt $sec dtk';
  }


  @override
  Widget build(BuildContext context) {
    return BlocListener<SensorBloc, SensorState>(
      listenWhen: (previous, current) => 
          (current.successMessage != null && previous.successMessage != current.successMessage) ||
          (current.errorMessage != null && previous.errorMessage != current.errorMessage),
      listener: (context, state) {
        if (_isDeletingSdCard) {
          _isDeletingSdCard = false;
          Navigator.of(context, rootNavigator: true).pop(); // Tutup loading dialog
          
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: Colors.green.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
            context.read<SensorBloc>().add(ClearSuccessEvent());
          }
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Profil Pengguna',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.indigo.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.indigo.withValues(alpha: 0.3)),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.indigo),
              title: const Text('Keluar (Log Out)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Keluar dari akun Google saat ini', style: TextStyle(fontSize: 12)),
              onTap: () => _showLogoutConfirmation(context),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Manajemen Data',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.red.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Hapus Semua Data & Reset Akun',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Kembali ke Level 1 dan hapus riwayat tugas.',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () => _showResetConfirmation(context),
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.orange.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.sd_storage, color: Colors.orange),
              title: const Text(
                'Hapus Data SD Card (Via Bluetooth)',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Menghapus file log pada perangkat keras',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () => _showSdCardDeleteConfirmation(context),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Pengaturan Interval Sensor',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Atur frekuensi pengambilan data oleh Node. Perubahan akan langsung dikirim ke perangkat jika sedang terhubung via Bluetooth dan tersimpan permanen.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          _buildIntervalCard(context),
        ],
      ),
    ));
  }

  Widget _buildIntervalCard(BuildContext context) {
    final sensorState = context.watch<SensorBloc>().state;
    final isConnected = sensorState.isConnected;

    return Container(
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Interval Mode Normal ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.speed_rounded, color: Colors.teal, size: 18),
                const SizedBox(width: 8),
                const Text('Mode Normal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatDuration(_normalIntervalSec),
                  style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          Slider(
            value: _normalIntervalSec.toDouble(),
            min: 5,
            max: 300,
            divisions: 59, // Step ~5 detik
            activeColor: Colors.teal,
            inactiveColor: Colors.teal.withValues(alpha: 0.2),
            onChanged: (val) => setState(() => _normalIntervalSec = val.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('5 dtk', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('5 mnt', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const Divider(height: 24),

          // --- Interval Mode Hemat Daya ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.battery_saver_rounded, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                const Text('Mode Hemat Daya', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatDuration(_hematIntervalSec),
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          Slider(
            value: _hematIntervalSec.toDouble(),
            min: 60,
            max: 7200, // Maks 2 jam
            divisions: 71, // Step ~100 detik
            activeColor: Colors.green,
            inactiveColor: Colors.green.withValues(alpha: 0.2),
            onChanged: (val) => setState(() => _hematIntervalSec = val.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('1 mnt', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('2 jam', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 16),

          // --- Tombol Simpan ---
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(isConnected ? Icons.send_rounded : Icons.save_rounded, size: 18),
              label: Text(isConnected ? 'Simpan & Kirim ke Node' : 'Simpan (Terapkan Saat Terhubung)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnected ? Colors.teal : Colors.grey.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () async {
                await _saveIntervalSettings();
                if (isConnected) {
                  if (!context.mounted) return;
                  context.read<SensorBloc>().add(SetIntervalEvent(
                    normalSec: _normalIntervalSec,
                    hematSec: _hematIntervalSec,
                  ));
                }
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isConnected
                        ? 'Interval disimpan dan dikirim ke Node!'
                        : 'Interval disimpan. Akan dikirim saat perangkat terhubung.'),
                    backgroundColor: Colors.teal.shade700,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
          if (!isConnected) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Hubungkan perangkat via Bluetooth untuk mengirim perubahan ke Node.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  void _showResetConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Konfirmasi Reset'),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin menghapus semua data Gamifikasi? '
          'Anda akan kehilangan semua Level, XP, Poin, dan Badges yang telah dikumpulkan. '
          'Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              // 1. Jalankan event reset Gamifikasi
              context.read<GamificationBloc>().add(ResetGamificationData());
              
              // 2. Bersihkan Log Riwayat Sensor (Lokal & Firebase)
              context.read<SensorBloc>().add(ClearSensorLog());
              
              // 3. Tutup dialog
              Navigator.pop(ctx);
              
              // 3. Kembali ke layar utama (keluar dari settings)
              Navigator.pop(context);
              
              // 4. Tampilkan Snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Semua data telah direset kembali ke Level 1.'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('Ya, Hapus Data'),
          ),
        ],
      ),
    );
  }

  void _showSdCardDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0F2B1D), // Dark greenish background matching the image
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Hapus Data SD Card',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Pilih perangkat keras yang ingin dihapus riwayat datanya. '
                'Tindakan ini tidak dapat dibatalkan dan akan menghapus seluruh data pada SD Card perangkat tersebut.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Align(
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.lightGreenAccent.shade400,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade500,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        context.read<SensorBloc>().add(DeleteSdCardEvent(target: 'gateway'));
                        Navigator.pop(ctx);
                        _isDeletingSdCard = true;
                        _showLoadingDialog(context, 'Menghapus data SD Card Gateway...');
                      },
                      child: const Text(
                        'Gateway',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange.shade500,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        context.read<SensorBloc>().add(DeleteSdCardEvent(target: 'node'));
                        Navigator.pop(ctx);
                        _isDeletingSdCard = true;
                        _showLoadingDialog(context, 'Menghapus data SD Card Node...');
                      },
                      child: const Text(
                        'Node',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Konfirmasi Keluar'),
          ],
        ),
        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              // 1. Tutup dialog
              Navigator.pop(ctx);
              
              // 2. Logout dari Google dan Firebase
              await GoogleSignIn().signOut();
              await FirebaseAuth.instance.signOut();
              
              if (!context.mounted) return;
              
              // 3. Kembali ke layar login dan hapus history
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
            child: const Text('Ya, Keluar'),
          ),
        ],
      ),
    );
  }
  
  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0F2B1D),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.orange),
              const SizedBox(height: 24),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Mohon tunggu, proses ini tidak memakan waktu lama...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

