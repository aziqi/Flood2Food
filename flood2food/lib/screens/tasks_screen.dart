import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/sensor/sensor_bloc.dart';
import '../bloc/gamification/gamification_bloc.dart';
import '../bloc/gamification/gamification_event.dart';
import '../bloc/gamification/gamification_state.dart';
import '../widgets/task_card.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gamification = context.watch<GamificationBloc>().state;
    final sensorState = context.watch<SensorBloc>().state;
    final tasks = gamification.dailyTasks;
    final colorScheme = Theme.of(context).colorScheme;

    if (tasks.isEmpty && !gamification.isGenerating) {
      context.read<GamificationBloc>().add(GenerateDailyTasks(sensorState.latestData));
    }

    final completed = tasks.where((t) => t.isCompleted).length;
    final total = tasks.length;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            centerTitle: true,
            title: const Text('Misi Harian', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            actions: [
              if (gamification.isGenerating)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary))),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '$completed/$total',
                        style: TextStyle(color: Colors.green[600], fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _profileHeader(context, gamification),
                  const SizedBox(height: 16),
                  _xpBar(context, gamification),
                  const SizedBox(height: 16),
                  _badgeSection(context, gamification),
                  
                  if (gamification.error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
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
                  ],
                ].animate(interval: 60.ms).fadeIn(duration: 500.ms, curve: Curves.easeOut).slideY(begin: 0.1, curve: Curves.easeOutQuint),
              ),
            ),
          ),
          if (tasks.isEmpty && gamification.isGenerating)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120), // Padding for Floating Nav Bar
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final task = tasks[index];
                    return TaskCard(
                      task: task,
                      onComplete: () => context.read<GamificationBloc>().add(CompleteTask(task.id)),
                    ).animate(delay: (index * 50).ms).fadeIn(duration: 400.ms, curve: Curves.easeOut).slideX(begin: 0.1, curve: Curves.easeOutCubic);
                  },
                  childCount: tasks.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _profileHeader(BuildContext context, GamificationState gamification) {
    final profile = gamification.profile;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.onSurface.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Level ${profile.level}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
                Text('${profile.totalPoints} Total XP', style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department_rounded, color: Colors.orange[400], size: 20),
                    const SizedBox(width: 4),
                    Text('${profile.streakDays}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.orange[400])),
                  ],
                ),
                Text('Hari beruntun', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.orange[300])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _xpBar(BuildContext context, GamificationState gamification) {
    final profile = gamification.profile;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${profile.currentXp} / ${profile.xpToNextLevel} XP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colorScheme.onSurface.withValues(alpha: 0.6))),
            Text('Menuju Level ${profile.level + 1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: colorScheme.primary)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: profile.levelProgress,
            minHeight: 12,
            backgroundColor: colorScheme.onSurface.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(colorScheme.primary),
          ),
        ),
      ],
    );
  }

  Widget _badgeSection(BuildContext context, GamificationState gamification) {
    final badges = gamification.profile.badges;
    if (badges.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pencapaian', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: colorScheme.onSurface.withValues(alpha: 0.6))),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: badges.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 16, color: Colors.amber[600]),
                    const SizedBox(width: 6),
                    Text(badges[index], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.amber[700])),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
