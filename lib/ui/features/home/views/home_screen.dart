import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/data/services/google_drive_service.dart';
import 'package:workout_tracker/ui/core/theme/app_colors.dart';
import 'package:workout_tracker/ui/core/theme/theme_controller.dart';
import 'package:workout_tracker/ui/core/widgets/modular_card.dart';
import 'package:workout_tracker/ui/core/widgets/section_header.dart';
import 'package:workout_tracker/ui/core/widgets/theme_switch_button.dart';
import 'package:workout_tracker/ui/features/exercise_info/views/exercise_info_page.dart';
import 'package:workout_tracker/ui/features/workout_log/views/exercise_statistics_screen.dart';
import 'package:workout_tracker/ui/features/workout_log/views/todays_workout_log_screen.dart';
import 'package:workout_tracker/ui/features/workout_split/views/workout_split_page.dart';
import 'package:workout_tracker/ui/features/weekly_activity/view_models/weekly_activity_view_model.dart';
import 'package:workout_tracker/ui/features/weekly_activity/views/weekly_activity_section.dart';
import 'widgets/hero_workout_banner.dart';
import 'widgets/quick_stat_card.dart';

class HomeScreen extends StatefulWidget {
  final ThemeController? themeController;

  const HomeScreen({
    super.key,
    this.themeController,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _scheduleStorageKey = 'workout_schedule';
  static const _splitStorageKey = 'split_choice';

  final GoogleDriveService _driveService = GoogleDriveService();
  final WeeklyActivityViewModel _weeklyActivityViewModel = WeeklyActivityViewModel();

  String _todaysWorkout = 'Rest';
  String _activeSplit = 'Bro Split';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _weeklyActivityViewModel.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    final preferences = await SharedPreferences.getInstance();
    final storedSchedule = preferences.getString(_scheduleStorageKey);
    final savedSplit = preferences.getString(_splitStorageKey) ?? 'Bro Split';
    var todaysWorkout = 'Rest';

    if (storedSchedule != null) {
      try {
        final decoded = jsonDecode(storedSchedule);
        if (decoded is Map) {
          final schedule = decoded.map<String, String>(
            (key, value) => MapEntry(key.toString(), value.toString()),
          );
          // Locale-safe weekday lookup
          todaysWorkout = schedule[DateFormat('EEEE', 'en_US').format(DateTime.now())] ?? 'Rest';
        }
      } on FormatException {
        todaysWorkout = 'Rest';
      }
    }

    if (!mounted) return;
    setState(() {
      _todaysWorkout = todaysWorkout;
      _activeSplit = savedSplit;
      _isLoading = false;
    });

    await _weeklyActivityViewModel.loadWeeklyActivity();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Tracker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        elevation: 0,
        actions: [
          ThemeSwitchButton(controller: widget.themeController),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Hero Workout Banner Card (Tappable to jump right into Today's Workout)
                  HeroWorkoutBanner(
                    todaysWorkout: _todaysWorkout,
                    isLoading: _isLoading,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TodaysWorkoutLogScreen(),
                        ),
                      ).then((_) => _loadDashboardData());
                    },
                  ),
                  const SizedBox(height: 16),

                  // Quick Stats Row with real-time Drive sync status binding
                  Row(
                    children: [
                      Expanded(
                        child: QuickStatCard(
                          label: 'Active Split',
                          value: _activeSplit,
                          icon: Icons.calendar_view_week_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ValueListenableBuilder<SyncState>(
                          valueListenable: _driveService.syncStateNotifier,
                          builder: (context, syncState, child) {
                            String syncText;
                            Color syncColor;
                            IconData syncIcon;

                            switch (syncState) {
                              case SyncState.synced:
                                syncText = 'Synced';
                                syncColor = AppColors.success;
                                syncIcon = Icons.cloud_done_rounded;
                              case SyncState.syncing:
                                syncText = 'Syncing...';
                                syncColor = AppColors.primary;
                                syncIcon = Icons.sync_rounded;
                              case SyncState.error:
                                syncText = 'Offline / Cache';
                                syncColor = AppColors.warning;
                                syncIcon = Icons.cloud_queue_rounded;
                            }

                            return QuickStatCard(
                              label: 'Drive Sync',
                              value: syncText,
                              icon: syncIcon,
                              color: syncColor,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Weekly Streak Heatmap Card
                  ListenableBuilder(
                    listenable: _weeklyActivityViewModel,
                    builder: (context, _) => WeeklyActivitySection(
                      weekActivity: _weeklyActivityViewModel.weekActivity,
                      streakCount: _weeklyActivityViewModel.streakCount,
                      isLoading: _weeklyActivityViewModel.isLoading,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section Header
                  const SectionHeader(title: 'Quick Navigation'),
                  const SizedBox(height: 12),

                  // Modular Feature Cards
                  ModularCard(
                    title: "Today's Workout Log",
                    subtitle: "Log your sets, reps, and weights for today's session",
                    icon: Icons.fitness_center_rounded,
                    iconColor: AppColors.primary,
                    iconBackgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TodaysWorkoutLogScreen(),
                        ),
                      ).then((_) => _loadDashboardData());
                    },
                  ),
                  const SizedBox(height: 12),

                  ModularCard(
                    title: "Exercise Statistics & Progress",
                    subtitle: "Track strength trends and performance over 1M, 3M, 6M, or 1Y",
                    icon: Icons.show_chart_rounded,
                    iconColor: AppColors.accent,
                    iconBackgroundColor: AppColors.accent.withValues(alpha: 0.1),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ExerciseStatisticsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  ModularCard(
                    title: "Workout Split & Schedule",
                    subtitle: "Choose your routine (Bro, Pull-Push) and plan weekdays",
                    icon: Icons.edit_calendar_rounded,
                    iconColor: AppColors.info,
                    iconBackgroundColor: AppColors.info.withValues(alpha: 0.1),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WorkoutSplitPage(),
                        ),
                      );
                      _loadDashboardData();
                    },
                  ),
                  const SizedBox(height: 12),

                  ModularCard(
                    title: "Exercise Directory",
                    subtitle: "Browse muscle groups and add or delete exercises in Drive",
                    icon: Icons.library_books_rounded,
                    iconColor: AppColors.warning,
                    iconBackgroundColor: AppColors.warning.withValues(alpha: 0.1),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ExerciseInfoPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
