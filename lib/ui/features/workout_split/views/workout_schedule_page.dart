import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/ui/core/theme/app_colors.dart';
import 'package:workout_tracker/ui/core/widgets/compact_sync_button.dart';
import 'package:workout_tracker/ui/core/widgets/modular_card.dart';
import 'package:workout_tracker/ui/core/widgets/status_badge.dart';

class WorkoutSchedulePage extends StatefulWidget {
  final String split;

  const WorkoutSchedulePage({required this.split, super.key});

  @override
  State<WorkoutSchedulePage> createState() => _WorkoutSchedulePageState();
}

class _WorkoutSchedulePageState extends State<WorkoutSchedulePage> {
  static const _scheduleStorageKey = 'workout_schedule';
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _broSplitOptions = [
    'Legs',
    'Shoulders',
    'Triceps',
    'Chest',
    'Back',
    'Biceps',
    'Core',
    'Abs',
    'Glutes',
    'Calves',
    'Forearms',
  ];

  Map<String, String> _schedule = {};
  bool _isLoading = true;

  List<String> get _workoutOptions {
    switch (widget.split) {
      case 'Bro Split':
        return _broSplitOptions;
      case 'Pull-Push Split':
        return const ['Push', 'Pull'];
      case 'Anterior-Posterior Split':
        return const ['Anterior', 'Posterior'];
      case 'Full Body Split':
        return const ['Full Body'];
      default:
        return const [];
    }
  }

  int? get _maximumWorkoutDays {
    switch (widget.split) {
      case 'Pull-Push Split':
      case 'Anterior-Posterior Split':
        return 4;
      case 'Full Body Split':
        return 3;
      default:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final preferences = await SharedPreferences.getInstance();
    final storedSchedule = preferences.getString(_scheduleStorageKey);
    Map<String, String> schedule = {};

    if (storedSchedule != null) {
      try {
        final decoded = jsonDecode(storedSchedule);
        if (decoded is Map) {
          schedule = decoded.map<String, String>(
            (key, value) => MapEntry(key.toString(), value.toString()),
          );
          schedule.removeWhere(
            (day, workout) =>
                !_weekdays.contains(day) || !_workoutOptions.contains(workout),
          );
        }
      } on FormatException {
        schedule = {};
      }
    }

    if (!mounted) return;
    setState(() {
      _schedule = schedule;
      _isLoading = false;
    });
  }

  Future<void> _saveSchedule() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_scheduleStorageKey, jsonEncode(_schedule));
  }

  Future<void> _chooseWorkout(String day) async {
    final currentWorkout = _schedule[day];
    final assignedWorkoutDays = _schedule.length;
    final limitReached = _maximumWorkoutDays != null &&
        assignedWorkoutDays >= _maximumWorkoutDays! &&
        currentWorkout == null;

    final selectedWorkout = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Configure $day Workout'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ..._workoutOptions.map(
                (workout) => ListTile(
                  title: Text(workout),
                  leading: Icon(
                    workout == currentWorkout
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: workout == currentWorkout ? AppColors.primary : null,
                  ),
                  enabled: !limitReached || workout == currentWorkout,
                  onTap: limitReached && workout != currentWorkout
                      ? null
                      : () => Navigator.pop(context, workout),
                ),
              ),
              if (limitReached)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Maximum of $_maximumWorkoutDays workout days reached for ${widget.split}.',
                    style: const TextStyle(color: AppColors.warning, fontSize: 12),
                  ),
                ),
              const Divider(),
              ListTile(
                title: const Text('Rest Day'),
                leading: Icon(
                  currentWorkout == null
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: currentWorkout == null ? AppColors.primary : null,
                ),
                onTap: () => Navigator.pop(context, 'Rest'),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedWorkout == null || !mounted) return;
    setState(() {
      if (selectedWorkout == 'Rest') {
        _schedule.remove(day);
      } else {
        _schedule[day] = selectedWorkout;
      }
    });
    await _saveSchedule();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.split} Schedule', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 14),
            child: Center(
              child: CompactSyncButton(),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _weekdays.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final day = _weekdays[index];
                final workout = _schedule[day] ?? 'Rest';
                final isRest = workout == 'Rest';

                return ModularCard(
                  title: day,
                  subtitle: isRest ? 'Rest Day' : 'Target: $workout',
                  icon: isRest ? Icons.nightlight_round : Icons.fitness_center_rounded,
                  iconColor: isRest ? Colors.grey : AppColors.primary,
                  iconBackgroundColor: isRest
                      ? Colors.grey.withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.1),
                  badge: StatusBadge.tag(
                    label: isRest ? 'REST' : workout.toUpperCase(),
                    color: isRest ? Colors.grey : AppColors.getMuscleColor(workout),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
                    onPressed: () => _chooseWorkout(day),
                  ),
                  onTap: () => _chooseWorkout(day),
                );
              },
            ),
    );
  }
}

