import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/domain/models/workout_split.dart';
import 'package:workout_tracker/ui/core/theme/app_colors.dart';
import 'package:workout_tracker/ui/core/widgets/compact_sync_button.dart';
import 'package:workout_tracker/ui/core/widgets/modular_card.dart';
import 'package:workout_tracker/ui/core/widgets/status_badge.dart';
import 'workout_schedule_page.dart';

class WorkoutSplitPage extends StatefulWidget {
  const WorkoutSplitPage({super.key});

  @override
  State<WorkoutSplitPage> createState() => _WorkoutSplitPageState();
}

class _WorkoutSplitPageState extends State<WorkoutSplitPage> {
  static const _storageKey = 'split_choice';
  static const _scheduleStorageKey = 'workout_schedule';
  static const _targetDaysStorageKey = 'split_target_days';
  static const _splitOptions = [
    'Bro Split',
    'Pull-Push Split',
    'Anterior-Posterior Split',
    'Full Body Split',
  ];

  String? _selectedSplit;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSelectedSplit();
  }

  Future<void> _loadSelectedSplit() async {
    final preferences = await SharedPreferences.getInstance();
    final savedSplit = preferences.getString(_storageKey);

    if (!mounted) return;
    setState(() {
      _selectedSplit = _splitOptions.contains(savedSplit) ? savedSplit : null;
      _isLoading = false;
    });
  }

  Future<int?> _promptWorkoutDays(
    BuildContext context, {
    required String split,
    int? currentDays,
  }) async {
    int selectedDays = currentDays ?? WorkoutSplit.getDefaultTargetDays(split);

    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text(
              'How many days are you working out?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select your weekly workout target for $split (1 to 7 days per week):',
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
                const SizedBox(height: 12),
                Text(
                  'You will be able to schedule up to $selectedDays workout ${selectedDays == 1 ? "day" : "days"} per week.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
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
                child: const Text('Continue'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _selectSplit(String split) async {
    final splitChanged = _selectedSplit != null && _selectedSplit != split;

    if (splitChanged) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Change Workout Split?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are changing your split from "$_selectedSplit" to "$split".',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Your current weekly schedule will be reset.',
                style: TextStyle(
                  color: Colors.orange[800],
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Change'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    final preferences = await SharedPreferences.getInstance();
    final currentTarget = preferences.getInt(_targetDaysStorageKey);

    if (!mounted) return;
    final chosenDays = await _promptWorkoutDays(
      context,
      split: split,
      currentDays: splitChanged ? null : currentTarget,
    );

    if (chosenDays == null || !mounted) return;

    setState(() => _selectedSplit = split);
    await preferences.setString(_storageKey, split);
    await preferences.setInt(_targetDaysStorageKey, chosenDays);

    if (splitChanged) {
      await preferences.remove(_scheduleStorageKey);
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkoutSchedulePage(
          split: split,
          initialTargetDays: chosenDays,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Workout Split', style: TextStyle(fontWeight: FontWeight.bold)),
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
              itemCount: _splitOptions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final split = _splitOptions[index];
                final isSelected = split == _selectedSplit;

                return ModularCard(
                  title: split,
                  subtitle: _getSplitDescription(split),
                  icon: isSelected ? Icons.check_circle_rounded : Icons.grid_view_rounded,
                  iconColor: isSelected ? Colors.white : AppColors.primary,
                  iconBackgroundColor: isSelected
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.1),
                  isHighlighted: isSelected,
                  badge: isSelected
                      ? StatusBadge.tag(
                          label: 'ACTIVE',
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () => _selectSplit(split),
                );
              },
            ),
    );
  }

  String _getSplitDescription(String split) {
    switch (split) {
      case 'Bro Split':
        return 'Isolate individual muscle groups (Legs, Shoulders, Chest, Back, Arms)';
      case 'Pull-Push Split':
        return 'Alternate push and pull days for upper & lower body';
      case 'Anterior-Posterior Split':
        return 'Separate front and back body workouts';
      case 'Full Body Split':
        return 'Full body workout each training session';
      default:
        return '';
    }
  }
}

