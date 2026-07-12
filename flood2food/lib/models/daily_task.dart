enum TaskCategory { watering, fertilizing, pHAdjustment, soilCheck, general }
enum TaskDifficulty { easy, medium, hard }

class DailyTask {
  final String id;
  final String title;
  final String description;
  final TaskCategory category;
  final TaskDifficulty difficulty;
  final int xpReward;
  final int pointReward;
  final bool isCompleted;
  final bool isDaily;
  final DateTime? completedAt;
  final String aiReason;

  DailyTask({
    required this.id,
    required this.title,
    required this.description,
    this.category = TaskCategory.general,
    this.difficulty = TaskDifficulty.easy,
    this.xpReward = 20,
    this.pointReward = 10,
    this.isCompleted = false,
    this.isDaily = true,
    this.completedAt,
    this.aiReason = '',
  });

  DailyTask copyWith({
    String? id,
    String? title,
    String? description,
    TaskCategory? category,
    TaskDifficulty? difficulty,
    int? xpReward,
    int? pointReward,
    bool? isCompleted,
    bool? isDaily,
    DateTime? completedAt,
    String? aiReason,
  }) =>
      DailyTask(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        category: category ?? this.category,
        difficulty: difficulty ?? this.difficulty,
        xpReward: xpReward ?? this.xpReward,
        pointReward: pointReward ?? this.pointReward,
        isCompleted: isCompleted ?? this.isCompleted,
        isDaily: isDaily ?? this.isDaily,
        completedAt: completedAt ?? this.completedAt,
        aiReason: aiReason ?? this.aiReason,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category.name,
    'difficulty': difficulty.name,
    'xpReward': xpReward,
    'pointReward': pointReward,
    'isCompleted': isCompleted,
    'isDaily': isDaily,
    'completedAt': completedAt?.toIso8601String(),
    'aiReason': aiReason,
  };

  factory DailyTask.fromJson(Map<String, dynamic> json) {
    TaskCategory parseCategory(String name) {
      return TaskCategory.values.firstWhere(
        (e) => e.name == name,
        orElse: () => TaskCategory.general,
      );
    }

    TaskDifficulty parseDifficulty(String name) {
      return TaskDifficulty.values.firstWhere(
        (e) => e.name == name,
        orElse: () => TaskDifficulty.easy,
      );
    }

    return DailyTask(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: parseCategory(json['category'] as String? ?? 'general'),
      difficulty:
          parseDifficulty(json['difficulty'] as String? ?? 'easy'),
      xpReward: json['xpReward'] as int? ?? 20,
      pointReward: json['pointReward'] as int? ?? 10,
      isCompleted: json['isCompleted'] as bool? ?? false,
      isDaily: json['isDaily'] as bool? ?? true,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      aiReason: json['aiReason'] as String? ?? '',
    );
  }
}
