class UserProfile {
  final String name;
  final String avatarPath;
  final int level;
  final int currentXp;
  final int xpToNextLevel;
  final int streakDays;
  final int totalTasksCompleted;
  final int totalPoints;
  final List<String> badges;

  const UserProfile({
    this.name = 'Flood2Food',
    this.avatarPath = '',
    this.level = 1,
    this.currentXp = 0,
    this.xpToNextLevel = 100,
    this.streakDays = 0,
    this.totalTasksCompleted = 0,
    this.totalPoints = 0,
    this.badges = const [],
  });

  double get levelProgress => currentXp / xpToNextLevel;

  UserProfile copyWith({
    String? name,
    String? avatarPath,
    int? level,
    int? currentXp,
    int? xpToNextLevel,
    int? streakDays,
    int? totalTasksCompleted,
    int? totalPoints,
    List<String>? badges,
  }) =>
      UserProfile(
        name: name ?? this.name,
        avatarPath: avatarPath ?? this.avatarPath,
        level: level ?? this.level,
        currentXp: currentXp ?? this.currentXp,
        xpToNextLevel: xpToNextLevel ?? this.xpToNextLevel,
        streakDays: streakDays ?? this.streakDays,
        totalTasksCompleted: totalTasksCompleted ?? this.totalTasksCompleted,
        totalPoints: totalPoints ?? this.totalPoints,
        badges: badges ?? this.badges,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'avatarPath': avatarPath,
        'level': level,
        'currentXp': currentXp,
        'xpToNextLevel': xpToNextLevel,
        'streakDays': streakDays,
        'totalTasksCompleted': totalTasksCompleted,
        'totalPoints': totalPoints,
        'badges': badges,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String? ?? 'Flood2Food',
      avatarPath: json['avatarPath'] as String? ?? '',
      level: json['level'] as int? ?? 1,
      currentXp: json['currentXp'] as int? ?? 0,
      xpToNextLevel: json['xpToNextLevel'] as int? ?? 100,
      streakDays: json['streakDays'] as int? ?? 0,
      totalTasksCompleted: json['totalTasksCompleted'] as int? ?? 0,
      totalPoints: json['totalPoints'] as int? ?? 0,
      badges: (json['badges'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
    );
  }
}
