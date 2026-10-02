import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/data/services/google_drive_service.dart';
import 'package:workout_tracker/ui/core/theme/app_colors.dart';
import 'package:workout_tracker/ui/core/widgets/modular_card.dart';
import 'package:workout_tracker/ui/core/widgets/section_header.dart';
import 'package:workout_tracker/ui/core/widgets/weekly_streak_widget.dart';
import 'package:workout_tracker/ui/features/exercise_info/views/exercise_info_page.dart';
import 'package:workout_tracker/ui/features/workout_log/views/exercise_statistics_screen.dart';
import 'package:workout_tracker/ui/features/workout_log/views/todays_workout_log_screen.dart';
import 'package:workout_tracker/ui/features/workout_split/views/workout_split_page.dart';
import 'widgets/hero_workout_banner.dart';
import 'widgets/quick_stat_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _scheduleStorageKey = 'workout_schedule';
  static const _splitStorageKey = 'split_choice';

  final GoogleDriveService _driveService = GoogleDriveService();

  String _todaysWorkout = 'Rest';
  String _activeSplit = 'Bro Split';
  bool _isLoading = true;
  Map<String, bool> _weekActivity = {};
  int _streakCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
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

    // Load weekly activity for streak widget — read all records in the current
    // Mon–Sun window (not filtered to today-only) so past days are marked.
    final weekRecords = await _driveService.getWeeklyDailyRecords();
    final Map<String, bool> activity = {};
    final now = DateTime.now();

    // Zero-out the time component so date arithmetic is timezone-safe.
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: now.weekday - 1));

    // Build a Set of date strings for O(1) lookup.
    final recordedDays = weekRecords.map((r) {
      return DateTime(r.date.year, r.date.month, r.date.day).toIso8601String();
    }).toSet();

    for (int i = 0; i < 7; i++) {
      final dayDate = monday.add(Duration(days: i));
      final dayName = DateFormat('E', 'en_US').format(dayDate); // 'Mon'…'Sun'
      activity[dayName] = recordedDays.contains(dayDate.toIso8601String());
    }

    final activeDaysCount = activity.values.where((v) => v).length;

    if (!mounted) return;
    setState(() {
      _todaysWorkout = todaysWorkout;
      _activeSplit = savedSplit;
      _weekActivity = activity;
      _streakCount = activeDaysCount;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Tracker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        elevation: 0,
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
                  WeeklyStreakWidget(
                    weekActivity: _weekActivity,
                    streakCount: _streakCount,
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
