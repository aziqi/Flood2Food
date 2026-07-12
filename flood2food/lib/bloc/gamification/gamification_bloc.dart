import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'gamification_event.dart';
import 'gamification_state.dart';
import '../../models/user_profile.dart';
import '../../models/daily_task.dart';
import '../../services/ai_api_service.dart';
import '../../services/ai_task_service.dart';
import '../../services/firebase_sync_service.dart';

class GamificationBloc extends Bloc<GamificationEvent, GamificationState> {
  GamificationBloc({
    UserProfile? storedProfile,
    List<DailyTask>? storedTasks,
    String? storedDate,
  }) : super(GamificationState(
          profile: storedProfile ?? const UserProfile(),
          dailyTasks: storedTasks ?? [],
          lastGeneratedDate: storedDate ?? '',
        )) {
    on<GenerateDailyTasks>(_onGenerateDailyTasks);
    on<CompleteTask>(_onCompleteTask);
    on<ResetGamificationData>(_onResetData);
    on<UpdateProfileDetails>(_onUpdateProfileDetails);
  }

  Future<void> _onGenerateDailyTasks(
    GenerateDailyTasks event,
    Emitter<GamificationState> emit,
  ) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    
    // Cegah pembuatan misi jika data belum ada (timestamp masih default 0)
    if (event.sensorData.timestamp.millisecondsSinceEpoch == 0) return;

    if (!event.forceRefresh && state.lastGeneratedDate == today && state.dailyTasks.isNotEmpty) return;

    emit(state.copyWith(isGenerating: true, error: null));

    // Cek apakah tanah sudah sangat subur (Skor >= 90)
    if (event.sensorData.plantHealthScore >= 90) {
      final optimalTask = DailyTask(
        id: 'optimal_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Pertahankan Kondisi Optimal',
        description: 'Skor kesehatan tanah sangat baik (${event.sensorData.plantHealthScore.toStringAsFixed(0)}/100)! Tidak ada perawatan khusus hari ini.',
        category: TaskCategory.general,
        difficulty: TaskDifficulty.easy,
        xpReward: 30, // Bonus besar karena berhasil merawat tanah
        pointReward: 15,
        aiReason: 'Seluruh parameter (NPK, pH, EC, Kelembaban) berada dalam rentang yang sangat ideal.',
      );
      
      final tasks = [optimalTask];
      await _saveData(tasks, today, state.profile);
      emit(state.copyWith(
        dailyTasks: tasks,
        lastGeneratedDate: today,
        isGenerating: false,
      ));
      return;
    }

    try {
      final tasks = await AiApiService.generateTasks(event.sensorData);
      await _saveData(tasks, today, state.profile);
      emit(state.copyWith(
        dailyTasks: tasks,
        lastGeneratedDate: today,
        isGenerating: false,
      ));
    } catch (e) {
      debugPrint(e.toString());
      final tasks = AiTaskService.generateDailyTasks(event.sensorData);
      await _saveData(tasks, today, state.profile);
      emit(state.copyWith(
        dailyTasks: tasks,
        lastGeneratedDate: today,
        isGenerating: false,
        error: 'Gagal memuat dari AI. Menggunakan tugas lokal.',
      ));
    }
  }

  void _onCompleteTask(CompleteTask event, Emitter<GamificationState> emit) {
    final index = state.dailyTasks.indexWhere((t) => t.id == event.taskId);
    if (index == -1 || state.dailyTasks[index].isCompleted) return;

    final task = state.dailyTasks[index];
    final updatedTasks = [...state.dailyTasks];
    updatedTasks[index] = task.copyWith(
      isCompleted: true,
      completedAt: DateTime.now(),
    );

    final profile = state.profile;
    int newXp = profile.currentXp + task.xpReward;
    int newLevel = profile.level;
    int newXpToNext = profile.xpToNextLevel;

    while (newXp >= newXpToNext) {
      newXp -= newXpToNext;
      newLevel++;
      newXpToNext = (newXpToNext * 1.3).round();
    }

    var updatedProfile = profile.copyWith(
      level: newLevel,
      currentXp: newXp,
      xpToNextLevel: newXpToNext,
      totalTasksCompleted: profile.totalTasksCompleted + 1,
      totalPoints: profile.totalPoints + task.pointReward,
    );

    final badges = _checkBadges(updatedProfile);
    updatedProfile = updatedProfile.copyWith(badges: badges);

    _saveData(updatedTasks, state.lastGeneratedDate, updatedProfile);
    emit(state.copyWith(dailyTasks: updatedTasks, profile: updatedProfile));
  }

  Future<void> _saveData(List<DailyTask> tasks, String date, UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(tasks.map((t) => t.toJson()).toList());
    await prefs.setString('stored_tasks', json);
    await prefs.setString('stored_tasks_date', date);
    await prefs.setString('stored_profile', jsonEncode(profile.toJson()));
    
    // Lempar data ke awan Firebase secara asinkron (tidak memblokir performa UI)
    FirebaseSyncService.syncUserProfile(profile);
    FirebaseSyncService.syncDailyTasks(tasks);
  }

  Future<void> _onUpdateProfileDetails(
    UpdateProfileDetails event,
    Emitter<GamificationState> emit,
  ) async {
    final updatedProfile = state.profile.copyWith(
      name: event.name,
      avatarPath: event.avatarPath,
    );
    await _saveData(state.dailyTasks, state.lastGeneratedDate, updatedProfile);
    emit(state.copyWith(profile: updatedProfile));
  }

  Future<void> _onResetData(ResetGamificationData event, Emitter<GamificationState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('stored_tasks');
    await prefs.remove('stored_tasks_date');
    await prefs.remove('stored_profile');
    
    emit(GamificationState());
  }

  List<String> _checkBadges(UserProfile profile) {
    final badges = <String>[...profile.badges];
    if (profile.totalTasksCompleted >= 1 && !badges.contains('First Step')) {
      badges.add('First Step');
    }
    if (profile.totalTasksCompleted >= 10 && !badges.contains('Green Thumb')) {
      badges.add('Green Thumb');
    }
    if (profile.totalTasksCompleted >= 50 && !badges.contains('Farm Master')) {
      badges.add('Farm Master');
    }
    if (profile.level >= 5 && !badges.contains('Level 5')) {
      badges.add('Level 5');
    }
    if (profile.level >= 10 && !badges.contains('Level 10')) {
      badges.add('Level 10');
    }
    if (profile.totalPoints >= 500 && !badges.contains('Point Collector')) {
      badges.add('Point Collector');
    }
    return badges;
  }
}
