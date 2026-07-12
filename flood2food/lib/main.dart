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
  await Firebase.initializeApp();

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
            themeAnimationDuration: const Duration(milliseconds: 600),
            themeAnimationCurve: Curves.easeInOutCubic,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
