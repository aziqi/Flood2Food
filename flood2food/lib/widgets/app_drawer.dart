import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/gamification/gamification_bloc.dart';
import '../screens/settings_screen.dart';
import '../screens/model_manager_screen.dart';
import '../services/ai_model_service.dart';
import '../models/ai_model.dart';
import '../main.dart'; // Import appThemeMode
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/calibration/spatial_calibration_screen.dart' as calibration;

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<GamificationBloc>().state.profile;
    final colorScheme = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.05),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOutCubic,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!) as ImageProvider
                        : (profile.avatarPath.isNotEmpty
                            ? FileImage(File(profile.avatarPath)) as ImageProvider
                            : const AssetImage('assets/profile.jpg')),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user?.displayName ?? profile.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w800, 
                    fontSize: 24,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.secondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Level ${profile.level} • ${profile.totalPoints} XP',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                _buildMenuItem(
                  context,
                  icon: Icons.memory_rounded,
                  title: 'Model AI',
                  subtitle: ValueListenableBuilder<AiModel?>(
                    valueListenable: AiModelService.activeModelNotifier,
                    builder: (context, activeModel, _) {
                      if (activeModel != null) return Text(activeModel.name, style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.5)));
                      return const SizedBox.shrink();
                    },
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ModelManagerScreen()));
                  },
                ),
                const SizedBox(height: 8),
                _buildMenuItem(
                  context,
                  icon: Icons.explore_rounded,
                  title: 'Kalibrasi Lahan',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const calibration.SpatialCalibrationScreen()));
                  },
                ),
                const SizedBox(height: 8),
                _buildMenuItem(
                  context,
                  icon: Icons.settings_rounded,
                  title: 'Pengaturan',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: appThemeMode,
              builder: (context, themeMode, _) {
                final isDarkTheme = themeMode == ThemeMode.dark;
                return SwitchListTile(
                  title: Text(
                    isDarkTheme ? 'Mode Gelap' : 'Mode Terang',
                    style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                  ),
                  secondary: Icon(
                    isDarkTheme ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: isDarkTheme ? colorScheme.primary : Colors.orange,
                  ),
                  activeThumbColor: colorScheme.primary,
                  activeTrackColor: colorScheme.primary.withValues(alpha: 0.2),
                  inactiveThumbColor: colorScheme.onSurface.withValues(alpha: 0.5),
                  inactiveTrackColor: colorScheme.onSurface.withValues(alpha: 0.1),
                  value: isDarkTheme,
                  onChanged: (val) {
                    appThemeMode.value = val ? ThemeMode.dark : ThemeMode.light;
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 120, top: 8), // Padding ekstra karena tertutup Bottom NavBar MainShell
            child: Center(
              child: Text(
                'Flood2Food v2.0 • Quantum Edition',
                style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, {required IconData icon, required String title, Widget? subtitle, required VoidCallback onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: colorScheme.primary, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: colorScheme.onSurface),
      ),
      subtitle: subtitle,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      hoverColor: colorScheme.primary.withValues(alpha: 0.05),
    );
  }
}
