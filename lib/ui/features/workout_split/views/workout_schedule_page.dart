import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/domain/models/workout_split.dart';
import 'package:workout_tracker/ui/core/theme/app_colors.dart';
import 'package:workout_tracker/ui/core/widgets/compact_sync_button.dart';
import 'package:workout_tracker/ui/core/widgets/modular_card.dart';
import 'package:workout_tracker/ui/core/widgets/status_badge.dart';

class WorkoutSchedulePage extends StatefulWidget {
  final String split;
  final int? initialTargetDays;

  const WorkoutSchedulePage({
    required this.split,
    this.initialTargetDays,
    super.key,
  });

  @override
  State<WorkoutSchedulePage> createState() => _WorkoutSchedulePageState();
}

class _WorkoutSchedulePageState extends State<WorkoutSchedulePage> {
  static const _scheduleStorageKey = 'workout_schedule';
  static const _targetDaysStorageKey = 'split_target_days';
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
  int _targetDays = 4;
  bool _isLoading = true;

  int get _maximumWorkoutDays => _targetDays;

  int get _assignedWorkoutDays =>
      _schedule.values.where((w) => w.isNotEmpty && w != 'Rest').length;

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

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final preferences = await SharedPreferences.getInstance();
    final storedSchedule = preferences.getString(_scheduleStorageKey);
    final storedTargetDays = preferences.getInt(_targetDaysStorageKey);

    int targetDays;
    if (storedTargetDays != null && storedTargetDays >= 1 && storedTargetDays <= 7) {
      targetDays = storedTargetDays;
    } else if (widget.initialTargetDays != null) {
      targetDays = widget.initialTargetDays!;
    } else {
      targetDays = WorkoutSplit.getDefaultTargetDays(widget.split);
    }

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
      _targetDays = targetDays;
      _isLoading = false;
    });
  }

  Future<void> _saveSchedule() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_scheduleStorageKey, jsonEncode(_schedule));
  }

  Future<void> _showEditTargetDaysDialog() async {
    int selectedDays = _targetDays;
    final updated = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text(
              'Change Weekly Target',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set target workout days for ${widget.split} (1 to 7 days per week):',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (index) {
                    final days = index + 1;
                    final isSelected = selectedDays == days;
                    final label = days == 1 ? '1 Day' : '$days Days';
                    return ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : null,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setDialogState(() => selectedDays = days);
                        }
                      },
                    );
                  }),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, selectedDays),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save Target'),
              ),
            ],
          );
        },
      ),
    );

    if (updated == null || !mounted) return;
    setState(() => _targetDays = updated);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_targetDaysStorageKey, updated);
  }

  Future<void> _chooseWorkout(String day) async {
    final currentWorkout = _schedule[day];
    final isCurrentlyActive =
        currentWorkout != null && currentWorkout.isNotEmpty && currentWorkout != 'Rest';
    final limitReached = _assignedWorkoutDays >= _maximumWorkoutDays && !isCurrentlyActive;

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
                  currentWorkout == null || currentWorkout == 'Rest'
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: currentWorkout == null || currentWorkout == 'Rest'
                      ? AppColors.primary
                      : null,
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
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ModularCard(
                  title: 'Weekly Target: $_targetDays Days',
                  subtitle: 'Scheduled: $_assignedWorkoutDays / $_targetDays active days',
                  icon: Icons.calendar_month_rounded,
                  iconColor: AppColors.primary,
                  iconBackgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  badge: _assignedWorkoutDays == _targetDays
                      ? StatusBadge.tag(label: 'GOAL MET', color: AppColors.success)
                      : _assignedWorkoutDays > _targetDays
                          ? StatusBadge.tag(label: 'OVER TARGET', color: AppColors.warning)
                          : StatusBadge.tag(
                              label: '${_targetDays - _assignedWorkoutDays} REMAINING',
                              color: AppColors.info,
                            ),
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _showEditTargetDaysDialog,
                  ),
                  onTap: _showEditTargetDaysDialog,
                ),
                const SizedBox(height: 16),
                ...List.generate(_weekdays.length, (index) {
                  final day = _weekdays[index];
                  final workout = _schedule[day] ?? 'Rest';
                  final isRest = workout == 'Rest';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ModularCard(
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
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

