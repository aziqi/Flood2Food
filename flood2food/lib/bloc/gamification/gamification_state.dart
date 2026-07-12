import '../../models/user_profile.dart';
import '../../models/daily_task.dart';

class GamificationState {
  final UserProfile profile;
  final List<DailyTask> dailyTasks;
  final String lastGeneratedDate;
  final bool isGenerating;
  final String? error;

  GamificationState({
    this.profile = const UserProfile(),
    this.dailyTasks = const [],
    this.lastGeneratedDate = '',
    this.isGenerating = false,
    this.error,
  });

  GamificationState copyWith({
    UserProfile? profile,
    List<DailyTask>? dailyTasks,
    String? lastGeneratedDate,
    bool? isGenerating,
    String? error,
  }) {
    return GamificationState(
      profile: profile ?? this.profile,
      dailyTasks: dailyTasks ?? this.dailyTasks,
      lastGeneratedDate: lastGeneratedDate ?? this.lastGeneratedDate,
      isGenerating: isGenerating ?? this.isGenerating,
      error: error ?? this.error,
    );
  }
}
