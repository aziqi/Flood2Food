import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/gamification/gamification_bloc.dart';
import '../bloc/sensor/sensor_bloc.dart';
import '../widgets/app_drawer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../models/user_profile.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gamification = context.watch<GamificationBloc>().state;
    final sensor = context.watch<SensorBloc>().state;
    final profile = gamification.profile;
    final data = sensor.latestData;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Profil & Statistik', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 100), // Padding bawah lega untuk nav bar
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLevelCard(context, profile.level, profile.levelProgress, colorScheme, profile),
            const SizedBox(height: 20),
            _buildStatGrid(context, profile, data, colorScheme),
            const SizedBox(height: 20),
            _buildBadgesSection(context, profile.badges, colorScheme),
            const SizedBox(height: 20),
            _buildAchievements(context, profile, colorScheme),
          ].animate(interval: 80.ms).fadeIn(duration: 500.ms, curve: Curves.easeOut).slideY(begin: 0.1, curve: Curves.easeOutQuint),
        ),
      ),
    );
  }

  Widget _buildLevelCard(BuildContext context, int level, double progress, ColorScheme colorScheme, UserProfile profile) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceTint.withValues(alpha: 0.1) : colorScheme.primary,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
        ],
        border: isDark ? Border.all(color: colorScheme.primary.withValues(alpha: 0.2)) : null,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? colorScheme.primary : colorScheme.onPrimary,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!) as ImageProvider
                      : (profile.avatarPath.isNotEmpty
                          ? FileImage(File(profile.avatarPath)) as ImageProvider
                          : const AssetImage('assets/profile.jpg')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            user?.displayName ?? profile.name,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: isDark ? colorScheme.onSurface : colorScheme.onPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? colorScheme.primary.withValues(alpha: 0.2) : colorScheme.onPrimary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events_rounded, size: 20, color: isDark ? colorScheme.primary : colorScheme.onPrimary),
                const SizedBox(width: 8),
                Text(
                  'Level $level',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? colorScheme.primary : colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: isDark ? colorScheme.surfaceContainerHighest : colorScheme.onPrimary.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(isDark ? colorScheme.primary : colorScheme.onPrimary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${(progress * 100).toStringAsFixed(0)}% menuju level berikutnya',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? colorScheme.onSurface.withValues(alpha: 0.5) : colorScheme.onPrimary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid(BuildContext context, dynamic profile, dynamic data, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: _statCard(context, 'Total Poin', '${profile.totalPoints}', Icons.stars_rounded, Colors.orange, colorScheme),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _statCard(context, 'Tugas Selesai', '${profile.totalTasksCompleted}', Icons.task_alt_rounded, Colors.green, colorScheme),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _statCard(context, 'Kesehatan', '${data.plantHealthScore.toStringAsFixed(0)}%', Icons.favorite_rounded, Colors.redAccent, colorScheme),
        ),
      ],
    );
  }

  Widget _statCard(BuildContext context, String label, String value, IconData icon, Color accentColor, ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onSurface.withValues(alpha: 0.5)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesSection(BuildContext context, List<String> badges, ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text('Lencana Kehormatan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 16),
          badges.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Selesaikan tugas untuk mendapatkan lencana pertamamu!',
                          style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: badges.map((b) => Chip(
                    avatar: const Icon(Icons.verified_rounded, size: 18, color: Colors.orange),
                    label: Text(b, style: TextStyle(fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                    backgroundColor: Colors.orange.withValues(alpha: 0.1),
                    side: BorderSide(color: Colors.orange.withValues(alpha: 0.2)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  )).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildAchievements(BuildContext context, dynamic profile, ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.military_tech_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text('Pencapaian', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 20),
          _achievementItem('Selesaikan 10 Tugas', 10, profile.totalTasksCompleted, colorScheme),
          const SizedBox(height: 16),
          _achievementItem('Kumpulkan 500 Poin', 500, profile.totalPoints, colorScheme),
          const SizedBox(height: 16),
          _achievementItem('Capai Level 5', 5, profile.level, colorScheme),
        ],
      ),
    );
  }

  Widget _achievementItem(String title, int target, int current, ColorScheme colorScheme) {
    final progress = (current / target).clamp(0.0, 1.0);
    final isCompleted = progress >= 1;
    final isDark = colorScheme.brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title, 
              style: TextStyle(
                fontSize: 15, 
                fontWeight: FontWeight.w700, 
                color: isCompleted ? colorScheme.onSurface : colorScheme.onSurface.withValues(alpha: 0.8)
              )
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green.withValues(alpha: 0.1) : colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$current / $target', 
                style: TextStyle(
                  fontSize: 13, 
                  fontWeight: FontWeight.w800, 
                  color: isCompleted ? Colors.green : colorScheme.onSurface.withValues(alpha: 0.5)
                )
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: isDark ? colorScheme.surfaceContainerHighest : colorScheme.onSurface.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(
              isCompleted ? Colors.green : colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
