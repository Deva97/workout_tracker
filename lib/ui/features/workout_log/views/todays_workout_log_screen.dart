import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:workout_tracker/domain/models/daily_record.dart';
import 'package:workout_tracker/domain/models/daily_workout_entry.dart';
import 'package:workout_tracker/domain/models/exercise.dart';
import 'package:workout_tracker/data/services/google_drive_service.dart';
import 'package:workout_tracker/ui/core/theme/app_colors.dart';
import 'package:workout_tracker/ui/core/widgets/empty_state_widget.dart';
import 'package:workout_tracker/ui/core/widgets/modular_card.dart';
import 'package:workout_tracker/ui/core/widgets/status_badge.dart';
import 'widgets/add_workout_set_modal.dart';
import 'widgets/rest_timer_widget.dart';

class TodaysWorkoutLogScreen extends StatefulWidget {
  const TodaysWorkoutLogScreen({super.key});

  @override
  State<TodaysWorkoutLogScreen> createState() => _TodaysWorkoutLogScreenState();
}

class _TodaysWorkoutLogScreenState extends State<TodaysWorkoutLogScreen> {
  final GoogleDriveService _driveService = GoogleDriveService();

  List<DailyWorkoutEntry> _todaysEntries = [];
  List<Exercise> _availableExercises = [];
  bool _isLoading = true;
  bool _showRestTimer = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTodaysWorkoutLog();
    });
  }

  Future<void> _loadTodaysWorkoutLog() async {
    try {
      final exercises = await _driveService.getExercises();
      final entries = await _driveService.getTodaysWorkoutEntries();

      if (!mounted) return;
      setState(() {
        _availableExercises = exercises;
        _todaysEntries = entries;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading today\'s workout: $e')),
      );
    }
  }

  /// Optimistically save set: update local cache & UI immediately,
  /// background Excel upload is triggered non-blockingly.
  Future<void> _handleSaveSet(DailyRecord record, bool keepOpen) async {
    try {
      await _driveService.addDailyRecordOptimistic(record);

      // Instantly update UI from local memory and start rest timer
      final updatedEntries = _driveService.dbContext.getTodaysWorkoutEntries();
      if (!mounted) return;
      setState(() {
        _todaysEntries = updatedEntries;
        _showRestTimer = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save set: $e')),
      );
    }
  }

  /// Optimistically delete set: update local cache & UI immediately,
  /// background Excel upload is triggered non-blockingly.
  Future<void> _deleteRecord(DailyWorkoutEntry entry) async {
    final deletedRecord = entry.record;
    try {
      await _driveService.deleteDailyRecordOptimistic(entry.record.id);

      final updatedEntries = _driveService.dbContext.getTodaysWorkoutEntries();
      if (!mounted) return;
      setState(() {
        _todaysEntries = updatedEntries;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Set ${deletedRecord.set} for "${entry.exercise.name}" deleted'),
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.primaryLight,
            onPressed: () async {
              await _driveService.addDailyRecordOptimistic(deletedRecord);
              final restored = _driveService.dbContext.getTodaysWorkoutEntries();
              if (mounted) {
                setState(() => _todaysEntries = restored);
              }
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting set: $e')),
      );
    }
  }

  /// Optimistically edit set: update local cache & UI immediately,
  /// background Excel upload is triggered non-blockingly.
  Future<void> _editRecord(DailyRecord original, DailyRecord updated) async {
    try {
      await _driveService.editDailyRecordOptimistic(updated);

      final updatedEntries = _driveService.dbContext.getTodaysWorkoutEntries();
      if (!mounted) return;
      setState(() {
        _todaysEntries = updatedEntries;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update set: $e')),
      );
    }
  }

  /// Trigger manual sync to Excel
  Future<void> _triggerManualSync() async {
    final result = await _driveService.manualSyncToExcel();
    if (!mounted) return;

    if (result == SyncState.synced) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Synced with Google Drive Excel!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sync failed. Changes saved locally in cache.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _openAddSetModal([Exercise? targetExercise, DailyRecord? editRecord]) {
    int nextSetNumber = 1;
    if (targetExercise != null && editRecord == null) {
      final existingSets = _todaysEntries
          .where((entry) => entry.exercise.guid == targetExercise.guid)
          .map((entry) => entry.record.set);
      if (existingSets.isNotEmpty) {
        nextSetNumber = existingSets.reduce((a, b) => a > b ? a : b) + 1;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).bottomSheetTheme.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: AddWorkoutSetModal(
          availableExercises: _availableExercises,
          initialExercise: targetExercise,
          initialSetNumber: editRecord?.set ?? nextSetNumber,
          editRecord: editRecord,
          onSaveSet: (record, keepOpen) {
            if (editRecord != null) {
              _editRecord(editRecord, record);
            } else {
              _handleSaveSet(record, keepOpen);
            }
          },
        ),
      ),
    );
  }

  Map<String, List<DailyWorkoutEntry>> _groupEntriesByExercise() {
    final Map<String, List<DailyWorkoutEntry>> grouped = {};
    for (final entry in _todaysEntries) {
      final key = entry.exercise.guid;
      grouped.putIfAbsent(key, () => []).add(entry);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final todayFormatted = DateFormat('EEEE, MMM d').format(DateTime.now());
    final groupedEntries = _groupEntriesByExercise();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Today\'s Workout Log', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            Text(
              todayFormatted.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showRestTimer ? Icons.timer_rounded : Icons.timer_outlined,
              color: _showRestTimer ? AppColors.primary : (isDark ? Colors.white70 : AppColors.textSecondary),
            ),
            tooltip: 'Toggle Rest Timer',
            onPressed: () {
              setState(() {
                _showRestTimer = !_showRestTimer;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: ValueListenableBuilder<SyncState>(
                valueListenable: _driveService.syncStateNotifier,
                builder: (context, syncState, child) {
                  return CompactSyncButton(
                    syncState: syncState,
                    onPressed: _triggerManualSync,
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSetModal(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('Add Set', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTodaysWorkoutLog,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_showRestTimer)
                    RestTimerWidget(
                      onClose: () {
                        setState(() => _showRestTimer = false);
                      },
                    ),
                  Expanded(
                    child: _todaysEntries.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Container(
                              height: MediaQuery.of(context).size.height * 0.65,
                              padding: const EdgeInsets.all(16),
                              child: EmptyStateWidget(
                                icon: Icons.fitness_center_rounded,
                                title: 'No Workout Logged Today',
                                description:
                                    'Track your workout sets, weights, reps, and RIR for today\'s session.',
                                buttonText: 'Add First Workout Set',
                                onButtonPressed: () => _openAddSetModal(),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                            itemCount: groupedEntries.keys.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final exerciseGuid = groupedEntries.keys.elementAt(index);
                              final entries = groupedEntries[exerciseGuid]!;
                              final exercise = entries.first.exercise;

                              return Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Exercise Header Card
                                    ModularCard(
                                      title: exercise.name,
                                      subtitle: '${entries.length} ${entries.length == 1 ? 'set' : 'sets'} completed',
                                      icon: Icons.fitness_center_rounded,
                                      iconColor: AppColors.primary,
                                      badge: exercise.bodyPart.isNotEmpty
                                          ? StatusBadge.tag(
                                              label: exercise.bodyPart.toUpperCase(),
                                              color: AppColors.getMuscleColor(exercise.bodyPart),
                                            )
                                          : null,
                                      trailing: IconButton(
                                        icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 22),
                                        tooltip: 'Add set for ${exercise.name}',
                                        onPressed: () => _openAddSetModal(exercise),
                                      ),
                                      onTap: () => _openAddSetModal(exercise),
                                    ),

                                    // Tabular Set Rows
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                                      child: Column(
                                        children: [
                                          const Divider(height: 6),
                                          const SizedBox(height: 4),

                                          ...entries.map((entry) {
                                            return Dismissible(
                                              key: ValueKey(entry.record.id),
                                              direction: DismissDirection.endToStart,
                                              background: Container(
                                                alignment: Alignment.centerRight,
                                                padding: const EdgeInsets.only(right: 16),
                                                margin: const EdgeInsets.symmetric(vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: AppColors.error,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                                              ),
                                              onDismissed: (_) => _deleteRecord(entry),
                                              child: Container(
                                                margin: const EdgeInsets.symmetric(vertical: 3),
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? AppColors.surfaceDarkElevated
                                                      : const Color(0xFFF8FAFC),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: isDark
                                                        ? AppColors.cardBorderDark
                                                        : const Color(0xFFEDF2F7),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    // Set Number Badge
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        'SET ${entry.record.set}',
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w700,
                                                          fontSize: 11,
                                                          color: AppColors.primary,
                                                          letterSpacing: 0.3,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),

                                                    // Metrics: Weight & Reps & RIR
                                                    Expanded(
                                                      child: Row(
                                                        children: [
                                                          if (entry.record.weight > 0) ...[
                                                            Text(
                                                              '${entry.record.weight} kg',
                                                              style: TextStyle(
                                                                fontWeight: FontWeight.w700,
                                                                fontSize: 14,
                                                                color: isDark ? AppColors.textLight : AppColors.textPrimary,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 6),
                                                            Text(
                                                              '•',
                                                              style: TextStyle(color: isDark ? Colors.white30 : Colors.grey.shade400),
                                                            ),
                                                            const SizedBox(width: 6),
                                                          ],
                                                          Text(
                                                            '${entry.record.reps} reps',
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.w600,
                                                              fontSize: 13,
                                                              color: isDark ? AppColors.textLight : AppColors.textPrimary,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            '•',
                                                            style: TextStyle(color: isDark ? Colors.white30 : Colors.grey.shade400),
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            'RIR ${entry.record.rir}',
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.w500,
                                                              fontSize: 12,
                                                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),

                                                    // Actions: Edit & Delete
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        IconButton(
                                                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                                          visualDensity: VisualDensity.compact,
                                                          padding: const EdgeInsets.all(6),
                                                          constraints: const BoxConstraints(),
                                                          tooltip: 'Edit set',
                                                          onPressed: () => _openAddSetModal(entry.exercise, entry.record),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        IconButton(
                                                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                                          visualDensity: VisualDensity.compact,
                                                          padding: const EdgeInsets.all(6),
                                                          constraints: const BoxConstraints(),
                                                          tooltip: 'Delete set',
                                                          onPressed: () => _deleteRecord(entry),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Small compact Sync button featuring rotating sync arrows and status colors
class CompactSyncButton extends StatefulWidget {
  final SyncState syncState;
  final VoidCallback onPressed;

  const CompactSyncButton({
    required this.syncState,
    required this.onPressed,
    super.key,
  });

  @override
  State<CompactSyncButton> createState() => _CompactSyncButtonState();
}

class _CompactSyncButtonState extends State<CompactSyncButton> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (widget.syncState == SyncState.syncing) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(CompactSyncButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.syncState == SyncState.syncing && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if (widget.syncState != SyncState.syncing && _rotationController.isAnimating) {
      _rotationController.stop();
      _rotationController.reset();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color buttonColor;
    Color textColor;
    String statusText;

    switch (widget.syncState) {
      case SyncState.synced:
        buttonColor = AppColors.success.withValues(alpha: 0.12);
        textColor = AppColors.success;
        statusText = 'Synced';
      case SyncState.syncing:
        buttonColor = AppColors.primary.withValues(alpha: 0.12);
        textColor = AppColors.primary;
        statusText = 'Syncing';
      case SyncState.error:
        buttonColor = AppColors.error.withValues(alpha: 0.12);
        textColor = AppColors.error;
        statusText = 'Sync';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: buttonColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: textColor.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationController.value * 2.0 * 3.141592653589793,
                    child: Icon(
                      Icons.sync_rounded,
                      size: 14,
                      color: textColor,
                    ),
                  );
                },
              ),
              const SizedBox(width: 4),
              Text(
                statusText,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
