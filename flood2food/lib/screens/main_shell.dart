import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/sensor/sensor_bloc.dart';
import '../bloc/sensor/sensor_state.dart';
import '../bloc/gamification/gamification_bloc.dart';
import '../bloc/gamification/gamification_event.dart';
import 'dashboard_screen.dart';
import 'tasks_screen.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  late final PageController _pageController;

  final _screens = const [
    DashboardScreen(),
    TasksScreen(),
    ChatScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavTapped(int index) {
    if (_currentIndex == index) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutQuint,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BlocListener<SensorBloc, SensorState>(
      listenWhen: (prev, curr) =>
          curr.isConnected && curr.latestData.nitrogen != 0,
      listener: (context, state) {
        final gameState = context.read<GamificationBloc>().state;
        if (gameState.dailyTasks.isEmpty && !gameState.isGenerating) {
          context
              .read<GamificationBloc>()
              .add(GenerateDailyTasks(state.latestData));
        }
      },
      child: Scaffold(
        extendBody: true, // Kunci agar konten memanjang hingga ke belakang Nav Bar
        body: PageView(
          controller: _pageController,
          physics: const BouncingScrollPhysics(),
          onPageChanged: (index) {
            setState(() => _currentIndex = index);
          },
          children: _screens,
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(32), // Capsule shape
              boxShadow: [
                BoxShadow(
                  color: colorScheme.brightness == Brightness.dark 
                      ? Colors.black.withValues(alpha: 0.5) 
                      : Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / 4;
                const pillWidth = 66.0;
                const pillHeight = 50.0;
                // Hitung titik tengah setiap ruang tab, lalu geser setengah ukuran kotak hijau
                final leftPos = (itemWidth * _currentIndex) + (itemWidth / 2) - (pillWidth / 2);

                return SizedBox(
                  height: pillHeight,
                  child: Stack(
                    children: [
                      // Kotak hijau (Indikator aktif) yang meluncur super mulus
                      // Kotak hijau (Indikator aktif) yang meluncur super mulus (120fps) tanpa memicu layout pass
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: leftPos),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutQuint, // Melesat cepat lalu melambat super halus
                        builder: (context, xOffset, child) {
                          return Transform.translate(
                            offset: Offset(xOffset, 0),
                            child: child,
                          );
                        },
                        child: Container(
                          width: pillWidth,
                          height: pillHeight,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                      // Baris Ikon yang statis di tempatnya
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildNavItem(context, 0, Icons.dashboard_rounded),
                          _buildNavItem(context, 1, Icons.task_alt_rounded),
                          _buildNavItem(context, 2, Icons.forum_rounded),
                          _buildNavItem(context, 3, Icons.person_rounded),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon) {
    final isSelected = _currentIndex == index;
    final colorScheme = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onTap: () => _onNavTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 66,
        height: 50,
        alignment: Alignment.center,
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(
            end: isSelected 
                ? colorScheme.onPrimary // Kontras di atas indikator hijau
                : colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          duration: const Duration(milliseconds: 300),
          builder: (context, color, child) {
            return Icon(
              icon,
              size: 26,
              color: color,
            );
          },
        ),
      ),
    );
  }
}
