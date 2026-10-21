import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'bloc/sensor/sensor_bloc.dart';
import 'bloc/gamification/gamification_bloc.dart';
import 'models/daily_task.dart';
import 'models/user_profile.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/splash_screen.dart';
import 'services/ai_model_service.dart';
import 'package:firebase_core/firebase_core.dart';

// Arsitektur Bionic: Zero-overhead Theme State
late final ValueNotifier<ThemeMode> appThemeMode;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init fallback: $e');
  }

  await initializeDateFormatting();
  await dotenv.load(fileName: '.env');

  final prefs = await SharedPreferences.getInstance();
  final storedDate = prefs.getString('stored_tasks_date') ?? '';
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final tasksJson = prefs.getString('stored_tasks');
  List<DailyTask> storedTasks = [];
  if (tasksJson != null && storedDate == today) {
    final list = jsonDecode(tasksJson) as List<dynamic>;
    storedTasks = list
        .map((e) => DailyTask.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  if (storedTasks.isEmpty) {
    storedTasks = [
      DailyTask(
        id: 'task_demo_1',
        title: 'Aplikasi Urea Cepat Larut',
        description: 'Kadar N perlu disuplai. Taburkan 35 gram Urea per meter persegi di petak sawah B.',
        category: TaskCategory.fertilizing,
        difficulty: TaskDifficulty.medium,
        xpReward: 35,
        pointReward: 15,
        aiReason: 'Nitrogen tanah butuh dorongan vegetatif pasca genangan air.',
      ),
      DailyTask(
        id: 'task_demo_2',
        title: 'Pengaturan Saluran Drainase',
        description: 'Pertahankan tinggi genangan air 3-5 cm agar sirkulasi oksigen perakaran optimal.',
        category: TaskCategory.watering,
        difficulty: TaskDifficulty.easy,
        xpReward: 25,
        pointReward: 10,
        aiReason: 'Sirkulasi air mencegah pembusukan akar pada tanaman padi muda.',
      ),
      DailyTask(
        id: 'task_demo_3',
        title: 'Inspeksi Titik Sensor Node 1',
        description: 'Pastikan probe stainless steel NPK tertancap kokoh 10 cm di kedalaman tanah.',
        category: TaskCategory.general,
        difficulty: TaskDifficulty.easy,
        xpReward: 20,
        pointReward: 10,
        aiReason: 'Menjaga akurasi pembacaan telemetri real-time LoRa/BLE.',
      ),
      DailyTask(
        id: 'task_demo_4',
        title: 'Aplikasi Pupuk Silika Daun',
        description: 'Semprot larutan silika cair di pagi hari untuk memperkuat batang tanaman.',
        category: TaskCategory.fertilizing,
        difficulty: TaskDifficulty.hard,
        xpReward: 45,
        pointReward: 20,
        aiReason: 'Silika meningkatkan ketahanan mekanis tanaman terhadap hembusan angin kencang.',
      ),
    ];
  }

  final profileJson = prefs.getString('stored_profile');
  UserProfile? storedProfile;
  if (profileJson != null) {
    try {
      storedProfile = UserProfile.fromJson(
        jsonDecode(profileJson) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('Gagal memuat profil: $e');
    }
  }

  storedProfile ??= const UserProfile(
    name: 'Budi Santoso',
    level: 7,
    currentXp: 380,
    xpToNextLevel: 500,
    streakDays: 14,
    totalTasksCompleted: 42,
    totalPoints: 1250,
    badges: ['Pemupuk Handal', 'Penjaga NPK', 'Detektif pH', 'Pahlawan Pangan', 'IoT Master'],
  );

  // Load saved theme (default to dark for the premium feel)
  final savedTheme = prefs.getString('theme_mode');
  ThemeMode initialThemeMode = ThemeMode.dark;
  if (savedTheme == 'light') initialThemeMode = ThemeMode.light;
  
  appThemeMode = ValueNotifier(initialThemeMode);
  
  // Listener to automatically save theme changes to memory
  appThemeMode.addListener(() {
    prefs.setString('theme_mode', appThemeMode.value == ThemeMode.light ? 'light' : 'dark');
  });

  // Pre-load AI Model settings to memory for 0-jank animations
  await AiModelService.getActiveModel();

  runApp(
    Flood2FoodApp(
      initialTasks: storedTasks,
      initialDate: storedDate == today ? storedDate : '',
      initialProfile: storedProfile,
    ),
  );
}

class Flood2FoodApp extends StatelessWidget {
  final List<DailyTask> initialTasks;
  final String initialDate;
  final UserProfile? initialProfile;

  const Flood2FoodApp({
    super.key,
    this.initialTasks = const [],
    this.initialDate = '',
    this.initialProfile,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => SensorBloc()),
        BlocProvider(
          create: (_) => GamificationBloc(
            storedProfile: initialProfile,
            storedTasks: initialTasks,
            storedDate: initialDate,
          ),
        ),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: appThemeMode,
        builder: (context, themeMode, _) {
          return MaterialApp(
            title: 'flood2food',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
