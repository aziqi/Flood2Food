import 'package:flutter/material.dart';
import '../models/daily_task.dart';

class TaskCard extends StatelessWidget {
  final DailyTask task;
  final VoidCallback onComplete;

  const TaskCard({super.key, required this.task, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: task.isCompleted
            ? Colors.green.withValues(alpha: isDark ? 0.05 : 0.02)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: task.isCompleted
              ? Colors.green.withValues(alpha: 0.2)
              : colorScheme.onSurface.withValues(alpha: 0.1),
        ),
        boxShadow: task.isCompleted ? [] : [
          BoxShadow(
            color: colorScheme.onSurface.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCategoryIcon(context),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                      color: task.isCompleted ? colorScheme.onSurface.withValues(alpha: 0.4) : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    task.description,
                    style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _rewardChip(context, '+${task.xpReward} XP', colorScheme.primary),
                      _rewardChip(context, '+${task.pointReward} pts', Colors.amber),
                      _difficultyChip(),
                    ],
                  ),
                  if (!task.isCompleted) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: onComplete,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.green.withValues(alpha: 0.1),
                          foregroundColor: Colors.green[600],
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Selesaikan Misi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryIcon(BuildContext context) {
    IconData icon;
    Color color;
    switch (task.category) {
      case TaskCategory.watering:
        icon = Icons.water_drop_rounded;
        color = const Color(0xFF2196F3);
      case TaskCategory.fertilizing:
        icon = Icons.eco_rounded;
        color = const Color(0xFF4CAF50);
      case TaskCategory.pHAdjustment:
        icon = Icons.science_rounded;
        color = const Color(0xFF9C27B0);
      case TaskCategory.soilCheck:
        icon = Icons.explore_rounded;
        color = const Color(0xFFFF9800);
      case TaskCategory.general:
        icon = Icons.build_rounded;
        color = Colors.grey;
    }

    if (task.isCompleted) color = Colors.green;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: task.isCompleted ? Colors.green.withValues(alpha: 0.1) : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(task.isCompleted ? Icons.check_rounded : icon, color: color, size: 28),
    );
  }

  Widget _rewardChip(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
    );
  }

  Widget _difficultyChip() {
    Color color;
    switch (task.difficulty) {
      case TaskDifficulty.easy: color = Colors.green;
      case TaskDifficulty.medium: color = Colors.orange;
      case TaskDifficulty.hard: color = Colors.red;
    }
    
    if (task.isCompleted) color = Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(task.difficulty.name.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}
